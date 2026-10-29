import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'image_compress_service.dart';

/// Tạo instance của ImageCompressService cho môi trường mobile/desktop (không phải Web).
ImageCompressService createImageCompressService() => NativeImageCompressService();

/// Nén bằng codec gốc của hệ điều hành (Android/iOS) qua `flutter_image_compress`.
/// Trên nền tảng plugin chưa hỗ trợ (Windows/Linux) sẽ trả về ảnh gốc.
class NativeImageCompressService implements ImageCompressService {
  @override
  Future<Uint8List> compress({
    required Uint8List bytes,
    required String filename,
    int? maxWidth = 1600,
    int? maxHeight = 1600,
    int quality = 80,
  }) async {
    if (bytes.isEmpty) return bytes;

    try {
      // Đọc kích thước từ header ảnh (không giải mã toàn bộ) để tính khung đích.
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      var width = descriptor.width;
      var height = descriptor.height;
      descriptor.dispose();
      buffer.dispose();
      if (width == 0 || height == 0) return bytes;

      final ratio = width / height;
      if (maxWidth != null && width > maxWidth) {
        width = maxWidth;
        height = (width / ratio).round();
      }
      if (maxHeight != null && height > maxHeight) {
        height = maxHeight;
        width = (height * ratio).round();
      }

      // Giống bản Web: giữ PNG, các định dạng còn lại chuyển về JPEG.
      final format = filename.toLowerCase().endsWith('.png')
          ? CompressFormat.png
          : CompressFormat.jpeg;

      // `minWidth`/`minHeight` là khung mà plugin thu nhỏ ảnh về (giữ tỉ lệ),
      // nên truyền đúng kích thước đích đã tính ở trên.
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: width,
        minHeight: height,
        quality: quality,
        format: format,
      );
      return result.isEmpty ? bytes : result;
    } catch (_) {
      // Lỗi nén không được chặn tính năng: trả về ảnh gốc như bản Web.
      return bytes;
    }
  }
}
