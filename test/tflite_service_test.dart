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

      final bytes = TfliteService.prepareInput(
        source,
        width: 224,
        height: 224,
        cropToGuide: false,
      );

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

    test('crops the guide area before resizing', () {
      final source = img.Image(width: 400, height: 400);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          final inside = x >= 10 && x < 390 && y >= 85 && y < 275;
          source.setPixelRgb(x, y, inside ? 0 : 255, inside ? 255 : 0, 0);
        }
      }

      final bytes = TfliteService.prepareInput(source, width: 224, height: 224);

      expect(bytes.sublist(0, 3), [0, 255, 0]);
      final last = (224 * 224 - 1) * 3;
      expect(bytes.sublist(last, last + 3), [0, 255, 0]);
    });

    test('computes a wide guide crop around the note area', () {
      expect(TfliteService.guideCropRect(720, 1280), (
        x: 18,
        y: 405,
        width: 684,
        height: 342,
      ));
      expect(TfliteService.guideCropRect(1280, 720), (
        x: 32,
        y: 20,
        width: 1216,
        height: 608,
      ));
      expect(() => TfliteService.guideCropRect(0, 720), throwsArgumentError);
    });
  });

  group('combinePredictions', () {
    test('keeps the higher confidence when both crops agree', () {
      final combined = TfliteService.combinePredictions(
        const TflitePrediction(value: '100 TL', confidence: 0.8),
        const TflitePrediction(value: '100 TL', confidence: 0.6),
      );

      expect(combined.value, '100 TL');
      expect(combined.confidence, 0.8);
    });

    test('returns zero confidence when the crops disagree', () {
      final combined = TfliteService.combinePredictions(
        const TflitePrediction(value: '100 TL', confidence: 0.8),
        const TflitePrediction(value: '50 TL', confidence: 0.7),
      );

      expect(combined.confidence, 0);
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
