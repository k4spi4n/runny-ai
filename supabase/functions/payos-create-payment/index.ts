import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// =============================================================================
// Tao link thanh toan PayOS cho 1 goi subscription.
//   1. Yeu cau user da dang nhap (JWT role == authenticated).
//   2. Doc gia goi tu DB bang service role (khong tin gia client gui).
//   3. Sinh orderCode, ky request (HMAC-SHA256 checksum key), goi PayOS.
//   4. Luu payment_orders (pending) de webhook doi soat sau.
// Tra ve { checkoutUrl, orderCode }.
// =============================================================================

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const PAYOS_ENDPOINT = 'https://api-merchant.payos.vn/v2/payment-requests';

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// Lay user id tu JWT (platform da verify_jwt). Tra null neu khong phai user that.
function getUserId(req: Request): string | null {
  const auth = req.headers.get('Authorization') ?? req.headers.get('authorization');
  if (!auth) return null;
  const token = auth.replace(/^Bearer\s+/i, '').trim();
  const parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    let b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    b64 += '='.repeat((4 - (b64.length % 4)) % 4);
    const payload = JSON.parse(atob(b64));
    if (payload.role !== 'authenticated') return null;
    return typeof payload.sub === 'string' ? payload.sub : null;
  } catch {
    return null;
  }
}

// HMAC-SHA256 -> hex. Dung de ky du lieu PayOS theo checksum key.
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

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed. Use POST.' }, 405);
  }

  const clientId = Deno.env.get('PAYOS_CLIENT_ID');
  const apiKey = Deno.env.get('PAYOS_API_KEY');
  const checksumKey = Deno.env.get('PAYOS_CHECKSUM_KEY');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!clientId || !apiKey || !checksumKey) {
    console.error('PayOS secrets are not configured.');
    return jsonResponse({ error: 'Cổng thanh toán chưa được cấu hình.' }, 500);
  }
  if (!supabaseUrl || !serviceKey) {
    console.error('SUPABASE_URL/SERVICE_ROLE_KEY not set.');
    return jsonResponse({ error: 'Lỗi cấu hình máy chủ.' }, 500);
  }

  try {
    const userId = getUserId(req);
    if (!userId) {
      return jsonResponse({ error: 'Bạn cần đăng nhập để thanh toán.' }, 401);
    }

    const rawBody = await req.json().catch(() => ({}));
    const planId = typeof rawBody?.plan_id === 'string' ? rawBody.plan_id : null;
    if (!planId) {
      return jsonResponse({ error: 'Thiếu thông tin gói cần mua.' }, 400);
    }

    // --- Doc gia goi tu DB (service role) — khong tin gia client gui. ---
    const planRes = await fetch(
      `${supabaseUrl}/rest/v1/subscription_plans?id=eq.${planId}&is_active=eq.true&select=id,name,price,duration_type`,
      {
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
        },
      },
    );
    const plans = await planRes.json();
    const plan = Array.isArray(plans) ? plans[0] : null;
    if (!plan) {
      return jsonResponse({ error: 'Không tìm thấy gói hợp lệ.' }, 404);
    }

    // Persist the order before asking PayOS for a checkout URL.  The DB allocates
    // a collision-free code and re-reads the active plan price server-side.
    const orderRes = await fetch(`${supabaseUrl}/rest/v1/rpc/create_payment_order`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
      body: JSON.stringify({ p_user_id: userId, p_plan_id: plan.id }),
    });
    const orderRows = await orderRes.json();
    const order = Array.isArray(orderRows) ? orderRows[0] : null;
    if (!orderRes.ok || !order) {
      console.error('Failed to create pending payment order:', orderRows);
      return jsonResponse({ error: 'Không thể tạo đơn thanh toán. Vui lòng thử lại.' }, 503);
    }
    const amount = Number(order.amount);
    const orderCode = Number(order.order_code);
    if (!Number.isSafeInteger(orderCode) || !Number.isFinite(amount) || amount <= 0) {
      return jsonResponse({ error: 'Đơn thanh toán không hợp lệ.' }, 500);
    }
    // PayOS gioi han description <= 25 ky tu.
    const description = `Runny ${plan.duration_type === 'yearly' ? 'goi nam' : 'goi thang'}`.slice(0, 25);

    const appBase = (Deno.env.get('APP_BASE_URL') ?? 'https://runny-ai.onrender.com/').replace(/\/+$/, '');
    const returnUrl = `${appBase}/?payment=success`;
    const cancelUrl = `${appBase}/?payment=cancel`;

    // Chu ky PayOS: cac truong sap xep theo alpha, noi bang '&', HMAC-SHA256 hex.
    const signatureData =
      `amount=${amount}&cancelUrl=${cancelUrl}&description=${description}&orderCode=${orderCode}&returnUrl=${returnUrl}`;
    const signature = await hmacSha256Hex(checksumKey, signatureData);

    const payosRes = await fetch(PAYOS_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-client-id': clientId,
        'x-api-key': apiKey,
      },
      body: JSON.stringify({
        orderCode,
        amount,
        description,
        cancelUrl,
        returnUrl,
        signature,
      }),
    });

    const payosData = await payosRes.json();
    const checkoutUrl = payosData?.data?.checkoutUrl;
    // A provider failure leaves a durable, cancelled audit row rather than an
    // orphan checkout URL that the webhook cannot reconcile.
    if (!payosRes.ok || payosData?.code !== '00' || !checkoutUrl) {
      await fetch(`${supabaseUrl}/rest/v1/payment_orders?order_code=eq.${orderCode}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', apikey: serviceKey, Authorization: `Bearer ${serviceKey}` },
        body: JSON.stringify({ status: 'cancelled' }),
      });
      console.error('PayOS create payment failed:', JSON.stringify(payosData));
      return jsonResponse({ error: 'Không tạo được liên kết thanh toán. Vui lòng thử lại.' }, 502);
    }

    return jsonResponse({ checkoutUrl, orderCode });
  } catch (error) {
    console.error('payos-create-payment error:', error);
    return jsonResponse({ error: (error as Error).message ?? 'Internal Server Error' }, 500);
  }
});
