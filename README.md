# 🏃‍♂️ Runny AI - Web App Trợ Lý Chạy Bộ Thông Minh

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)
![Status](https://img.shields.io/badge/status-Active_Development-orange.svg)

**Runny AI** là một nền tảng Web Application đột phá, đóng vai trò như một Huấn luyện viên ảo (AI Running Assistant) cá nhân hóa. Hệ thống tập trung vào việc thu thập, bóc tách và làm giàu dữ liệu chạy bộ từ các thiết bị/nền tảng bên thứ 3, từ đó ứng dụng Trí tuệ Nhân tạo (LLM) để phân tích sinh hiệu, tư vấn lịch tập và tối ưu hóa hiệu suất cho người dùng.

---

## 📑 Bảng mục lục

- [🌟 Tính năng nổi bật](#-tính-năng-nổi-bật)
- [🛠 Bức tranh Công nghệ (Tech Stack)](#-bức-tranh-công-nghệ-tech-stack)
- [🗄 Cấu trúc Dữ liệu](#-cấu-trúc-dữ-liệu)
- [🚀 Hướng dẫn Cài đặt](#-hướng-dẫn-cài-đặt)
- [👥 Thành viên Đội dự án](#-thành-viên-đội-dự-án)

---

## 🌟 Tính năng nổi bật (Dựa trên Sơ đồ Chức năng)

Dự án được cấu trúc thành 4 phân hệ chính:

### 1. 👤 Quản lý Tài khoản & Hồ sơ (User Management)

- **1.1 Xác thực nhanh chóng:** Tích hợp đăng nhập qua OAuth2 (Google/Facebook).
- **1.2 Quản lý Thể trạng:** Theo dõi các chỉ số cốt lõi như BMI, Max HR (Nhịp tim tối đa), Cân nặng.
- **1.3 Tích hợp Nền tảng:** Kết nối trực tiếp với API của các nền tảng thể thao lớn (Strava / Garmin).

### 2. 📊 Xử lý Dữ liệu Hoạt động (Activity Data Processing)

- **2.1 Import & Bóc tách Dữ liệu Đa nguồn:**
  - `2.1.1` Hỗ trợ tải lên thủ công file thô định dạng chuẩn (`.GPX`, `.FIT`).
  - `2.1.2` Đồng bộ background tự động thông qua Webhook/API từ Strava.
  - `2.1.3` **Làm giàu dữ liệu (Data Enrichment):** Tích hợp API tự động kéo dữ liệu Thời tiết & Chỉ số chất lượng không khí (AQI) dựa trên tọa độ và thời gian chạy.
- **2.2 Quản lý Lịch sử:** Lưu trữ và quản lý (CRUD) danh sách các hoạt động.
- **2.3 Trực quan hóa (Data Visualization):** Render biểu đồ tương tác chi tiết cho Pace (Tốc độ), HR (Nhịp tim) và Elevation (Độ cao).

### 3. 🧠 Lõi Trợ lý AI Thông minh (Core AI Assistant)

- **3.1 Khởi tạo Lịch tập (Goal-based Planning):** Sinh lịch tập tự động dựa trên mục tiêu cụ thể của user.
- **3.2 Phân tích Hậu hoạt động (Post-run Insights):** Phân tích chi tiết từng km, đưa ra nhận xét chuyên sâu và lời khuyên dựa trên nhịp tim và thời tiết.
- **3.3 Điều chỉnh Lịch tập Động (Dynamic Adjustment):** AI tự động dời lịch, giảm tải hoặc tăng cường độ bài tập dựa trên thể trạng thực tế và dữ liệu các buổi tập trước.
- **3.4 Chatbot HLV Ảo:** Giao diện hỏi đáp trực tiếp (Q&A) các vấn đề về dinh dưỡng, chấn thương, và giáo án chạy bộ.

### 4. 🏆 Động lực & Tương tác (Gamification & Social)

- **4.1 Huy hiệu Thành tích (Badges):** Tự động cấp quyền lợi/huy hiệu khi đạt các mốc thành tựu.
- **4.2 Bảng xếp hạng (Leaderboard):** Thi đua thành tích theo tổng quãng đường.
- **4.3 Kết nối Cộng đồng:** Đề xuất cung đường chạy thông minh và tính năng ghép đôi, tìm bạn chạy cùng (Matching dựa trên Pace và vị trí).

---

## 🛠 Bức tranh Công nghệ (Tech Stack)

_Phần này đang được cập nhật trong quá trình phát triển._

- **Front-end:** Flutter (Web)
- **Back-end:** Supabase (Postgres + Auth + Storage)
- **Database:** PostgreSQL (Lưu trữ quan hệ) + JSONB (Lưu trữ Time-series Data).
- **AI Integration:** [Ví dụ: Gemini API / OpenAI API]
- **3rd Party APIs:** Strava API, OpenWeatherMap API (Thời tiết).

---

## 🗄 Cấu trúc Dữ liệu

Hệ thống sử dụng cơ sở dữ liệu quan hệ kết hợp kiểu dữ liệu linh hoạt (JSONB) để đảm bảo hiệu năng tối đa cho dữ liệu Time-series.

Các bảng cốt lõi bao gồm:

- `USERS`: Thông tin cá nhân & Thể trạng.
- `TRAINING_SCHEDULES`: Lịch tập (Target pace, Target distance).
- `ACTIVITIES`: Tổng quan buổi chạy & Thông tin Thời tiết/AQI (Dữ liệu nhẹ, truy vấn nhanh).
- `ACTIVITY_DATA_POINTS`: Chứa chuỗi dữ liệu (Mảng JSON) từng giây/phút của HR, Pace, Cadence.
- `AI_INSIGHTS`: Lưu trữ lịch sử tư vấn và prompt của AI.

---

## 🚀 Hướng dẫn Cài đặt (Môi trường Local)

1. Clone repository về máy:

```bash
   git clone [https://github.com/](https://github.com/)[Tên_Tài_Khoản]/runny-ai.git
```

2. Cài đặt Docker Desktop (bắt buộc để chạy Supabase local).

3. Cài đặt Supabase CLI:

```bash
  npm install -g supabase
```

4. Khởi chạy Supabase local và áp migrations:

```bash
  cd runny-ai
  supabase start
  supabase db reset
```

5. Tạo file môi trường cho Flutter app:

```bash
  copy apps\runny_app\.env.example apps\runny_app\.env
```

6. Mở `apps/runny_app/.env` và điền `SUPABASE_URL` và `SUPABASE_ANON_KEY`.

- Lấy giá trị bằng lệnh: `supabase status`

7. Cài đặt Flutter (nếu chưa có):

- Tải Flutter SDK tại https://docs.flutter.dev/get-started/install
- Đảm bảo lệnh `flutter` chạy được trong terminal

8. Tạo Flutter app (web + đa nền tảng):

```bash
  flutter create -t app --platforms=android,ios,web,windows,macos,linux apps/runny_app
```

9. Chạy Flutter app (web):

```bash
  cd apps/runny_app
  flutter pub get
  flutter run -d chrome
```
