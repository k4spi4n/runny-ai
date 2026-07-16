import { validateStravaEvent } from "./strava_event.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

const now = Date.UTC(2026, 6, 16, 12);
const valid = {
  subscription_id: 42,
  owner_id: 1001,
  object_id: 9001,
  object_type: "activity",
  aspect_type: "create",
  event_time: Math.floor(now / 1_000),
};

Deno.test("Strava rejects a forged subscription id before enqueue", () => {
  assert(
    validateStravaEvent(valid, "999", now) === null,
    "forged subscription was accepted",
  );
});

Deno.test("Strava rejects malformed or implausible events", () => {
  assert(
    validateStravaEvent(
      { ...valid, object_type: "athlete" },
      "42",
      now,
    ) === null,
    "unsupported object type accepted",
  );
  assert(
    validateStravaEvent(
      { ...valid, event_time: Math.floor(now / 1_000) + 90_000 },
      "42",
      now,
    ) === null,
    "far-future event accepted",
  );
});

Deno.test("Strava accepts a well-formed configured event", () => {
  const event = validateStravaEvent(valid, "42", now);
  assert(event !== null, "valid event rejected");
  assert(event.ownerId === "1001", "owner normalization failed");
  assert(event.aspectType === "create", "aspect normalization failed");
});
