import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/services/image_compress_service.dart';

void main() {
  group('ImageCompressService Tests', () {
    late ImageCompressService compressService;

    setUp(() {
      compressService = ImageCompressService();
    });

    test('Should instantiate correct service implementation', () {
      expect(compressService, isNotNull);
    });

    test('Stub implementation should return original bytes unchanged', () async {
      final originalBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final compressedBytes = await compressService.compress(
        bytes: originalBytes,
        filename: 'test_food.jpg',
        maxWidth: 800,
        maxHeight: 600,
        quality: 80,
      );

      expect(compressedBytes, equals(originalBytes));
    });

    test('Stub implementation handles empty bytes correctly', () async {
      final originalBytes = Uint8List(0);
      final compressedBytes = await compressService.compress(
        bytes: originalBytes,
        filename: 'empty.png',
      );

      expect(compressedBytes.isEmpty, isTrue);
    });

    group('MIME Type Edge Cases in Stub', () {
      test('Stub handles different extensions without throwing error', () async {
        final originalBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
        final compressedPng = await compressService.compress(
          bytes: originalBytes,
          filename: 'image.png',
        );
        final compressedWebp = await compressService.compress(
          bytes: originalBytes,
          filename: 'image.webp',
        );

        expect(compressedPng, equals(originalBytes));
        expect(compressedWebp, equals(originalBytes));
      });
    });
  });
}
