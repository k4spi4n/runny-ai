import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

import {
  correlationId,
  envInt,
  fetchWithTimeout,
  readJsonBody,
  RequestBodyError,
} from "../_shared/http.ts";
import { verifyPayosSignature } from "../_shared/payos.ts";

const MAX_WEBHOOK_BYTES = 64_000;

function response(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

serve(async (req) => {
  const requestId = correlationId(req);
  if (req.method !== "POST") {
    return response({ error: "Method not allowed." }, 405);
  }

  const checksumKey = Deno.env.get("PAYOS_CHECKSUM_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!checksumKey || !supabaseUrl || !serviceKey) {
    console.error(JSON.stringify({
      event: "payos_webhook_misconfigured",
      request_id: requestId,
    }));
    return response({ error: "Server not configured." }, 503);
  }

  try {
    const payload = await readJsonBody(req, MAX_WEBHOOK_BYTES);
    const data = payload.data;
    const signature = payload.signature;
    if (
      !data ||
      typeof data !== "object" ||
      Array.isArray(data) ||
      typeof signature !== "string"
    ) {
      return response({ error: "Invalid webhook payload." }, 400);
    }
    const signedData = data as Record<string, unknown>;
    if (!await verifyPayosSignature(checksumKey, signedData, signature)) {
      console.warn(JSON.stringify({
        event: "payos_webhook_signature_mismatch",
        request_id: requestId,
      }));
      return response({ error: "Invalid signature." }, 401);
    }

    // Only signed fields decide whether entitlement can change. Outer
    // payload.success/code are deliberately ignored.
    if (String(signedData.code ?? "") !== "00") {
      return response({ success: true, processed: false });
    }
    const orderCode = Number(signedData.orderCode);
    const amount = Number(signedData.amount);
    if (
      !Number.isSafeInteger(orderCode) ||
      orderCode <= 0 ||
      !Number.isSafeInteger(amount) ||
      amount <= 0
    ) {
      // PayOS sends a signed sample while confirming a webhook. Acknowledge
      // samples that are not valid application order identifiers.
      return response({ success: true, processed: false });
    }

    const processResponse = await fetchWithTimeout(
      `${supabaseUrl}/rest/v1/rpc/process_payos_payment`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          p_order_code: orderCode,
          p_amount: amount,
        }),
      },
      {
        timeoutMs: envInt(
          "PAYOS_INTERNAL_TIMEOUT_MS",
          7_000,
          { min: 2_000, max: 15_000 },
        ),
      },
    );
    if (!processResponse.ok) {
      await processResponse.body?.cancel();
      console.error(JSON.stringify({
        event: "payos_webhook_processing_failed",
        request_id: requestId,
        status: processResponse.status,
      }));
      return response({ error: "Payment processing failed." }, 503);
    }
    const result = await processResponse.json();
    if (result?.reason === "order_not_found") {
      console.warn(JSON.stringify({
        event: "payos_order_not_found",
        request_id: requestId,
      }));
    }
    return response({
      success: true,
      processed: result?.processed === true,
    });
  } catch (error) {
    if (error instanceof RequestBodyError) {
      return response({ error: error.message }, error.status);
    }
    console.error(JSON.stringify({
      event: "payos_webhook_unhandled",
      request_id: requestId,
    }));
    return response({ error: "Internal Server Error." }, 500);
  }
});
