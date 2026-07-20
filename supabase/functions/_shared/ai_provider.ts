import {
  type AiFeature,
  type NormalizedAiRequest,
  providerModels,
} from "./ai_policy.ts";
import { envInt, fetchWithTimeout } from "./http.ts";

export type AiTier = "free" | "trial" | "paid";
export type AiProvider = "groq" | "modal" | "cerebras" | "openrouter";

export interface AiProviderConfig {
  provider: AiProvider;
  endpoint: string;
  apiKey?: string;
  modalKey?: string;
  modalSecret?: string;
}

const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";
const CEREBRAS_ENDPOINT = "https://api.cerebras.ai/v1/chat/completions";
const OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";

const PRIVILEGED_ORDER: readonly AiProvider[] = [
  "groq",
  "modal",
  "cerebras",
  "openrouter",
];
const FREE_ORDER: readonly AiProvider[] = [
  "groq",
  "cerebras",
  "openrouter",
  "modal",
];
const VISION_ORDER: readonly AiProvider[] = [
  "groq",
  "cerebras",
  "modal",
  "openrouter",
];

interface ProviderHealth {
  failures: number;
  openUntil: number;
}

// Edge isolates are short lived, but this still prevents a burst from repeatedly
// hammering a provider that has just started returning retryable failures.
const providerHealth = new Map<AiProvider, ProviderHealth>();

export function providerSequence(
  feature: AiFeature,
  tier: AiTier,
): AiProvider[] {
  if (feature === "activity_screenshot" || feature === "food_recognition") {
    return [...VISION_ORDER];
  }
  if (
    feature === "onboarding_goals" ||
    feature === "training_plan" ||
    tier !== "free"
  ) {
    return [...PRIVILEGED_ORDER];
  }
  return [...FREE_ORDER];
}

export function modalChatCompletionsUrl(raw: string): string {
  const base = raw.trim().replace(/\/+$/, "");
  if (!base) return "";
  if (base.endsWith("/v1/chat/completions")) return base;
  if (base.endsWith("/v1")) return `${base}/chat/completions`;
  return `${base}/v1/chat/completions`;
}

function configuredProviders(): Map<AiProvider, AiProviderConfig> {
  const providers = new Map<AiProvider, AiProviderConfig>();
  const groq = Deno.env.get("GROQ_API_KEY")?.trim();
  const cerebras = Deno.env.get("CEREBRAS_API_KEY")?.trim();
  const openRouter = Deno.env.get("OPENROUTER_API_KEY")?.trim();
  const modalEndpoint = modalChatCompletionsUrl(
    Deno.env.get("MODAL_ENDPOINT_URL") ?? "",
  );
  const modalKey = Deno.env.get("MODAL_PROXY_TOKEN_ID")?.trim();
  const modalSecret = Deno.env.get("MODAL_PROXY_TOKEN_SECRET")?.trim();

  if (groq) {
    providers.set("groq", {
      provider: "groq",
      endpoint: GROQ_ENDPOINT,
      apiKey: groq,
    });
  }
  if (modalEndpoint && modalKey && modalSecret) {
    providers.set("modal", {
      provider: "modal",
      endpoint: modalEndpoint,
      modalKey,
      modalSecret,
    });
  }
  if (cerebras) {
    providers.set("cerebras", {
      provider: "cerebras",
      endpoint: CEREBRAS_ENDPOINT,
      apiKey: cerebras,
    });
  }
  if (openRouter) {
    providers.set("openrouter", {
      provider: "openrouter",
      endpoint: OPENROUTER_ENDPOINT,
      apiKey: openRouter,
    });
  }
  return providers;
}

export function providerConfigs(
  feature: AiFeature,
  tier: AiTier,
): AiProviderConfig[] {
  const configured = configuredProviders();
  return providerSequence(feature, tier)
    .map((provider) => configured.get(provider))
    .filter((config): config is AiProviderConfig => config != null)
    .filter((config) => providerModels(feature, config.provider).length > 0);
}

export function providerHeaders(
  config: AiProviderConfig,
): Record<string, string> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (config.provider === "modal") {
    headers["Modal-Key"] = config.modalKey!;
    headers["Modal-Secret"] = config.modalSecret!;
  } else {
    headers.Authorization = `Bearer ${config.apiKey}`;
  }
  if (config.provider === "openrouter") {
    headers["HTTP-Referer"] = "https://runny-ai.onrender.com";
    headers["X-Title"] = "Runny AI";
  }
  return headers;
}

const SCHEMA_CONTRACT_LABEL = "Schema JSON bắt buộc:";

function appendCanonicalSchemaContract(body: Record<string, unknown>): void {
  const format = body.response_format as Record<string, unknown> | undefined;
  const jsonSchema = format?.json_schema as
    | Record<string, unknown>
    | undefined;
  const schema = jsonSchema?.schema;
  if (!schema || typeof schema !== "object") return;

  const messages = body.messages;
  if (!Array.isArray(messages)) return;
  const system = messages.find((message) =>
    message && typeof message === "object" &&
    (message as Record<string, unknown>).role === "system"
  ) as Record<string, unknown> | undefined;
  if (!system || typeof system.content !== "string") return;
  if (system.content.includes(SCHEMA_CONTRACT_LABEL)) return;
  system.content += `\n${SCHEMA_CONTRACT_LABEL}${JSON.stringify(schema)}`;
}

function preservesJsonSchema(provider: AiProvider, model: string): boolean {
  if (provider === "modal") return true;
  if (provider === "groq") return model.startsWith("openai/gpt-oss-");
  return false;
}

export function providerBody(
  request: NormalizedAiRequest,
  provider: AiProvider,
  model: string,
): Record<string, unknown> {
  const body = structuredClone(request.body);
  body.model = provider === "modal"
    ? (Deno.env.get("MODAL_MODEL")?.trim() || model)
    : model;

  if (provider === "modal" || provider === "openrouter") {
    body.max_tokens = body.max_completion_tokens;
    delete body.max_completion_tokens;
  }
  if (provider === "groq" && request.policy.allowImages) {
    // Qwen vision supports JSON Object Mode, but Groq documents that this
    // best-effort mode may still fail server-side JSON validation. Keep the
    // canonical schema in the prompt and validate locally instead.
    appendCanonicalSchemaContract(body);
    delete body.response_format;
    body.reasoning_effort = "none";
  }
  const format = body.response_format as Record<string, unknown> | undefined;
  if (
    format?.type === "json_schema" &&
    !preservesJsonSchema(provider, String(body.model))
  ) {
    appendCanonicalSchemaContract(body);
    body.response_format = { type: "json_object" };
  }
  return body;
}

export function modal503RetryDelayMs(retriesCompleted: number): number {
  return Math.min(8_000, 1_000 * 2 ** Math.max(0, retriesCompleted));
}

export async function fetchAiProvider(
  config: AiProviderConfig,
  body: Record<string, unknown>,
  timeoutMs: number,
): Promise<Response> {
  const deadline = Date.now() + timeoutMs;
  const maxModal503Retries = envInt("AI_MODAL_503_RETRIES", 4, {
    min: 0,
    max: 8,
  });
  let retriesCompleted = 0;

  while (true) {
    const remainingMs = deadline - Date.now();
    if (remainingMs < 1_000) {
      throw new DOMException("Provider request timed out.", "AbortError");
    }
    const response = await fetchWithTimeout(
      config.endpoint,
      {
        method: "POST",
        headers: providerHeaders(config),
        body: JSON.stringify(body),
      },
      { timeoutMs: remainingMs },
    );
    if (
      config.provider !== "modal" || response.status !== 503 ||
      retriesCompleted >= maxModal503Retries
    ) {
      return response;
    }

    const delayMs = modal503RetryDelayMs(retriesCompleted);
    if (deadline - Date.now() < delayMs + 1_000) return response;
    await response.body?.cancel();
    await new Promise((resolve) => setTimeout(resolve, delayMs));
    retriesCompleted++;
  }
}

export function providerTimeoutMs(provider: AiProvider): number {
  const defaults: Record<AiProvider, number> = {
    groq: 18_000,
    modal: 65_000,
    cerebras: 18_000,
    openrouter: 25_000,
  };
  return envInt(
    `AI_${provider.toUpperCase()}_TIMEOUT_MS`,
    defaults[provider],
    { min: 3_000, max: 120_000 },
  );
}

export function isProviderCircuitOpen(provider: AiProvider): boolean {
  const health = providerHealth.get(provider);
  if (!health) return false;
  if (health.openUntil === 0) return false;
  if (health.openUntil <= Date.now()) {
    providerHealth.delete(provider);
    return false;
  }
  return true;
}

export function recordProviderSuccess(provider: AiProvider): void {
  providerHealth.delete(provider);
}

export function recordProviderFailure(
  provider: AiProvider,
  retryable: boolean,
): void {
  if (!retryable) return;
  const previous = providerHealth.get(provider) ??
    { failures: 0, openUntil: 0 };
  const failures = previous.failures + 1;
  const threshold = envInt("AI_CIRCUIT_FAILURE_THRESHOLD", 3, {
    min: 2,
    max: 10,
  });
  providerHealth.set(provider, {
    failures,
    openUntil: failures >= threshold
      ? Date.now() + envInt("AI_CIRCUIT_COOLDOWN_MS", 30_000, {
        min: 5_000,
        max: 300_000,
      })
      : 0,
  });
}

export function isRetryableProviderStatus(status: number): boolean {
  return status === 408 || status === 409 || status === 429 || status >= 500;
}
