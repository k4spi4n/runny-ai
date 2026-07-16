import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

import { authenticatedUserId } from "../_shared/auth.ts";
import {
  correlationId,
  corsHeaders,
  isAllowedBrowserOrigin,
  jsonResponse,
  readJsonBody,
  RequestBodyError,
} from "../_shared/http.ts";
import {
  ensureFreshToken,
  exchangeCode,
  fetchRecentActivities,
  getStravaCredentials,
  StravaApiError,
  upsertRunActivity,
} from "../_shared/strava.ts";

// deno-lint-ignore no-explicit-any
async function syncRecent(supabase: any, userId: string): Promise<number> {
  const { data, error } = await supabase.rpc("get_strava_connection", {
    p_user_id: userId,
  });
  const connection = Array.isArray(data) ? data[0] : null;
  if (error || !connection) throw new Error("strava_connection_not_found");

  const accessToken = await ensureFreshToken(supabase, connection);
  const activities = await fetchRecentActivities(accessToken, {
    perPage: 30,
    after: Math.floor(Date.now() / 1_000) - 30 * 24 * 60 * 60,
  });
  let imported = 0;
  for (const activity of activities.slice(0, 30)) {
    if (await upsertRunActivity(supabase, userId, activity)) imported++;
  }
  return imported;
}

function randomState(): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(32)))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function redirectUri(): string {
  const raw = Deno.env.get("STRAVA_REDIRECT_URI")?.trim();
  if (!raw) throw new Error("strava_redirect_not_configured");
  const uri = new URL(raw);
  const local = uri.hostname === "localhost" || uri.hostname === "127.0.0.1";
  if (uri.protocol !== "https:" && !(local && uri.protocol === "http:")) {
    throw new Error("strava_redirect_invalid");
  }
  return uri.toString();
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
    return jsonResponse(
      req,
      { error: "Bạn cần đăng nhập để kết nối Strava." },
      401,
    );
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse(req, { error: "Server chưa cấu hình Supabase." }, 503);
  }
  const supabase = createClient(supabaseUrl, serviceKey);

  try {
    const payload = await readJsonBody(req, 4_096);
    const action = payload.action ?? "start";

    if (action === "start") {
      const { clientId } = getStravaCredentials();
      const state = randomState();
      const { error } = await supabase.rpc("create_oauth_state", {
        p_user_id: userId,
        p_state: state,
        p_provider: "strava",
      });
      if (error) throw new Error("strava_oauth_state_create_failed");

      const url = new URL("https://www.strava.com/oauth/authorize");
      url.searchParams.set("client_id", clientId);
      url.searchParams.set("redirect_uri", redirectUri());
      url.searchParams.set("response_type", "code");
      url.searchParams.set("approval_prompt", "auto");
      url.searchParams.set("scope", "activity:read_all,profile:read_all");
      url.searchParams.set("state", state);
      return jsonResponse(req, { authorizationUrl: url.toString() });
    }

    if (action === "connect") {
      const code = typeof payload.code === "string" &&
          /^[A-Za-z0-9_-]{8,500}$/.test(payload.code)
        ? payload.code
        : "";
      const state = typeof payload.state === "string" &&
          /^[a-f0-9]{64}$/.test(payload.state)
        ? payload.state
        : "";
      if (!code || !state) {
        return jsonResponse(req, {
          error: "Authorization code/state không hợp lệ.",
        }, 400);
      }
      const { data: consumed, error: stateError } = await supabase.rpc(
        "consume_oauth_state",
        {
          p_user_id: userId,
          p_state: state,
          p_provider: "strava",
        },
      );
      if (stateError || consumed !== true) {
        return jsonResponse(
          req,
          { error: "OAuth state không hợp lệ hoặc đã hết hạn." },
          400,
        );
      }

      const tokens = await exchangeCode(code);
      if (tokens.athleteId == null) {
        throw new Error("strava_athlete_missing");
      }
      const { error: saveError } = await supabase.rpc(
        "save_strava_connection",
        {
          p_user_id: userId,
          p_athlete_id: String(tokens.athleteId),
          p_access_token: tokens.accessToken,
          p_refresh_token: tokens.refreshToken,
          p_expires_at: new Date(tokens.expiresAt * 1_000).toISOString(),
        },
      );
      if (saveError) throw new Error("strava_connection_save_failed");
      await supabase
        .from("profiles")
        .update({ strava_id: String(tokens.athleteId) })
        .eq("id", userId);

      let imported = 0;
      try {
        imported = await syncRecent(supabase, userId);
      } catch {
        console.warn(JSON.stringify({
          event: "strava_initial_sync_failed",
          request_id: requestId,
        }));
      }
      return jsonResponse(req, {
        connected: true,
        athlete_id: tokens.athleteId,
        imported,
      });
    }

    if (action === "sync") {
      return jsonResponse(req, {
        imported: await syncRecent(supabase, userId),
      });
    }

    if (action === "disconnect") {
      const { error } = await supabase.rpc("disconnect_strava_connection", {
        p_user_id: userId,
      });
      if (error) throw new Error("strava_disconnect_failed");
      await supabase.from("profiles").update({ strava_id: null }).eq(
        "id",
        userId,
      );
      return jsonResponse(req, { disconnected: true });
    }

    return jsonResponse(req, { error: "Hành động không được hỗ trợ." }, 400);
  } catch (error) {
    if (error instanceof RequestBodyError) {
      return jsonResponse(req, { error: error.message }, error.status);
    }
    console.error(JSON.stringify({
      event: "strava_oauth_failed",
      request_id: requestId,
      kind: error instanceof StravaApiError
        ? `provider_${error.status}`
        : "internal",
    }));
    return jsonResponse(
      req,
      { error: "Không thể hoàn tất thao tác Strava. Vui lòng thử lại." },
      error instanceof StravaApiError ? 502 : 500,
    );
  }
});
