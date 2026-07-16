export function authenticatedUserId(req: Request): string | null {
  const auth = req.headers.get("authorization");
  if (!auth) return null;
  const token = auth.replace(/^Bearer\s+/i, "").trim();
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    let payloadPart = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    payloadPart += "=".repeat((4 - payloadPart.length % 4) % 4);
    const payload = JSON.parse(atob(payloadPart));
    if (payload?.role !== "authenticated") return null;
    return typeof payload.sub === "string" && payload.sub.length > 0
      ? payload.sub
      : null;
  } catch {
    return null;
  }
}
