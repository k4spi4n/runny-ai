import { normalizeAiRequest } from "./ai_policy.ts";
import {
  modalChatCompletionsUrl,
  providerBody,
  providerHeaders,
  providerSequence,
} from "./ai_provider.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function systemContent(body: Record<string, unknown>): string {
  const messages = body.messages as Record<string, unknown>[];
  const content = messages?.find((message) => message.role === "system")
    ?.content;
  assert(typeof content === "string", "provider system prompt missing");
  return content;
}

function occurrences(value: string, needle: string): number {
  return value.split(needle).length - 1;
}

Deno.test("onboarding and paid tiers place Modal immediately after Groq", () => {
  assert(
    providerSequence("onboarding_goals", "free").join(",") ===
      "groq,modal,cerebras,openrouter",
    "free onboarding order changed",
  );
  assert(
    providerSequence("training_plan", "free").join(",") ===
      "groq,modal,cerebras,openrouter",
    "onboarding plan order changed",
  );
  assert(
    providerSequence("chat", "paid").join(",") ===
      "groq,modal,cerebras,openrouter",
    "paid order changed",
  );
  assert(
    providerSequence("activity_screenshot", "trial").join(",") ===
      "groq,modal,cerebras,openrouter",
    "trial vision order changed",
  );
});

Deno.test("free non-onboarding features reserve Modal as fourth provider", () => {
  for (
    const feature of [
      "chat",
      "activity_screenshot",
      "food_recognition",
    ] as const
  ) {
    assert(
      providerSequence(feature, "free").join(",") ===
        "groq,cerebras,openrouter,modal",
      `free provider order changed for ${feature}`,
    );
  }
});

Deno.test("Modal endpoint URL and proxy authentication are normalized", () => {
  assert(
    modalChatCompletionsUrl("https://example.modal.direct/") ===
      "https://example.modal.direct/v1/chat/completions",
    "base endpoint was not normalized",
  );
  assert(
    modalChatCompletionsUrl("https://example.modal.direct/v1") ===
      "https://example.modal.direct/v1/chat/completions",
    "v1 endpoint was not normalized",
  );
  const headers = providerHeaders({
    provider: "modal",
    endpoint: "https://example.modal.direct/v1/chat/completions",
    modalKey: "wk-test",
    modalSecret: "ws-test",
  });
  assert(headers["Modal-Key"] === "wk-test", "Modal-Key missing");
  assert(headers["Modal-Secret"] === "ws-test", "Modal-Secret missing");
  assert(headers.Authorization == null, "Bearer auth leaked into Modal call");
});

Deno.test("schema-capable providers preserve the canonical response format", () => {
  const normalized = normalizeAiRequest({
    feature: "training_plan",
    messages: [{ role: "user", content: "Tạo lịch chạy 5 km an toàn." }],
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "small_plan",
        schema: { type: "object" },
      },
    },
  });
  const body = providerBody(
    normalized,
    "modal",
    "Qwen/Qwen3.5-27B-FP8",
  );
  assert(body.max_tokens === 4096, "Modal max_tokens missing");
  assert(
    body.max_completion_tokens == null,
    "unsupported Modal max_completion_tokens was retained",
  );
  const format = body.response_format as Record<string, unknown>;
  assert(format.type === "json_schema", "Modal JSON schema was downgraded");
  const jsonSchema = format.json_schema as Record<string, unknown>;
  assert(
    jsonSchema.name === "training_plan",
    "caller schema replaced the server contract",
  );
  assert(
    !systemContent(body).includes("Schema JSON bắt buộc:"),
    "native JSON schema was redundantly copied into the prompt",
  );

  const groqBody = providerBody(
    normalized,
    "groq",
    "openai/gpt-oss-120b",
  );
  const groqFormat = groqBody.response_format as Record<string, unknown>;
  assert(
    groqFormat.type === "json_schema",
    "Groq GPT-OSS schema was downgraded",
  );
  assert(
    !systemContent(groqBody).includes("Schema JSON bắt buộc:"),
    "Groq GPT-OSS schema was redundantly copied into the prompt",
  );
});

Deno.test("OpenRouter downgrade retains exactly one canonical schema contract", () => {
  const normalized = normalizeAiRequest({
    feature: "onboarding_goals",
    messages: [{ role: "user", content: "input" }],
  });
  const body = providerBody(normalized, "openrouter", "openrouter/free");
  const format = body.response_format as Record<string, unknown>;
  assert(format.type === "json_object", "OpenRouter format was not downgraded");
  const system = systemContent(body);
  assert(
    occurrences(system, "Schema JSON bắt buộc:") === 1,
    "canonical schema contract was not appended exactly once",
  );
  assert(system.includes('"goals"'), "fallback lost onboarding schema fields");
  assert(
    !system.includes("Giờ Việt Nam:"),
    "fallback added irrelevant time context",
  );
});

Deno.test("Groq models without strict-schema support receive one fallback contract", () => {
  const image = `data:image/png;base64,${btoa("small activity image")}`;
  const normalized = normalizeAiRequest({
    feature: "activity_screenshot",
    messages: [{
      role: "user",
      content: [{ type: "image_url", image_url: { url: image } }],
    }],
  });
  const body = providerBody(normalized, "groq", "qwen/qwen3.6-27b");
  const format = body.response_format as Record<string, unknown>;
  assert(
    format.type === "json_object",
    "Groq vision format was not downgraded",
  );
  const system = systemContent(body);
  assert(
    occurrences(system, "Schema JSON bắt buộc:") === 1,
    "Groq vision fallback schema was not appended exactly once",
  );
  assert(
    system.includes('"is_activity"'),
    "vision fallback lost schema fields",
  );
});

Deno.test("Groq food fallback removes response_format but retains its schema", () => {
  const image = `data:image/jpeg;base64,${btoa("small food image")}`;
  const normalized = normalizeAiRequest({
    feature: "food_recognition",
    messages: [{
      role: "user",
      content: [{ type: "image_url", image_url: { url: image } }],
    }],
  });
  const body = providerBody(normalized, "groq", "qwen/qwen3.6-27b");
  assert(
    body.response_format == null,
    "Groq food response_format was retained",
  );
  assert(body.reasoning_effort === "none", "Groq food reasoning was enabled");
  const system = systemContent(body);
  assert(
    occurrences(system, "Schema JSON bắt buộc:") === 1,
    "food fallback schema was not appended exactly once",
  );
  assert(system.includes('"is_food"'), "food fallback lost canonical fields");
  assert(
    system.includes("chỉ dẫn trong ảnh"),
    "food image-instruction defense was lost",
  );
});
