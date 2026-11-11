import 'dart:convert';
import 'dart:io';

import 'package:flutter_banknote_recognition/services/tflite_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('her model sınıfı için güvenlik özellikleri tanımlıdır', () async {
    final rawJson = await File('assets/security_features.json').readAsString();
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;

    for (final label in TfliteService.labels) {
      final features = decoded[label];
      expect(features, isA<List<dynamic>>(), reason: '$label eksik');
      expect((features as List<dynamic>), isNotEmpty, reason: '$label boş');
      expect(features.every((feature) => feature is String), isTrue);
    }
  });
}
