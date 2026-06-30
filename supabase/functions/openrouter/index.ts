import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// =============================================================================
// AI chat proxy: Groq (chinh) -> OpenRouter (fallback).
//
// Endpoint van giu ten `openrouter` de client khong phai doi (functions.invoke).
// Luong xu ly:
//   1. Neu co GROQ_API_KEY  -> thu lan luot cac model Groq. Tra ve ngay khi 1
//      model phan hoi 200. Groq nhanh (LPU) nen lam provider chinh.
//   2. Neu Groq that bai (thieu key / 429 rate-limit / 5xx / loi mang) -> fallback
//      sang OpenRouter voi co che `models` fallback san co.
// Ca hai deu OpenAI-compatible nen body & response giu nguyen dinh dang.
// =============================================================================

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// =============================================================================
// Guardrails: chong hoi sai chu de (ngoai chay bo), chong lam dung & spam API.
// =============================================================================

// --- Gioi han dau vao (chong payload lon / lam dung). Co the ghi de qua secret. ---
function envInt(name: string, fallback: number): number {
  const v = parseInt(Deno.env.get(name) ?? '', 10);
  return Number.isFinite(v) && v > 0 ? v : fallback;
}

const MAX_MESSAGES = () => envInt('AI_MAX_MESSAGES', 40);          // so luong message toi da
const MAX_MESSAGE_CHARS = () => envInt('AI_MAX_MESSAGE_CHARS', 4000); // do dai 1 message
const MAX_TOTAL_CHARS = () => envInt('AI_MAX_TOTAL_CHARS', 16000);    // tong do dai noi dung
const MAX_PER_MIN = () => envInt('AI_MAX_PER_MIN', 8);               // so request/phut/user (trial|paid)
const MAX_PER_DAY = () => envInt('AI_MAX_PER_DAY', 30);              // so request/ngay/user (trial|paid)
const FREE_MAX_PER_MIN = () => envInt('AI_FREE_MAX_PER_MIN', 3);     // so request/phut/user (free tier)
const FREE_MAX_PER_DAY = () => envInt('AI_FREE_MAX_PER_DAY', 5);     // so request/ngay/user (free tier)

// He thong prompt gioi han chu de: chi tra loi ve chay bo & the chat lien quan.
const TOPIC_GUARDRAIL = `Bạn là "Runny AI" — huấn luyện viên ảo CHỈ chuyên về chạy bộ và thể chất liên quan.
Phạm vi được phép: chạy bộ, luyện tập sức bền/tốc độ, kế hoạch tập, phòng tránh & phục hồi chấn thương, dinh dưỡng và giấc ngủ cho người chạy bộ, giày/thiết bị chạy, động lực tập luyện, phân tích buổi chạy.
Nếu người dùng hỏi ngoài phạm vi trên (ví dụ: lập trình, chính trị, tin tức, toán/đố vui chung, nội dung người lớn, lời khuyên y tế nghiêm trọng, hoặc bất cứ chủ đề không liên quan chạy bộ), hãy TỪ CHỐI một cách lịch sự bằng tiếng Việt, giải thích ngắn gọn rằng bạn chỉ hỗ trợ về chạy bộ, rồi gợi ý họ hỏi một câu liên quan chạy bộ. Tuyệt đối không trả lời nội dung ngoài phạm vi, không tạo nội dung gây hại, thù ghét hay bất hợp pháp.
Luôn trả lời bằng tiếng Việt, ngắn gọn, thân thiện.`;

type ChatMessage = { role?: string; content?: unknown };

// Lay user id tu JWT (platform da verify_jwt). Tra null neu khong phai user that.
function getUserId(req: Request): string | null {
  const auth = req.headers.get('Authorization') ?? req.headers.get('authorization');
  if (!auth) return null;
  const token = auth.replace(/^Bearer\s+/i, '').trim();
  const parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    let b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    b64 += '='.repeat((4 - (b64.length % 4)) % 4); // bù padding cho base64url
    const json = atob(b64);
    const payload = JSON.parse(json);
    // Chi chap nhan user da dang nhap (khong phai anon key).
    if (payload.role !== 'authenticated') return null;
    return typeof payload.sub === 'string' ? payload.sub : null;
  } catch {
    return null;
  }
}

// Kiem tra dau vao hop le, chong payload bat thuong. Tra ve thong bao loi (VI) hoac null.
function validateBody(rawBody: Record<string, unknown>): string | null {
  const messages = rawBody.messages;
  if (!Array.isArray(messages) || messages.length === 0) {
    return 'Yêu cầu không hợp lệ: thiếu nội dung tin nhắn.';
  }
  if (messages.length > MAX_MESSAGES()) {
    return 'Cuộc trò chuyện quá dài. Vui lòng bắt đầu lại.';
  }
  let total = 0;
  for (const m of messages as ChatMessage[]) {
    const content = typeof m?.content === 'string' ? m.content : '';
    if (content.length > MAX_MESSAGE_CHARS()) {
      return 'Tin nhắn quá dài. Vui lòng rút gọn câu hỏi của bạn.';
    }
    total += content.length;
  }
  if (total > MAX_TOTAL_CHARS()) {
    return 'Nội dung gửi đi quá lớn. Vui lòng rút gọn.';
  }
  return null;
}

// Chen guardrail chu de vao dau danh sach messages cho cac yeu cau chat tu do.
// Bo qua khi co response_format (cac yeu cau JSON noi bo nhu tao lich tap — da dung chu de).
function injectGuardrail(rawBody: Record<string, unknown>): Record<string, unknown> {
  if (rawBody.response_format) return rawBody;
  const messages = Array.isArray(rawBody.messages) ? [...(rawBody.messages as ChatMessage[])] : [];
  const guardrail: ChatMessage = { role: 'system', content: TOPIC_GUARDRAIL };
  return { ...rawBody, messages: [guardrail, ...messages] };
}

// Goi RPC check_ai_access bang service role: xac dinh tier (trial|paid|free), ap
// quota theo tier va khoa tinh nang cao cap voi free tier. Fail-open neu ha tang
// loi/chua cau hinh. `feature`: 'chat' (chat tu do) | 'plan' (tao/dieu chinh ke hoach).
async function checkAiAccess(
  userId: string,
  feature: string,
): Promise<{ allowed: boolean; reason?: string; tier?: string }> {
  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceKey) {
    console.warn('AI access check skipped: SUPABASE_URL/SERVICE_ROLE_KEY not set.');
    return { allowed: true };
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
        p_feature: feature,
        p_max_per_min: MAX_PER_MIN(),
        p_max_per_day: MAX_PER_DAY(),
        p_free_max_per_min: FREE_MAX_PER_MIN(),
        p_free_max_per_day: FREE_MAX_PER_DAY(),
      }),
    });
    if (!res.ok) {
      console.warn(`check_ai_access RPC returned ${res.status}`);
      return { allowed: true }; // fail-open
    }
    const data = await res.json();
    return { allowed: data?.allowed !== false, reason: data?.reason, tier: data?.tier };
  } catch (e) {
    console.warn(`check_ai_access RPC failed: ${e}`);
    return { allowed: true }; // fail-open
  }
}

// --- Groq config ------------------------------------------------------------
// Model Groq mac dinh (theo thu tu uu tien). 70b cho chat luong, 8b de vet khi
// 70b het 1K req/ngay. Ghi de: `supabase secrets set GROQ_MODELS="a,b"`.
const GROQ_DEFAULT_MODELS = [
  'llama-3.3-70b-versatile',
  'llama-3.1-8b-instant',
];

const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';

// --- OpenRouter config (fallback) -------------------------------------------
// Danh sach model free mac dinh dung lam fallback (theo thu tu uu tien).
// Co the ghi de bang secret: `supabase secrets set OPENROUTER_FALLBACK_MODELS="a:free,b:free"`
const DEFAULT_FALLBACK_MODELS = [
  'openai/gpt-oss-20b:free',
  'google/gemma-4-26b-a4b-it:free',
  'openrouter/free',
];

// OpenRouter chi cho phep toi da 3 model trong mang `models`.
const MAX_MODELS = 3;

const OPENROUTER_ENDPOINT = 'https://openrouter.ai/api/v1/chat/completions';

function parseList(raw: string | undefined): string[] {
  if (!raw || raw.trim().length === 0) return [];
  return raw.split(',').map((m) => m.trim()).filter((m) => m.length > 0);
}

function getGroqModels(): string[] {
  const custom = parseList(Deno.env.get('GROQ_MODELS'));
  return custom.length > 0 ? custom : GROQ_DEFAULT_MODELS;
}

function getFallbackModels(): string[] {
  const custom = parseList(Deno.env.get('OPENROUTER_FALLBACK_MODELS'));
  return custom.length > 0 ? custom : DEFAULT_FALLBACK_MODELS;
}

// Body gui sang Groq: bo `model`/`models` cua client (id kieu OpenRouter khong hop
// le tren Groq) va dat `model` rieng cho Groq. Giu nguyen messages/response_format/...
function buildGroqBody(rawBody: Record<string, unknown>, model: string): Record<string, unknown> {
  const { model: _m, models: _ms, ...rest } = rawBody;
  return { ...rest, model };
}

// Chuan hoa body cho OpenRouter: dam bao luon co mang `models` de ap dung fallback routing.
function applyModelFallback(body: Record<string, unknown>): Record<string, unknown> {
  const fallback = getFallbackModels();

  if (Array.isArray(body.models) && body.models.length > 0) {
    const capped = [...new Set(body.models as unknown[])].slice(0, MAX_MODELS);
    return { ...body, models: capped };
  }

  const primary = typeof body.model === 'string' ? body.model : null;
  const models = primary ? [primary, ...fallback] : [...fallback];
  const deduped = [...new Set(models)].slice(0, MAX_MODELS);

  const { model: _drop, ...rest } = body;
  return { ...rest, models: deduped };
}

// Thu lan luot cac model Groq. Tra ve Response (200) dau tien thanh cong, nguoc lai null.
async function tryGroq(
  rawBody: Record<string, unknown>,
  apiKey: string,
): Promise<Response | null> {
  for (const model of getGroqModels()) {
    try {
      const res = await fetch(GROQ_ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify(buildGroqBody(rawBody, model)),
      });

      if (res.ok) {
        const data = await res.text();
        return new Response(data, {
          status: res.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json', 'X-AI-Provider': `groq:${model}` },
        });
      }

      // 429 (rate-limit) hoac 5xx -> thu model Groq ke tiep / roi fallback.
      const errText = await res.text();
      console.warn(`Groq model ${model} returned ${res.status}: ${errText}`);
    } catch (e) {
      console.warn(`Groq model ${model} request failed: ${e}`);
    }
  }
  return null;
}

async function callOpenRouter(
  rawBody: Record<string, unknown>,
  apiKey: string,
): Promise<Response> {
  const body = applyModelFallback(rawBody);
  const response = await fetch(OPENROUTER_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
      'HTTP-Referer': 'https://github.com/k4spi4n/runny-ai',
      'X-Title': 'Runny AI',
    },
    body: JSON.stringify(body),
  });

  const responseData = await response.text();
  return new Response(responseData, {
    status: response.status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json', 'X-AI-Provider': 'openrouter' },
  });
}

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const groqApiKey = Deno.env.get('GROQ_API_KEY');
    const openRouterApiKey = Deno.env.get('OPENROUTER_API_KEY');

    if (!groqApiKey && !openRouterApiKey) {
      console.error('Neither GROQ_API_KEY nor OPENROUTER_API_KEY is set');
      return new Response(
        JSON.stringify({ error: 'No AI provider key configured on the server (set GROQ_API_KEY and/or OPENROUTER_API_KEY).' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // --- Guardrail 1: yeu cau user da dang nhap (chong lam dung an danh). ---
    const userId = getUserId(req);
    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Bạn cần đăng nhập để sử dụng trợ lý AI.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const rawBody = await req.json();

    // --- Guardrail 2: kiem tra dau vao (chong payload lon / lam dung). ---
    const validationError = validateBody(rawBody);
    if (validationError) {
      return new Response(
        JSON.stringify({ error: validationError }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // --- Guardrail 3: entitlement + quota theo tier (chong spam API & gate paywall). ---
    // Suy ra tinh nang tu payload: co response_format -> yeu cau JSON (tao/dieu chinh
    // ke hoach) = 'plan'; nguoc lai la chat tu do = 'chat'. Free tier bi khoa 'plan'.
    const feature = rawBody.response_format ? 'plan' : 'chat';
    const access = await checkAiAccess(userId, feature);
    if (!access.allowed) {
      if (access.reason === 'upgrade_required') {
        return new Response(
          JSON.stringify({
            error: 'Tính năng này dành cho gói trả phí. Vui lòng nâng cấp để tiếp tục.',
            code: 'upgrade_required',
          }),
          { status: 402, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
      const msg = access.reason === 'day'
        ? 'Bạn đã đạt giới hạn yêu cầu AI trong ngày. Nâng cấp gói để dùng nhiều hơn, hoặc thử lại vào ngày mai.'
        : 'Bạn đang gửi yêu cầu quá nhanh. Vui lòng chờ một lát rồi thử lại.';
      return new Response(
        JSON.stringify({ error: msg }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // --- Guardrail 4: gioi han chu de (chi chay bo) cho chat tu do. ---
    const body = injectGuardrail(rawBody);

    // 1) Groq lam provider chinh.
    if (groqApiKey) {
      const groqRes = await tryGroq(body, groqApiKey);
      if (groqRes) return groqRes;
      console.warn('Groq unavailable, falling back to OpenRouter');
    }

    // 2) Fallback sang OpenRouter.
    if (openRouterApiKey) {
      return await callOpenRouter(body, openRouterApiKey);
    }

    return new Response(
      JSON.stringify({ error: 'Groq failed and no OpenRouter fallback key is configured.' }),
      { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    console.error('Error in AI proxy:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Internal Server Error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
