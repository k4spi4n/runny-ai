import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

import {
  ensureFreshToken,
  fetchActivity,
  StravaApiError,
  type StravaConnection,
  upsertRunActivity,
} from "./strava.ts";

export interface StravaWebhookJob {
  id: string;
  owner_id: string;
  object_id: number | string;
  object_type: string;
  aspect_type: "create" | "update" | "delete";
  event_time?: string | null;
  attempts: number;
}

// deno-lint-ignore no-explicit-any
type ServiceClient = any;

function serviceClient(): ServiceClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error("strava_webhook_service_not_configured");
  }
  return createClient(url, key);
}

function athleteIdFromActivity(activity: unknown): string | null {
  if (!activity || typeof activity !== "object") return null;
  const athlete = (activity as Record<string, unknown>).athlete;
  if (!athlete || typeof athlete !== "object") return null;
  const id = (athlete as Record<string, unknown>).id;
  return typeof id === "number" || typeof id === "string" ? String(id) : null;
}

function verifyAthlete(
  activity: unknown,
  connection: StravaConnection,
  eventOwnerId: string,
): void {
  const connectedAthlete = connection.athlete_id == null
    ? null
    : String(connection.athlete_id);
  const fetchedAthlete = athleteIdFromActivity(activity);
  if (
    !connectedAthlete ||
    connectedAthlete !== eventOwnerId ||
    fetchedAthlete !== connectedAthlete
  ) {
    throw new Error("strava_athlete_identity_mismatch");
  }
}

async function connectionForOwner(
  supabase: ServiceClient,
  ownerId: string,
): Promise<StravaConnection> {
  const { data, error } = await supabase.rpc(
    "get_strava_connection_by_athlete",
    { p_athlete_id: ownerId },
  );
  const connection = Array.isArray(data) ? data[0] : null;
  if (error || !connection || String(connection.athlete_id) !== ownerId) {
    throw new Error("strava_connection_not_found");
  }
  return connection as StravaConnection;
}

async function markDeletedAtSource(
  supabase: ServiceClient,
  userId: string,
  activityId: number | string,
): Promise<void> {
  const { error } = await supabase
    .from("activities")
    .update({
      source_status: "deleted_at_source",
      source_deleted_at: new Date().toISOString(),
    })
    .eq("user_id", userId)
    .eq("source", "strava")
    .eq("strava_activity_id", activityId);
  if (error) throw new Error("strava_reconciliation_write_failed");
}

export async function processClaimedStravaJob(
  supabase: ServiceClient,
  job: StravaWebhookJob,
): Promise<void> {
  if (
    job.object_type !== "activity" ||
    !["create", "update", "delete"].includes(job.aspect_type)
  ) {
    throw new Error("strava_job_invalid");
  }

  const connection = await connectionForOwner(supabase, job.owner_id);
  const accessToken = await ensureFreshToken(supabase, connection);

  if (job.aspect_type === "delete") {
    try {
      const activity = await fetchActivity(accessToken, job.object_id);
      verifyAthlete(activity, connection, job.owner_id);
      await upsertRunActivity(supabase, connection.user_id, activity);
      return;
    } catch (error) {
      if (error instanceof StravaApiError && error.status === 404) {
        await markDeletedAtSource(
          supabase,
          connection.user_id,
          job.object_id,
        );
        return;
      }
      throw error;
    }
  }

  const activity = await fetchActivity(accessToken, job.object_id);
  verifyAthlete(activity, connection, job.owner_id);
  await upsertRunActivity(supabase, connection.user_id, activity);
}

function safeJobError(error: unknown): string {
  if (error instanceof StravaApiError) {
    return `strava_api_${error.status}`;
  }
  if (error instanceof Error && /^[a-z0-9_]{1,100}$/.test(error.message)) {
    return error.message;
  }
  return "strava_job_failed";
}

async function finishJob(
  supabase: ServiceClient,
  jobId: string,
  success: boolean,
  error?: unknown,
): Promise<void> {
  const result = await supabase.rpc("finish_strava_webhook_job", {
    p_job_id: jobId,
    p_success: success,
    p_error: success ? null : safeJobError(error),
  });
  if (result.error) throw new Error("strava_job_finish_failed");
}

export async function processStravaWebhookJob(jobId: string): Promise<void> {
  const supabase = serviceClient();
  const { data, error } = await supabase.rpc("claim_strava_webhook_job", {
    p_job_id: jobId,
  });
  const job = Array.isArray(data)
    ? data[0] as StravaWebhookJob | undefined
    : undefined;
  if (error || !job) return;
  try {
    await processClaimedStravaJob(supabase, job);
    await finishJob(supabase, job.id, true);
  } catch (jobError) {
    await finishJob(supabase, job.id, false, jobError);
  }
}

export async function processPendingStravaWebhookJobs(
  limit = 10,
): Promise<number> {
  const supabase = serviceClient();
  const { data, error } = await supabase.rpc(
    "claim_next_strava_webhook_jobs",
    { p_limit: limit },
  );
  if (error) throw new Error("strava_job_claim_failed");
  const jobs = Array.isArray(data) ? data as StravaWebhookJob[] : [];
  for (const job of jobs) {
    try {
      await processClaimedStravaJob(supabase, job);
      await finishJob(supabase, job.id, true);
    } catch (jobError) {
      await finishJob(supabase, job.id, false, jobError);
    }
  }
  return jobs.length;
}
