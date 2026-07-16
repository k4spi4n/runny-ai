function signatureBytes(signature: string): Uint8Array | null {
  if (!/^[a-fA-F0-9]{64}$/.test(signature)) return null;
  const bytes = new Uint8Array(32);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = Number.parseInt(signature.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

export function buildPayosSignaturePayload(
  data: Record<string, unknown>,
): string {
  return Object.keys(data)
    .sort()
    .map((key) => {
      const value = data[key];
      return `${key}=${value === null || value === undefined ? "" : value}`;
    })
    .join("&");
}

async function hmacKey(
  checksumKey: string,
  usage: KeyUsage[],
): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(checksumKey),
    { name: "HMAC", hash: "SHA-256" },
    false,
    usage,
  );
}

export async function verifyPayosSignature(
  checksumKey: string,
  data: Record<string, unknown>,
  signature: string,
): Promise<boolean> {
  const bytes = signatureBytes(signature);
  if (!bytes) return false;
  const key = await hmacKey(checksumKey, ["verify"]);
  return await crypto.subtle.verify(
    "HMAC",
    key,
    bytes.buffer as ArrayBuffer,
    new TextEncoder().encode(buildPayosSignaturePayload(data)),
  );
}

export async function hmacSha256Hex(
  checksumKey: string,
  message: string,
): Promise<string> {
  const key = await hmacKey(checksumKey, ["sign"]);
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message),
  );
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}
