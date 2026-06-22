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
    this.name = 'FoodRecognitionError';
  }
}

export interface FoodRecognitionService {
  analyze(image: FoodImageInput): Promise<FoodRecognitionResult>;
}

interface MockFoodProfile extends FoodRecognitionResult {
  keywords: string[];
}

const mockProfiles: MockFoodProfile[] = [
  {
    keywords: ['chicken', 'ga', 'com-ga', 'rice'],
    food_name: 'Com ga',
    confidence: 0.92,
    nutrition: {
      calories: 520,
      protein: 35,
      carbs: 55,
      fat: 15,
    },
  },
  {
    keywords: ['pho', 'noodle', 'beef', 'bo'],
    food_name: 'Pho bo',
    confidence: 0.88,
    nutrition: {
      calories: 430,
      protein: 28,
      carbs: 52,
      fat: 12,
    },
  },
  {
    keywords: ['salad', 'rau', 'green'],
    food_name: 'Salad uc ga',
    confidence: 0.86,
    nutrition: {
      calories: 310,
      protein: 32,
      carbs: 18,
      fat: 12,
    },
  },
  {
    keywords: ['banh-mi', 'banhmi', 'sandwich'],
    food_name: 'Banh mi',
    confidence: 0.84,
    nutrition: {
      calories: 470,
      protein: 20,
      carbs: 58,
      fat: 18,
    },
  },
];

export class MockFoodRecognitionService implements FoodRecognitionService {
  async analyze(image: FoodImageInput): Promise<FoodRecognitionResult> {
    if (image.byteLength < 128) {
      throw new FoodRecognitionError(
        'food_not_recognized',
        'AI khong nhan dien duoc mon an trong anh. Vui long thu anh khac ro hon.',
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
  const provider = Deno.env.get('FOOD_RECOGNITION_PROVIDER') ?? 'mock';

  if (provider !== 'mock') {
    console.warn(
      `FOOD_RECOGNITION_PROVIDER=${provider} is not implemented yet. Falling back to mock service.`,
    );
  }

  return new MockFoodRecognitionService();
}
