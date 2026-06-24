import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Danh sach model free mac dinh dung lam fallback (theo thu tu uu tien).
// OpenRouter se thu lan luot khi 1 model bi rate-limit/loi -> giam manh ti le that bai.
// Co the ghi de bang secret: `supabase secrets set OPENROUTER_FALLBACK_MODELS="a:free,b:free"`
const DEFAULT_FALLBACK_MODELS = [
  'meta-llama/llama-3.3-70b-instruct:free',
  'google/gemini-2.0-flash-exp:free',
  'deepseek/deepseek-chat-v3-0324:free',
  'qwen/qwen-2.5-72b-instruct:free',
  'mistralai/mistral-small-3.1-24b-instruct:free',
];

function getFallbackModels(): string[] {
  const raw = Deno.env.get('OPENROUTER_FALLBACK_MODELS');
  if (raw && raw.trim().length > 0) {
    return raw.split(',').map((m) => m.trim()).filter((m) => m.length > 0);
  }
  return DEFAULT_FALLBACK_MODELS;
}

// Chuan hoa body: dam bao luon co mang `models` de OpenRouter ap dung fallback routing.
// - Neu client da gui `models` -> ton trong nguyen ven.
// - Neu chi gui `model` -> models = [model, ...fallback] (loai trung).
// - Neu khong gui gi -> dung danh sach fallback.
function applyModelFallback(body: Record<string, unknown>): Record<string, unknown> {
  const fallback = getFallbackModels();

  if (Array.isArray(body.models) && body.models.length > 0) {
    return body;
  }

  const primary = typeof body.model === 'string' ? body.model : null;
  const models = primary ? [primary, ...fallback] : [...fallback];
  const deduped = [...new Set(models)];

  const { model: _drop, ...rest } = body;
  return { ...rest, models: deduped };
}

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const openRouterApiKey = Deno.env.get('OPENROUTER_API_KEY');
    if (!openRouterApiKey) {
      console.error('OPENROUTER_API_KEY is not set in environment variables');
      return new Response(
        JSON.stringify({ error: 'OPENROUTER_API_KEY is not set on the server.' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const rawBody = await req.json();
    const body = applyModelFallback(rawBody);

    // Call OpenRouter API
    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openRouterApiKey}`,
        'HTTP-Referer': 'https://github.com/k4spi4n/runny-ai',
        'X-Title': 'Runny AI',
      },
      body: JSON.stringify(body),
    });

    const responseData = await response.text();

    return new Response(responseData, {
      status: response.status,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    });
  } catch (error) {
    console.error('Error forwarding request to OpenRouter:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Internal Server Error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
