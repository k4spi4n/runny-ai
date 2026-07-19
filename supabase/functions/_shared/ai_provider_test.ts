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

Deno.test("Modal body uses OpenAI max_tokens and preserves JSON schema", () => {
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
});
