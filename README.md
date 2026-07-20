<p align="center">
  <a href="https://runny-ai.onrender.com/">
    <img src="apps/runny_app/assets/images/runny-ai-logo.png" alt="Runny AI" width="120" />
  </a>
</p>

<h1 align="center">Runny AI</h1>

<p align="center">
  AI-powered running coach and community platform · Trợ lý chạy bộ cá nhân tích hợp AI và cộng đồng
</p>

<p align="center">
  <a href="https://runny-ai.onrender.com/"><strong>Web app</strong></a>
  ·
  <a href="docs/setup.md">Setup Guide</a>
  ·
  <a href="docs/architecture.md">Architecture</a>
  ·
  <a href="docs/api.md">API</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.0%2B-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Supabase-PostgreSQL%20%2B%20Edge%20Functions-3ECF8E?logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/status-alpha-F59E0B" alt="Alpha" />
</p>

## English

### Overview

Runny AI helps runners turn training data into actionable coaching. The app combines activity analysis, AI coaching, personalized plans, readiness/recovery signals, nutrition tracking, and social motivation.

Production web: **https://runny-ai.onrender.com/**

### Highlights

- **AI Coach (text + voice):** context-aware coaching from activities, plans, readiness, and weather.
- **Personalized plans:** goal-based training schedules with rescheduling support.
- **Flexible activity import:** Strava sync, GPX/FIT import, manual input, and screenshot extraction.
- **Health features:** nutrition logs, weight/BMI tracking, and food recognition.
- **Community:** activity feed, leaderboard, badges, and run partner matching.

### Architecture and security principles

- Flutter + Provider client (`apps/runny_app`).
- Supabase backend: Auth, PostgreSQL (RLS), and Edge Functions.
- AI and weather are proxied through Edge Functions (no provider keys in client).
- AI gateway provider order is tier-aware and server-managed.

### Quick start

```bash
git clone <repository-url>
cd runny-ai/apps/runny_app
cp .env.example .env
flutter pub get
flutter run -d chrome
```

Client `.env` must include only `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and optional non-secret model hints.

## Tiếng Việt

### Giới thiệu

Runny AI giúp người chạy biến dữ liệu tập luyện thành gợi ý hành động. Ứng dụng kết hợp phân tích hoạt động, AI Coach, giáo án cá nhân, chỉ số hồi phục, dinh dưỡng và động lực cộng đồng.

Web production: **https://runny-ai.onrender.com/**

### Điểm nổi bật

- **AI Coach (văn bản + giọng nói):** tư vấn theo ngữ cảnh từ lịch sử chạy, giáo án, readiness và thời tiết.
- **Giáo án cá nhân hóa:** lập lịch tập theo mục tiêu, hỗ trợ dời lịch.
- **Nhập hoạt động linh hoạt:** đồng bộ Strava, nhập GPX/FIT, nhập tay, nhận diện từ ảnh chụp kết quả.
- **Theo dõi thể trạng:** nhật ký dinh dưỡng, cân nặng/BMI, nhận diện món ăn.
- **Cộng đồng:** bảng tin hoạt động, bảng xếp hạng, huy hiệu, ghép đôi bạn chạy.

### Kiến trúc và bảo mật

- Client Flutter + Provider (`apps/runny_app`).
- Backend Supabase: Auth, PostgreSQL (RLS), Edge Functions.
- AI và thời tiết luôn đi qua Edge Functions (không lộ API key ở client).
- Thứ tự fallback provider AI được quản lý phía server theo tier/tính năng.

### Bắt đầu nhanh

```bash
git clone <repository-url>
cd runny-ai/apps/runny_app
cp .env.example .env
flutter pub get
flutter run -d chrome
```

`.env` phía client chỉ nên chứa `SUPABASE_URL`, `SUPABASE_ANON_KEY` và model hint không nhạy cảm.

## Repository structure

```text
apps/runny_app/       Flutter client: pages, widgets, models, services
supabase/             Database migrations, seed data, Edge Functions
content-factory/      Marketing source assets and README screenshots
docs/                 Architecture, API, setup, and product docs
```

## Documentation

- [Setup Guide](docs/setup.md)
- [System Architecture](docs/architecture.md)
- [API Documentation](docs/api.md)
- [Tech Stack](docs/tech-stack.md)
- [Product Vision](docs/product-vision.md)
- [v0.1.0 release notes](release_notes_v0.1.0.md)

## License

Released under the [MIT License](LICENSE).
