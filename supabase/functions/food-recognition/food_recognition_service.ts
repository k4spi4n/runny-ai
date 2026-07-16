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
// Groq vision provider: nhan dien mon an that bang model vision cua Groq.
// OpenAI-compatible chat/completions + image_url (data URL base64).
// =============================================================================

// Model vision mac dinh. Ghi de bang secret: `supabase secrets set FOOD_RECOGNITION_MODEL=...`
// qwen/qwen3.6-27b la model multimodal con song tren Groq (llama-4-scout shutdown 2026-07-17).
// LUU Y: model nay khong ho tro response_format json_object on dinh -> phai prompt JSON + tu parse.
const GROQ_DEFAULT_VISION_MODEL = "qwen/qwen3.6-27b";
const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";

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

export class GroqFoodRecognitionService implements FoodRecognitionService {
  constructor(
    private readonly apiKey: string,
    private readonly model: string,
  ) {}

  async analyze(image: FoodImageInput): Promise<FoodRecognitionResult> {
    const mime = image.contentType.toLowerCase().startsWith("image/")
      ? image.contentType
      : "image/jpeg";
    const dataUrl = `data:${mime};base64,${bytesToBase64(image.bytes)}`;

    let res: Response;
    try {
      res = await fetchWithTimeout(GROQ_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify({
          model: this.model,
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            {
              role: "user",
              content: [
                { type: "text", text: USER_PROMPT },
                { type: "image_url", image_url: { url: dataUrl } },
              ],
            },
          ],
          // Tat che do suy luan (thinking) cua qwen3.6: tranh dot het token vao reasoning
          // khien `content` rong/cut -> JSON khong parse duoc.
          reasoning_effort: "none",
          temperature: 0.2,
          max_tokens: 700,
        }),
      }, {
        timeoutMs: envInt(
          "FOOD_PROVIDER_TIMEOUT_MS",
          20_000,
          { min: 3_000, max: 45_000 },
        ),
      });
    } catch {
      console.error("Groq vision request failed.");
      throw new FoodRecognitionError(
        "provider_unavailable",
        "Không thể kết nối dịch vụ nhận diện. Vui lòng thử lại sau.",
        503,
      );
    }

    if (!res.ok) {
      await readTextLimited(res);
      console.error(`Groq vision returned ${res.status}.`);
      // 429 -> de client biet la qua tai/han muc nha cung cap.
      const status = res.status === 429 ? 429 : 502;
      throw new FoodRecognitionError(
        "provider_error",
        "Dịch vụ nhận diện đang bận. Vui lòng thử lại sau ít phút.",
        status,
      );
    }

    const payload = await res.json();
    const choice = payload?.choices?.[0];
    const content: unknown = choice?.message?.content;
    if (typeof content !== "string" || content.trim().length === 0) {
      console.error("Groq vision returned empty content.");
      throw new FoodRecognitionError(
        "food_not_recognized",
        "AI không nhận diện được món ăn trong ảnh. Vui lòng thử ảnh khác rõ hơn.",
      );
    }

    const parsed = extractJsonObject(content);
    if (!parsed) {
      console.error("Groq vision returned invalid JSON.");
      throw new FoodRecognitionError(
        "food_not_recognized",
        "AI không nhận diện được món ăn trong ảnh. Vui lòng thử ảnh khác rõ hơn.",
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
  async analyze(image: FoodImageInput): Promise<FoodRecognitionResult> {
    if (image.byteLength < 128) {
      throw new FoodRecognitionError(
        "food_not_recognized",
        "AI khong nhan dien duoc mon an trong anh. Vui long thu anh khac ro hon.",
      );
    }

    const normalizedName = image.filename.toLowerCase();
    const matchedProfile = mockProfiles.find((profile) =>
      profile.keywords.some((keyword) => normalizedName.includes(keyword))
    );

    const profile = matchedProfile ?? mockProfiles[0];

    return {
      food_name: profile.food_name,
      confidence: matchedProfile ? profile.confidence : 0.74,
      nutrition: profile.nutrition,
    };
  }
}

export function createFoodRecognitionService(): FoodRecognitionService {
  const groqKey = Deno.env.get("GROQ_API_KEY");
  const provider = Deno.env.get("FOOD_RECOGNITION_PROVIDER") ?? "groq";
  const allowMock =
    Deno.env.get("FOOD_RECOGNITION_ALLOW_MOCK")?.toLowerCase() === "true";

  if (provider === "groq") {
    if (!groqKey) {
      throw new FoodRecognitionError(
        "provider_not_configured",
        "Dịch vụ nhận diện món ăn chưa được cấu hình.",
        503,
      );
    }
    const model = Deno.env.get("FOOD_RECOGNITION_MODEL") ??
      GROQ_DEFAULT_VISION_MODEL;
    return new GroqFoodRecognitionService(groqKey, model);
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
import { envInt, fetchWithTimeout, readTextLimited } from "../_shared/http.ts";
