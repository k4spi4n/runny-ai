import { normalizeAiRequest, providerModels } from "../_shared/ai_policy.ts";
import {
  type AiTier,
  isProviderCircuitOpen,
  isRetryableProviderStatus,
  providerBody,
  providerConfigs,
  providerHeaders,
  providerTimeoutMs,
  recordProviderFailure,
  recordProviderSuccess,
} from "../_shared/ai_provider.ts";
import { fetchWithTimeout, readTextLimited } from "../_shared/http.ts";

export interface FoodNutrition {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

export interface FoodRecognitionResult {
  food_name: string;
  confidence: number;
  nutrition: FoodNutrition;
}

export interface FoodImageInput {
  filename: string;
  contentType: string;
  byteLength: number;
  bytes: Uint8Array;
}

export class FoodRecognitionError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status = 422,
  ) {
    super(message);
    this.name = "FoodRecognitionError";
  }
}

export interface FoodRecognitionService {
  analyze(image: FoodImageInput): Promise<FoodRecognitionResult>;
}

// =============================================================================
// Multi-provider vision gateway. Provider order is tier-aware and shared with
// the text gateway.
// =============================================================================

// Gioi han hop ly de clamp ket qua model (chong gia tri vo ly / bi prompt-inject).
const MAX_CALORIES = 5000;
const MAX_MACRO_GRAMS = 500;
const MAX_FOOD_NAME_CHARS = 80;

// Yeu cau model tra ve JSON co cau truc, va TU CHOI anh khong phai mon an (is_food=false).
// Day la lop guardrail noi dung: chong nguoi dung upload anh rac/khong lien quan.
const SYSTEM_PROMPT =
  "Bạn là chuyên gia dinh dưỡng nhận diện món ăn qua ảnh. " +
  "Chỉ phân tích DUY NHẤT món ăn/đồ uống chính trong ảnh. " +
  "Nếu ảnh KHÔNG chứa thức ăn/đồ uống thật (ví dụ: người, phong cảnh, văn bản, ảnh chụp màn hình, nội dung phản cảm...), " +
  'hãy đặt "is_food": false và để các trường còn lại bằng 0/"". ' +
  "Ước lượng dinh dưỡng cho MỘT khẩu phần như thấy trong ảnh. " +
  "Đặt tên món bằng tiếng Việt nếu có thể. " +
  "CHỈ trả về JSON đúng schema, không thêm chữ nào khác.";

const USER_PROMPT =
  "Nhận diện món ăn trong ảnh và CHỈ trả về một đối tượng JSON hợp lệ theo schema sau " +
  "(số là số thực, không kèm đơn vị, không thêm chữ hay markdown nào ngoài JSON):\n" +
  '{"is_food": boolean, "food_name": string, "confidence": number (0..1), ' +
  '"nutrition": {"calories": number (kcal), "protein": number (g), "carbs": number (g), "fat": number (g)}}';

// Trich JSON tu noi dung model tra ve, chiu duoc fence markdown (```json ... ```)
// hoac chu thua quanh JSON. Tra ve null neu khong tim thay JSON hop le.
function extractJsonObject(content: string): Record<string, unknown> | null {
  // Bo khoi suy luan <think>...</think> neu model van tra ve dang raw.
  const trimmed = content.replace(/<think>[\s\S]*?<\/think>/gi, "").trim();
  // Uu tien thu parse truc tiep (truong hop model tra ve JSON thuan).
  try {
    return JSON.parse(trimmed) as Record<string, unknown>;
  } catch {
    // bo qua, thu trich tu trong chuoi
  }
  // Lay tu dau '{' den cuoi '}' de bo fence/chu thua.
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start === -1 || end === -1 || end <= start) return null;
  try {
    return JSON.parse(trimmed.slice(start, end + 1)) as Record<string, unknown>;
  } catch {
    return null;
  }
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000; // tranh tran call stack khi spread mang lon vao fromCharCode
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

function clampNumber(value: unknown, min: number, max: number): number {
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) return 0;
  return Math.min(Math.max(n, min), max);
}

export class MultiProviderFoodRecognitionService
  implements FoodRecognitionService {
  constructor(private readonly tier: AiTier) {}

  async analyze(image: FoodImageInput): Promise<FoodRecognitionResult> {
    const mime = image.contentType.toLowerCase().startsWith("image/")
      ? image.contentType
      : "image/jpeg";
    const dataUrl = `data:${mime};base64,${bytesToBase64(image.bytes)}`;

    const normalized = normalizeAiRequest({
      feature: "food_recognition",
      messages: [{
        role: "user",
        content: [
          { type: "text", text: `${SYSTEM_PROMPT}\n\n${USER_PROMPT}` },
          { type: "image_url", image_url: { url: dataUrl } },
        ],
      }],
      response_format: { type: "json_object" },
    });

    let parsed: Record<string, unknown> | null = null;
    for (const config of providerConfigs("food_recognition", this.tier)) {
      if (isProviderCircuitOpen(config.provider)) continue;
      for (const model of providerModels("food_recognition", config.provider)) {
        try {
          const res = await fetchWithTimeout(config.endpoint, {
            method: "POST",
            headers: providerHeaders(config),
            body: JSON.stringify(
              providerBody(normalized, config.provider, model),
            ),
          }, { timeoutMs: providerTimeoutMs(config.provider) });
          if (!res.ok) {
            recordProviderFailure(
              config.provider,
              isRetryableProviderStatus(res.status),
            );
            await res.body?.cancel();
            console.warn(JSON.stringify({
              event: "food_provider_rejected",
              provider: config.provider,
              model,
              status: res.status,
            }));
            continue;
          }
          const responseText = await readTextLimited(res, 1_000_000);
          const payload = JSON.parse(responseText);
          const content: unknown = payload?.choices?.[0]?.message?.content;
          parsed = typeof content === "string"
            ? extractJsonObject(content)
            : null;
          if (!parsed) {
            recordProviderFailure(config.provider, true);
            continue;
          }
          recordProviderSuccess(config.provider);
          break;
        } catch {
          recordProviderFailure(config.provider, true);
          console.warn(JSON.stringify({
            event: "food_provider_failed",
            provider: config.provider,
            model,
          }));
        }
      }
      if (parsed) break;
    }
    if (!parsed) {
      throw new FoodRecognitionError(
        "provider_unavailable",
        "Dịch vụ nhận diện đang bận. Vui lòng thử lại sau ít phút.",
        503,
      );
    }

    const isFood = parsed.is_food === true;
    const foodName = typeof parsed.food_name === "string"
      ? parsed.food_name.trim().slice(0, MAX_FOOD_NAME_CHARS)
      : "";

    if (!isFood || foodName.length === 0) {
      throw new FoodRecognitionError(
        "not_food",
        "Ảnh không chứa món ăn nhận diện được. Vui lòng chụp ảnh món ăn.",
      );
    }

    const nutritionRaw = (parsed.nutrition ?? {}) as Record<string, unknown>;
    return {
      food_name: foodName,
      confidence: clampNumber(parsed.confidence, 0, 1),
      nutrition: {
        calories: Math.round(
          clampNumber(nutritionRaw.calories, 0, MAX_CALORIES),
        ),
        protein: Math.round(
          clampNumber(nutritionRaw.protein, 0, MAX_MACRO_GRAMS),
        ),
        carbs: Math.round(clampNumber(nutritionRaw.carbs, 0, MAX_MACRO_GRAMS)),
        fat: Math.round(clampNumber(nutritionRaw.fat, 0, MAX_MACRO_GRAMS)),
      },
    };
  }
}

// =============================================================================
// Mock provider: dung khi chua co GROQ_API_KEY (phat trien local) hoac
// FOOD_RECOGNITION_PROVIDER=mock. Doan theo ten file, khong phan tich pixel.
// =============================================================================

interface MockFoodProfile extends FoodRecognitionResult {
  keywords: string[];
}

const mockProfiles: MockFoodProfile[] = [
  {
    keywords: ["chicken", "ga", "com-ga", "rice"],
    food_name: "Com ga",
    confidence: 0.92,
    nutrition: { calories: 520, protein: 35, carbs: 55, fat: 15 },
  },
  {
    keywords: ["pho", "noodle", "beef", "bo"],
    food_name: "Pho bo",
    confidence: 0.88,
    nutrition: { calories: 430, protein: 28, carbs: 52, fat: 12 },
  },
  {
    keywords: ["salad", "rau", "green"],
    food_name: "Salad uc ga",
    confidence: 0.86,
    nutrition: { calories: 310, protein: 32, carbs: 18, fat: 12 },
  },
  {
    keywords: ["banh-mi", "banhmi", "sandwich"],
    food_name: "Banh mi",
    confidence: 0.84,
    nutrition: { calories: 470, protein: 20, carbs: 58, fat: 18 },
  },
];

export class MockFoodRecognitionService implements FoodRecognitionService {
  analyze(image: FoodImageInput): Promise<FoodRecognitionResult> {
    if (image.byteLength < 128) {
      return Promise.reject(
        new FoodRecognitionError(
          "food_not_recognized",
          "AI khong nhan dien duoc mon an trong anh. Vui long thu anh khac ro hon.",
        ),
      );
    }

    const normalizedName = image.filename.toLowerCase();
    const matchedProfile = mockProfiles.find((profile) =>
      profile.keywords.some((keyword) => normalizedName.includes(keyword))
    );

    const profile = matchedProfile ?? mockProfiles[0];

    return Promise.resolve({
      food_name: profile.food_name,
      confidence: matchedProfile ? profile.confidence : 0.74,
      nutrition: profile.nutrition,
    });
  }
}

export function createFoodRecognitionService(
  tier: AiTier,
): FoodRecognitionService {
  const provider = Deno.env.get("FOOD_RECOGNITION_PROVIDER") ?? "ai";
  const allowMock =
    Deno.env.get("FOOD_RECOGNITION_ALLOW_MOCK")?.toLowerCase() === "true";

  if (provider === "ai" || provider === "groq") {
    if (providerConfigs("food_recognition", tier).length === 0) {
      throw new FoodRecognitionError(
        "provider_not_configured",
        "Dịch vụ nhận diện món ăn chưa được cấu hình.",
        503,
      );
    }
    return new MultiProviderFoodRecognitionService(tier);
  }

  if (provider === "mock" && allowMock) {
    return new MockFoodRecognitionService();
  }
  throw new FoodRecognitionError(
    "provider_not_configured",
    "Dịch vụ nhận diện món ăn chưa được cấu hình.",
    503,
  );
}
