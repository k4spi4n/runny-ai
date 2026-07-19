import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

import { normalizeAiRequest, providerModels } from "./ai_policy.ts";
import {
  type AiTier,
  isProviderCircuitOpen,
  isRetryableProviderStatus,
  providerBody,
  providerConfigs,
  providerHeaders,
  providerTimeoutMs,
  recordProviderFailure,
  recordProviderSuccess,
} from "./ai_provider.ts";
import {
  correlationId,
  envInt,
  fetchWithTimeout,
  readTextLimited,
} from "./http.ts";

export interface TrainingPlanJob {
  id: string;
  user_id: string;
  schedule_id: string;
  goal: string;
  start_date: string;
  end_date?: string | null;
  attempts: number;
}

// deno-lint-ignore no-explicit-any
type ServiceClient = any;

const PLAN_RESPONSE_FORMAT = {
  type: "json_schema",
  json_schema: {
    name: "training_plan",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        title: { type: "string" },
        target_distance_km: { type: "number" },
        target_pace_min_per_km: { type: "number" },
        weeks: { type: "integer" },
        workouts: {
          type: "array",
          minItems: 1,
          maxItems: 200,
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              day_offset: { type: "integer" },
              title: { type: "string" },
              description: { type: "string" },
              target_distance_km: { type: "number" },
              target_duration_min: { type: "number" },
              target_pace_min_per_km: { type: "number" },
              source: { type: "string", enum: ["ai"] },
              workout_type: {
                type: "string",
                enum: [
                  "easy_run",
                  "long_run",
                  "interval",
                  "tempo",
                  "recovery",
                ],
              },
              start_time: {
                type: "string",
                pattern: "^(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$",
              },
            },
            required: [
              "day_offset",
              "title",
              "description",
              "target_distance_km",
              "target_duration_min",
              "target_pace_min_per_km",
              "source",
              "workout_type",
              "start_time",
            ],
          },
        },
      },
      required: [
        "title",
        "target_distance_km",
        "target_pace_min_per_km",
        "weeks",
        "workouts",
      ],
    },
  },
} as const;

function serviceClient(): ServiceClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("training_plan_service_not_configured");
  return createClient(url, key);
}

function planFromProviderPayload(payload: unknown): Record<string, unknown> {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("training_plan_provider_shape");
  }
  const choices = (payload as Record<string, unknown>).choices;
  if (!Array.isArray(choices) || choices.length === 0) {
    throw new Error("training_plan_provider_shape");
  }
  const message = (choices[0] as Record<string, unknown> | undefined)?.message;
  if (!message || typeof message !== "object" || Array.isArray(message)) {
    throw new Error("training_plan_provider_shape");
  }
  const content = (message as Record<string, unknown>).content;
  if (typeof content !== "string" || content.length > 750_000) {
    throw new Error("training_plan_provider_shape");
  }
  let decoded: unknown;
  const cleaned = content.replace(/<think>[\s\S]*?<\/think>/gi, "").trim();
  try {
    decoded = JSON.parse(cleaned);
  } catch {
    const start = cleaned.indexOf("{");
    const end = cleaned.lastIndexOf("}");
    if (start < 0 || end <= start) {
      throw new Error("training_plan_invalid_json");
    }
    try {
      decoded = JSON.parse(cleaned.slice(start, end + 1));
    } catch {
      throw new Error("training_plan_invalid_json");
    }
  }
  if (!decoded || typeof decoded !== "object" || Array.isArray(decoded)) {
    throw new Error("training_plan_invalid_json");
  }
  return decoded as Record<string, unknown>;
}

async function callPlanProvider(
  prompt: string,
  requestId: string,
  tier: AiTier,
): Promise<Record<string, unknown>> {
  const normalized = normalizeAiRequest({
    feature: "training_plan",
    messages: [{ role: "user", content: prompt }],
    response_format: PLAN_RESPONSE_FORMAT,
  });
  const totalTimeoutMs = envInt(
    "TRAINING_PLAN_AI_TOTAL_TIMEOUT_MS",
    180_000,
    { min: 30_000, max: 280_000 },
  );
  const deadline = Date.now() + totalTimeoutMs;

  for (const config of providerConfigs("training_plan", tier)) {
    if (isProviderCircuitOpen(config.provider)) continue;
    for (const model of providerModels("training_plan", config.provider)) {
      const remainingMs = deadline - Date.now();
      if (remainingMs < 1_000) {
        throw new Error("training_plan_provider_timeout");
      }
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
          {
            timeoutMs: Math.min(
              providerTimeoutMs(config.provider),
              remainingMs,
            ),
          },
        );
        if (!response.ok) {
          recordProviderFailure(
            config.provider,
            isRetryableProviderStatus(response.status),
          );
          await response.body?.cancel();
          console.warn(JSON.stringify({
            event: "training_plan_provider_rejected",
            request_id: requestId,
            provider: config.provider,
            model,
            status: response.status,
          }));
          continue;
        }
        const text = await readTextLimited(response, 1_000_000);
        const plan = planFromProviderPayload(JSON.parse(text));
        recordProviderSuccess(config.provider);
        return plan;
      } catch (error) {
        recordProviderFailure(config.provider, true);
        console.warn(JSON.stringify({
          event: "training_plan_provider_failed",
          request_id: requestId,
          provider: config.provider,
          model,
          reason: error instanceof DOMException && error.name === "AbortError"
            ? "timeout"
            : "invalid_or_network",
        }));
      }
    }
  }
  throw new Error("training_plan_provider_unavailable");
}

async function resolveAiTier(
  supabase: ServiceClient,
  userId: string,
): Promise<AiTier> {
  const now = new Date();
  const [subscriptionResult, profileResult] = await Promise.all([
    supabase
      .from("user_subscriptions")
      .select("end_date")
      .eq("user_id", userId)
      .eq("status", "active")
      .gt("end_date", now.toISOString())
      .limit(1)
      .maybeSingle(),
    supabase
      .from("profiles")
      .select("trial_ends_at")
      .eq("id", userId)
      .maybeSingle(),
  ]);
  if (subscriptionResult.error || profileResult.error) {
    throw new Error("training_plan_tier_read_failed");
  }
  if (subscriptionResult.data) return "paid";
  const trialEnd = profileResult.data?.trial_ends_at;
  if (typeof trialEnd === "string" && new Date(trialEnd) > now) return "trial";
  return "free";
}

async function buildPlanPrompt(
  supabase: ServiceClient,
  job: TrainingPlanJob,
): Promise<string> {
  const [profileResult, activitiesResult, scheduleResult] = await Promise.all([
    supabase
      .from("profiles")
      .select("gender,weight_kg,height_cm,bmi,max_hr,preferred_pace_min_per_km")
      .eq("id", job.user_id)
      .single(),
    supabase
      .from("activities")
      .select("started_at,distance_km,duration_min,avg_hr,elevation_gain_m")
      .eq("user_id", job.user_id)
      .order("started_at", { ascending: false })
      .limit(5),
    supabase
      .from("training_schedules")
      .select("id")
      .eq("user_id", job.user_id)
      .eq("status", "active")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);
  if (profileResult.error || activitiesResult.error || scheduleResult.error) {
    throw new Error("training_plan_context_read_failed");
  }

  let manualWorkouts: unknown[] = [];
  const activeScheduleId = scheduleResult.data?.id;
  if (typeof activeScheduleId === "string") {
    const manualResult = await supabase
      .from("scheduled_workouts")
      .select(
        "date,title,description,target_distance_km,target_duration_min,target_pace_min_per_km,workout_type,start_time",
      )
      .eq("schedule_id", activeScheduleId)
      .eq("source", "manual")
      .gte("date", job.start_date)
      .order("date", { ascending: true })
      .limit(100);
    if (manualResult.error) {
      throw new Error("training_plan_context_read_failed");
    }
    manualWorkouts = manualResult.data ?? [];
  }

  return `
Tạo một lịch chạy bộ an toàn bằng tiếng Việt.

Mục tiêu: ${job.goal}
Ngày bắt đầu: ${job.start_date}
Ngày kết thúc: ${job.end_date ?? "AI tự chọn, tối đa 52 tuần"}
Hồ sơ: ${JSON.stringify(profileResult.data)}
5 hoạt động gần nhất: ${JSON.stringify(activitiesResult.data ?? [])}
Các buổi manual bắt buộc giữ nguyên trong DB: ${JSON.stringify(manualWorkouts)}

Quy tắc:
- Chỉ trả về JSON đúng schema. Mảng workouts chỉ chứa buổi source="ai";
  máy chủ sẽ tự sao chép các buổi manual.
- day_offset tính từ ngày bắt đầu, không âm, không vượt ngày kết thúc.
- Không xếp buổi AI trùng ngày với bất kỳ buổi manual nào ở trên.
- Không quá một buổi AI mỗi ngày.
- workout_type chỉ là easy_run, long_run, interval, tempo hoặc recovery.
- start_time dùng HH:mm:ss.
- Số liệu dùng km, phút và phút/km; phải dương, thực tế và tương thích nhau.
- Không xếp hai bài nặng liên tiếp. Tăng tải bảo thủ dựa trên lịch sử; nếu dữ
  liệu ít thì ưu tiên easy/recovery và cự ly thấp.
`.trim();
}

function safeJobError(error: unknown): string {
  if (
    error instanceof Error &&
    /^[a-z0-9_]{1,100}$/.test(error.message)
  ) {
    return error.message;
  }
  return "training_plan_failed";
}

async function finishFailed(
  supabase: ServiceClient,
  jobId: string,
  error: unknown,
): Promise<void> {
  const result = await supabase.rpc("finish_training_plan_job", {
    p_job_id: jobId,
    p_error: safeJobError(error),
  });
  if (result.error) throw new Error("training_plan_finish_failed");
}

export async function processClaimedTrainingPlanJob(
  supabase: ServiceClient,
  job: TrainingPlanJob,
): Promise<void> {
  const requestId = correlationId();
  try {
    const tier = await resolveAiTier(supabase, job.user_id);
    if (providerConfigs("training_plan", tier).length === 0) {
      throw new Error("training_plan_provider_not_configured");
    }
    const prompt = await buildPlanPrompt(supabase, job);
    const plan = await callPlanProvider(prompt, requestId, tier);
    const result = await supabase.rpc("complete_training_plan_job", {
      p_job_id: job.id,
      p_plan: plan,
    });
    if (result.error) throw new Error("training_plan_persist_failed");
    console.log(JSON.stringify({
      event: "training_plan_completed",
      request_id: requestId,
      job_id: job.id,
      attempt: job.attempts,
    }));
  } catch (error) {
    await finishFailed(supabase, job.id, error);
    console.warn(JSON.stringify({
      event: "training_plan_attempt_failed",
      request_id: requestId,
      job_id: job.id,
      attempt: job.attempts,
      reason: safeJobError(error),
    }));
  }
}

export async function processTrainingPlanJob(jobId: string): Promise<void> {
  const supabase = serviceClient();
  const { data, error } = await supabase.rpc("claim_training_plan_job", {
    p_job_id: jobId,
  });
  const job = Array.isArray(data)
    ? data[0] as TrainingPlanJob | undefined
    : undefined;
  if (error || !job) return;
  await processClaimedTrainingPlanJob(supabase, job);
}

export async function processPendingTrainingPlanJobs(
  limit = 2,
): Promise<number> {
  const supabase = serviceClient();
  const { data, error } = await supabase.rpc(
    "claim_next_training_plan_jobs",
    { p_limit: limit },
  );
  if (error) throw new Error("training_plan_claim_failed");
  const jobs = Array.isArray(data) ? data as TrainingPlanJob[] : [];
  for (const job of jobs) {
    await processClaimedTrainingPlanJob(supabase, job);
  }
  return jobs.length;
}
