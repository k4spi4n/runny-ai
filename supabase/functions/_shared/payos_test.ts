import {
  buildPayosSignaturePayload,
  hmacSha256Hex,
  verifyPayosSignature,
} from "./payos.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("PayOS signature payload is canonical and sorted", () => {
  const payload = buildPayosSignaturePayload({
    orderCode: 123,
    amount: 99000,
    code: "00",
    description: "Runny",
  });
  assert(
    payload ===
      "amount=99000&code=00&description=Runny&orderCode=123",
    `unexpected canonical payload: ${payload}`,
  );
});

Deno.test("PayOS signed data verifies and tampering fails", async () => {
  const key = "unit-test-checksum-key";
  const data = {
    orderCode: 123456,
    amount: 199000,
    code: "00",
    description: "Monthly Plan",
  };
  const signature = await hmacSha256Hex(
    key,
    buildPayosSignaturePayload(data),
  );
  assert(
    await verifyPayosSignature(key, data, signature),
    "valid signature rejected",
  );
  assert(
    !(await verifyPayosSignature(
      key,
      { ...data, amount: data.amount + 1 },
      signature,
    )),
    "tampered amount accepted",
  );
  assert(
    !(await verifyPayosSignature(key, data, "not-a-signature")),
    "malformed signature accepted",
  );
});
