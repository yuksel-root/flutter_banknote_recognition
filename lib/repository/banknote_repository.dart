import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/banknote_result.dart';
import '../models/video_frame.dart';
import '../services/tflite_service.dart';

class BanknoteRepository {
  BanknoteRepository({
    required SharedPreferences preferences,
    TfliteService? tfliteService,
    AssetBundle? assetBundle,
  }) : _preferences = preferences,
       _tfliteService = tfliteService ?? TfliteService(),
       _assetBundle = assetBundle ?? rootBundle;

  static const String confidenceThresholdKey = 'confidence_threshold';
  static const double defaultConfidenceThreshold = 0.7;
  static const String securityFeaturesAsset = 'assets/security_features.json';

  final SharedPreferences _preferences;
  final TfliteService _tfliteService;
  final AssetBundle _assetBundle;

  Future<Map<String, List<String>>>? _securityFeatures;

  Future<LivePrediction> analyzeFrame(VideoFrame frame) {
    return _tfliteService.predictFrame(frame);
  }

  Future<BanknoteResult> createResult(LivePrediction prediction) async {
    final securityFeatures = await _loadSecurityFeatures();
    final best = prediction.best;
    final features = securityFeatures[best.value] ?? const <String>[];

    return BanknoteResult(
      value: best.value,
      confidence: best.confidence,
      securityFeatures: List<String>.unmodifiable(features),
    );
  }

  double get confidenceThreshold => _confidenceThreshold;

  double get _confidenceThreshold {
    final stored = _preferences.get(confidenceThresholdKey);
    if (stored is! num) {
      return defaultConfidenceThreshold;
    }

    final value = stored.toDouble();
    if (!value.isFinite) {
      return defaultConfidenceThreshold;
    }

    return value.clamp(0.0, 1.0).toDouble();
  }

  Future<Map<String, List<String>>> _loadSecurityFeatures() {
    return _securityFeatures ??= _readSecurityFeatures();
  }

  Future<Map<String, List<String>>> _readSecurityFeatures() async {
    final rawJson = await _assetBundle.loadString(securityFeaturesAsset);
    final decoded = jsonDecode(rawJson);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid security features asset.');
    }

    final result = <String, List<String>>{};

    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! List || value.any((feature) => feature is! String)) {
        throw const FormatException('Invalid security features asset.');
      }

      result[entry.key] = List<String>.unmodifiable(value.cast<String>());
    }

    return Map<String, List<String>>.unmodifiable(result);
  }
}
