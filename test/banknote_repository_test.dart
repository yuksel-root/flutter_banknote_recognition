import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_banknote_recognition/repository/banknote_repository.dart';
import 'package:flutter_banknote_recognition/services/tflite_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTfliteService extends TfliteService {
  _FakeTfliteService(this.prediction);

  final TflitePrediction prediction;

  @override
  Future<TflitePrediction> predict(XFile image) async => prediction;
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

void main() {
  Future<SharedPreferences> createPreferences(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('güven eşiğinin altındaki sonucu reddeder', () async {
    final preferences = await createPreferences({
      BanknoteRepository.confidenceThresholdKey: 0.8,
    });
    final repository = BanknoteRepository(
      preferences: preferences,
      tfliteService: _FakeTfliteService(
        const TflitePrediction(value: '100 TL', confidence: 0.79),
      ),
      assetBundle: _FakeAssetBundle('{}'),
    );

    final result = await repository.recognize(XFile('test.jpg'));

    expect(result, isNull);
  });

  test(
    'eşiğe eşit sonucu kabul eder ve güvenlik özelliklerini eşler',
    () async {
      final preferences = await createPreferences({
        BanknoteRepository.confidenceThresholdKey: 0.8,
      });
      final repository = BanknoteRepository(
        preferences: preferences,
        tfliteService: _FakeTfliteService(
          const TflitePrediction(value: '100 TL', confidence: 0.8),
        ),
        assetBundle: _FakeAssetBundle(
          jsonEncode({
            '100 TL': ['Filigranı kontrol edin.', 'Emniyet şeridine bakın.'],
          }),
        ),
      );

      final result = await repository.recognize(XFile('test.jpg'));

      expect(result, isNotNull);
      expect(result!.value, '100 TL');
      expect(result.confidence, 0.8);
      expect(result.securityFeatures, [
        'Filigranı kontrol edin.',
        'Emniyet şeridine bakın.',
      ]);
    },
  );

  test('varsayılan eşik değerini kullanır', () async {
    final preferences = await createPreferences({});
    final repository = BanknoteRepository(
      preferences: preferences,
      tfliteService: _FakeTfliteService(
        const TflitePrediction(value: '50 TL', confidence: 0.69),
      ),
      assetBundle: _FakeAssetBundle('{}'),
    );

    final result = await repository.recognize(XFile('test.jpg'));

    expect(BanknoteRepository.defaultConfidenceThreshold, 0.7);
    expect(result, isNull);
  });

  test('özellik bulunamazsa boş liste döndürür', () async {
    final preferences = await createPreferences({});
    final repository = BanknoteRepository(
      preferences: preferences,
      tfliteService: _FakeTfliteService(
        const TflitePrediction(value: '200 TL', confidence: 0.75),
      ),
      assetBundle: _FakeAssetBundle(
        jsonEncode({
          '100 TL': ['Test'],
        }),
      ),
    );

    final result = await repository.recognize(XFile('test.jpg'));

    expect(result, isNotNull);
    expect(result!.value, '200 TL');
    expect(result.securityFeatures, isEmpty);
  });
}
