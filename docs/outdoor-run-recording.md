# Ghi buổi chạy GPS trên Android / iOS

Chọn **nút Ghi chạy màu đỏ ở giữa thanh menu dưới cùng**. Cấp quyền vị trí chính xác,
chờ **GPS sẵn sàng**, rồi chọn **Bắt đầu**. Có thể kéo/phóng to bản đồ, căn giữa,
tạm dừng, tiếp tục, kết thúc và xem trước trước khi lưu. Bấm lại nút đỏ
để trở lại buổi chạy hoặc bản nháp. Menu cố định có Trang chủ, Lịch sử, Ghi chạy,
Cộng đồng và Thêm; Lịch tập, HLV AI, Dinh dưỡng và Hồ sơ nằm trong Thêm.
Chỉ tài khoản đã đăng nhập trên Android/iOS
được ghi; web vẫn xem lịch sử và bản đồ của các buổi đã lưu.

## Production: Supabase Dashboard

1. Mở đúng project trong **Supabase Dashboard → SQL Editor → New query**.
2. Dán toàn bộ `supabase/migrations/20261103000000_record_outdoor_runs.sql`
   và chọn **Run**, một lần, sau khi đã áp dụng các migration trước đó.
3. Trong **Table Editor**, kiểm tra bảng `activity_routes` đã bật RLS và có
   hai policy cho chủ sở hữu; bảng `activities` có cột `has_gps_route`.
4. Build/cài ứng dụng mới sau khi migration thành công. Không cần Edge Function,
   provider secret, API key bản đồ hoặc thay đổi cấu hình Render.

Migration thêm bảng GPS riêng và RPC `save_recorded_run` chạy với quyền người gọi,
không dùng service role. Khóa ngoại `(activity_id, user_id)` ngăn gắn tuyến đường
vào hoạt động của người khác. Không cấp quyền truy cập GPS cho `anon`. RPC lưu
hoạt động và tuyến đường trong một transaction. UUID của bản nháp không đổi qua
các lần thử: nếu server đã lưu mà mất phản hồi, lần thử tiếp trả lại bản ghi đã
lưu, không tạo thêm hoạt động hoặc ghi đè số liệu. Xóa hoạt động sẽ xóa tuyến đường.
Migration cũng tăng độ chính xác số liệu thời gian/quãng đường của `activities`;
các bản ghi cũ giữ nguyên giá trị và không truy vấn bảng GPS.

## Thiết bị và bản đồ

### Kiểm tra trong Android Emulator

Emulator dùng vị trí GPS giả lập, không tự xác định vị trí thật của máy tính.
Trong Android Studio, mở **Running Devices → Extended controls (…) → Location**,
chọn địa điểm rồi bấm **Set location**. Có thể phát một tuyến đường để kiểm tra
di chuyển. Tọa độ mặc định có thể ở Google campus tại Mỹ; đây không phải vị trí
thật của người dùng. Trên điện thoại thật, bật vị trí chính xác và kiểm tra ngoài trời.

Bản đồ hiển thị vòng tròn sai số và độ chính xác ước tính do thiết bị báo cáo.
Vị trí quá cũ hoặc không đủ chính xác không được hiển thị như vị trí trực tiếp;
tuyến đã ghi vẫn được giữ. Kéo bản đồ tắt tự bám; bấm nút căn giữa để bám lại.

### Điện thoại thật

- Chạy `flutter pub get` trong `apps/runny_app`, rồi `flutter run -d <device-id>`.
  Giữ `.env` client như trước: chỉ URL và anon/publishable key Supabase.
- Android: dùng quyền vị trí chính xác và location foreground service được khởi
  động khi màn hình ghi chạy đang mở; quyền `FOREGROUND_SERVICE_LOCATION` và
  `WAKE_LOCK` đã khai báo. Geolocator gộp service có type `location` vào manifest.
  Không yêu cầu quyền vị trí mọi lúc vì đây là phiên ghi do người dùng khởi động.
  Cho phép thông báo để dễ thấy trạng thái GPS; không tắt quyền vị trí giữa buổi.
- iOS: `UIBackgroundModes=location`, mô tả quyền bằng tiếng Việt/Anh, AppleSettings
  fitness, không tự tạm dừng, cho phép cập nhật nền và chỉ báo vị trí nền đã cấu hình.
  Build/sign trên macOS với Xcode, kiểm tra **Runner → Signing & Capabilities →
  Background Modes → Location updates**. Không đặt `BYPASS_PERMISSION_LOCATION_ALWAYS=1`.
  Phiên ghi bắt đầu khi app đang hiển thị; quyền When In Use và chỉ báo nền cho
  phép tiếp tục phiên đó, tùy cài đặt iOS
  ([Apple: location authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)).
- Dùng Geolocator có sẵn và `flutter_map 8.3.2` (Android/iOS/web). Bản đồ dùng HTTPS
  OpenStreetMap, User-Agent ứng dụng, attribution hiển thị và cache mặc định của
  flutter_map. Không cần key hoặc tài khoản thanh toán. Tuân thủ
  [OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/):
  không tải hàng loạt/prefetch; dịch vụ best effort, không có SLA. Khi lưu lượng
  tăng, chuyển sang tile host có dung lượng phù hợp trong `run_route_map.dart`.
  [flutter_map platform support](https://pub.dev/packages/flutter_map/versions/8.3.2),
  [Geolocator configuration](https://pub.dev/packages/geolocator/versions/11.1.0),
  [Android foreground location](https://developer.android.com/develop/sensors-and-location/location/permissions#foreground_location).
- GPS và vẽ tuyến không phụ thuộc tile/network. Khi offline, nền bản đồ có thể
  trống; chấm vị trí, các đoạn tuyến, thời gian và quãng đường vẫn hoạt động.
  Lưu Supabase và tải lại tuyến đã lưu cần kết nối.

## Dữ liệu cục bộ và giới hạn

Service Provider giữ toàn bộ trạng thái; màn hình chỉ điều khiển/hiển thị. File
JSON trong application support được tách theo user ID, ghi qua file tạm với
flush/rename. Snapshot mỗi 5 giây và khi tạm dừng/tiếp tục/kết thúc; bản nháp đã
kết thúc không bị xóa khi điều hướng, đóng app hoặc lưu thất bại. Chỉ xóa sau
xác nhận bỏ hoặc sau phản hồi lưu thành công. Lỗi bộ nhớ được hiển thị và chặn
upload cho đến khi ghi được bản nháp.

Nếu hệ điều hành giết tiến trình hoặc người dùng buộc đóng app, không có tự
khởi động lại GPS: mở lại sẽ hiện bản xem trước từ checkpoint cuối, có thể mất
phần chưa checkpoint (thường khoảng 5 giây khi tiến trình vẫn được chạy).
Không cộng thời gian sau checkpoint khi
khôi phục. Đăng xuất dừng GPS và giữ bản nháp riêng để chủ tài khoản đăng nhập lại.
Xóa ứng dụng/dữ liệu ứng dụng sẽ xóa bản nháp chưa lưu.

Fix yêu cầu tọa độ hợp lệ, accuracy ≤25m và tuổi ≤10 giây; gap >15 giây, fix kém
chính xác, lỗi GPS hoặc tạm dừng tạo đoạn mới, không nối khoảng trống. Timer vẫn
chạy khi mất GPS. Bỏ jitter <3m và bước nhảy >12m/s. Pace chỉ hiển thị sau 100m.
Giới hạn lưu: 100.000 điểm, 8MiB tuyến, 7 ngày thời gian hoạt động/1.000km mỗi run.
Các ngưỡng GPS cần kiểm chứng thực địa trên thiết bị thật.

## Kiểm chứng

Đã chạy trên Windows ngày 2026-11-03: `flutter analyze` sạch; 39 test tập trung
đều thành công; `flutter build web --release` và `flutter build apk --debug`
thành công. Web build có cảnh báo Wasm dry-run từ `dart:html` của Geolocator web
có sẵn; bản JavaScript release vẫn build thành công. APK debug ở
`apps/runny_app/build/app/outputs/flutter-apk/app-debug.apk`.

Chưa chạy test RLS vì Docker daemon/local stack không hoạt động. Không có điện
thoại Android/iOS kết nối; chưa build iOS vì host Windows không có Xcode. Các
kiểm tra thiết bị thật bên dưới vẫn cần hoàn thành trước khi phát hành mobile.

Từ `apps/runny_app`:

```sh
flutter analyze
flutter test test/recorded_run_test.dart test/services/run_recording_service_test.dart test/run_route_map_test.dart test/activity_summary_card_test.dart test/activity_parser_test.dart
flutter build web --release
```

Khi Docker/local Supabase đang chạy và migration đã áp dụng (chỉ local):

```sh
supabase test db supabase/tests/recorded_run_security_test.sql
```

Test SQL dùng hai user trong transaction rồi rollback; kiểm tra owner đọc được,
user khác không đọc/ghi được, retry không trùng và thời gian/đoạn tuyến được giữ.

Thiết bị thật Android **và** iOS còn cần kiểm tra:

1. Từ chối quyền, từ chối vĩnh viễn, cấp lại trong Settings; tắt/bật dịch vụ vị trí;
   vị trí gần đúng; Start chỉ bật với fix chính xác còn mới.
2. Chạy >100m, kéo/zoom/recenter, tạm dừng rồi di chuyển xa và tiếp tục: không cộng
   thời gian/quãng đường tạm dừng, không nối tuyến giữa hai đoạn.
3. Mất GPS trong khi đang chạy và phục hồi: timer không dừng, không nối gap.
4. Khóa màn hình 5–10 phút; chuyển ứng dụng; kiểm tra GPS vẫn cập nhật, thống kê
   và notification/chỉ báo nền, cả khi bật chế độ tiết kiệm pin.
5. Tắt Wi-Fi/dữ liệu, chạy và kết thúc; thoát/vào lại bản nháp, bật mạng rồi lưu.
6. Ngắt phản hồi save sau khi server commit rồi thử lại: chỉ một activity/route.
   Mở lại lịch sử, kiểm tra đúng số liệu và số đoạn; xác nhận bỏ chỉ sau dialog.
7. Đăng xuất/đăng nhập tài khoản khác: không hiện tuyến/bản nháp tài khoản trước.
