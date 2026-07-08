import 'dart:typed_data';
import 'image_compress_service.dart';

/// Tạo instance của ImageCompressService cho môi trường mobile/desktop (không phải Web).
ImageCompressService createImageCompressService() => StubImageCompressService();

class StubImageCompressService implements ImageCompressService {
  @override
  Future<Uint8List> compress({
    required Uint8List bytes,
    required String filename,
    int? maxWidth = 1600,
    int? maxHeight = 1600,
    int quality = 80,
  }) async {
    // Trên di động/desktop, tạm thời trả về ảnh gốc (các thư viện camera picker đã hỗ trợ
    // tham số imageQuality khi bắt hình ảnh).
    return bytes;
  }
}
