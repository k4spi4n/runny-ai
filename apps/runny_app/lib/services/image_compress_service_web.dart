import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'image_compress_service.dart';

/// Tạo instance của ImageCompressService cho môi trường Web.
ImageCompressService createImageCompressService() => WebImageCompressService();

class WebImageCompressService implements ImageCompressService {
  @override
  Future<Uint8List> compress({
    required Uint8List bytes,
    required String filename,
    int? maxWidth = 1600,
    int? maxHeight = 1600,
    int quality = 80,
  }) async {
    if (bytes.isEmpty) return bytes;

    // Nhận diện MIME type dựa trên tên file
    final mimeType = _getMimeType(filename);

    try {
      // 1. Chuyển đổi Uint8List thành JS Uint8Array
      final jsArray = bytes.toJS;
      // Tạo danh sách chứa mảng JS để tạo Blob
      final blobParts = [jsArray].toJS;
      final blob = web.Blob(blobParts, web.BlobPropertyBag(type: mimeType));

      // 2. Tạo URL đối tượng cho ảnh để HTMLImageElement tải
      final url = web.URL.createObjectURL(blob);
      final img = web.document.createElement('img') as web.HTMLImageElement;
      img.src = url;

      // Đợi ảnh tải xong
      final loadCompleter = Completer<void>();
      img.onload = (() {
        loadCompleter.complete();
      }).toJS;

      img.onerror = ((web.Event event) {
        loadCompleter.completeError('Không thể đọc dữ liệu ảnh trên trình duyệt.');
      }).toJS;

      try {
        await loadCompleter.future;
      } finally {
        web.URL.revokeObjectURL(url);
      }

      // 3. Tính toán kích thước mới để resize thông minh
      int width = img.naturalWidth;
      int height = img.naturalHeight;

      if (width == 0 || height == 0) {
        return bytes; // Ảnh trống hoặc lỗi kích thước
      }

      double ratio = width / height;

      if (maxWidth != null && width > maxWidth) {
        width = maxWidth;
        height = (width / ratio).round();
      }

      if (maxHeight != null && height > maxHeight) {
        height = maxHeight;
        width = (height * ratio).round();
      }

      // 4. Tạo Canvas để vẽ ảnh đã resize
      final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
      canvas.width = width;
      canvas.height = height;

      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      ctx.drawImage(img, 0, 0, width, height);

      // 5. Nén và xuất ra Blob với định dạng và chất lượng mong muốn
      // Groq và các API AI thích JPEG hoặc PNG. Ta mặc định chuyển đổi định dạng ảnh lớn về JPEG để nén tốt nhất
      final outputMimeType = mimeType == 'image/png' ? 'image/png' : 'image/jpeg';
      final qualityVal = (quality / 100.0).toJS;

      final blobCompleter = Completer<web.Blob?>();
      canvas.toBlob((web.Blob? resultBlob) {
        blobCompleter.complete(resultBlob);
      }.toJS, outputMimeType, qualityVal);

      final compressedBlob = await blobCompleter.future;
      if (compressedBlob == null) {
        return bytes; // Thất bại thì trả về ảnh gốc
      }

      // 6. Đọc Blob kết quả thành Uint8List
      final readerCompleter = Completer<Uint8List>();
      final reader = web.FileReader();

      reader.onloadend = (() {
        final result = reader.result;
        if (result != null && result.isDefinedAndNotNull) {
          final arrayBuffer = result as JSArrayBuffer;
          readerCompleter.complete(arrayBuffer.toDart.asUint8List());
        } else {
          readerCompleter.completeError('Không thể chuyển đổi ảnh đã nén thành byte.');
        }
      }).toJS;

      reader.onerror = (() {
        readerCompleter.completeError('Lỗi khi đọc file ảnh đã nén.');
      }).toJS;

      reader.readAsArrayBuffer(compressedBlob);
      return await readerCompleter.future;
    } catch (e) {
      // Bất kỳ lỗi nào trong quá trình nén bằng trình duyệt sẽ fallback trả về dữ liệu ảnh gốc
      // để không chặn tính năng của người dùng.
      return bytes;
    }
  }

  String _getMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg'; // Mặc định là jpeg (bao gồm cả jpg, heic...)
  }
}
