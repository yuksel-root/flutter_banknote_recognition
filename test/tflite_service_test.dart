import 'package:flutter_banknote_recognition/services/tflite_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('prepareInput', () {
    test('resizes the full image and produces RGB data', () {
      final source = img.Image(width: 100, height: 300);
      for (var y = 0; y < source.height; y++) {
        final segment = y ~/ 100;
        final red = segment == 0 ? 255 : 0;
        final green = segment == 1 ? 255 : 0;
        final blue = segment == 2 ? 255 : 0;
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgb(x, y, red, green, blue);
        }
      }

      final bytes = TfliteService.prepareInput(source, width: 224, height: 224);

      expect(bytes.length, 224 * 224 * 3);

      final top = 112 * 3;
      expect(bytes.sublist(top, top + 3), [255, 0, 0]);

      final middle = (112 * 224 + 112) * 3;
      expect(bytes.sublist(middle, middle + 3), [0, 255, 0]);

      final bottom = (223 * 224 + 112) * 3;
      expect(bytes.sublist(bottom, bottom + 3), [0, 0, 255]);
    });

    test('rejects invalid target dimensions', () {
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
    test('converts uint8 model output to probabilities', () {
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

    test('preserves already normalized output', () {
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

    test('converts logit output to probabilities with softmax', () {
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

    test('rejects empty or invalid output', () {
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
