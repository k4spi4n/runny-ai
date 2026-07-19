import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

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
} from "../_shared/http.ts";
import { processTrainingPlanJob } from "../_shared/training_plan.ts";

const MAX_BODY_BYTES = 8_192;

function serviceConfig(): { url: string; key: string } | null {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  return url && key ? { url, key } : null;
}

async function rpc(
  config: { url: string; key: string },
  name: string,
  body: Record<string, unknown>,
): Promise<{ ok: boolean; status: number; data: unknown }> {
  const response = await fetchWithTimeout(
    `${config.url}/rest/v1/rpc/${name}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: config.key,
        Authorization: `Bearer ${config.key}`,
      },
      body: JSON.stringify(body),
    },
    {
      timeoutMs: envInt(
        "AI_INTERNAL_TIMEOUT_MS",
        5_000,
        { min: 1_000, max: 15_000 },
      ),
    },
  );
  const text = await readTextLimited(response, 64_000);
  let data: unknown = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = null;
  }
  return { ok: response.ok, status: response.status, data };
}

function errorMessage(data: unknown): string {
  if (!data || typeof data !== "object" || Array.isArray(data)) return "";
  const message = (data as Record<string, unknown>).message;
  return typeof message === "string" ? message : "";
}

function dateString(value: unknown, required: boolean): string | null {
  if (value == null && !required) return null;
  if (
    typeof value !== "string" ||
    !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
    Number.isNaN(Date.parse(`${value}T00:00:00Z`))
  ) {
    throw new RequestBodyError("Invalid plan date.", 400);
  }
  return value;
}

serve(async (req) => {
  const requestId = correlationId(req);
  if (!isAllowedBrowserOrigin(req)) {
    return jsonResponse(req, { error: "Origin is not allowed." }, 403);
  }
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  if (req.method !== "POST") {
    return jsonResponse(req, { error: "Method not allowed." }, 405);
  }
  const userId = authenticatedUserId(req);
  if (!userId) {
    return jsonResponse(req, { error: "Authentication required." }, 401);
  }
  const config = serviceConfig();
  if (!config) {
    return jsonResponse(
      req,
      { error: "Training plan service is unavailable." },
      503,
    );
  }

  try {
    const body = await readJsonBody(req, MAX_BODY_BYTES);
    const goal = typeof body.goal === "string" ? body.goal.trim() : "";
    const idempotencyKey = typeof body.idempotency_key === "string"
      ? body.idempotency_key.trim()
      : "";
    if (
      goal.length < 10 ||
      goal.length > 4_000 ||
      !/^[A-Za-z0-9._:-]{16,120}$/.test(idempotencyKey)
    ) {
      throw new RequestBodyError("Invalid training plan request.", 400);
    }
    const startDate = dateString(body.start_date, true)!;
    const endDate = dateString(body.end_date, false);

    const access = await rpc(config, "check_ai_access", {
      p_user_id: userId,
      p_feature: "plan",
      p_max_per_min: envInt("AI_PLAN_MAX_PER_MIN", 3, { max: 30 }),
      p_max_per_day: envInt("AI_PLAN_MAX_PER_DAY", 30, { max: 500 }),
      p_free_max_per_min: envInt(
        "AI_FREE_PLAN_MAX_PER_MIN",
        1,
        { max: 5 },
      ),
      p_free_max_per_day: envInt(
        "AI_FREE_PLAN_MAX_PER_DAY",
        1,
        { max: 10 },
      ),
    });
    const accessData = access.data as Record<string, unknown> | null;
    if (!access.ok || accessData?.allowed !== true) {
      const reason = accessData?.reason;
      if (reason === "upgrade_required") {
        return jsonResponse(
          req,
          {
            error: "Tính năng này dành cho gói trả phí.",
            code: "upgrade_required",
          },
          402,
        );
      }
      if (reason === "minute" || reason === "day") {
        return jsonResponse(
          req,
          { error: "Đã đạt giới hạn tạo lịch tập.", code: "rate_limited" },
          429,
        );
      }
      return jsonResponse(
        req,
        { error: "Không thể xác minh quyền tạo lịch tập." },
        503,
      );
    }

    const enqueued = await rpc(config, "enqueue_training_plan_job", {
      p_user_id: userId,
      p_goal: goal,
      p_start_date: startDate,
      p_end_date: endDate,
      p_idempotency_key: idempotencyKey,
    });
    if (!enqueued.ok) {
      const message = errorMessage(enqueued.data);
      if (message.includes("upgrade_required")) {
        return jsonResponse(
          req,
          {
            error: "Tính năng này dành cho gói trả phí.",
            code: "upgrade_required",
          },
          402,
        );
      }
      console.error(JSON.stringify({
        event: "training_plan_enqueue_failed",
        request_id: requestId,
        status: enqueued.status,
      }));
      return jsonResponse(
        req,
        { error: "Không thể bắt đầu tạo lịch tập." },
        503,
      );
    }
    const row = Array.isArray(enqueued.data)
      ? enqueued.data[0] as Record<string, unknown> | undefined
      : undefined;
    const jobId = typeof row?.job_id === "string" ? row.job_id : null;
    const scheduleId = typeof row?.schedule_id === "string"
      ? row.schedule_id
      : null;
    if (!jobId || !scheduleId) {
      return jsonResponse(
        req,
        { error: "Không thể bắt đầu tạo lịch tập." },
        503,
      );
    }

    const task = processTrainingPlanJob(jobId);
    // deno-lint-ignore no-explicit-any
    const edgeRuntime = (globalThis as any).EdgeRuntime;
    if (edgeRuntime?.waitUntil) {
      edgeRuntime.waitUntil(task);
    } else {
      task.catch(() => undefined);
    }

    return jsonResponse(
      req,
      {
        job_id: jobId,
        schedule_id: scheduleId,
        status: row?.job_status ?? "pending",
        reused: row?.reused === true,
      },
      202,
      { "X-Request-ID": requestId },
    );
  } catch (error) {
    if (error instanceof RequestBodyError) {
      return jsonResponse(req, { error: error.message }, error.status);
    }
    console.error(JSON.stringify({
      event: "training_plan_request_failed",
      request_id: requestId,
    }));
    return jsonResponse(
      req,
      { error: "Không thể bắt đầu tạo lịch tập." },
      503,
    );
  }
});
