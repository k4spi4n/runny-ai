import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

import {
  AiPolicyError,
  normalizeAiRequest,
  type NormalizedAiRequest,
  providerModels,
} from "../_shared/ai_policy.ts";
import {
  type AiTier,
  fetchAiProvider,
  isProviderCircuitOpen,
  isRetryableProviderStatus,
  providerBody,
  providerConfigs,
  providerTimeoutMs,
  recordProviderFailure,
  recordProviderSuccess,
} from "../_shared/ai_provider.ts";
import { authenticatedUserId } from "../_shared/auth.ts";
import {
  correlationId,
  corsHeaders,
  envInt,
  fetchWithTimeout,
  isAllowedBrowserOrigin,
  jsonResponse,
  readJsonBody,
  readTextLimited,
  RequestBodyError,
  withIdleTimeout,
} from "../_shared/http.ts";

const MAX_REQUEST_BYTES = 4_250_000;

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
  tier: AiTier,
): Promise<Response | null> {
  const totalTimeoutMs = envInt(
    "AI_TOTAL_TIMEOUT_MS",
    100_000,
    { min: 10_000, max: 180_000 },
  );
  const deadline = Date.now() + totalTimeoutMs;

  for (const config of providerConfigs(normalized.feature, tier)) {
    if (isProviderCircuitOpen(config.provider)) {
      console.warn(JSON.stringify({
        event: "ai_provider_circuit_open",
        request_id: requestId,
        provider: config.provider,
        feature: normalized.feature,
      }));
      continue;
    }
    const models = providerModels(normalized.feature, config.provider);
    for (const model of models) {
      const remainingMs = deadline - Date.now();
      if (remainingMs < 1_000) return null;
      try {
        const response = await fetchAiProvider(
          config,
          providerBody(normalized, config.provider, model),
          Math.min(providerTimeoutMs(config.provider), remainingMs),
        );
        if (response.ok) {
          if (!normalized.wantsStream && normalized.policy.structuredOutput) {
            const text = await readTextLimited(response, 1_000_000);
            try {
              const payload = JSON.parse(text);
              const content = payload?.choices?.[0]?.message?.content;
              if (typeof content !== "string") throw new Error("no_content");
              const start = content.indexOf("{");
              const end = content.lastIndexOf("}");
              if (start < 0 || end <= start) throw new Error("no_json");
              JSON.parse(content.slice(start, end + 1));
            } catch {
              recordProviderFailure(config.provider, true);
              console.warn(JSON.stringify({
                event: "ai_provider_invalid_structured_output",
                request_id: requestId,
                provider: config.provider,
                model,
                feature: normalized.feature,
              }));
              continue;
            }
            recordProviderSuccess(config.provider);
            return successResponse(
              req,
              new Response(text, {
                status: response.status,
                headers: response.headers,
              }),
              `${config.provider}:${model}`,
              requestId,
              false,
            );
          }
          recordProviderSuccess(config.provider);
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
        recordProviderFailure(
          config.provider,
          isRetryableProviderStatus(response.status),
        );
        await response.body?.cancel();
      } catch (error) {
        recordProviderFailure(config.provider, true);
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
  feature: "onboarding" | "chat" | "plan" | "vision" | "food",
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
          p_max_per_min: envInt(
            `AI_${feature.toUpperCase()}_MAX_PER_MIN`,
            feature === "plan" ? 3 : feature === "vision" ? 4 : 12,
            { max: 100 },
          ),
          p_max_per_day: envInt(
            `AI_${feature.toUpperCase()}_MAX_PER_DAY`,
            feature === "plan" ? 30 : feature === "vision" ? 40 : 200,
            { max: 10_000 },
          ),
          p_free_max_per_min: envInt(
            `AI_FREE_${feature.toUpperCase()}_MAX_PER_MIN`,
            1,
            { max: 10 },
          ),
          p_free_max_per_day: envInt(
            `AI_FREE_${feature.toUpperCase()}_MAX_PER_DAY`,
            feature === "chat" ? 8 : feature === "onboarding" ? 2 : 1,
            { max: 50 },
          ),
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

    const tier: AiTier = access.tier === "free"
      ? "free"
      : access.tier === "paid"
      ? "paid"
      : "trial";
    const response = await callProviders(req, normalized, requestId, tier);
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
