import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

import {
  correlationId,
  jsonResponse,
  readJsonBody,
  RequestBodyError,
} from "../_shared/http.ts";
import { processPendingStravaWebhookJobs } from "../_shared/strava_webhook.ts";

function constantTimeEqual(left: string, right: string): boolean {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  const length = Math.max(leftBytes.length, rightBytes.length);
  let difference = leftBytes.length ^ rightBytes.length;
  for (let i = 0; i < length; i++) {
    difference |= (leftBytes[i] ?? 0) ^ (rightBytes[i] ?? 0);
  }
  return difference === 0;
}

serve(async (req) => {
  const requestId = correlationId(req);
  if (req.method !== "POST") {
    return jsonResponse(req, { error: "Method not allowed." }, 405);
  }
  const expected = Deno.env.get("STRAVA_WEBHOOK_WORKER_TOKEN")?.trim();
  const supplied = req.headers.get("x-worker-token")?.trim() ?? "";
  if (
    !expected ||
    expected.length < 32 ||
    !constantTimeEqual(supplied, expected)
  ) {
    return jsonResponse(req, { error: "Unauthorized." }, 401);
  }
  try {
    const body = await readJsonBody(req, 1_024);
    const rawLimit = body.limit;
    const limit = typeof rawLimit === "number" && Number.isInteger(rawLimit)
      ? Math.max(1, Math.min(50, rawLimit))
      : 10;
    const processed = await processPendingStravaWebhookJobs(limit);
    return jsonResponse(
      req,
      { processed },
      200,
      { "X-Request-ID": requestId },
    );
  } catch (error) {
    if (error instanceof RequestBodyError) {
      return jsonResponse(req, { error: error.message }, error.status);
    }
    console.error(JSON.stringify({
      event: "strava_worker_failed",
      request_id: requestId,
    }));
    return jsonResponse(req, { error: "Worker failed." }, 500);
  }
});
