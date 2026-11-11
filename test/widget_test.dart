import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_banknote_recognition/app.dart';
import 'package:flutter_banknote_recognition/bloc/scanner_bloc.dart';
import 'package:flutter_banknote_recognition/repository/banknote_repository.dart';
import 'package:flutter_banknote_recognition/services/camera_service.dart';
import 'package:flutter_banknote_recognition/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBanknoteRepository extends BanknoteRepository {
  _FakeBanknoteRepository(SharedPreferences preferences)
    : super(preferences: preferences);
}

void main() {
  testWidgets('scanner screen shows the base guidance', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cameraService = CameraService();
    final ttsService = TtsService();
    final scannerBloc = ScannerBloc(
      repository: _FakeBanknoteRepository(preferences),
    );

    addTearDown(() async {
      await scannerBloc.close();
      cameraService.dispose();
    });

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<TtsService>.value(value: ttsService),
          RepositoryProvider<CameraService>.value(value: cameraService),
        ],
        child: BlocProvider<ScannerBloc>.value(
          value: scannerBloc,
          child: const BanknoteApp(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Banknot Tanıma'), findsOneWidget);
    expect(find.text('Banknotu hazırlayın'), findsOneWidget);
    expect(find.text('Kamera başlatılıyor...'), findsOneWidget);
    expect(find.text('Tara'), findsOneWidget);
    expect(find.text('Türkçe seslendirme kullanılamıyor.'), findsOneWidget);

    final scanButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Tara'),
    );
    expect(scanButton.onPressed, isNull);
  });
}
