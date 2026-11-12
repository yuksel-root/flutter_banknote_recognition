import 'dart:convert';
import 'dart:io';

import 'package:flutter_banknote_recognition/services/tflite_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('security features exist for every model class', () async {
    final rawJson = await File('assets/security_features.json').readAsString();
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;

    for (final label in TfliteService.labels) {
      final value = '$label TL';
      final features = decoded[value];
      expect(features, isA<List<dynamic>>(), reason: '$value is missing');
      expect(
        (features as List<dynamic>),
        isNotEmpty,
        reason: '$value is empty',
      );
      expect(features.every((feature) => feature is String), isTrue);
    }
  });
}
