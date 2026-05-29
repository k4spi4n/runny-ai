import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

const stravaVerifyToken =
  Deno.env.get("STRAVA_VERIFY_TOKEN") ?? "RUNNY_AI_STRAVA_TOKEN";

serve(async (req) => {
  const url = new URL(req.url);

  // 1. Strava Webhook Verification (GET)
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

  // 2. Handle Strava Webhook Event (POST)
  if (req.method === "POST") {
    try {
      const body = await req.json();
      console.log("Strava event push received:", body);

      const objectType = body.object_type;
      const aspectType = body.aspect_type; // 'create', 'update', 'delete'
      const objectId = body.object_id; // Activity ID or Athlete ID
      const ownerId = body.owner_id; // Strava Athlete ID

      if (objectType === "activity" && aspectType === "create") {
        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
        const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
        const supabase = createClient(supabaseUrl, supabaseKey);

        // TODO: In a real app, use `ownerId` to find user's auth token,
        // then fetch full activity details from Strava API:
        // GET https://www.strava.com/api/v3/activities/{objectId}
        // Then parse distance, moving_time, total_elevation_gain, average_heartrate

        // For now, we store the webhook notification as a background sync task or basic activity
        console.log(
          `Processing new activity ${objectId} for athlete ${ownerId}`,
        );

        // Mock basic insert if user lookup is skipped for demo
        /*
        await supabase.from("activities").insert([
          {
            // user_id: '...', // Looked up from profiles where strava_id = ownerId
            started_at: new Date().toISOString(),
            distance_km: 0, 
            duration_min: 0,
            notes: `Auto-synced from Strava (ID: ${objectId})`,
            data_points: body,
          }
        ]);
        */
      }

      // Strava requires 200 response within 2s, so we respond immediately
      return new Response("OK", { status: 200 });
    } catch (e) {
      console.error("Error processing Strava webhook:", e);
      return new Response("Internal Server Error", { status: 500 });
    }
  }

  return new Response("Method not allowed", { status: 405 });
});
