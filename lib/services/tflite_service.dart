import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/video_frame.dart';

class RankedPrediction {
  const RankedPrediction({required this.value, required this.confidence});

  final String value;
  final double confidence;
}

class LivePrediction {
  const LivePrediction({required this.ranked, required this.elapsed});

  final List<RankedPrediction> ranked;
  final Duration elapsed;

  RankedPrediction get best => ranked.first;
}

class TfliteService {
  static const String modelAsset = 'assets/model.tflite';
  static const List<String> labels = [
    '5 TL',
    '10 TL',
    '20 TL',
    '50 TL',
    '100 TL',
    '200 TL',
  ];
  static const int topPredictionCount = 5;

  Interpreter? _interpreter;
  Future<Interpreter>? _loadingInterpreter;
  bool _disposed = false;
  int _inputWidth = 0;
  int _inputHeight = 0;
  TensorType? _inputType;
  TensorType? _outputType;
  int _classCount = 0;

  Future<LivePrediction> predictFrame(VideoFrame frame) async {
    if (_disposed) {
      throw StateError('Model service has already been disposed.');
    }

    final interpreter = await _ensureInterpreter();
    final stopwatch = Stopwatch()..start();
    final rgbBytes = frameToInput(
      frame,
      width: _inputWidth,
      height: _inputHeight,
    );
    final probabilities = normalizeScores(_runInference(interpreter, rgbBytes));
    stopwatch.stop();

    return LivePrediction(
      ranked: rankedPredictions(probabilities),
      elapsed: stopwatch.elapsed,
    );
  }

  static List<RankedPrediction> rankedPredictions(List<double> probabilities) {
    if (probabilities.length != labels.length) {
      throw ArgumentError('The model returned an unexpected score count.');
    }

    final indices = List<int>.generate(probabilities.length, (index) => index)
      ..sort((a, b) => probabilities[b].compareTo(probabilities[a]));

    return List<RankedPrediction>.unmodifiable(
      indices
          .take(topPredictionCount)
          .map(
            (index) => RankedPrediction(
              value: labels[index],
              confidence: probabilities[index].clamp(0.0, 1.0),
            ),
          ),
    );
  }

  static Uint8List frameToInput(
    VideoFrame frame, {
    required int width,
    required int height,
  }) {
    if (width <= 0 || height <= 0 || width != height) {
      throw ArgumentError('Model input dimensions must be equal and positive.');
    }
    if (frame.width <= 0 || frame.height <= 0 || frame.planes.isEmpty) {
      throw ArgumentError('Frame dimensions and planes must be valid.');
    }

    final rotation = ((frame.rotationDegrees % 360) + 360) % 360;
    if (rotation % 90 != 0) {
      throw ArgumentError('Frame rotation must be a multiple of 90 degrees.');
    }

    final rotatedWidth = rotation == 90 || rotation == 270
        ? frame.height
        : frame.width;
    final rotatedHeight = rotation == 90 || rotation == 270
        ? frame.width
        : frame.height;

    final yPlane = frame.planes.first;
    final isBgra = frame.format == FrameFormat.bgra8888;
    final interleavedUv =
        frame.format == FrameFormat.yuv420 && frame.planes.length == 2;
    final uPlane = isBgra || frame.planes.length < 2 ? null : frame.planes[1];
    final vPlane = isBgra || frame.planes.length < 3 ? null : frame.planes[2];

    if (frame.format == FrameFormat.yuv420 && frame.planes.length == 1) {
      throw const FormatException('YUV frame must have at least two planes.');
    }
    if (isBgra && frame.planes.length != 1) {
      throw const FormatException('BGRA frame must have one plane.');
    }

    final output = Uint8List(width * height * 3);
    var outputIndex = 0;

    for (var outputY = 0; outputY < height; outputY++) {
      final dy = (outputY * rotatedHeight) ~/ height;

      for (var outputX = 0; outputX < width; outputX++) {
        final dx = (outputX * rotatedWidth) ~/ width;

        final int sourceX;
        final int sourceY;

        switch (rotation) {
          case 0:
            sourceX = dx;
            sourceY = dy;
            break;
          case 90:
            sourceX = dy;
            sourceY = frame.height - 1 - dx;
            break;
          case 180:
            sourceX = frame.width - 1 - dx;
            sourceY = frame.height - 1 - dy;
            break;
          case 270:
            sourceX = frame.width - 1 - dy;
            sourceY = dx;
            break;
          default:
            throw ArgumentError('Unsupported frame rotation: $rotation.');
        }

        if (isBgra) {
          final pixelIndex =
              sourceY * yPlane.bytesPerRow + sourceX * yPlane.pixelStride;
          output[outputIndex++] = yPlane.bytes[pixelIndex + 2];
          output[outputIndex++] = yPlane.bytes[pixelIndex + 1];
          output[outputIndex++] = yPlane.bytes[pixelIndex];
          continue;
        }

        final yIndex =
            sourceY * yPlane.bytesPerRow + sourceX * yPlane.pixelStride;
        final uvX = sourceX >> 1;
        final uvY = sourceY >> 1;
        final uIndex = uvY * uPlane!.bytesPerRow + uvX * uPlane.pixelStride;
        final uValue = uPlane.bytes[uIndex];
        final vValue = interleavedUv
            ? uPlane.bytes[uIndex + 1]
            : vPlane!.bytes[uvY * vPlane.bytesPerRow +
                  uvX * vPlane.pixelStride];

        final c = yPlane.bytes[yIndex] - 16;
        final d = uValue - 128;
        final e = vValue - 128;

        final red = (298 * c + 409 * e + 128) >> 8;
        final green = (298 * c - 100 * d - 208 * e + 128) >> 8;
        final blue = (298 * c + 516 * d + 128) >> 8;

        output[outputIndex++] = red < 0
            ? 0
            : red > 255
            ? 255
            : red;
        output[outputIndex++] = green < 0
            ? 0
            : green > 255
            ? 255
            : green;
        output[outputIndex++] = blue < 0
            ? 0
            : blue > 255
            ? 255
            : blue;
      }
    }

    return output;
  }

  Future<Interpreter> _ensureInterpreter() {
    final interpreter = _interpreter;
    if (interpreter != null) {
      return Future.value(interpreter);
    }

    return _loadingInterpreter ??= _loadInterpreter();
  }

  Future<Interpreter> _loadInterpreter() async {
    try {
      final interpreter = await Interpreter.fromAsset(modelAsset);

      if (_disposed) {
        interpreter.close();
        throw StateError('Model service has already been disposed.');
      }

      try {
        _configure(interpreter);
      } catch (_) {
        interpreter.close();
        rethrow;
      }

      _interpreter = interpreter;
      return interpreter;
    } finally {
      _loadingInterpreter = null;
    }
  }

  void _configure(Interpreter interpreter) {
    final input = interpreter.getInputTensor(0);
    final output = interpreter.getOutputTensor(0);
    final inputShape = input.shape;
    final outputShape = output.shape;
    final inputType = input.type;
    final outputType = output.type;

    if (inputType != TensorType.uint8 && inputType != TensorType.float32) {
      throw StateError('Unsupported model input type: $inputType.');
    }

    if (inputShape.length != 4 ||
        inputShape[0] != 1 ||
        inputShape[1] <= 0 ||
        inputShape[2] <= 0 ||
        inputShape[2] != inputShape[1] ||
        inputShape[3] != 3) {
      throw StateError('Unsupported model input shape: $inputShape.');
    }

    if (outputType != TensorType.uint8 && outputType != TensorType.float32) {
      throw StateError('Unsupported model output type: $outputType.');
    }

    if (outputShape.length != 2 ||
        outputShape[0] != 1 ||
        outputShape[1] != labels.length) {
      throw StateError('Unsupported model output shape: $outputShape.');
    }

    _inputType = inputType;
    _outputType = outputType;
    _inputHeight = inputShape[1];
    _inputWidth = inputShape[2];
    _classCount = outputShape[1];
  }

  List<num> _runInference(Interpreter interpreter, Uint8List rgbBytes) {
    final inputType = _inputType;
    final outputType = _outputType;

    if (inputType == TensorType.uint8) {
      final output = Uint8List(_classCount);
      interpreter.run(rgbBytes.buffer, output.buffer);
      return output;
    }

    if (inputType == TensorType.float32) {
      final input = Float32List(rgbBytes.length);
      for (var index = 0; index < rgbBytes.length; index++) {
        input[index] = rgbBytes[index] / 255.0;
      }

      if (outputType == TensorType.uint8) {
        final output = Uint8List(_classCount);
        interpreter.run(input.buffer, output.buffer);
        return output;
      }

      final output = Float32List(_classCount);
      interpreter.run(input.buffer, output.buffer);
      return output;
    }

    throw StateError('Unsupported model input type: $inputType.');
  }

  static List<double> normalizeScores(List<num> scores) {
    if (scores.isEmpty) {
      throw const FormatException('The model returned no scores.');
    }

    final values = scores
        .map((score) => score.toDouble())
        .toList(growable: false);
    if (values.any((value) => !value.isFinite)) {
      throw const FormatException('The model returned invalid scores.');
    }

    final sum = values.fold<double>(0, (total, value) => total + value);
    if (sum <= 0) {
      throw const FormatException('The model returned invalid scores.');
    }

    final alreadyNormalized =
        values.every((value) => value >= 0 && value <= 1) &&
        (sum - 1).abs() <= 0.05;
    final quantizedRange = values.every(
      (value) => value >= 0 && value <= 255 && value == value.roundToDouble(),
    );

    if (alreadyNormalized || quantizedRange) {
      return values.map((value) => value / sum).toList(growable: false);
    }

    final maxScore = values.reduce(math.max);
    final exponentials = values
        .map((value) => math.exp(value - maxScore))
        .toList(growable: false);
    final exponentialSum = exponentials.fold<double>(
      0,
      (total, value) => total + value,
    );

    if (!exponentialSum.isFinite || exponentialSum <= 0) {
      throw const FormatException('The model returned invalid scores.');
    }

    return exponentials
        .map((value) => value / exponentialSum)
        .toList(growable: false);
  }

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    final interpreter = _interpreter;
    _interpreter = null;
    interpreter?.close();
  }
}
