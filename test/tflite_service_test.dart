import 'package:flutter_banknote_recognition/services/tflite_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('prepareInput', () {
    test('görüntüyü ortadan kırpar, yeniden boyutlandırır ve RGB üretir', () {
      final source = img.Image(width: 300, height: 100);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          final isLeft = x < source.width / 2;
          source.setPixelRgb(x, y, isLeft ? 255 : 0, 0, isLeft ? 0 : 255);
        }
      }

      final bytes = TfliteService.prepareInput(source, width: 224, height: 224);

      expect(bytes.length, 224 * 224 * 3);

      final topLeft = (112 * 224) * 3;
      expect(bytes.sublist(topLeft, topLeft + 3), [255, 0, 0]);

      final topRight = (112 * 224 + 223) * 3;
      expect(bytes.sublist(topRight, topRight + 3), [0, 0, 255]);
    });

    test('geçersiz hedef boyutlarını reddeder', () {
      final source = img.Image(width: 10, height: 10);

      expect(
        () => TfliteService.prepareInput(source, width: 0, height: 0),
        throwsArgumentError,
      );
      expect(
        () => TfliteService.prepareInput(source, width: 224, height: 112),
        throwsArgumentError,
      );
    });
  });

  group('normalizeScores', () {
    test('uint8 model çıktısını olasılıklara dönüştürür', () {
      final probabilities = TfliteService.normalizeScores([
        20,
        209,
        0,
        2,
        25,
        0,
      ]);

      expect(probabilities.length, TfliteService.labels.length);
      expect(probabilities.reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(probabilities[1], closeTo(209 / 256, 1e-9));
    });

    test('zaten normalize edilmiş çıktıyı korur', () {
      final probabilities = TfliteService.normalizeScores([
        0.05,
        0.9,
        0.01,
        0.02,
        0.01,
        0.01,
      ]);

      expect(probabilities.reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(probabilities[1], closeTo(0.9, 1e-9));
    });

    test('logit çıktısını softmax ile olasılıklara dönüştürür', () {
      final probabilities = TfliteService.normalizeScores([
        2.0,
        -1.0,
        0.5,
        0.0,
        -2.0,
        1.0,
      ]);

      expect(probabilities.reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(probabilities.every((probability) => probability >= 0), isTrue);
      expect(probabilities[0], greaterThan(probabilities[1]));
    });

    test('boş veya geçersiz çıktıyı reddeder', () {
      expect(() => TfliteService.normalizeScores([]), throwsFormatException);
      expect(
        () => TfliteService.normalizeScores([0, 0, 0]),
        throwsFormatException,
      );
      expect(
        () => TfliteService.normalizeScores([1, double.nan]),
        throwsFormatException,
      );
    });
  });
}
