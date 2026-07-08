import 'dart:typed_data';
import 'image_compress_service_stub.dart'
    if (dart.library.js_interop) 'image_compress_service_web.dart';

/// Dịch vụ nén ảnh thông minh trước khi gửi lên backend.
/// Hỗ trợ nén bằng Canvas ở phía Client trên Web để tối ưu băng thông.
abstract class ImageCompressService {
  /// Nén và điều chỉnh kích thước ảnh.
  ///
  /// [bytes]: Dữ liệu ảnh dạng raw bytes.
  /// [filename]: Tên tệp ảnh (để lấy định dạng và MIME type).
  /// [maxWidth]: Chiều rộng tối đa mong muốn (mặc định 1600).
  /// [maxHeight]: Chiều cao tối đa mong muốn (mặc định 1600).
  /// [quality]: Chất lượng nén từ 1-100 (mặc định 80).
  Future<Uint8List> compress({
    required Uint8List bytes,
    required String filename,
    int? maxWidth = 1600,
    int? maxHeight = 1600,
    int quality = 80,
  });

  factory ImageCompressService() => createImageCompressService();
}
