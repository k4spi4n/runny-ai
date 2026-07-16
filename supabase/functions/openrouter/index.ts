import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

import {
  AiPolicyError,
  normalizeAiRequest,
  type NormalizedAiRequest,
  providerModels,
} from "../_shared/ai_policy.ts";
import { authenticatedUserId } from "../_shared/auth.ts";
import {
  correlationId,
  corsHeaders,
  envInt,
  fetchWithTimeout,
  isAllowedBrowserOrigin,
  jsonResponse,
  readJsonBody,
  RequestBodyError,
  withIdleTimeout,
} from "../_shared/http.ts";

const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";
const CEREBRAS_ENDPOINT = "https://api.cerebras.ai/v1/chat/completions";
const OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";

const MAX_REQUEST_BYTES = 4_250_000;

type Provider = "groq" | "cerebras" | "openrouter";

interface ProviderConfig {
  provider: Provider;
  endpoint: string;
  apiKey: string;
}

function providerConfigs(): ProviderConfig[] {
  const configs: ProviderConfig[] = [];
  const groq = Deno.env.get("GROQ_API_KEY");
  const cerebras = Deno.env.get("CEREBRAS_API_KEY");
  const openRouter = Deno.env.get("OPENROUTER_API_KEY");
  if (groq) {
    configs.push({ provider: "groq", endpoint: GROQ_ENDPOINT, apiKey: groq });
  }
  if (cerebras) {
    configs.push({
      provider: "cerebras",
      endpoint: CEREBRAS_ENDPOINT,
      apiKey: cerebras,
    });
  }
  if (openRouter) {
    configs.push({
      provider: "openrouter",
      endpoint: OPENROUTER_ENDPOINT,
      apiKey: openRouter,
    });
  }
  return configs;
}

function providerBody(
  request: NormalizedAiRequest,
  provider: Provider,
  model: string,
): Record<string, unknown> {
  const body = structuredClone(request.body);
  body.model = model;
  if (provider === "openrouter") {
    body.max_tokens = body.max_completion_tokens;
    delete body.max_completion_tokens;
  }
  if (provider !== "groq") {
    const format = body.response_format as Record<string, unknown> | undefined;
    if (format?.type === "json_schema") {
      body.response_format = { type: "json_object" };
    }
  }
  return body;
}

function providerHeaders(
  config: ProviderConfig,
): Record<string, string> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "Authorization": `Bearer ${config.apiKey}`,
  };
  if (config.provider === "openrouter") {
    headers["HTTP-Referer"] = "https://runny-ai.onrender.com";
    headers["X-Title"] = "Runny AI";
  }
  return headers;
}

function successResponse(
  req: Request,
  response: Response,
  providerLabel: string,
  requestId: string,
  wantsStream: boolean,
): Response {
  const commonHeaders = {
    ...corsHeaders(req),
    "Cache-Control": "no-store",
    "X-AI-Provider": providerLabel,
    "X-Request-ID": requestId,
  };
  if (wantsStream && response.body) {
    const idleTimeout = envInt(
      "AI_STREAM_IDLE_TIMEOUT_MS",
      20_000,
      { min: 5_000, max: 60_000 },
    );
    return new Response(withIdleTimeout(response.body, idleTimeout), {
      status: 200,
      headers: {
        ...commonHeaders,
        "Content-Type": "text/event-stream; charset=utf-8",
        "Connection": "keep-alive",
      },
    });
  }
  return new Response(response.body, {
    status: 200,
    headers: {
      ...commonHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

async function callProviders(
  req: Request,
  normalized: NormalizedAiRequest,
  requestId: string,
): Promise<Response | null> {
  const timeoutMs = envInt(
    "AI_PROVIDER_TIMEOUT_MS",
    25_000,
    { min: 3_000, max: 60_000 },
  );
  const totalTimeoutMs = envInt(
    "AI_TOTAL_TIMEOUT_MS",
    55_000,
    { min: 5_000, max: 90_000 },
  );
  const deadline = Date.now() + totalTimeoutMs;

  for (const config of providerConfigs()) {
    const models = providerModels(normalized.feature, config.provider);
    for (const model of models) {
      const remainingMs = deadline - Date.now();
      if (remainingMs < 1_000) return null;
      try {
        const response = await fetchWithTimeout(
          config.endpoint,
          {
            method: "POST",
            headers: providerHeaders(config),
            body: JSON.stringify(
              providerBody(normalized, config.provider, model),
            ),
          },
          { timeoutMs: Math.min(timeoutMs, remainingMs) },
        );
        if (response.ok) {
          return successResponse(
            req,
            response,
            `${config.provider}:${model}`,
            requestId,
            normalized.wantsStream,
          );
        }
        console.warn(JSON.stringify({
          event: "ai_provider_rejected",
          request_id: requestId,
          provider: config.provider,
          model,
          feature: normalized.feature,
          status: response.status,
        }));
        await response.body?.cancel();
      } catch (error) {
        console.warn(JSON.stringify({
          event: "ai_provider_failed",
          request_id: requestId,
          provider: config.provider,
          model,
          feature: normalized.feature,
          error: error instanceof DOMException && error.name === "AbortError"
            ? "timeout"
            : "network_error",
        }));
      }
    }
  }
  return null;
}

async function checkAiAccess(
  userId: string,
  feature: "chat" | "plan" | "vision",
  requestId: string,
): Promise<{ allowed: boolean; reason?: string; tier?: string }> {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    console.error(JSON.stringify({
      event: "ai_access_misconfigured",
      request_id: requestId,
    }));
    return { allowed: false, reason: "unavailable" };
  }

  try {
    const response = await fetchWithTimeout(
      `${url}/rest/v1/rpc/check_ai_access`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          p_user_id: userId,
          p_feature: feature,
          p_max_per_min: envInt("AI_MAX_PER_MIN", 8, { max: 100 }),
          p_max_per_day: envInt("AI_MAX_PER_DAY", 30, { max: 10_000 }),
          p_free_max_per_min: envInt("AI_FREE_MAX_PER_MIN", 3, { max: 20 }),
          p_free_max_per_day: envInt("AI_FREE_MAX_PER_DAY", 5, { max: 100 }),
        }),
      },
      {
        timeoutMs: envInt(
          "AI_INTERNAL_TIMEOUT_MS",
          5_000,
          { min: 1_000, max: 15_000 },
        ),
      },
    );
    if (!response.ok) {
      await response.body?.cancel();
      return { allowed: false, reason: "unavailable" };
    }
    const data = await response.json();
    return {
      allowed: data?.allowed === true,
      reason: typeof data?.reason === "string" ? data.reason : undefined,
      tier: typeof data?.tier === "string" ? data.tier : undefined,
    };
  } catch {
    return { allowed: false, reason: "unavailable" };
  }
}

function accessDeniedResponse(
  req: Request,
  reason: string | undefined,
  requestId: string,
): Response {
  if (reason === "upgrade_required") {
    return jsonResponse(
      req,
      {
        error: "Tính năng này dành cho gói trả phí.",
        code: "upgrade_required",
      },
      402,
      { "X-Request-ID": requestId },
    );
  }
  if (reason === "minute" || reason === "day") {
    return jsonResponse(
      req,
      {
        error: reason === "day"
          ? "Bạn đã đạt giới hạn AI trong ngày."
          : "Bạn đang gửi yêu cầu quá nhanh.",
        code: "rate_limited",
      },
      429,
      { "X-Request-ID": requestId },
    );
  }
  return jsonResponse(
    req,
    { error: "Dịch vụ AI tạm thời chưa thể xác minh quyền truy cập." },
    503,
    { "X-Request-ID": requestId },
  );
}

serve(async (req) => {
  const requestId = correlationId(req);

  if (!isAllowedBrowserOrigin(req)) {
    return jsonResponse(
      req,
      { error: "Origin is not allowed." },
      403,
      { "X-Request-ID": requestId },
    );
  }
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(req),
    });
  }
  if (req.method !== "POST") {
    return jsonResponse(
      req,
      { error: "Method not allowed." },
      405,
      { "X-Request-ID": requestId },
    );
  }

  const userId = authenticatedUserId(req);
  if (!userId) {
    return jsonResponse(
      req,
      { error: "Bạn cần đăng nhập để sử dụng trợ lý AI." },
      401,
      { "X-Request-ID": requestId },
    );
  }
  if (providerConfigs().length === 0) {
    console.error(JSON.stringify({
      event: "ai_provider_misconfigured",
      request_id: requestId,
    }));
    return jsonResponse(
      req,
      { error: "Dịch vụ AI chưa được cấu hình." },
      503,
      { "X-Request-ID": requestId },
    );
  }

  try {
    const rawBody = await readJsonBody(req, MAX_REQUEST_BYTES);
    const normalized = normalizeAiRequest(rawBody);
    const access = await checkAiAccess(
      userId,
      normalized.policy.entitlementFeature,
      requestId,
    );
    if (!access.allowed) {
      return accessDeniedResponse(req, access.reason, requestId);
    }

    const response = await callProviders(req, normalized, requestId);
    if (response) return response;
    return jsonResponse(
      req,
      { error: "Nhà cung cấp AI đang bận. Vui lòng thử lại sau." },
      502,
      { "X-Request-ID": requestId },
    );
  } catch (error) {
    if (error instanceof RequestBodyError) {
      return jsonResponse(
        req,
        { error: error.message },
        error.status,
        { "X-Request-ID": requestId },
      );
    }
    if (error instanceof AiPolicyError) {
      return jsonResponse(
        req,
        { error: error.message },
        400,
        { "X-Request-ID": requestId },
      );
    }
    console.error(JSON.stringify({
      event: "ai_proxy_unhandled",
      request_id: requestId,
    }));
    return jsonResponse(
      req,
      { error: "Dịch vụ AI gặp lỗi nội bộ." },
      500,
      { "X-Request-ID": requestId },
    );
  }
});
