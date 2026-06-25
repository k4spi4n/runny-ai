# Setup Guide

This guide will help you get the Runny AI project up and running on your local machine.

## Prerequisites

- **Flutter SDK**: `^3.12.0`
- **Dart SDK**: `^3.0.0`
- **Supabase CLI**: For local backend development (optional but recommended)
- **Git**

## Installation

### 1. Clone the repository
```bash
git clone https://github.com/your-repo/runny-ai.git
cd runny-ai
```

### 2. Frontend Setup (Flutter)
```bash
cd apps/runny_app
flutter pub get
```

### Bước 3: Thiết lập Hệ thống Máy chủ (Supabase)
#### Phát triển cục bộ (Local Development)
1. Đảm bảo Docker Desktop đang chạy.
2. Khởi chạy Supabase cục bộ và áp dụng database migrations:
   ```bash
   supabase start
   supabase db reset
   ```
   Lệnh `supabase status` sẽ in ra `Project URL` (cổng API, mặc định cấu hình dự án là `http://127.0.0.1:34321`) và khóa public (`Publishable key` dạng `sb_publishable_...` ở CLI mới, hoặc `anon key` JWT ở CLI cũ) dùng cho `.env` của client ở Bước 4.
3. Cấu hình secrets bảo mật cho các Edge Function (AI, thời tiết). Với môi trường local, các secret được nạp từ một tệp env riêng phía server (**không phải `.env` của client**). Tạo tệp `supabase/functions/.env` từ mẫu rồi điền key thật:
   ```bash
   cp supabase/functions/.env.example supabase/functions/.env
   ```
   ```env
   # supabase/functions/.env
   GROQ_API_KEY=YOUR_KEY            # AI text/chat (CHÍNH) — https://console.groq.com/keys
   OPENROUTER_API_KEY=YOUR_KEY      # AI text/chat (FALLBACK) — https://openrouter.ai/keys
   WAQI_API_KEY=YOUR_KEY            # AQI (chính) — https://aqicn.org/data-platform/token/
   OPENWEATHER_API_KEY=YOUR_KEY     # Thời tiết + AQI dự phòng — https://openweathermap.org/api
   FOOD_RECOGNITION_PROVIDER=mock   # Nhận dạng món ăn hiện dùng mock, chưa cần key
   ```
   > Hàm `weather` chỉ cần **một trong hai** `WAQI_API_KEY` hoặc `OPENWEATHER_API_KEY` là chạy. Tuy nhiên nếu chỉ có WAQI thì nhiệt độ/icon thời tiết phụ thuộc trạm đo gần đó; nên cấu hình thêm `OPENWEATHER_API_KEY` để có dữ liệu thời tiết ổn định.
   > Tệp `supabase/functions/.env` đã được `.gitignore` bỏ qua — không commit key lên git.
4. Phục vụ các Edge Function cục bộ (nạp secrets từ tệp vừa tạo). **Giữ cửa sổ terminal này mở** trong suốt quá trình phát triển; mở terminal khác để chạy ứng dụng:
   ```bash
   supabase functions serve --env-file supabase/functions/.env
   ```
   > Khi sửa code function (`.ts`) thì runtime tự nạp lại. Nhưng khi đổi/thêm key trong `supabase/functions/.env` thì phải dừng (`Ctrl+C`) và chạy lại lệnh này.

#### Triển khai lên Cloud (Production Deployment)
1. Tạo một dự án mới trên bảng điều khiển [Supabase Dashboard](https://supabase.com/).
2. Áp dụng migrations lên database của dự án.
3. Thiết lập các keys bảo mật trên cloud backend:
   ```bash
   supabase secrets set GROQ_API_KEY=YOUR_KEY
   supabase secrets set OPENROUTER_API_KEY=YOUR_KEY
   supabase secrets set WAQI_API_KEY=YOUR_KEY
   supabase secrets set OPENWEATHER_API_KEY=YOUR_KEY
   ```
4. Triển khai các Hàm Edge:
   ```bash
   supabase functions deploy openrouter
   supabase functions deploy strava_webhook
   supabase functions deploy weather
   ```

### Bước 4: Cấu hình Biến môi trường Client (.env)
Tạo tệp cấu hình hệ thống từ tệp mẫu:
```bash
supabase functions deploy openrouter
supabase functions deploy strava_webhook
supabase functions deploy weather
```
Mở tệp `.env` và cập nhật các thông số:
- **SUPABASE_URL** và **SUPABASE_ANON_KEY**: Địa chỉ URL và khóa public của dự án Supabase (lấy từ kết quả lệnh `supabase status` khi chạy local, hoặc tại mục Cài đặt API trên Cloud). Lưu ý dùng **Project URL** (cổng API `http://127.0.0.1:34321` khi local) chứ không phải chuỗi kết nối database; `SUPABASE_ANON_KEY` nhận `Publishable key` (`sb_publishable_...`) hoặc `anon key` JWT, **không phải** Storage S3 Access Key.
- **Chú ý bảo mật**: Không cấu hình các private API key (`GROQ_API_KEY`, `OPENROUTER_API_KEY`, `WAQI_API_KEY`, `OPENWEATHER_API_KEY`) trong file `.env` này. Toàn bộ các dịch vụ AI và thời tiết sẽ được proxy qua Edge Functions để bảo mật 100% (tránh lộ key khi đóng gói Web app). Các key đó cấu hình ở phía server theo Bước 3.

### 4. Environment Variables
Copy the `.env.example` to `.env` in the `apps/runny_app` directory:
```bash
cp .env.example .env
```
Fill in the required keys:
- `SUPABASE_URL` & `SUPABASE_ANON_KEY`: From your Supabase Project Settings.
- `OPENROUTER_API_KEY`: From [OpenRouter](https://openrouter.ai/).
- `GEMINI_API_KEY`: From [Google AI Studio](https://aistudio.google.com/).
- `STRAVA_CLIENT_ID` & `STRAVA_CLIENT_SECRET`: From [Strava API Settings](https://www.strava.com/settings/api).

## Running the App

To run the Flutter app on your connected device or emulator:
```bash
flutter run
```

## Troubleshooting
- **Missing Dependencies**: Ensure `flutter pub get` is run in `apps/runny_app`.
- **API Errors**: Check your `.env` file for correct keys and ensure Supabase Edge Functions are correctly deployed and accessible.

