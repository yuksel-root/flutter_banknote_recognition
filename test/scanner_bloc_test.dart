import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_banknote_recognition/bloc/scanner_bloc.dart';
import 'package:flutter_banknote_recognition/bloc/scanner_event.dart';
import 'package:flutter_banknote_recognition/bloc/scanner_state.dart';
import 'package:flutter_banknote_recognition/bloc/stable_frame_tracker.dart';
import 'package:flutter_banknote_recognition/models/banknote_result.dart';
import 'package:flutter_banknote_recognition/models/video_frame.dart';
import 'package:flutter_banknote_recognition/repository/banknote_repository.dart';
import 'package:flutter_banknote_recognition/services/camera_service.dart';
import 'package:flutter_banknote_recognition/services/tflite_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBanknoteRepository extends BanknoteRepository {
  _FakeBanknoteRepository(SharedPreferences preferences, this.predictions)
    : super(preferences: preferences);

  final List<LivePrediction> predictions;
  int analyzeCount = 0;

  @override
  double get confidenceThreshold => 0.7;

  @override
  Future<LivePrediction> analyzeFrame(VideoFrame frame) async {
    final prediction = predictions[analyzeCount];
    analyzeCount += 1;
    return prediction;
  }

  @override
  Future<BanknoteResult> createResult(LivePrediction prediction) async {
    return BanknoteResult(
      value: prediction.best.value,
      confidence: prediction.best.confidence,
      securityFeatures: const ['Test özelliği'],
    );
  }
}

class _FakeFrameSource implements ScannerFrameSource {
  _FakeFrameSource({this.ready = true});

  final bool ready;
  final VideoFrame frame = VideoFrame(
    width: 2,
    height: 2,
    format: FrameFormat.yuv420,
    rotationDegrees: 0,
    planes: [
      FramePlane(
        bytes: Uint8List.fromList([16, 16, 16, 16]),
        bytesPerRow: 2,
        pixelStride: 1,
      ),
      FramePlane(
        bytes: Uint8List.fromList([128]),
        bytesPerRow: 1,
        pixelStride: 1,
      ),
      FramePlane(
        bytes: Uint8List.fromList([128]),
        bytesPerRow: 1,
        pixelStride: 1,
      ),
    ],
  );

  final Completer<void> stopped = Completer<void>();
  int startCount = 0;
  bool _active = false;

  @override
  bool get isReady => ready;

  @override
  int get frameRotationDegrees => 0;

  @override
  Future<void> startImageStream() async {
    startCount += 1;
    _active = true;
  }

  @override
  Future<VideoFrame?> nextFrame() async {
    if (!_active) {
      return null;
    }
    return frame;
  }

  @override
  Future<void> stopImageStream() async {
    if (!_active) {
      return;
    }
    _active = false;
    if (!stopped.isCompleted) {
      stopped.complete();
    }
  }
}

LivePrediction prediction(String value, double confidence) {
  return LivePrediction(
    ranked: [
      RankedPrediction(value: value, confidence: confidence),
      const RankedPrediction(value: '50 TL', confidence: 0.1),
      const RankedPrediction(value: '20 TL', confidence: 0.06),
      const RankedPrediction(value: '10 TL', confidence: 0.04),
      const RankedPrediction(value: '5 TL', confidence: 0.02),
    ],
    elapsed: const Duration(milliseconds: 120),
  );
}

void main() {
  group('StableFrameTracker', () {
    test('requires the configured number of matching frames', () {
      final tracker = StableFrameTracker(
        requiredFrames: 3,
        minimumConfidence: 0.7,
      );

      expect(tracker.add(prediction('100 TL', 0.8)), isNull);
      expect(tracker.add(prediction('100 TL', 0.82)), isNull);
      expect(tracker.matchedFrames, 2);

      final stable = tracker.add(prediction('100 TL', 0.81));

      expect(stable, isNotNull);
      expect(stable!.best.value, '100 TL');
      expect(tracker.matchedFrames, 3);
    });

    test('picks the highest confidence frame when the label is stable', () {
      final tracker = StableFrameTracker(
        requiredFrames: 3,
        minimumConfidence: 0.7,
      );

      tracker.add(prediction('100 TL', 0.75));
      tracker.add(prediction('100 TL', 0.95));
      final stable = tracker.add(prediction('100 TL', 0.8));

      expect(stable!.best.confidence, 0.95);
    });

    test('resets when the label changes', () {
      final tracker = StableFrameTracker(
        requiredFrames: 3,
        minimumConfidence: 0.7,
      );

      tracker.add(prediction('100 TL', 0.8));
      expect(tracker.add(prediction('50 TL', 0.8)), isNull);
      expect(tracker.matchedFrames, 1);

      expect(tracker.add(prediction('50 TL', 0.8)), isNull);
      final stable = tracker.add(prediction('50 TL', 0.8));

      expect(stable!.best.value, '50 TL');
    });

    test('resets when confidence is below the threshold', () {
      final tracker = StableFrameTracker(
        requiredFrames: 3,
        minimumConfidence: 0.7,
      );

      tracker.add(prediction('100 TL', 0.8));
      expect(tracker.add(prediction('100 TL', 0.6)), isNull);
      expect(tracker.matchedFrames, 0);

      expect(tracker.add(prediction('100 TL', 0.8)), isNull);
      expect(tracker.matchedFrames, 1);
      expect(tracker.add(prediction('100 TL', 0.8)), isNull);
      final stable = tracker.add(prediction('100 TL', 0.8));

      expect(stable, isNotNull);
    });
  });

  group('ScannerBloc', () {
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
    });

    test('emits live predictions and a result after stable frames', () async {
      final repository = _FakeBanknoteRepository(preferences, [
        prediction('100 TL', 0.8),
        prediction('100 TL', 0.85),
        prediction('100 TL', 0.9),
      ]);
      final frameSource = _FakeFrameSource();
      final bloc = ScannerBloc(
        repository: repository,
        frameSource: frameSource,
      );
      final states = <ScannerState>[];
      final subscription = bloc.stream.listen(states.add);
      final resultFuture = bloc.stream.firstWhere(
        (state) => state is ScannerResult,
      );

      bloc.add(const ScanStarted());
      final state = await resultFuture;
      await frameSource.stopped.future;

      expect(state, isA<ScannerResult>());
      final resultState = state as ScannerResult;
      expect(resultState.result.value, '100 TL');
      expect(resultState.result.confidence, 0.9);
      expect(resultState.ranked.length, 5);
      expect(resultState.elapsed, const Duration(milliseconds: 120));
      expect(repository.analyzeCount, 3);
      expect(frameSource.startCount, 1);
      expect(states.whereType<ScannerScanning>().length, greaterThan(1));

      await subscription.cancel();
      await bloc.close();
    });

    test('emits an error when the camera is not ready', () async {
      final repository = _FakeBanknoteRepository(preferences, const []);
      final frameSource = _FakeFrameSource(ready: false);
      final bloc = ScannerBloc(
        repository: repository,
        frameSource: frameSource,
      );
      final errorFuture = bloc.stream.firstWhere(
        (state) => state is ScannerError,
      );

      bloc.add(const ScanStarted());
      final state = await errorFuture;

      expect((state as ScannerError).message, contains('Kamera hazır değil'));
      expect(frameSource.startCount, 0);

      await bloc.close();
    });
  });
}
