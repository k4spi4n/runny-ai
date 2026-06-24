# 🚀 Runny AI - Release v0.1.0-alpha (First Beta/Tester Release)

Chào mừng các bạn đến với phiên bản thử nghiệm đầu tiên (**v0.1.0-alpha**) của dự án **Runny AI**! Đây là bản thử nghiệm đầu tiên cho tester, đánh dấu sự hoàn thiện của bộ khung ứng dụng (Frontend Flutter + Backend Supabase) cùng các lõi chức năng cốt lõi.

---

## 📝 Release Changelog & Quy Trình

### 1. Summary (Tóm tắt)
Runny AI v0.1.0-alpha là bản phát hành thử nghiệm đầu tiên phục vụ theo dõi chạy bộ, AI Coach tư vấn tập luyện, nhập hoạt động thô, trực quan hóa biểu đồ nâng cao, hồ sơ sức khỏe và tương tác cộng đồng. Phiên bản này đồng bộ hóa tag `v0.1.0` trên hệ thống và tích hợp quy trình phát triển chuyên nghiệp trên GitHub.

### 2. New Features (Tính năng mới)
*   **Lõi Trợ lý AI Coach thông minh** (#29, #41): Chatbot HLV Ảo trò chuyện trực tiếp (Q&A) tương tác với AI về kỹ thuật, chấn thương và dinh dưỡng. Tự động lập giáo án chạy bộ động (Training Plans) dựa trên mục tiêu qua OpenRouter/Gemini. Tích hợp nhập liệu giọng nói (Speech-to-Text).
*   **Import Đa nguồn & Đồng bộ Strava** (#36, #44): Nhập thủ công các hoạt động chạy thô từ file chuẩn `.GPX` hoặc `.FIT`. Kết nối trực tiếp qua Strava API OAuth2 & Webhooks để đồng bộ hoạt động tự động khi kết thúc buổi chạy.
*   **Biểu đồ dữ liệu nâng cao & Shoe Tracker** (#28, #44): Trực quan hóa Pace, Heart Rate (Nhịp tim) và Elevation (Độ cao) thời gian thực kèm con trỏ đồng bộ hóa chéo (synced cursor crosshair). Quản lý danh sách giày chạy bộ, tự động cộng dồn cự ly và cảnh báo thay giày khi đạt ngưỡng hao mòn.
*   **Theo dõi sức khỏe & Cân nặng** (#30, #37): Nhật ký theo dõi cân nặng, tự động tính BMI và trực quan hóa biểu đồ xu hướng.
*   **Cộng đồng & Trò chơi hóa (Gamification)**: Bảng xếp hạng runner theo quãng đường tích lũy, hệ thống Huy hiệu ghi nhận cột mốc, và tính năng ghép đôi bạn chạy (Partner Matching) dựa trên dải Pace và khu vực hoạt động.
*   **Tính năng bổ trợ**: Quản lý thực đơn tracking (#31, #38) và bổ sung gói đăng ký Weekly/Monthly/Yearly (#40).
*   **Giao diện sáng/tối & Đa ngôn ngữ** (#25, #35, #42): Hỗ trợ chuyển đổi Theme (Light/Dark Mode) và Ngôn ngữ (Vietnamese/English).

### 3. Bug Fixes (Sửa lỗi)
*   Khắc phục lỗi trả về `Future` không đồng bộ trong `setState` khi refresh trang cân nặng (#37).
*   Sửa lỗi kết nối API thời tiết & AQI, đảm bảo dữ liệu chạy qua proxy ổn định (#36).

### 4. Changed (Thay đổi quan trọng)
*   🛡️ **Cải tiến bảo mật API Key**: Loại bỏ hoàn toàn các private API key (`OPENROUTER_API_KEY`, `GEMINI_API_KEY`, `OPENWEATHER_API_KEY`) khỏi phía client. Toàn bộ các yêu cầu AI và thời tiết hiện được proxy an toàn 100% qua Supabase Edge Functions, triệt tiêu rủi ro lộ key trên môi trường Flutter Web bundle.
*   **Đồng bộ phiên bản**: Đồng bộ hóa tag, release title và metadata phiên bản (`0.1.0-alpha+1` trong `pubspec.yaml`).
*   **Tài liệu hóa**: Bổ sung tài liệu onboarding, kiến trúc hệ thống và hướng dẫn thiết lập chi tiết (#43, #45).

### 5. Testing & CI Evidence (Bằng chứng kiểm thử)
*   **Manual Testing**: Chi tiết các kịch bản kiểm thử mẫu được trình bày ở phần bên dưới.
*   **Automated Testing**: Tích hợp smoke/widget test cho Flutter tại `apps/runny_app/test/widget_test.dart`.
*   🚀 **GitHub Actions CI Pipeline**: Đã cấu hình chạy tự động kiểm tra chất lượng code, lint (`flutter analyze`) và chạy tests (`flutter test`) mỗi khi có push hoặc PR (xem cấu hình tại [.github/workflows/ci.yml](file:///D:/CODE/runny-ai/.github/workflows/ci.yml)).

### 6. Known Issues (Lỗi / Hạn chế đã biết)
*   Dịch vụ đồng bộ Strava Webhook hiện đang chạy local/mock do môi trường thử nghiệm chưa cấu hình HTTPS public URL chính thức.
*   Các hình ảnh screenshot giao diện đang được bổ sung và sẽ cập nhật đầy đủ ở phiên bản v1.0.0-stable.
*   Chưa cung cấp build artifact (APK/IPA hoặc Web build zip) trực tiếp trên GitHub Release. Tester cần build hoặc chạy cục bộ từ source code tag.

### 7. Contributors (Người đóng góp)
Bản phát hành này được hoàn thiện nhờ nỗ lực của các thành viên:
*   **k4spi4n** (Đặng Thái Bình)
*   **ZevsVT** / **Vũ Hoàng Phúc**
*   **keithwalker69**
*   **kamikaze5826**
*   **AkasameVN26**

---

## 💻 Yêu Cầu Hệ Thống (Prerequisites)
Để cài đặt và chạy thử dự án cục bộ, máy tính của Tester cần cài sẵn:
1.  **Flutter SDK**: Phiên bản `^3.12.0` ([Hướng dẫn tải Flutter](https://docs.flutter.dev/get-started/install)).
2.  **Dart SDK**: Phiên bản `^3.0.0`.
3.  **Docker Desktop**: Bắt buộc để khởi chạy môi trường Supabase cục bộ.
4.  **Supabase CLI**: Quản lý database và các Edge Functions.
    *   Cài đặt qua NPM: `npm install -g supabase`
    *   Hoặc cài đặt qua Homebrew (macOS): `brew install supabase/tap/supabase`
5.  **Git**: Để kiểm soát phiên bản mã nguồn.

---

## 🚀 Hướng Dẫn Cài Đặt Môi Trường Chi Tiết

### Bước 1: Clone dự án
Mở terminal và thực thi lệnh sau để tải mã nguồn dự án:
```bash
git clone https://github.com/k4spi4n/runny-ai.git
cd runny-ai
git checkout v0.1.0
```

### Bước 2: Cài đặt & Khởi chạy Backend (Supabase Local)
Đảm bảo **Docker Desktop** đang hoạt động trên máy tính của bạn. Tại thư mục gốc của dự án:
```bash
# Khởi động dịch vụ Supabase cục bộ
supabase start
```
Hệ thống sẽ tạo ra các container cho PostgreSQL, Auth, Edge Functions, và Studio.

Tiếp theo, áp dụng cấu trúc dữ liệu và dữ liệu mẫu (migrations & seed):
```bash
# Thực hiện migrations để tạo cấu trúc bảng, RLS policies, trigger và RPC functions
supabase db reset
```

Cấu hình các API key bảo mật trên Supabase Backend (để sử dụng Edge Functions proxy):
```bash
supabase secrets set --local OPENROUTER_API_KEY=YOUR_OPENROUTER_API_KEY
supabase secrets set --local GEMINI_API_KEY=YOUR_GEMINI_API_KEY
supabase secrets set --local OPENWEATHER_API_KEY=YOUR_OPENWEATHER_API_KEY
```
*(Nếu muốn chạy thử nghiệm các hàm Edge cục bộ không cần deploy lên cloud, bạn có thể khởi chạy máy chủ chức năng bằng lệnh: `supabase functions serve`)*

Ghi nhận thông tin **API URL** và **anon key** bằng lệnh:
```bash
supabase status
```

### Bước 3: Cấu hình Biến môi trường (.env)
Di chuyển vào thư mục ứng dụng Flutter:
```bash
cd apps/runny_app
```
Tạo tệp `.env` từ file mẫu `.env.example`:
*   Trên Windows (PowerShell): `copy .env.example .env`
*   Trên macOS/Linux: `cp .env.example .env`

Mở tệp `.env` bằng trình soạn thảo và điền các thông số kết nối Supabase (không cần điền các API key thời tiết hay AI do đã được proxy bảo mật ở backend):
```env
# --- Supabase Configuration ---
SUPABASE_URL=YOUR_LOCAL_SUPABASE_URL (Lấy từ kết quả lệnh 'supabase status' - thường là http://127.0.0.1:54321)
SUPABASE_ANON_KEY=YOUR_LOCAL_SUPABASE_ANON_KEY (Lấy từ kết quả lệnh 'supabase status')

# --- AI Configuration (Edge Function Proxy) ---
# Không cần thiết lập API key ở đây. Hãy dùng supabase secrets set trên backend.
OPENROUTER_MODEL=meta-llama/llama-3.3-70b-instruct:free

# --- Tích hợp Strava (Tùy chọn) ---
STRAVA_CLIENT_ID=your_strava_client_id
STRAVA_CLIENT_SECRET=your_strava_client_secret
STRAVA_REDIRECT_URI=http://localhost:3000/
STRAVA_VERIFY_TOKEN=your_strava_webhook_verify_token
```

### Bước 4: Cài đặt Thư viện & Khởi chạy Frontend
Đảm bảo bạn vẫn đang ở trong thư mục `apps/runny_app`:
```bash
# Cài đặt toàn bộ dependencies trong pubspec.yaml
flutter pub get

# Chạy ứng dụng trên trình duyệt Chrome (Web là môi trường chính kiểm thử trong v0.1.0)
flutter run -d chrome
```

---

## 📖 Hướng Dẫn Sử Dụng dành cho Tester

1.  **Đăng nhập & Thiết lập ban đầu:**
    *   Truy cập giao diện chính, tiến hành đăng ký tài khoản mới bằng Email/Mật khẩu hoặc sử dụng tài khoản có sẵn trong DB seed.
    *   Hệ thống sẽ chuyển hướng đến màn hình **Onboarding**. Hãy điền các thông tin thể trạng (Cân nặng, Chiều cao, Pace mục tiêu) để kích hoạt hệ thống phân tích.
2.  **Nhập dữ liệu tập luyện:**
    *   Truy cập trang **Import Activity** (nhấp vào nút thêm hoạt động ở trang Dashboard hoặc trang Lịch sử).
    *   Bạn có thể tải lên một tệp `.gpx` hoặc `.fit` mẫu để giả lập một buổi chạy thực tế (có thể tìm các tệp GPX mẫu trên mạng hoặc xuất từ Garmin/Strava).
    *   Sau khi tải lên, truy cập **Activity History** để xem danh sách và nhấp vào chi tiết hoạt động để kiểm tra biểu đồ và phân tích AI.
3.  **Tương tác với AI Coach:**
    *   Truy cập tab **AI Coach** từ thanh điều hướng chính.
    *   Thực hiện gửi các câu hỏi về chạy bộ để kiểm tra thời gian phản hồi và chất lượng câu trả lời.
    *   Yêu cầu AI lập giáo án tập luyện: Bấm "Tạo giáo án chạy bộ", chọn cự ly mục tiêu (ví dụ: 10K), và kiểm tra danh sách bài tập được sinh ra ở trang **Training Plan**.
4.  **Theo dõi Giày & Cân nặng:**
    *   Vào **Profile** > Chọn **Shoe Tracker** > Bấm thêm giày chạy bộ mới (nhãn hiệu, số km hiện tại, ngưỡng cảnh báo hao mòn).
    *   Vào trang **Health & Nutrition** > Chọn **Weight Tracking** > Cập nhật cân nặng mới của bạn và kiểm tra biểu đồ cập nhật BMI tự động.

---

## 📋 Kịch Bản Kiểm Thử Mẫu (Suggested Test Cases)

### Kịch bản 1: Kiểm thử luồng Đăng ký & Onboarding mới
*   **Các bước thực hiện:**
    1.  Mở app -> Nhấp "Sign Up" tại màn hình `login_page`.
    2.  Điền thông tin email hợp lệ và mật khẩu, nhấn Đăng ký.
    3.  Ứng dụng chuyển hướng đến màn hình `onboarding_page`.
    4.  Nhập đầy đủ thông tin: Cân nặng = `70 kg`, Chiều cao = `175 cm`, Mục tiêu = `Chạy Half Marathon`.
    5.  Bấm "Hoàn thành".
*   **Kết quả mong đợi:**
    *   Tài khoản mới được tạo thành công trong Supabase Auth (`auth.users`).
    *   Bảng `profiles` được khởi tạo dòng dữ liệu tương ứng với `onboarding_completed = true`.
    *   Chuyển hướng thành công vào màn hình `dashboard_page` hiển thị lời chào kèm theo thông số BMI tương ứng (~22.86).

### Kịch bản 2: Tải lên hoạt động (GPX/FIT) & Phân tích biểu đồ
*   **Các bước thực hiện:**
    1.  Từ Dashboard, bấm biểu tượng "+" để mở trang `import_activity_page`.
    2.  Nhấp "Chọn File" và tải lên một tệp `.gpx` chứa tọa độ và nhịp tim.
    3.  Chờ hệ thống xử lý và bấm "Xem chi tiết".
*   **Kết quả mong đợi:**
    *   Ứng dụng tải file lên Supabase Storage và phân tích dữ liệu thành công.
    *   Chuyển hướng đến màn hình `activity_details_page`.
    *   Hiển thị bản đồ cung đường (nếu có GPS) và các biểu đồ Pace, Heart Rate, Elevation tương tác (khi di chuột qua điểm bất kỳ trên biểu đồ này, đường dóng ngang/dọc của biểu đồ kia sẽ hiển thị đồng bộ theo trục thời gian).
    *   Hộp thoại AI phân tích hiển thị nhận xét chi tiết về buổi chạy dựa trên các thông số tải lên.

### Kịch bản 3: Lập giáo án chạy bộ động bằng AI Coach
*   **Các bước thực hiện:**
    1.  Mở màn hình `ai_coach_page`.
    2.  Gửi tin nhắn: *"Tôi muốn chuẩn bị chạy cự ly 10K trong 8 tuần tới, hãy tạo lịch tập giúp tôi."*
    3.  Chờ AI trả lời, sau đó bấm nút "Áp dụng Giáo án vào Lịch tập".
    4.  Chuyển sang trang `training_plan_page`.
*   **Kết quả mong đợi:**
    *   AI phản hồi hợp lệ, đưa ra định hướng tập luyện chi tiết.
    *   Nút áp dụng hoạt động đúng, lưu thông tin lịch tập vào bảng `training_schedules`.
    *   Màn hình `training_plan_page` hiển thị danh sách các bài tập phân bổ theo từng tuần (ví dụ: Chạy bền, chạy biến tốc, chạy dài cuối tuần) kèm theo trạng thái "Chưa hoàn thành".

### Kịch bản 4: Theo dõi giày và tính năng cảnh báo hao mòn
*   **Các bước thực hiện:**
    1.  Truy cập trang `profile_page` -> Chọn **Shoe Tracker**.
    2.  Thêm giày mới: Tên = `Nike Pegasus 40`, Số km hiện tại = `480 km`, Ngưỡng cảnh báo = `500 km`.
    3.  Nhập/Đồng bộ thêm một hoạt động chạy bộ mới có cự ly `25 km` và gắn thẻ đôi giày `Nike Pegasus 40`.
*   **Kết quả mong đợi:**
    *   Giày chạy bộ được cập nhật tổng số km chạy thành `505 km`.
    *   Ứng dụng hiển thị cảnh báo đỏ hoặc thông báo khuyến nghị thay thế do đôi giày đã vượt ngưỡng hao mòn quy định (`505 km > 500 km`).

---

## 🐛 Báo Cáo Lỗi & Phản Hồi (Feedback Loops)
Nếu phát hiện bất kỳ lỗi (bug), hành vi bất thường, hoặc trải nghiệm chưa tối ưu, vui lòng báo cáo tại mục **Issues** của dự án trên GitHub theo mẫu sau:
1.  **Tiêu đề:** `[BUG] - Mô tả ngắn gọn lỗi` (Ví dụ: `[BUG] - Biểu đồ nhịp tim bị tràn viền trên màn hình iPad`)
2.  **Môi trường:** (Ví dụ: Windows 11, Google Chrome v120.0, màn hình FullHD)
3.  **Các bước tái hiện lỗi:**
    *   *Bước 1: ...*
    *   *Bước 2: ...*
4.  **Kết quả thực tế:** (Mô tả chi tiết lỗi xảy ra)
5.  **Kết quả mong muốn:** (Hành vi đúng của ứng dụng)
6.  **Ảnh chụp màn hình / Video minh họa:** (Nếu có)

---
*Cảm ơn sự đóng góp quý báu của các bạn để sản phẩm Runny AI ngày một hoàn thiện hơn! Chúc các bạn có những trải nghiệm kiểm thử tuyệt vời!* 🏃‍♂️
