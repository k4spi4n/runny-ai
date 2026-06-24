# Tài liệu API Hệ thống

Dự án Runny AI sử dụng nền tảng Supabase làm hạ tầng kỹ thuật chính, kết hợp các dịch vụ xác thực, cơ sở dữ liệu quan hệ và tính toán phi máy chủ.

## Địa chỉ Kết nối (Base URL)
Mọi yêu cầu kết nối được gửi tới địa chỉ máy chủ dự án:
`https://[MÃ_DỰ_ÁN].supabase.co`

## Cơ chế Xác thực
Hệ thống sử dụng chuẩn xác thực JWT thông qua dịch vụ Supabase Auth. Các yêu cầu gửi đi yêu cầu các thông tin định danh sau:
- `Authorization: Bearer [MÃ_JWT_NGƯỜI_DÙNG]`
- `apikey: [KHÓA_ANON_CỦA_DỰ_ÁN]`

---

## Các Hàm Xử lý Máy chủ (Edge Functions)

### 1. Cổng kết nối AI (AI Proxy)
Chuyển tiếp và bảo mật các yêu cầu xử lý trí tuệ nhân tạo.

- **Đường dẫn**: `POST /functions/v1/openrouter`
- **Chức năng**: Bảo mật khóa API và điều phối yêu cầu tới các mô hình ngôn ngữ lớn (LLM). Provider chính là **Groq** (suy luận nhanh nhờ LPU); khi Groq lỗi hoặc bị rate-limit (429), proxy tự **fallback sang OpenRouter**.
- **Định dạng dữ liệu**: Tuân theo chuẩn OpenAI Chat Completions (cả Groq lẫn OpenRouter đều tương thích). Header `X-AI-Provider` cho biết provider đã phục vụ request.
- **Guardrails (bảo vệ phía server, không thể bỏ qua từ client)**:
  - **Yêu cầu đăng nhập**: request phải kèm JWT của người dùng (`role = authenticated`). Thiếu → `401`.
  - **Giới hạn chủ đề**: tự chèn system prompt giới hạn trợ lý CHỈ trả lời về chạy bộ & thể chất liên quan; câu hỏi ngoài phạm vi sẽ bị từ chối lịch sự. (Bỏ qua với các yêu cầu `response_format` nội bộ như sinh lịch tập — vốn đã đúng chủ đề.)
  - **Kiểm tra đầu vào**: chặn payload bất thường (số tin nhắn / độ dài vượt ngưỡng). Vi phạm → `400`.
  - **Rate-limit theo user**: mặc định 12 request/phút và 200 request/ngày (đếm atomic qua RPC `check_ai_rate_limit` + bảng `ai_rate_limit`, dùng service role). Vượt → `429`. Ngưỡng chỉnh qua secret `AI_MAX_PER_MIN` / `AI_MAX_PER_DAY` / `AI_MAX_MESSAGES` / `AI_MAX_MESSAGE_CHARS` / `AI_MAX_TOTAL_CHARS`.
  - **Lỗi trả về** dạng `{ "error": "<thông báo tiếng Việt>" }`; client hiển thị trực tiếp thông báo này.

### 2. Nhận dạng món ăn bằng AI
Phân tích ảnh món ăn và trả về tên món dự đoán cùng ước lượng dinh dưỡng.

- **Đường dẫn Supabase Edge Function**: `POST /functions/v1/food-recognition/analyze`
- **Đường dẫn nghiệp vụ tương đương**: `POST /api/food-recognition/analyze`
- **Định dạng dữ liệu**: `multipart/form-data`
- **File field**: `image` hoặc `file`
- **Giới hạn hiện tại**: Ảnh tối đa 5MB, MIME `image/*` hoặc phần mở rộng ảnh phổ biến.
- **Response thành công**:
  ```json
  {
    "food_name": "Com ga",
    "confidence": 0.92,
    "nutrition": {
      "calories": 520,
      "protein": 35,
      "carbs": 55,
      "fat": 15
    }
  }
  ```
- **Ghi chú triển khai**: Hiện dùng `MockFoodRecognitionService` trong `supabase/functions/food-recognition/food_recognition_service.ts`. Khi tích hợp Vision API thật, thay implementation của `FoodRecognitionService` và cấu hình secret trên Supabase, không hard-code API key.

### 3. Dịch vụ Thời tiết và Môi trường
Cung cấp thông tin thời tiết và chất lượng không khí dựa trên vị trí địa lý.

- **Đường dẫn**: `POST /functions/v1/weather`
- **Secrets yêu cầu (phía server)**: cần ít nhất **một trong hai** `WAQI_API_KEY` hoặc `OPENWEATHER_API_KEY`; thiếu cả hai sẽ trả lỗi `500`. `WAQI_API_KEY` cung cấp AQI (và nhiệt độ/độ ẩm/gió nếu trạm đo gần đó có dữ liệu); `OPENWEATHER_API_KEY` cung cấp thời tiết đầy đủ kèm AQI dự phòng.
- **Dữ liệu đầu vào**:
  ```json
  {
    "lat": 10.762622,
    "lon": 106.660172
  }
  ```
- **Response**: gộp dữ liệu thô từ các nguồn để client tự parse:
  ```json
  {
    "weather": { "...": "OpenWeatherMap current weather, null nếu không có key" },
    "waqi": { "...": "WAQI feed, null nếu không có key/không có trạm" },
    "owm_aqi": { "...": "OpenWeatherMap air pollution, dùng làm AQI dự phòng" }
  }
  ```

### 4. Tiếp nhận Dữ liệu Strava (Webhook)
Lắng nghe và xử lý thông báo hoạt động từ Strava.

- **Đường dẫn**: `POST /functions/v1/strava_webhook`
- **Hành vi**: Tự động kích hoạt quy trình đồng bộ hóa khi người dùng có hoạt động tập luyện mới.

---

## Các Hàm Nghiệp vụ Cơ sở dữ liệu (RPC)

### `get_leaderboard`
Truy xuất danh sách bảng xếp hạng người dùng.
- **Tham số**: `p_limit` (Giới hạn số lượng bản ghi)

### `get_match_suggestions`
Đề xuất đối tác chạy bộ phù hợp dựa trên tiêu chí nhịp độ và vị trí.

---

## Cấu trúc Bảng Dữ liệu Cốt lõi

| Tên Bảng | Vai trò |
| :--- | :--- |
| `profiles` | Quản lý thông tin cá nhân và cấu hình tích hợp của người dùng. |
| `activities` | Lưu trữ chi tiết các buổi chạy và tọa độ di chuyển. |
| `training_schedules` | Quản lý giáo án và lịch trình tập luyện cá nhân. |
| `ai_insights` | Lưu trữ kết quả phân tích và lời khuyên từ AI. |
| `badges` | Quản lý danh hiệu và thành tựu của người dùng. |
| `run_matches` | Quản lý các yêu cầu kết nối và bạn chạy bộ. |
| `ai_rate_limit` | Bộ đếm rate-limit cho cổng AI proxy (chống spam/lạm dụng, chỉ service role truy cập). |
