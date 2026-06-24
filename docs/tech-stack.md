# Danh mục Công nghệ

Runny AI được xây dựng trên nền tảng công nghệ hiện đại, ưu tiên hiệu suất cao, khả năng mở rộng và trải nghiệm người dùng tối ưu.

## Frontend (Ứng dụng Di động)
- **Framework**: [Flutter](https://flutter.dev/) (Ngôn ngữ Dart)
- **Quản lý Trạng thái**: [Provider](https://pub.dev/packages/provider)
- **Biểu đồ & Trực quan hóa**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Giao tiếp Mạng**: `http`, `supabase_flutter`
- **AI SDK**: `google_generative_ai` (sử dụng khi cần dự phòng trực tiếp)
- **Vị trí địa lý**: `geolocator`
- **Đa ngôn ngữ**: Hệ thống l10n tùy chỉnh dựa trên JSON (Hỗ trợ Tiếng Anh & Tiếng Việt)

## Backend (Nền tảng Cloud)
- **Cơ sở dữ liệu**: PostgreSQL với cơ chế Row Level Security (RLS) để bảo mật dữ liệu.
- **Xác thực**: Supabase Auth (dựa trên chuẩn JWT)
- **Serverless Logic**: Edge Functions chạy trên nền tảng Deno (TypeScript)
- **Lưu trữ tệp**: Supabase Storage cho các dữ liệu hình ảnh người dùng.

## Dịch vụ & Tích hợp bên thứ ba
- **Động cơ Trí tuệ nhân tạo (AI Engine)**: 
  - [Groq](https://groq.com/) (chính): Suy luận tốc độ cao nhờ LPU (Llama 3.3 70B / 3.1 8B).
  - [OpenRouter](https://openrouter.ai/) (fallback): Truy cập đa mô hình khi Groq lỗi/rate-limit.
- **Dữ liệu Thể thao**: [Strava API](https://developers.strava.com/) (OAuth2 & Webhooks)
- **Thời tiết**: [OpenWeatherMap API](https://openweathermap.org/api)
- **Chất lượng không khí**: [WAQI API](https://aqicn.org/api/)

## Công cụ & Quy trình Phát triển
- **Quản lý gói**: Pub (Dart), Deno (Backend)
- **Quản lý phiên bản**: Git
- **Môi trường phát triển (IDE)**: VS Code / Android Studio
- **Quản trị Cơ sở dữ liệu**: Migrations SQL được quản lý qua Supabase CLI.
