export interface ValidatedStravaEvent {
  subscriptionId: string;
  ownerId: string;
  objectId: string;
  objectType: "activity";
  aspectType: "create" | "update" | "delete";
  eventSeconds: number;
  eventTime: string;
}

function integerString(value: unknown): string | null {
  if (typeof value === "number" && Number.isSafeInteger(value) && value > 0) {
    return String(value);
  }
  if (typeof value === "string" && /^\d+$/.test(value)) return value;
  return null;
}

export function validateStravaEvent(
  body: Record<string, unknown>,
  expectedSubscriptionId: string,
  nowMs = Date.now(),
): ValidatedStravaEvent | null {
  const subscriptionId = integerString(body.subscription_id);
  const ownerId = integerString(body.owner_id);
  const objectId = integerString(body.object_id);
  const seconds = typeof body.event_time === "number"
    ? body.event_time
    : typeof body.event_time === "string"
    ? Number(body.event_time)
    : Number.NaN;
  const objectType = body.object_type;
  const aspectType = body.aspect_type;
  if (
    subscriptionId !== expectedSubscriptionId ||
    !ownerId ||
    !objectId ||
    !Number.isSafeInteger(seconds) ||
    seconds <= 0 ||
    seconds > Math.floor(nowMs / 1_000) + 86_400 ||
    objectType !== "activity" ||
    (aspectType !== "create" &&
      aspectType !== "update" &&
      aspectType !== "delete")
  ) {
    return null;
  }
  return {
    subscriptionId,
    ownerId,
    objectId,
    objectType,
    aspectType,
    eventSeconds: seconds,
    eventTime: new Date(seconds * 1_000).toISOString(),
  };
}
