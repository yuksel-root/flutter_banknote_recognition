import 'dart:typed_data';

import 'package:flutter_banknote_recognition/models/video_frame.dart';
import 'package:flutter_banknote_recognition/services/tflite_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeScores', () {
    test('keeps probabilities that already sum to one', () {
      final scores = TfliteService.normalizeScores([0.1, 0.2, 0.7]);

      expect(scores[0], closeTo(0.1, 1e-9));
      expect(scores[1], closeTo(0.2, 1e-9));
      expect(scores[2], closeTo(0.7, 1e-9));
    });

    test('applies softmax to raw logits', () {
      final scores = TfliteService.normalizeScores([1, 2, 3]);

      expect(scores.reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(scores[2], greaterThan(scores[1]));
      expect(scores[1], greaterThan(scores[0]));
    });

    test('normalizes quantized scores', () {
      final scores = TfliteService.normalizeScores([10, 20, 70]);

      expect(scores[0], closeTo(0.1, 1e-9));
      expect(scores[1], closeTo(0.2, 1e-9));
      expect(scores[2], closeTo(0.7, 1e-9));
    });

    test('rejects empty and invalid scores', () {
      expect(() => TfliteService.normalizeScores([]), throwsFormatException);
      expect(
        () => TfliteService.normalizeScores([double.nan, 1]),
        throwsFormatException,
      );
      expect(
        () => TfliteService.normalizeScores([0, 0]),
        throwsFormatException,
      );
    });
  });

  group('rankedPredictions', () {
    test('returns the five highest scores in order', () {
      final ranked = TfliteService.rankedPredictions([
        0.01,
        0.04,
        0.10,
        0.20,
        0.60,
        0.05,
      ]);

      expect(ranked.length, TfliteService.topPredictionCount);
      expect(ranked.map((prediction) => prediction.value), [
        '100 TL',
        '50 TL',
        '20 TL',
        '200 TL',
        '10 TL',
      ]);
      expect(ranked.first.confidence, 0.60);
    });

    test('rejects an unexpected score count', () {
      expect(
        () => TfliteService.rankedPredictions([0.5, 0.5]),
        throwsArgumentError,
      );
    });
  });

  group('frameToInput', () {
    test('converts a YUV frame to RGB', () {
      final frame = VideoFrame(
        width: 2,
        height: 2,
        format: FrameFormat.yuv420,
        rotationDegrees: 0,
        planes: [
          FramePlane(
            bytes: Uint8List.fromList([76, 76, 76, 76]),
            bytesPerRow: 2,
            pixelStride: 1,
          ),
          FramePlane(
            bytes: Uint8List.fromList([85]),
            bytesPerRow: 1,
            pixelStride: 1,
          ),
          FramePlane(
            bytes: Uint8List.fromList([255]),
            bytesPerRow: 1,
            pixelStride: 1,
          ),
        ],
      );

      final bytes = TfliteService.frameToInput(
        frame,
        width: 2,
        height: 2,
        cropToNote: false,
      );

      expect(bytes, [255, 0, 0, 255, 0, 0, 255, 0, 0, 255, 0, 0]);
    });

    test('rotates the frame clockwise', () {
      const quadrants = [
        [76, 85, 255],
        [150, 44, 21],
        [29, 255, 107],
        [235, 128, 128],
      ];
      final yBytes = Uint8List(16);
      final uBytes = Uint8List(4);
      final vBytes = Uint8List(4);

      for (var blockY = 0; blockY < 2; blockY++) {
        for (var blockX = 0; blockX < 2; blockX++) {
          final color = quadrants[blockY * 2 + blockX];
          for (var y = 0; y < 2; y++) {
            for (var x = 0; x < 2; x++) {
              yBytes[(blockY * 2 + y) * 4 + blockX * 2 + x] = color[0];
            }
          }
          uBytes[blockY * 2 + blockX] = color[1];
          vBytes[blockY * 2 + blockX] = color[2];
        }
      }

      final frame = VideoFrame(
        width: 4,
        height: 4,
        format: FrameFormat.yuv420,
        rotationDegrees: 90,
        planes: [
          FramePlane(bytes: yBytes, bytesPerRow: 4, pixelStride: 1),
          FramePlane(bytes: uBytes, bytesPerRow: 2, pixelStride: 1),
          FramePlane(bytes: vBytes, bytesPerRow: 2, pixelStride: 1),
        ],
      );

      final bytes = TfliteService.frameToInput(
        frame,
        width: 2,
        height: 2,
        cropToNote: false,
      );

      expect(bytes, [0, 0, 255, 255, 0, 0, 255, 255, 255, 0, 255, 0]);
    });

    test('converts a BGRA frame to RGB', () {
      final frame = VideoFrame(
        width: 2,
        height: 2,
        format: FrameFormat.bgra8888,
        rotationDegrees: 0,
        planes: [
          FramePlane(
            bytes: Uint8List.fromList([
              255,
              0,
              0,
              255,
              0,
              255,
              0,
              255,
              0,
              0,
              255,
              255,
              255,
              255,
              255,
              255,
            ]),
            bytesPerRow: 8,
            pixelStride: 4,
          ),
        ],
      );

      final bytes = TfliteService.frameToInput(
        frame,
        width: 2,
        height: 2,
        cropToNote: false,
      );

      expect(bytes, [0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255]);
    });

    test('crops the centered note band before inference', () {
      final bytes = Uint8List(4 * 16 * 4);
      for (var y = 0; y < 16; y++) {
        final green = y >= 8 && y < 10;
        for (var x = 0; x < 4; x++) {
          final index = (y * 4 + x) * 4;
          bytes[index] = 0;
          bytes[index + 1] = green ? 255 : 0;
          bytes[index + 2] = green ? 0 : 255;
          bytes[index + 3] = 255;
        }
      }

      final frame = VideoFrame(
        width: 4,
        height: 16,
        format: FrameFormat.bgra8888,
        rotationDegrees: 0,
        planes: [FramePlane(bytes: bytes, bytesPerRow: 16, pixelStride: 4)],
      );

      final output = TfliteService.frameToInput(frame, width: 2, height: 2);

      expect(output, [0, 255, 0, 0, 255, 0, 0, 255, 0, 0, 255, 0]);
    });

    test('brightens dark frames before inference', () {
      final frame = VideoFrame(
        width: 2,
        height: 2,
        format: FrameFormat.bgra8888,
        rotationDegrees: 0,
        planes: [
          FramePlane(
            bytes: Uint8List.fromList([
              10,
              10,
              10,
              255,
              10,
              10,
              10,
              255,
              10,
              10,
              10,
              255,
              10,
              10,
              10,
              255,
            ]),
            bytesPerRow: 8,
            pixelStride: 4,
          ),
        ],
      );

      final bytes = TfliteService.frameToInput(
        frame,
        width: 2,
        height: 2,
        cropToNote: false,
      );

      expect(bytes.first, inInclusiveRange(55, 65));
      expect(bytes[1], bytes.first);
      expect(bytes[2], bytes.first);
    });

    test('keeps bright frames unchanged', () {
      final frame = VideoFrame(
        width: 2,
        height: 2,
        format: FrameFormat.bgra8888,
        rotationDegrees: 0,
        planes: [
          FramePlane(
            bytes: Uint8List.fromList([
              200,
              200,
              200,
              255,
              200,
              200,
              200,
              255,
              200,
              200,
              200,
              255,
              200,
              200,
              200,
              255,
            ]),
            bytesPerRow: 8,
            pixelStride: 4,
          ),
        ],
      );

      final bytes = TfliteService.frameToInput(
        frame,
        width: 2,
        height: 2,
        cropToNote: false,
      );

      expect(bytes, List<int>.filled(12, 200));
    });

    test('rejects invalid frames and target sizes', () {
      final validFrame = VideoFrame(
        width: 2,
        height: 2,
        format: FrameFormat.yuv420,
        rotationDegrees: 0,
        planes: [
          FramePlane(bytes: Uint8List(4), bytesPerRow: 2, pixelStride: 1),
          FramePlane(bytes: Uint8List(1), bytesPerRow: 1, pixelStride: 1),
          FramePlane(bytes: Uint8List(1), bytesPerRow: 1, pixelStride: 1),
        ],
      );

      expect(
        () => TfliteService.frameToInput(validFrame, width: 2, height: 3),
        throwsArgumentError,
      );
      expect(
        () => TfliteService.frameToInput(
          VideoFrame(
            width: 2,
            height: 2,
            format: FrameFormat.yuv420,
            rotationDegrees: 45,
            planes: validFrame.planes,
          ),
          width: 2,
          height: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => TfliteService.frameToInput(
          VideoFrame(
            width: 2,
            height: 2,
            format: FrameFormat.yuv420,
            rotationDegrees: 0,
            planes: [validFrame.planes.first],
          ),
          width: 2,
          height: 2,
        ),
        throwsFormatException,
      );
    });
  });
}
