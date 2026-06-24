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
   Lệnh `supabase status` sẽ in ra `Project URL` (cổng API, mặc định cấu hình dự án là `http://127.0.0.1:34321`) và khóa public (`Publishable key` dạng `sb_publishable_...` ở CLI mới, hoặc `anon key` JWT ở CLI cũ) dùng cho `.env` của client ở Bước 4.
3. Cấu hình secrets bảo mật cho các Edge Function (AI, thời tiết). Với môi trường local, các secret được nạp từ một tệp env riêng phía server (**không phải `.env` của client**). Tạo tệp `supabase/functions/.env` từ mẫu rồi điền key thật:
   ```bash
   cp supabase/functions/.env.example supabase/functions/.env
   ```
   ```env
   # supabase/functions/.env
   OPENROUTER_API_KEY=YOUR_KEY      # AI text/chat — https://openrouter.ai/keys
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
cp apps/runny_app/.env.example apps/runny_app/.env
```
Mở tệp `.env` và cập nhật các thông số:
- **SUPABASE_URL** và **SUPABASE_ANON_KEY**: Địa chỉ URL và khóa public của dự án Supabase (lấy từ kết quả lệnh `supabase status` khi chạy local, hoặc tại mục Cài đặt API trên Cloud). Lưu ý dùng **Project URL** (cổng API `http://127.0.0.1:34321` khi local) chứ không phải chuỗi kết nối database; `SUPABASE_ANON_KEY` nhận `Publishable key` (`sb_publishable_...`) hoặc `anon key` JWT, **không phải** Storage S3 Access Key.
- **Chú ý bảo mật**: Không cấu hình các private API key (`OPENROUTER_API_KEY`, `WAQI_API_KEY`, `OPENWEATHER_API_KEY`) trong file `.env` này. Toàn bộ các dịch vụ AI và thời tiết sẽ được proxy qua Edge Functions để bảo mật 100% (tránh lộ key khi đóng gói Web app). Các key đó cấu hình ở phía server theo Bước 3.

## 3. Khởi chạy Ứng dụng

Sau khi hoàn tất các bước cấu hình, bạn có thể chạy thử ứng dụng trên thiết bị di động hoặc trình duyệt web (Web là môi trường chính kiểm thử trong v0.1.0):

```bash
cd apps/runny_app
flutter run -d chrome
```

---
© 2026 Đội ngũ phát triển Runny AI. MIT License.
