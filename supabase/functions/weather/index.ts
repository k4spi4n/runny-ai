import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const cache = new Map<string, { expiresAt: number; payload: Record<string, unknown> }>();
const cacheTtlMs = 10 * 60 * 1000;

// Ánh xạ mã thời tiết WMO của Open-Meteo sang mô tả tiếng Việt + mã icon kiểu
// OpenWeather (client render qua https://openweathermap.org/img/wn/{icon}@2x.png).
// Tham khảo: https://open-meteo.com/en/docs (WMO Weather interpretation codes)
function mapWmoCode(code: number | null | undefined, isDay: boolean): {
  description: string;
  icon: string;
} {
  const suffix = isDay ? 'd' : 'n';
  switch (code) {
    case 0:
      return { description: 'Trời quang', icon: `01${suffix}` };
    case 1:
      return { description: 'Trời gần như quang', icon: `02${suffix}` };
    case 2:
      return { description: 'Có mây rải rác', icon: `03${suffix}` };
    case 3:
      return { description: 'Trời nhiều mây', icon: `04${suffix}` };
    case 45:
    case 48:
      return { description: 'Sương mù', icon: `50${suffix}` };
    case 51:
    case 53:
    case 55:
      return { description: 'Mưa phùn', icon: `09${suffix}` };
    case 56:
    case 57:
      return { description: 'Mưa phùn lạnh', icon: `09${suffix}` };
    case 61:
      return { description: 'Mưa nhẹ', icon: `10${suffix}` };
    case 63:
      return { description: 'Mưa vừa', icon: `10${suffix}` };
    case 65:
      return { description: 'Mưa to', icon: `10${suffix}` };
    case 66:
    case 67:
      return { description: 'Mưa lạnh', icon: `13${suffix}` };
    case 71:
    case 73:
    case 75:
    case 77:
      return { description: 'Tuyết rơi', icon: `13${suffix}` };
    case 80:
    case 81:
    case 82:
      return { description: 'Mưa rào', icon: `09${suffix}` };
    case 85:
    case 86:
      return { description: 'Mưa tuyết', icon: `13${suffix}` };
    case 95:
      return { description: 'Dông', icon: `11${suffix}` };
    case 96:
    case 99:
      return { description: 'Dông kèm mưa đá', icon: `11${suffix}` };
    default:
      return { description: 'Không có thông tin thời tiết', icon: `01${suffix}` };
  }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed. Use POST.' }), {
      status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
  try {
    const auth = req.headers.get('authorization') ?? req.headers.get('Authorization');
    if (!auth?.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Authentication required.' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return new Response(JSON.stringify({ error: 'Invalid JSON body.' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const latitude = Number(body.lat);
    const longitude = Number(body.lon);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return new Response(
        JSON.stringify({ error: 'lat and lon must be finite geographic coordinates.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    const lat = latitude.toFixed(3);
    const lon = longitude.toFixed(3);
    const cacheKey = `${lat}:${lon}`;
    const cached = cache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return new Response(JSON.stringify(cached.payload), {
        status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'private, max-age=600' },
      });
    }

    // WAQI là nguồn dự phòng cho AQI khi Open-Meteo không có dữ liệu, đồng thời
    // cung cấp tên địa điểm (Open-Meteo không trả về tên trạm/thành phố).
    const waqiApiKey = Deno.env.get('WAQI_API_KEY');

    // Nguồn chính: Open-Meteo — không cần API key và phủ sóng theo lưới toàn cầu
    // (không phụ thuộc vào trạm quan trắc cụ thể như WAQI).
    const forecastUrl =
      `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}` +
      `&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,is_day` +
      `&wind_speed_unit=kmh&timezone=auto`;
    const airUrl =
      `https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${lat}&longitude=${lon}` +
      `&current=us_aqi&timezone=auto`;
    const waqiUrl = waqiApiKey
      ? `https://api.waqi.info/feed/geo:${lat};${lon}/?token=${waqiApiKey}`
      : null;

    const fetchJson = async (url: string, label: string) => {
      try {
        const res = await fetch(url);
        if (res.ok) return await res.json();
        console.error(`${label} error: ${res.status} ${await res.text()}`);
      } catch (e) {
        console.error(`${label} fetch failed:`, e);
      }
      return null;
    };

    const [forecast, air, waqiRaw] = await Promise.all([
      fetchJson(forecastUrl, 'Open-Meteo forecast'),
      fetchJson(airUrl, 'Open-Meteo air-quality'),
      waqiUrl ? fetchJson(waqiUrl, 'WAQI') : Promise.resolve(null),
    ]);

    const waqi = waqiRaw && waqiRaw.status === 'ok' ? waqiRaw.data : null;

    // --- Chuẩn hoá kết quả ---
    const current = forecast?.current ?? {};
    const isDay = current.is_day === 1 || current.is_day === undefined;
    const { description, icon } = mapWmoCode(current.weather_code, isDay);

    let temperatureC: number | null = typeof current.temperature_2m === 'number'
      ? current.temperature_2m
      : null;
    let feelsLikeC: number | null = typeof current.apparent_temperature === 'number'
      ? current.apparent_temperature
      : null;
    let humidity: number | null = typeof current.relative_humidity_2m === 'number'
      ? Math.round(current.relative_humidity_2m)
      : null;
    let windKph: number | null = typeof current.wind_speed_10m === 'number'
      ? current.wind_speed_10m
      : null;

    // AQI: ưu tiên us_aqi của Open-Meteo, dự phòng bằng WAQI.
    let aqi: number | null = typeof air?.current?.us_aqi === 'number'
      ? Math.round(air.current.us_aqi)
      : null;
    let source = aqi != null ? 'open-meteo' : null;
    if (aqi == null && waqi && typeof waqi.aqi === 'number') {
      aqi = waqi.aqi;
      source = 'waqi';
    }

    // Tên địa điểm: chỉ WAQI cung cấp (Open-Meteo không có).
    const locationName: string | null = waqi?.city?.name ?? null;

    // Nếu Open-Meteo thiếu một vài trường, lấp bằng iaqi của WAQI nếu có.
    if (waqi?.iaqi) {
      const iaqi = waqi.iaqi;
      if (temperatureC == null && typeof iaqi.t?.v === 'number') temperatureC = iaqi.t.v;
      if (humidity == null && typeof iaqi.h?.v === 'number') humidity = Math.round(iaqi.h.v);
      if (windKph == null && typeof iaqi.w?.v === 'number') windKph = iaqi.w.v * 3.6;
    }

    const normalized = {
        source: source ?? (temperatureC != null ? 'open-meteo' : null),
        temperature_c: temperatureC,
        feels_like_c: feelsLikeC ?? temperatureC,
        humidity,
        wind_kph: windKph,
        description,
        icon,
        aqi,
        location_name: locationName,
      };
    cache.set(cacheKey, { expiresAt: Date.now() + cacheTtlMs, payload: normalized });
    return new Response(
      JSON.stringify(normalized),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'private, max-age=600' },
      }
    );
  } catch (error) {
    console.error('Error fetching weather data:', error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Internal Server Error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
