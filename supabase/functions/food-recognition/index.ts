import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  createFoodRecognitionService,
  FoodRecognitionError,
} from './food_recognition_service.ts';

// =============================================================================
// Food recognition proxy (Groq vision). Giu API key o server, ap dat guardrails
// chong lam dung & spam giong function `openrouter`:
//   1. Yeu cau user da dang nhap (JWT role == authenticated).
//   2. Kiem tra dinh dang/kich thuoc anh (multipart, magic-byte, min/max size).
//   3. Entitlement + quota theo tier qua RPC check_ai_access (feature 'food'):
//      free tier bi khoa, trial|paid co han muc rieng. Fail-open neu chua cau hinh.
//   4. Loc noi dung: model tu choi anh khong phai mon an (xu ly trong service).
// =============================================================================

// Groq nhan anh base64 toi da 4MB; base64 phinh ~4/3 lan so voi raw, cong them
// phan data-URL prefix + JSON wrapping -> gioi han raw an toan ~2.8MB.
const maxImageBytes = 2_900_000;
const minImageBytes = 1024; // < 1KB gan nhu chac chan khong phai anh mon an that

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function envInt(name: string, fallback: number): number {
  const v = parseInt(Deno.env.get(name) ?? '', 10);
  return Number.isFinite(v) && v > 0 ? v : fallback;
}

// Han muc rieng cho nhan dien anh: chat hon chat van ban vi goi vision ton kem hon.
// Dung chung bo dem voi function openrouter (cung bang ai_rate_limit theo user).
// Free tier khong duoc dung tinh nang nay (gate o RPC check_ai_access, feature 'food').
const FOOD_MAX_PER_MIN = () => envInt('FOOD_AI_MAX_PER_MIN', 6);
const FOOD_MAX_PER_DAY = () => envInt('FOOD_AI_MAX_PER_DAY', 30);

// --- Guardrail 1: lay user id tu JWT. Tra null neu khong phai user da dang nhap. ---
function getUserId(req: Request): string | null {
  const auth = req.headers.get('Authorization') ?? req.headers.get('authorization');
  if (!auth) return null;
  const token = auth.replace(/^Bearer\s+/i, '').trim();
  const parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    let b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    b64 += '='.repeat((4 - (b64.length % 4)) % 4); // bu padding base64url
    const payload = JSON.parse(atob(b64));
    if (payload.role !== 'authenticated') return null; // tu choi anon key
    return typeof payload.sub === 'string' ? payload.sub : null;
  } catch {
    return null;
  }
}

// --- Guardrail 3: entitlement + quota theo tier (chong spam + gate paywall). ---
// Feature 'food': free tier bi khoa (RPC tra upgrade_required). Fail-open neu
// ha tang chua cau hinh.
async function checkAiAccess(
  userId: string,
): Promise<{ allowed: boolean; reason?: string; tier?: string }> {
  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  // 'food' la tinh nang tra phi -> fail-CLOSED: khong xac minh duoc quyen thi tu
  // choi (tranh mo khoa mien phi khi ha tang loi/chua cau hinh).
  const onUnavailable = { allowed: false, reason: 'unavailable' };
  if (!url || !serviceKey) {
    console.warn('AI access check skipped: SUPABASE_URL/SERVICE_ROLE_KEY not set.');
    return onUnavailable;
  }
  try {
    const res = await fetch(`${url}/rest/v1/rpc/check_ai_access`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
      body: JSON.stringify({
        p_user_id: userId,
        p_feature: 'food',
        p_max_per_min: FOOD_MAX_PER_MIN(),
        p_max_per_day: FOOD_MAX_PER_DAY(),
        // Free tier khong dung duoc 'food' nen 2 cap free khong anh huong; truyen 0.
        p_free_max_per_min: 0,
        p_free_max_per_day: 0,
      }),
    });
    if (!res.ok) {
      console.warn(`check_ai_access RPC returned ${res.status}`);
      return onUnavailable;
    }
    const data = await res.json();
    return { allowed: data?.allowed !== false, reason: data?.reason, tier: data?.tier };
  } catch (e) {
    console.warn(`check_ai_access RPC failed: ${e}`);
    return onUnavailable;
  }
}

// --- Guardrail 2: xac thuc anh that bang magic-byte (phong thu sau, khong tin
// vao content-type/ten file do client gui). Tra ve mime chuan hoac null. ---
function detectImageMime(bytes: Uint8Array): string | null {
  if (bytes.length < 12) return null;
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) {
    return 'image/png';
  }
  if (bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46) return 'image/gif';
  if (
    bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
    bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50
  ) {
    return 'image/webp';
  }
  if (bytes[4] === 0x66 && bytes[5] === 0x74 && bytes[6] === 0x79 && bytes[7] === 0x70) {
    return 'image/heic';
  }
  return null;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const url = new URL(req.url);
  if (!url.pathname.endsWith('/analyze')) {
    return jsonResponse({ error: 'Endpoint not found. Use POST /food-recognition/analyze.' }, 404);
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed. Use POST.' }, 405);
  }

  try {
    // --- Guardrail 1: yeu cau user da dang nhap. ---
    const userId = getUserId(req);
    if (!userId) {
      return jsonResponse({ error: 'Bạn cần đăng nhập để dùng tính năng nhận diện món ăn.' }, 401);
    }

    const contentType = req.headers.get('content-type') ?? '';
    if (!contentType.toLowerCase().includes('multipart/form-data')) {
      return jsonResponse(
        { error: 'Invalid request. Please upload an image using multipart/form-data.' },
        415,
      );
    }

    const formData = await req.formData();
    const uploadedFile = formData.get('image') ?? formData.get('file');

    if (!(uploadedFile instanceof File)) {
      return jsonResponse({ error: 'No image file was uploaded.' }, 400);
    }

    if (uploadedFile.size > maxImageBytes) {
      return jsonResponse(
        { error: `Image is too large. Maximum size is ${maxImageBytes / 1024 / 1024}MB.` },
        413,
      );
    }
    if (uploadedFile.size < minImageBytes) {
      return jsonResponse({ error: 'Ảnh quá nhỏ hoặc rỗng. Vui lòng chọn ảnh món ăn rõ ràng.' }, 400);
    }

    const bytes = new Uint8Array(await uploadedFile.arrayBuffer());

    // --- Guardrail 2: xac thuc anh that (magic-byte), khong tin content-type client. ---
    const mime = detectImageMime(bytes);
    if (!mime) {
      return jsonResponse({ error: 'Tệp tải lên không phải ảnh hợp lệ.' }, 415);
    }

    // --- Guardrail 3: entitlement + quota theo tier (chong spam + gate paywall). ---
    const access = await checkAiAccess(userId);
    if (!access.allowed) {
      if (access.reason === 'upgrade_required') {
        return jsonResponse({
          error: 'Nhận diện món ăn dành cho gói trả phí. Vui lòng nâng cấp để tiếp tục.',
          code: 'upgrade_required',
        }, 402);
      }
      if (access.reason === 'unavailable') {
        // Fail-closed: khong xac minh duoc quyen -> bao ban thay vi mo khoa mien phi.
        return jsonResponse({ error: 'Dịch vụ đang bận. Vui lòng thử lại sau giây lát.' }, 503);
      }
      const msg = access.reason === 'day'
        ? 'Bạn đã đạt giới hạn nhận diện món ăn trong ngày. Vui lòng thử lại vào ngày mai.'
        : 'Bạn đang gửi yêu cầu quá nhanh. Vui lòng chờ một lát rồi thử lại.';
      return jsonResponse({ error: msg }, 429);
    }

    // --- Guardrail 4: loc noi dung (tu choi anh khong phai mon an) o trong service. ---
    const service = createFoodRecognitionService();
    const result = await service.analyze({
      filename: uploadedFile.name,
      contentType: mime,
      byteLength: uploadedFile.size,
      bytes,
    });

    return jsonResponse(result as unknown as Record<string, unknown>);
  } catch (error) {
    console.error('Food recognition error:', error);

    if (error instanceof FoodRecognitionError) {
      return jsonResponse({ error: error.message, code: error.code }, error.status);
    }

    return jsonResponse({ error: 'Unable to analyze this food image. Please try again.' }, 500);
  }
});
