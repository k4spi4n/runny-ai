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

interface CacheEntry {
  expiresAt: number;
  payload: Record<string, unknown>;
}

const cache = new Map<string, CacheEntry>();
const CACHE_TTL_MS = 10 * 60 * 1_000;
const CACHE_MAX_ENTRIES = 256;

function cacheGet(key: string): Record<string, unknown> | null {
  const now = Date.now();
  const entry = cache.get(key);
  if (!entry) return null;
  if (entry.expiresAt <= now) {
    cache.delete(key);
    return null;
  }
  cache.delete(key);
  cache.set(key, entry);
  return entry.payload;
}

function cacheSet(key: string, payload: Record<string, unknown>): void {
  const now = Date.now();
  for (const [cachedKey, entry] of cache) {
    if (entry.expiresAt <= now) cache.delete(cachedKey);
  }
  cache.delete(key);
  while (cache.size >= CACHE_MAX_ENTRIES) {
    const oldest = cache.keys().next().value;
    if (typeof oldest !== "string") break;
    cache.delete(oldest);
  }
  cache.set(key, { expiresAt: now + CACHE_TTL_MS, payload });
}

function mapWmoCode(
  code: number | null | undefined,
  isDay: boolean,
): { description: string; icon: string } {
  const suffix = isDay ? "d" : "n";
  switch (code) {
    case 0:
      return { description: "Trời quang", icon: `01${suffix}` };
    case 1:
      return { description: "Trời gần như quang", icon: `02${suffix}` };
    case 2:
      return { description: "Có mây rải rác", icon: `03${suffix}` };
    case 3:
      return { description: "Trời nhiều mây", icon: `04${suffix}` };
    case 45:
    case 48:
      return { description: "Sương mù", icon: `50${suffix}` };
    case 51:
    case 53:
    case 55:
      return { description: "Mưa phùn", icon: `09${suffix}` };
    case 56:
    case 57:
      return { description: "Mưa phùn lạnh", icon: `09${suffix}` };
    case 61:
      return { description: "Mưa nhẹ", icon: `10${suffix}` };
    case 63:
      return { description: "Mưa vừa", icon: `10${suffix}` };
    case 65:
      return { description: "Mưa to", icon: `10${suffix}` };
    case 66:
    case 67:
      return { description: "Mưa lạnh", icon: `13${suffix}` };
    case 71:
    case 73:
    case 75:
    case 77:
      return { description: "Tuyết rơi", icon: `13${suffix}` };
    case 80:
    case 81:
    case 82:
      return { description: "Mưa rào", icon: `09${suffix}` };
    case 85:
    case 86:
      return { description: "Mưa tuyết", icon: `13${suffix}` };
    case 95:
      return { description: "Dông", icon: `11${suffix}` };
    case 96:
    case 99:
      return { description: "Dông kèm mưa đá", icon: `11${suffix}` };
    default:
      return {
        description: "Không có thông tin thời tiết",
        icon: `01${suffix}`,
      };
  }
}

async function fetchJson(
  url: string,
  label: string,
  requestId: string,
): Promise<Record<string, unknown> | null> {
  try {
    const response = await fetchWithTimeout(
      url,
      {},
      {
        timeoutMs: envInt(
          "WEATHER_PROVIDER_TIMEOUT_MS",
          8_000,
          { min: 2_000, max: 20_000 },
        ),
        retries: 1,
      },
    );
    const text = await readTextLimited(response, 256_000);
    if (!response.ok) {
      console.warn(JSON.stringify({
        event: "weather_provider_rejected",
        request_id: requestId,
        provider: label,
        status: response.status,
      }));
      return null;
    }
    const data = JSON.parse(text);
    return data && typeof data === "object" && !Array.isArray(data)
      ? data as Record<string, unknown>
      : null;
  } catch {
    console.warn(JSON.stringify({
      event: "weather_provider_failed",
      request_id: requestId,
      provider: label,
    }));
    return null;
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
  if (!authenticatedUserId(req)) {
    return jsonResponse(req, { error: "Authentication required." }, 401);
  }

  try {
    const body = await readJsonBody(req, 2_048);
    const latitude = Number(body.lat);
    const longitude = Number(body.lon);
    if (
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180
    ) {
      return jsonResponse(
        req,
        { error: "lat and lon must be finite geographic coordinates." },
        400,
      );
    }

    const lat = latitude.toFixed(3);
    const lon = longitude.toFixed(3);
    const cacheKey = `${lat}:${lon}`;
    const cached = cacheGet(cacheKey);
    if (cached) {
      return jsonResponse(
        req,
        cached,
        200,
        { "Cache-Control": "private, max-age=600" },
      );
    }

    const forecastUrl =
      `https://api.open-meteo.com/v1/forecast?latitude=${lat}` +
      `&longitude=${lon}` +
      "&current=temperature_2m,relative_humidity_2m," +
      "apparent_temperature,weather_code,wind_speed_10m,is_day" +
      "&wind_speed_unit=kmh&timezone=auto";
    const airUrl =
      `https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${lat}` +
      `&longitude=${lon}&current=us_aqi&timezone=auto`;
    const waqiKey = Deno.env.get("WAQI_API_KEY");
    const waqiUrl = waqiKey
      ? `https://api.waqi.info/feed/geo:${lat};${lon}/?token=${waqiKey}`
      : null;

    const [forecast, air, waqiRaw] = await Promise.all([
      fetchJson(forecastUrl, "open_meteo_forecast", requestId),
      fetchJson(airUrl, "open_meteo_air", requestId),
      waqiUrl ? fetchJson(waqiUrl, "waqi", requestId) : Promise.resolve(null),
    ]);
    if (!forecast && !air && !waqiRaw) {
      return jsonResponse(
        req,
        { error: "Weather providers are temporarily unavailable." },
        502,
      );
    }

    const current = forecast?.current as Record<string, unknown> | undefined ??
      {};
    const airCurrent = air?.current as Record<string, unknown> | undefined;
    const waqi = waqiRaw?.status === "ok" &&
        waqiRaw.data &&
        typeof waqiRaw.data === "object"
      ? waqiRaw.data as Record<string, unknown>
      : null;
    const isDay = current.is_day === 1 || current.is_day === undefined;
    const weatherCode = typeof current.weather_code === "number"
      ? current.weather_code
      : null;
    const { description, icon } = mapWmoCode(weatherCode, isDay);

    let temperatureC = typeof current.temperature_2m === "number"
      ? current.temperature_2m
      : null;
    const feelsLikeC = typeof current.apparent_temperature === "number"
      ? current.apparent_temperature
      : null;
    let humidity = typeof current.relative_humidity_2m === "number"
      ? Math.round(current.relative_humidity_2m)
      : null;
    let windKph = typeof current.wind_speed_10m === "number"
      ? current.wind_speed_10m
      : null;
    let aqi = typeof airCurrent?.us_aqi === "number"
      ? Math.round(airCurrent.us_aqi)
      : null;
    let source = aqi != null ? "open-meteo" : null;
    if (aqi == null && typeof waqi?.aqi === "number") {
      aqi = waqi.aqi;
      source = "waqi";
    }

    const city = waqi?.city as Record<string, unknown> | undefined;
    const locationName = typeof city?.name === "string" ? city.name : null;
    const iaqi = waqi?.iaqi as Record<string, unknown> | undefined;
    if (iaqi) {
      const temp = iaqi.t as Record<string, unknown> | undefined;
      const humid = iaqi.h as Record<string, unknown> | undefined;
      const wind = iaqi.w as Record<string, unknown> | undefined;
      if (temperatureC == null && typeof temp?.v === "number") {
        temperatureC = temp.v;
      }
      if (humidity == null && typeof humid?.v === "number") {
        humidity = Math.round(humid.v);
      }
      if (windKph == null && typeof wind?.v === "number") {
        windKph = wind.v * 3.6;
      }
    }

    const normalized: Record<string, unknown> = {
      source: source ?? (temperatureC != null ? "open-meteo" : null),
      temperature_c: temperatureC,
      feels_like_c: feelsLikeC ?? temperatureC,
      humidity,
      wind_kph: windKph,
      description,
      icon,
      aqi,
      location_name: locationName,
    };
    cacheSet(cacheKey, normalized);
    return jsonResponse(
      req,
      normalized,
      200,
      { "Cache-Control": "private, max-age=600" },
    );
  } catch (error) {
    if (error instanceof RequestBodyError) {
      return jsonResponse(req, { error: error.message }, error.status);
    }
    console.error(JSON.stringify({
      event: "weather_unhandled",
      request_id: requestId,
    }));
    return jsonResponse(req, { error: "Internal Server Error." }, 500);
  }
});
