import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

import { authenticatedUserId } from "../_shared/auth.ts";
import {
  correlationId,
  corsHeaders,
  envInt,
  fetchWithTimeout,
  isAllowedBrowserOrigin,
  jsonResponse,
  readBodyBytes,
  RequestBodyError,
} from "../_shared/http.ts";
import {
  createFoodRecognitionService,
  FoodRecognitionError,
} from "./food_recognition_service.ts";

const MAX_IMAGE_BYTES = 2_900_000;
const MIN_IMAGE_BYTES = 1_024;
const MAX_MULTIPART_BYTES = 3_100_000;

function detectImageMime(bytes: Uint8Array): string | null {
  if (bytes.length < 12) return null;
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return "image/jpeg";
  }
  if (
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47
  ) {
    return "image/png";
  }
  if (bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46) {
    return "image/gif";
  }
  if (
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return "image/webp";
  }
  if (
    bytes[4] === 0x66 &&
    bytes[5] === 0x74 &&
    bytes[6] === 0x79 &&
    bytes[7] === 0x70
  ) {
    return "image/heic";
  }
  return null;
}

async function checkAiAccess(
  userId: string,
): Promise<{ allowed: boolean; reason?: string }> {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return { allowed: false, reason: "unavailable" };
  try {
    const response = await fetchWithTimeout(
      `${url}/rest/v1/rpc/check_ai_access`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          p_user_id: userId,
          p_feature: "food",
          p_max_per_min: envInt("FOOD_AI_MAX_PER_MIN", 6, { max: 30 }),
          p_max_per_day: envInt("FOOD_AI_MAX_PER_DAY", 30, { max: 500 }),
          p_free_max_per_min: 1,
          p_free_max_per_day: 1,
        }),
      },
      { timeoutMs: 5_000 },
    );
    if (!response.ok) {
      await response.body?.cancel();
      return { allowed: false, reason: "unavailable" };
    }
    const data = await response.json();
    return {
      allowed: data?.allowed === true,
      reason: typeof data?.reason === "string" ? data.reason : undefined,
    };
  } catch {
    return { allowed: false, reason: "unavailable" };
  }
}

serve(async (req) => {
  const requestId = correlationId(req);
  if (!isAllowedBrowserOrigin(req)) {
    return jsonResponse(req, { error: "Origin is not allowed." }, 403);
  }
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  const url = new URL(req.url);
  if (!url.pathname.endsWith("/analyze")) {
    return jsonResponse(req, { error: "Endpoint not found." }, 404);
  }
  if (req.method !== "POST") {
    return jsonResponse(req, { error: "Method not allowed." }, 405);
  }

  const userId = authenticatedUserId(req);
  if (!userId) {
    return jsonResponse(
      req,
      { error: "Bạn cần đăng nhập để dùng tính năng nhận diện món ăn." },
      401,
    );
  }

  try {
    const contentType = req.headers.get("content-type") ?? "";
    if (!contentType.toLowerCase().includes("multipart/form-data")) {
      return jsonResponse(
        req,
        { error: "Please upload an image using multipart/form-data." },
        415,
      );
    }
    const multipartBytes = await readBodyBytes(req, MAX_MULTIPART_BYTES);
    const boundedRequest = new Request(req.url, {
      method: "POST",
      headers: { "Content-Type": contentType },
      body: multipartBytes.buffer.slice(
        multipartBytes.byteOffset,
        multipartBytes.byteOffset + multipartBytes.byteLength,
      ) as ArrayBuffer,
    });
    const formData = await boundedRequest.formData();
    const uploadedFile = formData.get("image") ?? formData.get("file");
    if (!(uploadedFile instanceof File)) {
      return jsonResponse(req, { error: "No image file was uploaded." }, 400);
    }
    if (uploadedFile.size > MAX_IMAGE_BYTES) {
      return jsonResponse(req, { error: "Image is too large." }, 413);
    }
    if (uploadedFile.size < MIN_IMAGE_BYTES) {
      return jsonResponse(
        req,
        { error: "Ảnh quá nhỏ hoặc rỗng. Vui lòng chọn ảnh rõ ràng." },
        400,
      );
    }

    const bytes = new Uint8Array(await uploadedFile.arrayBuffer());
    const mime = detectImageMime(bytes);
    if (!mime) {
      return jsonResponse(
        req,
        { error: "Tệp tải lên không phải ảnh hợp lệ." },
        415,
      );
    }

    const access = await checkAiAccess(userId);
    if (!access.allowed) {
      if (access.reason === "upgrade_required") {
        return jsonResponse(
          req,
          {
            error: "Nhận diện món ăn dành cho gói trả phí.",
            code: "upgrade_required",
          },
          402,
        );
      }
      if (access.reason === "minute" || access.reason === "day") {
        return jsonResponse(
          req,
          { error: "Bạn đã đạt giới hạn nhận diện món ăn." },
          429,
        );
      }
      return jsonResponse(
        req,
        { error: "Dịch vụ đang bận. Vui lòng thử lại sau." },
        503,
      );
    }

    const service = createFoodRecognitionService();
    const result = await service.analyze({
      filename: uploadedFile.name,
      contentType: mime,
      byteLength: uploadedFile.size,
      bytes,
    });
    return jsonResponse(
      req,
      result as unknown as Record<string, unknown>,
      200,
      { "X-Request-ID": requestId },
    );
  } catch (error) {
    if (error instanceof RequestBodyError) {
      return jsonResponse(req, { error: error.message }, error.status);
    }
    if (error instanceof FoodRecognitionError) {
      return jsonResponse(
        req,
        { error: error.message, code: error.code },
        error.status,
      );
    }
    console.error(JSON.stringify({
      event: "food_recognition_unhandled",
      request_id: requestId,
    }));
    return jsonResponse(
      req,
      { error: "Unable to analyze this food image. Please try again." },
      500,
    );
  }
});
