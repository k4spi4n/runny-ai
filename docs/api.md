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

### 1. Cổng kết nối AI (OpenRouter Proxy)
Chuyển tiếp và bảo mật các yêu cầu xử lý trí tuệ nhân tạo.

- **Đường dẫn**: `POST /functions/v1/openrouter`
- **Chức năng**: Bảo mật khóa API và điều phối yêu cầu tới các mô hình ngôn ngữ lớn (LLM).
- **Định dạng dữ liệu**: Tuân theo tiêu chuẩn của OpenRouter.

### 2. Dịch vụ Thời tiết và Môi trường
Cung cấp thông tin thời tiết và chất lượng không khí dựa trên vị trí địa lý.

- **Đường dẫn**: `POST /functions/v1/weather`
- **Dữ liệu đầu vào**:
  ```json
  {
    "lat": 10.762622,
    "lon": 106.660172
  }
  ```

### 3. Tiếp nhận Dữ liệu Strava (Webhook)
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
