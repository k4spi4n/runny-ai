import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

import {
  correlationId,
  jsonResponse,
  readJsonBody,
  RequestBodyError,
} from "../_shared/http.ts";
import { validateStravaEvent } from "../_shared/strava_event.ts";
import { processStravaWebhookJob } from "../_shared/strava_webhook.ts";

const MAX_WEBHOOK_BYTES = 16_384;

function webhookConfig(): {
  verifyToken: string | null;
  subscriptionId: string | null;
} {
  const verifyToken = Deno.env.get("STRAVA_VERIFY_TOKEN")?.trim() ?? null;
  const subscriptionId = Deno.env.get("STRAVA_SUBSCRIPTION_ID")?.trim() ?? null;
  return {
    verifyToken: verifyToken && verifyToken.length >= 16 &&
        verifyToken !== "RUNNY_AI_STRAVA_TOKEN"
      ? verifyToken
      : null,
    subscriptionId: subscriptionId && /^\d+$/.test(subscriptionId)
      ? subscriptionId
      : null,
  };
}

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

function serviceClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return null;
  return createClient(url, key);
}

serve(async (req) => {
  const requestId = correlationId(req);
  const config = webhookConfig();

  if (req.method === "GET") {
    if (!config.verifyToken) {
      console.error(JSON.stringify({
        event: "strava_webhook_verify_misconfigured",
        request_id: requestId,
      }));
      return new Response("Service unavailable", { status: 503 });
    }
    const url = new URL(req.url);
    const mode = url.searchParams.get("hub.mode") ?? "";
    const token = url.searchParams.get("hub.verify_token") ?? "";
    const challenge = url.searchParams.get("hub.challenge");
    if (
      mode !== "subscribe" ||
      !challenge ||
      !constantTimeEqual(token, config.verifyToken)
    ) {
      return new Response("Forbidden", { status: 403 });
    }
    return new Response(JSON.stringify({ "hub.challenge": challenge }), {
      status: 200,
      headers: { "Content-Type": "application/json; charset=utf-8" },
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (!config.subscriptionId) {
    console.error(JSON.stringify({
      event: "strava_webhook_subscription_misconfigured",
      request_id: requestId,
    }));
    return new Response("Service unavailable", { status: 503 });
  }
  const supabase = serviceClient();
  if (!supabase) {
    console.error(JSON.stringify({
      event: "strava_webhook_service_misconfigured",
      request_id: requestId,
    }));
    return new Response("Service unavailable", { status: 503 });
  }

  try {
    const body = await readJsonBody(req, MAX_WEBHOOK_BYTES);
    const event = validateStravaEvent(body, config.subscriptionId);
    if (!event) {
      return new Response("Forbidden", { status: 403 });
    }

    const eventKey = [
      event.subscriptionId,
      event.ownerId,
      event.objectId,
      event.aspectType,
      event.eventSeconds,
    ].join(":");
    const { data, error } = await supabase.rpc(
      "enqueue_strava_webhook_job",
      {
        p_event_key: eventKey,
        p_subscription_id: event.subscriptionId,
        p_owner_id: event.ownerId,
        p_object_id: event.objectId,
        p_object_type: event.objectType,
        p_aspect_type: event.aspectType,
        p_event_time: event.eventTime,
      },
    );
    if (error) {
      console.error(JSON.stringify({
        event: "strava_webhook_enqueue_failed",
        request_id: requestId,
      }));
      return new Response("Service unavailable", { status: 503 });
    }

    const accepted = data?.accepted === true;
    const jobId = typeof data?.job_id === "string" ? data.job_id : null;
    if (accepted && jobId) {
      const task = processStravaWebhookJob(jobId);
      // deno-lint-ignore no-explicit-any
      const edgeRuntime = (globalThis as any).EdgeRuntime;
      if (edgeRuntime?.waitUntil) {
        edgeRuntime.waitUntil(task);
      } else {
        task.catch(() => undefined);
      }
    }

    console.log(JSON.stringify({
      event: "strava_webhook_received",
      request_id: requestId,
      accepted,
      result: data?.reason ?? "queued",
    }));
    return new Response("OK", { status: 200 });
  } catch (error) {
    if (error instanceof RequestBodyError) {
      return jsonResponse(req, { error: error.message }, error.status);
    }
    console.error(JSON.stringify({
      event: "strava_webhook_unhandled",
      request_id: requestId,
    }));
    return new Response("Service unavailable", { status: 503 });
  }
});
