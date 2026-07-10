// =============================================================================
// Logic dùng chung cho tích hợp Strava (OAuth + đồng bộ hoạt động).
// Dùng bởi cả Edge Function `strava_oauth` (client gọi) và `strava_webhook`
// (Strava đẩy sự kiện). API key/secret luôn ở server, không bao giờ lộ ra client.
// =============================================================================

const STRAVA_TOKEN_URL = 'https://www.strava.com/oauth/token';
const STRAVA_API = 'https://www.strava.com/api/v3';

// Chỉ tự nhập các hoạt động dạng chạy bộ (sản phẩm là HLV chạy bộ).
const RUN_TYPES = new Set(['Run', 'TrailRun', 'VirtualRun']);

export interface StravaCredentials {
  clientId: string;
  clientSecret: string;
}

export function getStravaCredentials(): StravaCredentials {
  const clientId = Deno.env.get('STRAVA_CLIENT_ID') ?? '';
  const clientSecret = Deno.env.get('STRAVA_CLIENT_SECRET') ?? '';
  if (!clientId || !clientSecret) {
    throw new Error('Thiếu STRAVA_CLIENT_ID / STRAVA_CLIENT_SECRET trên server.');
  }
  return { clientId, clientSecret };
}

export interface StravaTokenResult {
  accessToken: string;
  refreshToken: string;
  expiresAt: number; // epoch seconds
  athleteId?: number;
}

/// Đổi authorization code (từ luồng OAuth) lấy access/refresh token + athlete id.
export async function exchangeCode(code: string): Promise<StravaTokenResult> {
  const { clientId, clientSecret } = getStravaCredentials();
  const res = await fetch(STRAVA_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: clientId,
      client_secret: clientSecret,
      code,
      grant_type: 'authorization_code',
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Strava token exchange thất bại (${res.status}): ${text}`);
  }
  const data = await res.json();
  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresAt: data.expires_at,
    athleteId: data.athlete?.id,
  };
}

export interface StravaConnection {
  user_id: string;
  athlete_id: string | null;
  access_token: string | null;
  refresh_token: string | null;
  expires_at: string | null;
  requires_reauth: boolean;
}

/// Đảm bảo có access token còn hạn; nếu sắp/đã hết hạn thì refresh và lưu lại.
// deno-lint-ignore no-explicit-any
export async function ensureFreshToken(
  supabase: any,
  connection: StravaConnection,
): Promise<string> {
  const nowSec = Math.floor(Date.now() / 1000);
  const expiresAtSec = connection.expires_at
    ? Math.floor(new Date(connection.expires_at).getTime() / 1000)
    : 0;

  // Còn hạn (đệm 60s) -> dùng luôn.
  if (!connection.requires_reauth && connection.access_token && expiresAtSec - 60 > nowSec) {
    return connection.access_token;
  }

  if (connection.requires_reauth || !connection.refresh_token) {
    throw new Error('Người dùng chưa kết nối Strava (thiếu refresh token).');
  }

  const { clientId, clientSecret } = getStravaCredentials();
  const res = await fetch(STRAVA_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: 'refresh_token',
      refresh_token: connection.refresh_token,
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Strava refresh token thất bại (${res.status}): ${text}`);
  }
  const data = await res.json();

  const { error } = await supabase.rpc('save_strava_connection', {
    p_user_id: connection.user_id,
    p_athlete_id: connection.athlete_id,
    p_access_token: data.access_token,
    p_refresh_token: data.refresh_token,
    p_expires_at: new Date(data.expires_at * 1000).toISOString(),
  });
  if (error) throw new Error(`Không thể lưu Strava token mới: ${error.message}`);

  return data.access_token;
}

// deno-lint-ignore no-explicit-any
export async function fetchActivity(
  accessToken: string,
  activityId: number | string,
): Promise<any> {
  const res = await fetch(`${STRAVA_API}/activities/${activityId}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Strava lấy hoạt động thất bại (${res.status}): ${text}`);
  }
  return await res.json();
}

// deno-lint-ignore no-explicit-any
export async function fetchRecentActivities(
  accessToken: string,
  { perPage = 30, after }: { perPage?: number; after?: number } = {},
): Promise<any[]> {
  const params = new URLSearchParams({ per_page: String(perPage) });
  if (after) params.set('after', String(after));
  const res = await fetch(`${STRAVA_API}/athlete/activities?${params}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Strava lấy danh sách hoạt động thất bại (${res.status}): ${text}`);
  }
  return await res.json();
}

// deno-lint-ignore no-explicit-any
export function isRunActivity(act: any): boolean {
  const type = act?.sport_type ?? act?.type ?? '';
  return RUN_TYPES.has(type);
}

// deno-lint-ignore no-explicit-any
export function mapActivity(userId: string, act: any): Record<string, unknown> {
  const latlng: number[] | null = Array.isArray(act.start_latlng) && act.start_latlng.length === 2
    ? act.start_latlng
    : null;
  return {
    user_id: userId,
    source: 'strava',
    strava_activity_id: act.id,
    started_at: act.start_date,
    distance_km: (act.distance ?? 0) / 1000,
    duration_min: (act.moving_time ?? 0) / 60,
    avg_hr: act.average_heartrate != null ? Math.round(act.average_heartrate) : null,
    avg_cadence: act.average_cadence != null ? Math.round(act.average_cadence * 2) : null,
    elevation_gain_m: act.total_elevation_gain ?? null,
    name: act.name ?? 'Strava activity',
    notes: null,
    start_lat: latlng ? latlng[0] : null,
    start_lon: latlng ? latlng[1] : null,
    // Strava's complete response can contain route/privacy metadata and is much
    // larger than the chart schema consumed by the app.  Keep only normalized
    // activity columns; detailed streams require a dedicated, private feature.
    data_points: null,
  };
}

/// Nhập (upsert) một hoạt động chạy bộ; bỏ qua nếu đã tồn tại (chống trùng).
/// Trả về true nếu thực sự ghi/cập nhật, false nếu bị bỏ qua.
// deno-lint-ignore no-explicit-any
export async function upsertRunActivity(
  supabase: any,
  userId: string,
  act: any,
): Promise<boolean> {
  if (!isRunActivity(act)) return false;
  const row = mapActivity(userId, act);
  const { error } = await supabase
    .from('activities')
    .upsert(row, { onConflict: 'user_id,strava_activity_id' });
  if (error) {
    console.error('upsertRunActivity error:', error);
    return false;
  }
  return true;
}
