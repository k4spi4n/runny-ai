# Tầm nhìn Sản phẩm, Personas & User Stories

Tài liệu này mô tả tầm nhìn sản phẩm, nhóm người dùng mục tiêu (personas), các kịch
bản sử dụng (scenarios) và user stories của **Runny AI**, làm cơ sở định hướng ưu tiên
tính năng cho từng increment. Mọi user story dưới đây đều ánh xạ tới tính năng đã được
hiện thực trong mã nguồn và được truy vết qua Issue/PR tương ứng.

## 1. Tầm nhìn Sản phẩm (Product Vision)

> Dành cho **những người chạy bộ phong trào và bán chuyên** muốn cải thiện hiệu suất
> nhưng **không đủ điều kiện thuê huấn luyện viên cá nhân**, **Runny AI** là một hệ sinh
> thái luyện tập được hỗ trợ bởi AI, **cung cấp huấn luyện viên ảo cá nhân hóa, phân tích
> hoạt động chuyên sâu và động lực cộng đồng**. Khác với các ứng dụng chỉ ghi nhận số
> liệu (Strava, Garmin Connect), Runny AI **biến dữ liệu thô thành lời khuyên hành động
> và giáo án tập luyện động** theo mục tiêu của từng người.

**Vấn đề giải quyết:** người chạy bộ có dữ liệu (GPX/FIT, pace, nhịp tim) nhưng thiếu
chuyên môn để diễn giải và thiếu kế hoạch tập luyện cá nhân hóa, dẫn đến tập sai, chấn
thương hoặc mất động lực.

## 2. Personas

### Persona A — "Minh, người mới bắt đầu"
- 27 tuổi, nhân viên văn phòng, mới chạy bộ 3 tháng.
- **Mục tiêu:** hoàn thành 5K an toàn, không chấn thương.
- **Khó khăn:** không biết pace hợp lý, không biết khi nào nên nghỉ.
- **Cần:** giáo án dễ theo, lời khuyên đơn giản, theo dõi cân nặng/BMI.

### Persona B — "Lan, runner bán chuyên"
- 34 tuổi, đã chạy half-marathon, tập 4–5 buổi/tuần.
- **Mục tiêu:** phá PR 10K, chuẩn bị full marathon.
- **Khó khăn:** muốn phân tích sâu pace/HR/elevation từng km, quản lý độ mòn giày.
- **Cần:** import GPX/FIT & đồng bộ Strava, biểu đồ tương tác, Shoe Tracker.

### Persona C — "Khoa, runner thích cộng đồng"
- 22 tuổi, sinh viên, chạy để giảm stress và kết bạn.
- **Mục tiêu:** duy trì thói quen, có động lực hàng ngày.
- **Khó khăn:** dễ bỏ cuộc khi chạy một mình.
- **Cần:** bảng xếp hạng, huy hiệu, ghép đôi bạn chạy.

## 3. Scenarios tiêu biểu

- **S1 — Onboarding:** Minh đăng ký, nhập chiều cao/cân nặng/mục tiêu; hệ thống tính BMI
  và khởi tạo hồ sơ để AI cá nhân hóa giáo án.
- **S2 — Phân tích buổi chạy:** Lan import file `.gpx` sau buổi long-run, xem biểu đồ
  Pace/HR/Elevation đồng bộ và nhận nhận xét AI cho từng chặng.
- **S3 — Giữ động lực:** Khoa kiểm tra bảng xếp hạng tuần, nhận huy hiệu mốc 50km và tìm
  bạn chạy cùng dải pace trong khu vực.

## 4. User Stories (ánh xạ tới Issue/PR)

| ID | User Story | Persona | Bằng chứng |
| -- | ---------- | ------- | ---------- |
| US-1 | *Là người mới*, tôi muốn nhập thể trạng khi onboarding để app tính BMI và cá nhân hóa giáo án. | A | Onboarding/Profile (#20, #17) |
| US-2 | *Là runner bán chuyên*, tôi muốn import file GPX/FIT để số hóa buổi chạy. | B | Import (#36, #44) |
| US-3 | *Là runner bán chuyên*, tôi muốn đồng bộ Strava tự động để không phải nhập tay. | B | Strava OAuth2/Webhook (#36, #44) |
| US-4 | *Là runner bán chuyên*, tôi muốn xem biểu đồ Pace/HR/Elevation tương tác để phân tích buổi chạy. | B | Advanced charts (#28, #44) |
| US-5 | *Là runner bán chuyên*, tôi muốn theo dõi độ mòn giày để biết khi nào cần thay. | B | Shoe Tracker (#28, #44) |
| US-6 | *Là người dùng bất kỳ*, tôi muốn hỏi AI Coach về kỹ thuật/chấn thương để được tư vấn ngay. | A,B,C | AI Coach (#29, #41) |
| US-7 | *Là người dùng bất kỳ*, tôi muốn AI lập giáo án theo mục tiêu (5K/10K/HM/FM). | A,B | Training Plans (#29) |
| US-8 | *Là người mới*, tôi muốn theo dõi cân nặng & BMI theo thời gian để giám sát sức khỏe. | A | Weight Tracker (#30, #37) |
| US-9 | *Là runner thích cộng đồng*, tôi muốn xem bảng xếp hạng & huy hiệu để có động lực. | C | Gamification |
| US-10 | *Là runner thích cộng đồng*, tôi muốn ghép đôi bạn chạy cùng pace/khu vực. | C | Partner Matching |
| US-11 | *Là người dùng quốc tế*, tôi muốn đổi ngôn ngữ và Light/Dark mode. | A,B,C | i18n & theme (#25, #35, #42) |

## 5. Liên kết tài liệu

- Kiến trúc hệ thống: [architecture.md](architecture.md)
- Hướng dẫn cài đặt: [setup.md](setup.md)
- Tài liệu API: [api.md](api.md)
- Danh mục công nghệ: [tech-stack.md](tech-stack.md)
