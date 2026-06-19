# 🚀 Runny AI - Release v0.1.0-alpha (First Beta/Tester Release)

Chào mừng các bạn đến với phiên bản thử nghiệm đầu tiên (**v0.1.0-alpha**) của dự án **Runny AI**! Đây là cột mốc quan trọng, đánh dấu sự hoàn thiện của bộ khung ứng dụng (Frontend Flutter + Backend Supabase) cùng các lõi chức năng cốt lõi. 

Tài liệu này được biên soạn nhằm hướng dẫn chi tiết cho đội ngũ Kiểm thử (Testers) cách thiết lập môi trường phát triển cục bộ (Local Environment), cấu hình các biến bảo mật, cách sử dụng các tính năng ứng dụng, và các kịch bản kiểm thử (Test Scenarios) mẫu.

---

## 📑 Bảng mục lục
1. [🌟 Tổng quan về Runny AI](#-tong-quan-ve-runny-ai)
2. [🛠 Các Tính Năng Hoàn Thiện trong v0.1.0](#-cac-tinh-nang-hoan-thien-trong-v010)
3. [💻 Yêu Cầu Hệ Thống (Prerequisites)](#-yeu-cau-he-thong-prerequisites)
4. [🚀 Hướng Dẫn Cài Đặt Môi Trường Chi Tiết](#-huong-dan-cai-dat-moi-truong-chi-tiet)
   - [Bước 1: Clone dự án](#buoc-1-clone-du-an)
   - [Bước 2: Cài đặt & Khởi chạy Backend (Supabase Local)](#buoc-2-cai-dat--khoi-chay-backend-supabase-local)
   - [Bước 3: Cấu hình Biến môi trường (.env)](#buoc-3-cau-hinh-bien-moi-truong-env)
   - [Bước 4: Cài đặt Thư viện & Khởi chạy Frontend](#buoc-4-cai-dat-thu-vien--khoi-chay-frontend)
5. [📖 Hướng Dẫn Sử Dụng dành cho Tester](#-huong-dan-su-dung-danh-cho-tester)
6. [📋 Kịch Bản Kiểm Thử Mẫu (Suggested Test Cases)](#-kich-ban-kiem-thu-mau-suggested-test-cases)
7. [🐛 Báo Cáo Lỗi & Phản Hồi (Feedback Loops)](#-bao-cao-loi--phan-hoi-feedback-loops)

---

## 🌟 Tổng quan về Runny AI
**Runny AI** là một hệ sinh thái thể dục thể thao chuyên nghiệp, được hỗ trợ bởi trí tuệ nhân tạo (AI), thiết kế riêng biệt cho cộng đồng những người đam mê chạy bộ. Dự án kết hợp công nghệ theo dõi hoạt động tiên tiến, huấn luyện viên ảo cá nhân hóa (AI Running Assistant) và các tính năng tương tác cộng đồng giúp người dùng tối ưu hóa hiệu suất tập luyện.

---

## 🛠 Các Tính Năng Hoàn Thiện trong v0.1.0
Phiên bản `v0.1.0-alpha` tích hợp đầy đủ 13 màn hình giao diện cốt lõi cùng hạ tầng dữ liệu và Serverless Edge Functions:

### 1. 👤 Quản lý Tài khoản & Hồ sơ (Auth & Onboarding)
*   **Xác thực bảo mật:** Sử dụng Supabase Auth để quản lý Đăng ký/Đăng nhập.
*   **Bảng hỏi thể trạng (Onboarding):** Thu thập thông tin ban đầu: Chiều cao, cân nặng, nhịp tim tối đa (Max HR), mục tiêu và kinh nghiệm chạy bộ để AI tối ưu hóa giáo án.
*   **Hồ sơ người dùng (User Profile):** Hiển thị tổng quan thành tích, cấu hình liên kết bên thứ ba (Strava), và theo dõi thiết bị (Shoe Tracker).

### 2. 📊 Xử lý & Trực quan hóa Hoạt động (Activity Processing)
*   **Import Đa nguồn:** Hỗ trợ người dùng tải lên thủ công tệp thô chuẩn `.GPX` hoặc `.FIT` từ đồng hồ thể thao.
*   **Đồng bộ tự động Strava:** Kết nối trực tiếp qua Strava API OAuth2 & Webhooks để đồng bộ hoạt động tự động mỗi khi kết thúc buổi chạy.
*   **Trực quan hóa Dữ liệu (fl_chart):** Biểu đồ tương tác thời gian thực cho Pace, Heart Rate (Nhịp tim) và Elevation (Độ cao) kèm theo con trỏ tương tác đồng bộ hóa giữa các biểu đồ (synced cursor crosshair).
*   **Làm giàu dữ liệu:** Tự động kéo dữ liệu Thời tiết lịch sử tại thời điểm chạy để AI phân tích.

### 3. 🧠 Lõi Trợ lý AI Coach thông minh
*   **Chatbot HLV Ảo:** Giao diện trò chuyện trực tiếp (Q&A) tương tác với AI (Llama 3.3 qua OpenRouter hoặc Google Gemini) về kỹ thuật, chấn thương và dinh dưỡng.
*   **Thiết lập Giáo án Tự động:** Sinh giáo án chạy bộ động (Training Plans) dựa trên mục tiêu (ví dụ: Chạy 5K, 10K, Half Marathon, Full Marathon).
*   **Phân tích Hậu hoạt động (Post-run Insights):** Đưa ra đánh giá chuyên sâu cho từng km của buổi chạy vừa hoàn thành.

### 4. 👟 Sức Khỏe & Quản lý Trang thiết bị (Health & Gear)
*   **Theo dõi Cân nặng (Weight Tracker):** Ghi nhật ký cân nặng, tự động tính toán chỉ số BMI và vẽ biểu đồ xu hướng.
*   **Theo dõi Giày chạy (Shoe Tracker):** Quản lý danh sách giày giày chạy, tự động cộng dồn số km đã đi để cảnh báo thay giày khi đạt ngưỡng hao mòn (thường là 500km - 800km).

### 5. 🏆 Động lực & Tương tác (Gamification & Social)
*   **Bảng xếp hạng (Leaderboard):** Xếp hạng runner theo tổng quãng đường chạy tích lũy.
*   **Hệ thống Huy hiệu (Badges):** Trao tặng huy hiệu khi đạt các mốc cự ly hoặc tần suất tập luyện.
*   **Ghép bạn chạy bộ (Partner Matching):** Đề xuất bạn chạy có cùng dải Pace và khu vực hoạt động gần nhau.

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
```

### Bước 2: Cài đặt & Khởi chạy Backend (Supabase Local)
Đảm bảo **Docker Desktop** đang hoạt động trên máy tính của bạn. Tại thư mục gốc của dự án:
```bash
# Khởi động dịch vụ Supabase cục bộ (sẽ mất vài phút trong lần chạy đầu tiên để tải Docker Images)
supabase start
```
Hệ thống sẽ tạo ra các container cho PostgreSQL, Auth, Edge Functions, và Studio. Sau khi hoàn tất, màn hình sẽ hiển thị cấu hình dịch vụ.

Tiếp theo, áp dụng cấu trúc dữ liệu và dữ liệu mẫu (migrations & seed):
```bash
# Thực hiện migrations để tạo cấu trúc bảng, RLS policies, trigger và RPC functions
supabase db reset
```

Triển khai các Serverless Edge Functions cục bộ phục vụ cho AI và thời tiết:
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

Mở tệp `.env` bằng trình soạn thảo và điền đầy đủ các thông số cần thiết:
```env
# --- Supabase Configuration ---
SUPABASE_URL=YOUR_LOCAL_SUPABASE_URL (Lấy từ kết quả lệnh 'supabase status' - thường là http://127.0.0.1:54321)
SUPABASE_ANON_KEY=YOUR_LOCAL_SUPABASE_ANON_KEY (Lấy từ kết quả lệnh 'supabase status')

# --- AI Configuration (OpenRouter - Chính) ---
OPENROUTER_API_KEY=your_openrouter_api_key
OPENROUTER_MODEL=meta-llama/llama-3.3-70b-instruct:free
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1

# --- AI Configuration (Google Gemini - Dự phòng) ---
GEMINI_API_KEY=your_gemini_api_key
GEMINI_MODEL=gemini-1.5-flash

# --- Tích hợp Strava (Tùy chọn) ---
STRAVA_CLIENT_ID=your_strava_client_id
STRAVA_CLIENT_SECRET=your_strava_client_secret
STRAVA_REDIRECT_URI=http://localhost:3000/
STRAVA_VERIFY_TOKEN=your_strava_webhook_verify_token

# --- Các dịch vụ thời tiết ---
OPENWEATHER_API_KEY=your_openweather_api_key
```

### Bước 4: Cài đặt Thư viện & Khởi chạy Frontend
Đảm bảo bạn vẫn đang ở trong thư mục `apps/runny_app`:
```bash
# Cài đặt toàn bộ dependencies trong pubspec.yaml
flutter pub get

# Chạy ứng dụng trên trình duyệt Chrome (Web là môi trường chính kiểm thử trong v0.1.0)
flutter run -d chrome

# Hoặc chạy trên thiết bị di động / máy ảo có sẵn
flutter run
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
