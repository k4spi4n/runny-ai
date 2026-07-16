const DEFAULT_ALLOWED_ORIGINS = [
  "https://runny-ai.onrender.com",
  "http://localhost:3000",
  "http://localhost:5173",
  "http://localhost:8080",
];

const DEFAULT_MAX_ERROR_BYTES = 2_048;

export class RequestBodyError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = "RequestBodyError";
  }
}

export interface FetchPolicy {
  timeoutMs?: number;
  retries?: number;
  retryStatuses?: ReadonlySet<number>;
  retryMethods?: ReadonlySet<string>;
}

export function envInt(
  name: string,
  fallback: number,
  { min = 1, max = Number.MAX_SAFE_INTEGER } = {},
): number {
  const parsed = Number.parseInt(Deno.env.get(name) ?? "", 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, parsed));
}

export function correlationId(req?: Request): string {
  const supplied = req?.headers.get("x-request-id")?.trim();
  if (supplied && /^[a-zA-Z0-9._:-]{1,100}$/.test(supplied)) return supplied;
  return crypto.randomUUID();
}

export function allowedOrigins(): Set<string> {
  const configured = (Deno.env.get("APP_ALLOWED_ORIGINS") ?? "")
    .split(",")
    .map((origin) => origin.trim().replace(/\/+$/, ""))
    .filter(Boolean);
  return new Set(configured.length > 0 ? configured : DEFAULT_ALLOWED_ORIGINS);
}

export function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("origin")?.replace(/\/+$/, "");
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-request-id",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "600",
    "Vary": "Origin",
  };
  if (origin && allowedOrigins().has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

export function isAllowedBrowserOrigin(req: Request): boolean {
  const origin = req.headers.get("origin");
  if (!origin) return true;
  return allowedOrigins().has(origin.replace(/\/+$/, ""));
}

export function jsonResponse(
  req: Request,
  body: Record<string, unknown>,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(req),
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...extraHeaders,
    },
  });
}

export async function readJsonBody(
  req: Request,
  maxBytes: number,
): Promise<Record<string, unknown>> {
  const bytes = await readBodyBytes(req, maxBytes);
  try {
    const parsed = JSON.parse(new TextDecoder().decode(bytes));
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("JSON root must be an object");
    }
    return parsed as Record<string, unknown>;
  } catch (error) {
    if (error instanceof RequestBodyError) throw error;
    throw new RequestBodyError("Request body must be valid JSON.", 400);
  }
}

export async function readBodyBytes(
  req: Request,
  maxBytes: number,
): Promise<Uint8Array> {
  const contentLength = Number.parseInt(
    req.headers.get("content-length") ?? "",
    10,
  );
  if (Number.isFinite(contentLength) && contentLength > maxBytes) {
    throw new RequestBodyError("Request body is too large.", 413);
  }
  if (!req.body) {
    throw new RequestBodyError("Request body is required.", 400);
  }

  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > maxBytes) {
        await reader.cancel("body limit exceeded");
        throw new RequestBodyError("Request body is too large.", 413);
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

export async function readTextLimited(
  response: Response,
  maxBytes = DEFAULT_MAX_ERROR_BYTES,
): Promise<string> {
  if (!response.body) return "";
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (total < maxBytes) {
      const { done, value } = await reader.read();
      if (done) break;
      const remaining = maxBytes - total;
      const chunk = value.byteLength <= remaining
        ? value
        : value.slice(0, remaining);
      chunks.push(chunk);
      total += chunk.byteLength;
      if (value.byteLength > remaining) {
        await reader.cancel("response limit exceeded");
        break;
      }
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

function backoffMs(attempt: number): number {
  const base = Math.min(1_500, 150 * 2 ** attempt);
  return base + Math.floor(Math.random() * 100);
}

export async function fetchWithTimeout(
  input: string | URL | Request,
  init: RequestInit = {},
  policy: FetchPolicy = {},
): Promise<Response> {
  const timeoutMs = policy.timeoutMs ?? 10_000;
  const retries = Math.max(0, Math.min(2, policy.retries ?? 0));
  const retryStatuses = policy.retryStatuses ??
    new Set([408, 425, 429, 500, 502, 503, 504]);
  const retryMethods = policy.retryMethods ?? new Set(["GET", "HEAD"]);
  const method =
    (init.method ?? (input instanceof Request ? input.method : "GET"))
      .toUpperCase();
  const canRetry = retryMethods.has(method);

  let lastError: unknown;
  for (let attempt = 0; attempt <= retries; attempt++) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    const externalSignal = init.signal;
    const abortFromExternal = () => controller.abort();
    externalSignal?.addEventListener("abort", abortFromExternal, {
      once: true,
    });
    try {
      const response = await fetch(input, {
        ...init,
        signal: controller.signal,
      });
      if (
        attempt < retries &&
        canRetry &&
        retryStatuses.has(response.status)
      ) {
        await response.body?.cancel();
        await new Promise((resolve) => setTimeout(resolve, backoffMs(attempt)));
        continue;
      }
      return response;
    } catch (error) {
      lastError = error;
      if (attempt >= retries || !canRetry) throw error;
      await new Promise((resolve) => setTimeout(resolve, backoffMs(attempt)));
    } finally {
      clearTimeout(timeout);
      externalSignal?.removeEventListener("abort", abortFromExternal);
    }
  }
  throw lastError instanceof Error
    ? lastError
    : new Error("Provider request failed.");
}

export function withIdleTimeout(
  body: ReadableStream<Uint8Array>,
  idleTimeoutMs: number,
): ReadableStream<Uint8Array> {
  const reader = body.getReader();
  return new ReadableStream<Uint8Array>({
    async pull(controller) {
      let timer: ReturnType<typeof setTimeout> | undefined;
      try {
        const result = await Promise.race([
          reader.read(),
          new Promise<never>((_, reject) => {
            timer = setTimeout(
              () => reject(new Error("Provider stream timed out.")),
              idleTimeoutMs,
            );
          }),
        ]);
        if (result.done) {
          controller.close();
          reader.releaseLock();
          return;
        }
        controller.enqueue(result.value);
      } catch (error) {
        await reader.cancel("stream timeout");
        controller.error(error);
      } finally {
        if (timer !== undefined) clearTimeout(timer);
      }
    },
    async cancel(reason) {
      await reader.cancel(reason);
    },
  });
}
