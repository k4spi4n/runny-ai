# Hướng dẫn Thiết lập Dự án Runny AI

Tài liệu này cung cấp các bước chi tiết để cấu hình, cài đặt và vận hành hệ thống Runny AI trên môi trường phát triển cục bộ.

## 1. Yêu cầu Hệ thống

Trước khi bắt đầu, hãy đảm bảo máy tính của bạn đã cài đặt các công cụ sau:

- **Flutter SDK**: Phiên bản `^3.12.0`
- **Dart SDK**: Phiên bản `^3.0.0`
- **Supabase CLI**: Công cụ quản trị phía máy chủ và các hàm Edge.
- **Git**: Công cụ quản lý mã nguồn và phiên bản.

## 2. Quy trình Cài đặt Chi tiết

### Bước 1: Sao chép Mã nguồn
Sử dụng Git để tải mã nguồn dự án về máy tính:
```bash
git clone https://github.com/your-repo/runny-ai.git
cd runny-ai
```

### Bước 2: Cấu hình Ứng dụng Mobile
Di chuyển vào thư mục ứng dụng và khởi tạo các thư viện phụ thuộc:
```bash
cd apps/runny_app
flutter pub get
```

### Bước 3: Thiết lập Hệ thống Máy chủ (Supabase)
1. **Khởi tạo dự án**: Tạo một dự án mới trên bảng điều khiển [Supabase Dashboard](https://supabase.com/).
2. **Cấu trúc dữ liệu**: Truy cập trình soạn thảo SQL trên Supabase và thực thi các tệp trong thư mục `supabase/migrations/` (theo thứ tự thời gian) để thiết lập các bảng, chính sách bảo mật và hàm nghiệp vụ.
3. **Triển khai Hàm Edge**: Thực hiện lệnh sau tại thư mục gốc của dự án để đưa các hàm xử lý logic lên máy chủ:
```bash
supabase functions deploy openrouter
supabase functions deploy strava_webhook
supabase functions deploy weather
```

### Bước 4: Cấu hình Biến môi trường
Tạo tệp cấu hình hệ thống từ tệp mẫu:
```bash
cp apps/runny_app/.env.example apps/runny_app/.env
```
Mở tệp `.env` và cập nhật các thông số bảo mật:
- **Thông tin Supabase**: Địa chỉ URL và khóa Anon (Lấy tại mục Cài đặt API).
- **Dịch vụ Trí tuệ nhân tạo**: Khóa API của OpenRouter hoặc Google Gemini.
- **Tích hợp Strava**: Mã định danh (Client ID) và mã bảo mật (Client Secret) từ hệ thống Strava.

## 3. Khởi chạy Ứng dụng

Sau khi hoàn tất các bước cấu hình, bạn có thể bắt đầu chạy ứng dụng trên thiết bị:

```bash
cd apps/runny_app
flutter run
```

*Lưu ý: Đảm bảo thiết bị di động hoặc trình giả lập của bạn đã được kết nối và nhận diện bởi Flutter.*

## 4. Xử lý Sự cố và Hỗ trợ

- **Lỗi thiếu thư viện**: Thực hiện lại lệnh `flutter pub get` để đảm bảo tất cả các gói phụ thuộc đã được tải về đầy đủ.
- **Lỗi kết nối máy chủ**: Kiểm tra lại thông số địa chỉ URL trong tệp cấu hình và đảm bảo đường truyền mạng ổn định.
- **Lỗi xử lý AI**: Xác nhận các hàm Edge đã được triển khai thành công và các khóa bảo mật (secrets) đã được thiết lập chính xác trên máy chủ bằng lệnh `supabase secrets set`.

---
© 2026 Đội ngũ phát triển Runny AI.
