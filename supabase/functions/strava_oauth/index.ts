import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";
import {
  getStravaCredentials,
  ensureFreshToken,
  exchangeCode,
  fetchRecentActivities,
  upsertRunActivity,
} from "../_shared/strava.ts";

// =============================================================================
// Strava OAuth + đồng bộ thủ công (client gọi kèm JWT).
//   action 'start': tạo OAuth state một-lần, gắn với user hiện tại.
//   action 'connect': đổi authorization code lấy token trong private schema, rồi
//                      nhập ngay các hoạt động gần đây.
//   action 'sync':     nhập các hoạt động gần đây (nút "Đồng bộ ngay").
// Giữ STRAVA_CLIENT_SECRET ở server; client chỉ gửi `code`/`action`.
// =============================================================================

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Lấy user id từ JWT (yêu cầu đã đăng nhập, từ chối anon key).
function getUserId(req: Request): string | null {
  const auth = req.headers.get("Authorization") ?? req.headers.get("authorization");
  if (!auth) return null;
  const token = auth.replace(/^Bearer\s+/i, "").trim();
  const parts = token.split(".");
  if (parts.length < 2) return null;
  try {
    let b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    b64 += "=".repeat((4 - (b64.length % 4)) % 4);
    const payload = JSON.parse(atob(b64));
    if (payload.role !== "authenticated") return null;
    return typeof payload.sub === "string" ? payload.sub : null;
  } catch {
    return null;
  }
}

// Nhập hoạt động gần đây (30 ngày) cho user. Trả về số lượng đã nhập.
// deno-lint-ignore no-explicit-any
async function syncRecent(supabase: any, userId: string): Promise<number> {
  const { data, error } = await supabase.rpc('get_strava_connection', { p_user_id: userId });
  const connection = Array.isArray(data) ? data[0] : null;
  if (error || !connection) throw new Error("Không tìm thấy kết nối Strava.");

  const accessToken = await ensureFreshToken(supabase, connection);
  const afterSec = Math.floor(Date.now() / 1000) - 30 * 24 * 60 * 60;
  const activities = await fetchRecentActivities(accessToken, {
    perPage: 30,
    after: afterSec,
  });

  let imported = 0;
  for (const act of activities) {
    if (await upsertRunActivity(supabase, userId, act)) imported++;
  }
  return imported;
}

function randomState(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('');
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed. Use POST." }, 405);
  }

  const userId = getUserId(req);
  if (!userId) {
    return jsonResponse({ error: "Bạn cần đăng nhập để kết nối Strava." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse({ error: "Server chưa cấu hình Supabase." }, 500);
  }
  const supabase = createClient(supabaseUrl, serviceKey);

  let payload: Record<string, unknown> = {};
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Body không hợp lệ (cần JSON)." }, 400);
  }
  const action = payload.action ?? "start";

  try {
    if (action === 'start') {
      const { clientId } = getStravaCredentials();
      const redirectUri = Deno.env.get('STRAVA_REDIRECT_URI') ?? '';
      if (!redirectUri) return jsonResponse({ error: 'Thiếu STRAVA_REDIRECT_URI trên server.' }, 500);
      const state = randomState();
      const { error } = await supabase.rpc('create_oauth_state', {
        p_user_id: userId,
        p_state: state,
        p_provider: 'strava',
      });
      if (error) throw new Error(`Không thể tạo OAuth state: ${error.message}`);
      const url = new URL('https://www.strava.com/oauth/authorize');
      url.searchParams.set('client_id', clientId);
      url.searchParams.set('redirect_uri', redirectUri);
      url.searchParams.set('response_type', 'code');
      url.searchParams.set('approval_prompt', 'auto');
      url.searchParams.set('scope', 'activity:read_all,profile:read_all');
      url.searchParams.set('state', state);
      return jsonResponse({ authorizationUrl: url.toString() });
    }

    if (action === "connect") {
      const code = typeof payload.code === "string" ? payload.code : "";
      const state = typeof payload.state === 'string' ? payload.state : '';
      if (!code || !state) return jsonResponse({ error: "Thiếu authorization code hoặc state." }, 400);
      const { data: consumed, error: stateError } = await supabase.rpc('consume_oauth_state', {
        p_user_id: userId, p_state: state, p_provider: 'strava',
      });
      if (stateError || consumed != true) return jsonResponse({ error: 'OAuth state không hợp lệ hoặc đã hết hạn.' }, 400);

      const tokens = await exchangeCode(code);
      const { error: saveError } = await supabase.rpc('save_strava_connection', {
        p_user_id: userId,
        p_athlete_id: tokens.athleteId != null ? String(tokens.athleteId) : null,
        p_access_token: tokens.accessToken,
        p_refresh_token: tokens.refreshToken,
        p_expires_at: new Date(tokens.expiresAt * 1000).toISOString(),
      });
      if (saveError) throw new Error(`Không thể lưu kết nối Strava: ${saveError.message}`);
      await supabase.from('profiles').update({ strava_id: tokens.athleteId != null ? String(tokens.athleteId) : null }).eq('id', userId);

      // Nhập ngay các hoạt động gần đây (fail-soft nếu lỗi).
      let imported = 0;
      try {
        imported = await syncRecent(supabase, userId);
      } catch (e) {
        console.error("Initial sync after connect failed:", e);
      }

      return jsonResponse({
        connected: true,
        athlete_id: tokens.athleteId ?? null,
        imported,
      });
    }

    if (action === "sync") {
      const imported = await syncRecent(supabase, userId);
      return jsonResponse({ imported });
    }

    if (action === 'disconnect') {
      const { error } = await supabase.rpc('disconnect_strava_connection', { p_user_id: userId });
      if (error) throw new Error(`Không thể ngắt kết nối Strava: ${error.message}`);
      await supabase.from('profiles').update({ strava_id: null }).eq('id', userId);
      return jsonResponse({ disconnected: true });
    }

    return jsonResponse({ error: `Hành động không hỗ trợ: ${action}` }, 400);
  } catch (e) {
    console.error("strava_oauth error:", e);
    return jsonResponse({ error: String(e instanceof Error ? e.message : e) }, 500);
  }
});
