import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_banknote_recognition/models/video_frame.dart';
import 'package:flutter_banknote_recognition/repository/banknote_repository.dart';
import 'package:flutter_banknote_recognition/services/tflite_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTfliteService extends TfliteService {
  _FakeTfliteService(this.prediction);

  final LivePrediction prediction;

  @override
  Future<LivePrediction> predictFrame(VideoFrame frame) async => prediction;
}

class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this.json);

  final String json;

  @override
  Future<ByteData> load(String key) async {
    if (key != BanknoteRepository.securityFeaturesAsset) {
      throw FlutterError('Unexpected asset: $key');
    }

    final bytes = Uint8List.fromList(utf8.encode(json));
    return ByteData.sublistView(bytes);
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
    elapsed: const Duration(milliseconds: 96),
  );
}

VideoFrame frame() {
  return VideoFrame(
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
}

void main() {
  Future<SharedPreferences> createPreferences(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('analyzeFrame returns the service prediction', () async {
    final preferences = await createPreferences({});
    final livePrediction = prediction('100 TL', 0.8);
    final repository = BanknoteRepository(
      preferences: preferences,
      tfliteService: _FakeTfliteService(livePrediction),
      assetBundle: _FakeAssetBundle('{}'),
    );

    final result = await repository.analyzeFrame(frame());

    expect(result, same(livePrediction));
  });

  test('createResult maps the best prediction and security features', () async {
    final preferences = await createPreferences({});
    final repository = BanknoteRepository(
      preferences: preferences,
      tfliteService: _FakeTfliteService(prediction('100 TL', 0.8)),
      assetBundle: _FakeAssetBundle(
        jsonEncode({
          '100 TL': ['Filigranı kontrol edin.', 'Emniyet şeridine bakın.'],
        }),
      ),
    );

    final result = await repository.createResult(prediction('100 TL', 0.8));

    expect(result.value, '100 TL');
    expect(result.confidence, 0.8);
    expect(result.securityFeatures, [
      'Filigranı kontrol edin.',
      'Emniyet şeridine bakın.',
    ]);
  });

  test('returns an empty list when features are missing', () async {
    final preferences = await createPreferences({});
    final repository = BanknoteRepository(
      preferences: preferences,
      tfliteService: _FakeTfliteService(prediction('200 TL', 0.75)),
      assetBundle: _FakeAssetBundle(
        jsonEncode({
          '100 TL': ['Test'],
        }),
      ),
    );

    final result = await repository.createResult(prediction('200 TL', 0.75));

    expect(result.value, '200 TL');
    expect(result.securityFeatures, isEmpty);
  });

  test('uses the stored confidence threshold', () async {
    final preferences = await createPreferences({
      BanknoteRepository.confidenceThresholdKey: 0.82,
    });
    final repository = BanknoteRepository(
      preferences: preferences,
      tfliteService: _FakeTfliteService(prediction('50 TL', 0.9)),
      assetBundle: _FakeAssetBundle('{}'),
    );

    expect(repository.confidenceThreshold, 0.82);
  });

  test('uses the default confidence threshold', () async {
    final preferences = await createPreferences({});
    final repository = BanknoteRepository(
      preferences: preferences,
      tfliteService: _FakeTfliteService(prediction('50 TL', 0.9)),
      assetBundle: _FakeAssetBundle('{}'),
    );

    expect(repository.confidenceThreshold, 0.7);
  });
}
