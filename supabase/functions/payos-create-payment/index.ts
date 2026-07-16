import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

import { authenticatedUserId } from "../_shared/auth.ts";
import {
  correlationId,
  corsHeaders,
  envInt,
  fetchWithTimeout,
  isAllowedBrowserOrigin,
  jsonResponse,
  readJsonBody,
  readTextLimited,
  RequestBodyError,
} from "../_shared/http.ts";
import { hmacSha256Hex, isUuid } from "../_shared/payos.ts";

const PAYOS_ENDPOINT = "https://api-merchant.payos.vn/v2/payment-requests";

interface PaymentOrder {
  order_code: number;
  amount: number;
  plan_id: string;
  plan_name: string;
  duration_type: string;
  reused: boolean;
}

function providerHeaders(
  clientId: string,
  apiKey: string,
): Record<string, string> {
  return {
    "Content-Type": "application/json",
    "x-client-id": clientId,
    "x-api-key": apiKey,
  };
}

async function responseJson(response: Response): Promise<unknown> {
  const text = await readTextLimited(response, 64_000);
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function checkoutFromProvider(data: Record<string, unknown>): string | null {
  const nested = data.data;
  if (!nested || typeof nested !== "object" || Array.isArray(nested)) {
    return null;
  }
  const record = nested as Record<string, unknown>;
  if (
    typeof record.checkoutUrl === "string" &&
    record.checkoutUrl.startsWith("https://pay.payos.vn/")
  ) {
    return record.checkoutUrl;
  }
  const paymentLinkId = record.paymentLinkId ?? record.id;
  if (
    typeof paymentLinkId === "string" &&
    /^[A-Za-z0-9_-]{10,100}$/.test(paymentLinkId)
  ) {
    return `https://pay.payos.vn/web/${paymentLinkId}`;
  }
  return null;
}

function appBaseUrl(): string {
  const raw = (Deno.env.get("APP_BASE_URL") ??
    "https://runny-ai.onrender.com").replace(/\/+$/, "");
  const url = new URL(raw);
  const local = url.hostname === "localhost" || url.hostname === "127.0.0.1";
  if (url.protocol !== "https:" && !(local && url.protocol === "http:")) {
    throw new Error("invalid_app_base_url");
  }
  return url.toString().replace(/\/+$/, "");
}

async function recoverCheckout(
  orderCode: number,
  headers: Record<string, string>,
): Promise<{ checkoutUrl?: string; definitiveMissing: boolean }> {
  const response = await fetchWithTimeout(
    `${PAYOS_ENDPOINT}/${orderCode}`,
    { headers },
    {
      timeoutMs: envInt(
        "PAYOS_PROVIDER_TIMEOUT_MS",
        12_000,
        { min: 3_000, max: 30_000 },
      ),
      retries: 1,
    },
  );
  const parsed = await responseJson(response);
  const body = parsed && typeof parsed === "object" && !Array.isArray(parsed)
    ? parsed as Record<string, unknown>
    : {};
  if (response.status === 404) return { definitiveMissing: true };
  if (!response.ok || body.code !== "00") {
    throw new Error("payos_recovery_failed");
  }
  const checkoutUrl = checkoutFromProvider(body);
  const providerData = body.data as Record<string, unknown> | undefined;
  if (
    checkoutUrl &&
    (providerData?.status === "PENDING" ||
      providerData?.status === "PROCESSING")
  ) {
    return { checkoutUrl, definitiveMissing: false };
  }
  throw new Error("payos_order_not_pending");
}

async function cancelPendingOrder(
  supabaseUrl: string,
  serviceKey: string,
  orderCode: number,
  userId: string,
): Promise<void> {
  try {
    const response = await fetchWithTimeout(
      `${supabaseUrl}/rest/v1/rpc/cancel_payment_order`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          p_order_code: orderCode,
          p_user_id: userId,
        }),
      },
      { timeoutMs: 5_000 },
    );
    await response.body?.cancel();
  } catch {
    // The pending order remains auditable and expires from idempotent reuse
    // after 30 minutes even if this best-effort cleanup fails.
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
  if (req.method !== "POST") {
    return jsonResponse(req, { error: "Method not allowed." }, 405);
  }

  const clientId = Deno.env.get("PAYOS_CLIENT_ID");
  const apiKey = Deno.env.get("PAYOS_API_KEY");
  const checksumKey = Deno.env.get("PAYOS_CHECKSUM_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (
    !clientId ||
    !apiKey ||
    !checksumKey ||
    !supabaseUrl ||
    !serviceKey
  ) {
    console.error(JSON.stringify({
      event: "payos_create_misconfigured",
      request_id: requestId,
    }));
    return jsonResponse(
      req,
      { error: "Cổng thanh toán chưa được cấu hình." },
      503,
    );
  }

  const userId = authenticatedUserId(req);
  if (!userId) {
    return jsonResponse(
      req,
      { error: "Bạn cần đăng nhập để thanh toán." },
      401,
    );
  }

  let order: PaymentOrder | null = null;
  try {
    const body = await readJsonBody(req, 2_048);
    const planId = body.plan_id;
    const idempotencyKey = body.idempotency_key;
    if (
      !isUuid(planId) ||
      typeof idempotencyKey !== "string" ||
      !/^[A-Za-z0-9._:-]{16,120}$/.test(idempotencyKey)
    ) {
      return jsonResponse(
        req,
        { error: "Yêu cầu thanh toán không hợp lệ." },
        400,
      );
    }

    const orderResponse = await fetchWithTimeout(
      `${supabaseUrl}/rest/v1/rpc/create_payment_order`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          p_user_id: userId,
          p_plan_id: planId,
          p_idempotency_key: idempotencyKey,
        }),
      },
      { timeoutMs: 7_000 },
    );
    const orderData = await responseJson(orderResponse);
    if (!orderResponse.ok || !Array.isArray(orderData) || !orderData[0]) {
      console.warn(JSON.stringify({
        event: "payos_order_create_rejected",
        request_id: requestId,
        status: orderResponse.status,
      }));
      return jsonResponse(
        req,
        {
          error: orderResponse.status === 429
            ? "Bạn đang tạo đơn quá nhanh. Vui lòng chờ một lát."
            : "Không thể tạo đơn thanh toán. Vui lòng thử lại.",
        },
        orderResponse.status === 429 ? 429 : 503,
      );
    }
    const rawOrder = orderData[0] as Record<string, unknown>;
    const orderCode = Number(rawOrder.order_code);
    const amount = Number(rawOrder.amount);
    if (
      !Number.isSafeInteger(orderCode) ||
      orderCode <= 0 ||
      !Number.isSafeInteger(amount) ||
      amount <= 0 ||
      !isUuid(rawOrder.plan_id) ||
      typeof rawOrder.duration_type !== "string"
    ) {
      throw new Error("invalid_payment_order_response");
    }
    order = {
      order_code: orderCode,
      amount,
      plan_id: rawOrder.plan_id,
      plan_name: typeof rawOrder.plan_name === "string"
        ? rawOrder.plan_name
        : "Runny",
      duration_type: rawOrder.duration_type,
      reused: rawOrder.reused === true,
    };

    const headers = providerHeaders(clientId, apiKey);
    if (order.reused) {
      try {
        const recovered = await recoverCheckout(order.order_code, headers);
        if (recovered.checkoutUrl) {
          return jsonResponse(
            req,
            {
              checkoutUrl: recovered.checkoutUrl,
              orderCode: order.order_code,
              reused: true,
            },
            200,
            { "X-Request-ID": requestId },
          );
        }
      } catch (error) {
        if (
          error instanceof Error &&
          error.message === "payos_order_not_pending"
        ) {
          await cancelPendingOrder(
            supabaseUrl,
            serviceKey,
            order.order_code,
            userId,
          );
          return jsonResponse(
            req,
            {
              error: "Đơn thanh toán cũ không còn hiệu lực. Vui lòng thử lại.",
            },
            409,
          );
        }
        if (
          !(error instanceof Error) ||
          error.message !== "payos_recovery_failed"
        ) {
          throw error;
        }
        return jsonResponse(
          req,
          { error: "Cổng thanh toán đang bận. Vui lòng thử lại." },
          503,
        );
      }
    }

    const baseUrl = appBaseUrl();
    const returnUrl = `${baseUrl}/?payment=success`;
    const cancelUrl = `${baseUrl}/?payment=cancel`;
    const description = order.duration_type === "yearly"
      ? "RunnyNam"
      : "RunnyTh";
    const signaturePayload = `amount=${order.amount}&cancelUrl=${cancelUrl}` +
      `&description=${description}&orderCode=${order.order_code}` +
      `&returnUrl=${returnUrl}`;
    const signature = await hmacSha256Hex(
      checksumKey,
      signaturePayload,
    );

    const payosResponse = await fetchWithTimeout(
      PAYOS_ENDPOINT,
      {
        method: "POST",
        headers,
        body: JSON.stringify({
          orderCode: order.order_code,
          amount: order.amount,
          description,
          cancelUrl,
          returnUrl,
          signature,
        }),
      },
      {
        timeoutMs: envInt(
          "PAYOS_PROVIDER_TIMEOUT_MS",
          12_000,
          { min: 3_000, max: 30_000 },
        ),
      },
    );
    const parsedProvider = await responseJson(payosResponse);
    const providerData = parsedProvider &&
        typeof parsedProvider === "object" &&
        !Array.isArray(parsedProvider)
      ? parsedProvider as Record<string, unknown>
      : {};
    const checkoutUrl = checkoutFromProvider(providerData);
    if (payosResponse.ok && providerData.code === "00" && checkoutUrl) {
      return jsonResponse(
        req,
        {
          checkoutUrl,
          orderCode: order.order_code,
          reused: false,
        },
        200,
        { "X-Request-ID": requestId },
      );
    }

    // If PayOS accepted the original request but its response was lost, lookup
    // by the same merchant order code recovers the existing checkout link.
    try {
      const recovered = await recoverCheckout(order.order_code, headers);
      if (recovered.checkoutUrl) {
        return jsonResponse(
          req,
          {
            checkoutUrl: recovered.checkoutUrl,
            orderCode: order.order_code,
            reused: true,
          },
          200,
          { "X-Request-ID": requestId },
        );
      }
    } catch {
      // Handle definitive client rejection below; transient provider state
      // leaves the pending order intact for a later idempotent retry.
    }

    if (
      payosResponse.status >= 400 &&
      payosResponse.status < 500 &&
      payosResponse.status !== 429
    ) {
      await cancelPendingOrder(
        supabaseUrl,
        serviceKey,
        order.order_code,
        userId,
      );
    }
    console.warn(JSON.stringify({
      event: "payos_provider_create_failed",
      request_id: requestId,
      status: payosResponse.status,
    }));
    return jsonResponse(
      req,
      { error: "Không tạo được liên kết thanh toán. Vui lòng thử lại." },
      payosResponse.status === 429 || payosResponse.status >= 500 ? 503 : 502,
    );
  } catch (error) {
    if (error instanceof RequestBodyError) {
      return jsonResponse(req, { error: error.message }, error.status);
    }
    console.error(JSON.stringify({
      event: "payos_create_unhandled",
      request_id: requestId,
      has_order: order !== null,
    }));
    return jsonResponse(
      req,
      { error: "Không thể tạo đơn thanh toán. Vui lòng thử lại." },
      503,
    );
  }
});
