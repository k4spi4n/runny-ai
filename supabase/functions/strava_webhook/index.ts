import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";
import {
  ensureFreshToken,
  fetchActivity,
  upsertRunActivity,
} from "../_shared/strava.ts";

const stravaVerifyToken =
  Deno.env.get("STRAVA_VERIFY_TOKEN") ?? "RUNNY_AI_STRAVA_TOKEN";

// Tự nhập hoạt động khi Strava báo có hoạt động mới: tra cứu user theo athlete
// id, làm mới token, lấy chi tiết hoạt động rồi ghi vào bảng activities.
// deno-lint-ignore no-explicit-any
async function processEvent(body: any): Promise<void> {
  const objectType = body.object_type;
  const aspectType = body.aspect_type; // 'create' | 'update' | 'delete'
  const objectId = body.object_id; // activity id
  const ownerId = body.owner_id; // strava athlete id

  if (objectType !== "activity") return;

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) {
    console.error("Webhook bỏ qua: thiếu SUPABASE_URL/SERVICE_ROLE_KEY.");
    return;
  }
  const supabase = createClient(supabaseUrl, serviceKey);

  // Xoá hoạt động bên Strava -> gỡ bản ghi tương ứng (nếu có).
  if (aspectType === "delete") {
    await supabase
      .from("activities")
      .delete()
      .eq("strava_activity_id", objectId);
    return;
  }

  if (aspectType !== "create" && aspectType !== "update") return;

  // Tra cứu user theo athlete id (đã lưu khi kết nối OAuth).
  const { data: profile, error } = await supabase
    .from("profiles")
    .select("id, strava_access_token, strava_refresh_token, strava_expires_at")
    .eq("strava_id", String(ownerId))
    .maybeSingle();

  if (error || !profile) {
    console.warn(`Không tìm thấy user cho athlete ${ownerId}.`);
    return;
  }

  try {
    const accessToken = await ensureFreshToken(supabase, profile);
    const activity = await fetchActivity(accessToken, objectId);
    const ok = await upsertRunActivity(supabase, profile.id, activity);
    console.log(
      `Strava ${aspectType} activity ${objectId} cho user ${profile.id}: ${ok ? "đã nhập" : "bỏ qua"}.`,
    );
  } catch (e) {
    console.error(`Xử lý hoạt động Strava ${objectId} lỗi:`, e);
  }
}

serve(async (req) => {
  const url = new URL(req.url);

  // 1. Xác thực webhook (GET) — Strava gọi khi đăng ký subscription.
  if (req.method === "GET") {
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");

    if (mode && token) {
      if (mode === "subscribe" && token === stravaVerifyToken) {
        console.log("Strava webhook verified successfully.");
        return new Response(JSON.stringify({ "hub.challenge": challenge }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      return new Response("Forbidden", { status: 403 });
    }
    return new Response("Bad Request", { status: 400 });
  }

  // 2. Nhận sự kiện (POST). Strava yêu cầu phản hồi 200 trong 2s -> xử lý nền.
  if (req.method === "POST") {
    try {
      const body = await req.json();
      console.log("Strava event push received:", body);

      const task = processEvent(body).catch((e) =>
        console.error("processEvent error:", e)
      );

      // Chạy nền sau khi đã trả 200 (nếu runtime hỗ trợ), nếu không thì await.
      // deno-lint-ignore no-explicit-any
      const edge = (globalThis as any).EdgeRuntime;
      if (edge?.waitUntil) {
        edge.waitUntil(task);
      } else {
        await task;
      }

      return new Response("OK", { status: 200 });
    } catch (e) {
      console.error("Error processing Strava webhook:", e);
      // Vẫn trả 200 để Strava không retry dồn dập khi body lỗi.
      return new Response("OK", { status: 200 });
    }
  }

  return new Response("Method not allowed", { status: 405 });
});
