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

    const rawBody = await req.json();

    // 1) Groq lam provider chinh.
    if (groqApiKey) {
      const groqRes = await tryGroq(rawBody, groqApiKey);
      if (groqRes) return groqRes;
      console.warn('Groq unavailable, falling back to OpenRouter');
    }

    // 2) Fallback sang OpenRouter.
    if (openRouterApiKey) {
      return await callOpenRouter(rawBody, openRouterApiKey);
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
