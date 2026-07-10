import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// =============================================================================
// Webhook PayOS: kich hoat/gia han subscription khi thanh toan thanh cong.
//   - verify_jwt = false (PayOS goi khong kem JWT Supabase) -> xem config.toml.
//   - Xac thuc chu ky webhook bang PAYOS_CHECKSUM_KEY.
//   - Doi soat theo order_code; idempotent (da paid -> tra 200, khong lam lai).
//   - Khi thanh cong: payment_orders.paid + tao/gia han user_subscriptions
//     (end_date cong don: greatest(now, end_date hien tai) + thoi han goi).
// =============================================================================

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

async function hmacSha256Hex(key: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    enc.encode(key),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', cryptoKey, enc.encode(message));
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

// Chu ky webhook PayOS: cac field cua `data` sap xep theo key (alpha), noi thanh
// querystring key=value&..., gia tri null/undefined -> '', roi HMAC-SHA256 hex.
function buildSignaturePayload(data: Record<string, unknown>): string {
  return Object.keys(data)
    .sort()
    .map((k) => {
      const v = data[k];
      const s = v === null || v === undefined ? '' : String(v);
      return `${k}=${s}`;
    })
    .join('&');
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  const checksumKey = Deno.env.get('PAYOS_CHECKSUM_KEY');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!checksumKey || !supabaseUrl || !serviceKey) {
    console.error('PayOS webhook misconfigured (missing checksum/service key).');
    return jsonResponse({ error: 'Server not configured.' }, 500);
  }

  try {
    const payload = await req.json();
    const data = payload?.data as Record<string, unknown> | undefined;
    const signature = payload?.signature as string | undefined;

    // --- Xac thuc chu ky. ---
    if (!data || !signature) {
      return jsonResponse({ error: 'Invalid webhook payload.' }, 400);
    }
    const expected = await hmacSha256Hex(checksumKey, buildSignaturePayload(data));
    if (expected !== signature) {
      console.warn('PayOS webhook signature mismatch.');
      return jsonResponse({ error: 'Invalid signature.' }, 401);
    }

    const orderCode = Number(data.orderCode);
    if (!Number.isFinite(orderCode)) {
      // Ping kiem tra webhook cua PayOS (orderCode mau) -> nhan, khong xu ly.
      return jsonResponse({ success: true });
    }

    // PayOS coi giao dich thanh cong khi code === '00'.
    const success = payload?.success === true || payload?.code === '00' || data.code === '00';
    if (!success) {
      return jsonResponse({ success: true }); // khong phai thanh cong -> bo qua
    }

    const amount = Number(data.amount);
    if (!Number.isSafeInteger(amount) || amount <= 0) {
      return jsonResponse({ error: 'Invalid payment amount.' }, 400);
    }
    // The RPC locks the order row and performs all subscription mutations in
    // one transaction, making duplicate/concurrent webhooks idempotent.
    const processRes = await fetch(`${supabaseUrl}/rest/v1/rpc/process_payos_payment`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: serviceKey, Authorization: `Bearer ${serviceKey}` },
      body: JSON.stringify({ p_order_code: orderCode, p_amount: amount }),
    });
    const result = await processRes.json();
    if (!processRes.ok) {
      console.error('PayOS payment processing failed:', result);
      return jsonResponse({ error: 'Failed to activate subscription.' }, 500);
    }
    if (result?.reason === 'order_not_found') console.warn(`PayOS webhook: order ${orderCode} not found.`);
    return jsonResponse({ success: true, processed: result?.processed === true });
  } catch (error) {
    console.error('payos-webhook error:', error);
    return jsonResponse({ error: (error as Error).message ?? 'Internal Server Error' }, 500);
  }
});
