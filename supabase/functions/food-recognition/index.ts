import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  createFoodRecognitionService,
  FoodRecognitionError,
} from './food_recognition_service.ts';

const maxImageBytes = 5 * 1024 * 1024;

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

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const url = new URL(req.url);
  if (!url.pathname.endsWith('/analyze')) {
    return jsonResponse({ error: 'Endpoint not found. Use POST /food-recognition/analyze.' }, 404);
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed. Use POST.' }, 405);
  }

  try {
    const contentType = req.headers.get('content-type') ?? '';
    if (!contentType.toLowerCase().includes('multipart/form-data')) {
      return jsonResponse(
        { error: 'Invalid request. Please upload an image using multipart/form-data.' },
        415,
      );
    }

    const formData = await req.formData();
    const uploadedFile = formData.get('image') ?? formData.get('file');

    if (!(uploadedFile instanceof File)) {
      return jsonResponse({ error: 'No image file was uploaded.' }, 400);
    }

    const looksLikeImage =
      uploadedFile.type.toLowerCase().startsWith('image/') ||
      /\.(jpe?g|png|gif|webp|heic|heif)$/i.test(uploadedFile.name);

    if (!looksLikeImage) {
      return jsonResponse({ error: 'Uploaded file must be an image.' }, 415);
    }

    if (uploadedFile.size > maxImageBytes) {
      return jsonResponse(
        { error: `Image is too large. Maximum size is ${maxImageBytes / 1024 / 1024}MB.` },
        413,
      );
    }

    const bytes = new Uint8Array(await uploadedFile.arrayBuffer());
    const service = createFoodRecognitionService();
    const result = await service.analyze({
      filename: uploadedFile.name,
      contentType: uploadedFile.type,
      byteLength: uploadedFile.size,
      bytes,
    });

    return jsonResponse(result);
  } catch (error) {
    console.error('Food recognition error:', error);

    if (error instanceof FoodRecognitionError) {
      return jsonResponse({ error: error.message, code: error.code }, error.status);
    }

    return jsonResponse({ error: 'Unable to analyze this food image. Please try again.' }, 500);
  }
});
