# Hướng dẫn Thiết lập Dự án Runny AI

Tài liệu này cung cấp các bước chi tiết để cấu hình, cài đặt và vận hành hệ thống Runny AI trên môi trường phát triển cục bộ và môi trường máy chủ.

## 1. Yêu cầu Hệ thống

Trước khi bắt đầu, hãy đảm bảo máy tính của bạn đã cài đặt các công cụ sau:

- **Flutter SDK**: Phiên bản `^3.12.0`
- **Dart SDK**: Phiên bản `^3.0.0`
- **Docker Desktop**: Bắt buộc khi phát triển với backend Supabase cục bộ.
- **Supabase CLI**: Công cụ quản trị phía máy chủ và các hàm Edge.
- **Git**: Công cụ quản lý mã nguồn và phiên bản.

## 2. Quy trình Cài đặt Chi tiết

### Bước 1: Sao chép Mã nguồn & Checkout Tag
Sử dụng Git để tải mã nguồn dự án về máy tính và chuyển về tag phát hành:
```bash
git clone https://github.com/k4spi4n/runny-ai.git
cd runny-ai
git checkout v0.1.0
```

### Bước 2: Cài đặt Dependencies Frontend
Di chuyển vào thư mục ứng dụng và khởi tạo các thư viện phụ thuộc:
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
3. Cấu hình secrets bảo mật cho các chức năng AI và thời tiết:
   ```bash
   supabase secrets set --local OPENROUTER_API_KEY=YOUR_KEY
   supabase secrets set --local GEMINI_API_KEY=YOUR_KEY
   supabase secrets set --local OPENWEATHER_API_KEY=YOUR_KEY
   ```

#### Triển khai lên Cloud (Production Deployment)
1. Tạo một dự án mới trên bảng điều khiển [Supabase Dashboard](https://supabase.com/).
2. Áp dụng migrations lên database của dự án.
3. Thiết lập các keys bảo mật trên cloud backend:
   ```bash
   supabase secrets set OPENROUTER_API_KEY=YOUR_KEY
   supabase secrets set GEMINI_API_KEY=YOUR_KEY
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
cp apps/runny_app/.env.example apps/runny_app/.env
```
Mở tệp `.env` và cập nhật các thông số:
- **SUPABASE_URL** và **SUPABASE_ANON_KEY**: Địa chỉ URL và khóa Anon của dự án Supabase (lấy từ kết quả lệnh `supabase status` khi chạy local, hoặc tại mục Cài đặt API trên Cloud).
- **Chú ý bảo mật**: Không cấu hình các private API key (`OPENROUTER_API_KEY`, `GEMINI_API_KEY`, `OPENWEATHER_API_KEY`) trong file `.env` này. Toàn bộ các dịch vụ AI và thời tiết sẽ được proxy qua Edge Functions để bảo mật 100% (tránh lộ key khi đóng gói Web app).

## 3. Khởi chạy Ứng dụng

Sau khi hoàn tất các bước cấu hình, bạn có thể chạy thử ứng dụng trên thiết bị di động hoặc trình duyệt web (Web là môi trường chính kiểm thử trong v0.1.0):

```bash
cd apps/runny_app
flutter run -d chrome
```

---
© 2026 Đội ngũ phát triển Runny AI. MIT License.
