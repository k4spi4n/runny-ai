import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const lat = url.searchParams.get('lat');
    const lon = url.searchParams.get('lon');

    if (!lat || !lon) {
      return new Response(
        JSON.stringify({ error: 'Missing lat or lon query parameters' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const openWeatherApiKey = Deno.env.get('OPENWEATHER_API_KEY');
    const waqiApiKey = Deno.env.get('WAQI_API_KEY');

    if (!openWeatherApiKey && !waqiApiKey) {
      console.error('Neither OPENWEATHER_API_KEY nor WAQI_API_KEY is set in environment variables');
      return new Response(
        JSON.stringify({ error: 'No API keys set on the server.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    let weatherData = null;
    let waqiData = null;
    let owmAqiData = null;

    // 1. Fetch Weather from OpenWeatherMap if key is set
    if (openWeatherApiKey) {
      try {
        const weatherUrl = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${openWeatherApiKey}&units=metric&lang=vi`;
        const weatherResponse = await fetch(weatherUrl);
        if (weatherResponse.ok) {
          weatherData = await weatherResponse.ok ? await weatherResponse.json() : null;
        }
      } catch (e) {
        console.error('OpenWeather weather error in proxy:', e);
      }

      // Fetch AQI fallback from OpenWeatherMap Air Pollution
      try {
        const owmAirUrl = `https://api.openweathermap.org/data/2.5/air_pollution?lat=${lat}&lon=${lon}&appid=${openWeatherApiKey}`;
        const owmAirResponse = await fetch(owmAirUrl);
        if (owmAirResponse.ok) {
          owmAqiData = await owmAirResponse.json();
        }
      } catch (e) {
        console.error('OpenWeather AQI error in proxy:', e);
      }
    }

    // 2. Fetch AQI and Weather from WAQI if key is set
    if (waqiApiKey) {
      try {
        const waqiUrl = `https://api.waqi.info/feed/geo:${lat};${lon}/?token=${waqiApiKey}`;
        const waqiResponse = await fetch(waqiUrl);
        if (waqiResponse.ok) {
          const waqiJson = await waqiResponse.json();
          if (waqiJson.status === 'ok') {
            waqiData = waqiJson;
          }
        }
      } catch (e) {
        console.error('WAQI error in proxy:', e);
      }
    }

    return new Response(
      JSON.stringify({
        weather: weatherData,
        waqi: waqiData,
        owm_aqi: owmAqiData,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error fetching weather data:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Internal Server Error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
