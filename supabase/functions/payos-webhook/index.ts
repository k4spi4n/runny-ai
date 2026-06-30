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

// Cong them thoi han goi vao 1 moc thoi gian (ISO) theo duration_type.
function addDuration(base: Date, durationType: string): Date {
  const d = new Date(base);
  if (durationType === 'yearly') {
    d.setDate(d.getDate() + 365);
  } else if (durationType === 'weekly') {
    d.setDate(d.getDate() + 7);
  } else {
    d.setDate(d.getDate() + 30); // monthly mac dinh
  }
  return d;
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

    // --- Tim don. Idempotent: da paid -> tra 200. ---
    const orderRes = await fetch(
      `${supabaseUrl}/rest/v1/payment_orders?order_code=eq.${orderCode}&select=order_code,user_id,plan_id,status`,
      { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
    );
    const orders = await orderRes.json();
    const order = Array.isArray(orders) ? orders[0] : null;
    if (!order) {
      console.warn(`PayOS webhook: order ${orderCode} not found.`);
      return jsonResponse({ success: true }); // ping hoac don la -> nhan
    }
    if (order.status === 'paid') {
      return jsonResponse({ success: true }); // da xu ly truoc do
    }

    // --- Lay thoi han goi. ---
    const planRes = await fetch(
      `${supabaseUrl}/rest/v1/subscription_plans?id=eq.${order.plan_id}&select=duration_type`,
      { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
    );
    const planRows = await planRes.json();
    const durationType = Array.isArray(planRows) && planRows[0]?.duration_type
      ? String(planRows[0].duration_type)
      : 'monthly';

    // --- Moc gia han: cong don neu dang con subscription active. ---
    const activeRes = await fetch(
      `${supabaseUrl}/rest/v1/user_subscriptions?user_id=eq.${order.user_id}&status=eq.active&select=id,end_date&order=end_date.desc`,
      { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
    );
    const activeRows = await activeRes.json();
    const now = new Date();
    let base = now;
    if (Array.isArray(activeRows) && activeRows[0]?.end_date) {
      const existingEnd = new Date(activeRows[0].end_date);
      if (existingEnd > now) base = existingEnd; // cong don tu cuoi ky hien tai
    }
    const endDate = addDuration(base, durationType);

    // Huy cac row active cu (tranh trung active).
    if (Array.isArray(activeRows) && activeRows.length > 0) {
      await fetch(
        `${supabaseUrl}/rest/v1/user_subscriptions?user_id=eq.${order.user_id}&status=eq.active`,
        {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
            Prefer: 'return=minimal',
          },
          body: JSON.stringify({ status: 'cancelled' }),
        },
      );
    }

    // Tao subscription active moi.
    const subRes = await fetch(`${supabaseUrl}/rest/v1/user_subscriptions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        Prefer: 'return=minimal',
      },
      body: JSON.stringify({
        user_id: order.user_id,
        plan_id: order.plan_id,
        status: 'active',
        start_date: now.toISOString(),
        end_date: endDate.toISOString(),
      }),
    });
    if (!subRes.ok) {
      console.error('Failed to create subscription:', await subRes.text());
      return jsonResponse({ error: 'Failed to activate subscription.' }, 500);
    }

    // Danh dau don da thanh toan.
    await fetch(`${supabaseUrl}/rest/v1/payment_orders?order_code=eq.${orderCode}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        Prefer: 'return=minimal',
      },
      body: JSON.stringify({ status: 'paid', paid_at: now.toISOString() }),
    });

    return jsonResponse({ success: true });
  } catch (error) {
    console.error('payos-webhook error:', error);
    return jsonResponse({ error: (error as Error).message ?? 'Internal Server Error' }, 500);
  }
});
