import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TflitePrediction {
  const TflitePrediction({required this.value, required this.confidence});

  final String value;
  final double confidence;
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

  Interpreter? _interpreter;
  Future<Interpreter>? _loadingInterpreter;
  bool _disposed = false;
  int _inputWidth = 0;
  int _inputHeight = 0;
  TensorType? _inputType;
  TensorType? _outputType;
  int _classCount = 0;

  Future<TflitePrediction> predict(XFile image) async {
    if (_disposed) {
      throw StateError('Model service has already been disposed.');
    }

    final interpreter = await _ensureInterpreter();
    final encodedImage = await image.readAsBytes();
    final decodedImage = img.decodeImage(encodedImage);

    if (decodedImage == null) {
      throw const FormatException('The captured image could not be decoded.');
    }

    final rgbBytes = prepareInput(
      decodedImage,
      width: _inputWidth,
      height: _inputHeight,
    );

    final output = _runInference(interpreter, rgbBytes);
    final probabilities = normalizeScores(output);
    var bestIndex = 0;
    var bestProbability = probabilities.first;

    for (var index = 1; index < probabilities.length; index++) {
      if (probabilities[index] > bestProbability) {
        bestIndex = index;
        bestProbability = probabilities[index];
      }
    }

    return TflitePrediction(
      value: labels[bestIndex],
      confidence: bestProbability.clamp(0.0, 1.0),
    );
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

  static Uint8List prepareInput(
    img.Image source, {
    required int width,
    required int height,
  }) {
    if (width <= 0 || height <= 0 || width != height) {
      throw ArgumentError('Model input dimensions must be equal and positive.');
    }

    final oriented = img.bakeOrientation(source);
    final resized = img.copyResizeCropSquare(
      oriented,
      size: width,
      interpolation: img.Interpolation.linear,
    );

    return resized.getBytes(order: img.ChannelOrder.rgb);
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
