import 'package:camera/camera.dart';
import 'package:flutter_banknote_recognition/bloc/scanner_bloc.dart';
import 'package:flutter_banknote_recognition/bloc/scanner_event.dart';
import 'package:flutter_banknote_recognition/bloc/scanner_state.dart';
import 'package:flutter_banknote_recognition/models/banknote_result.dart';
import 'package:flutter_banknote_recognition/repository/banknote_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBanknoteRepository extends BanknoteRepository {
  _FakeBanknoteRepository(SharedPreferences preferences, this.result)
    : super(preferences: preferences);

  final BanknoteResult? result;

  @override
  Future<BanknoteResult?> recognize(XFile image) async => result;
}

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  const result = BanknoteResult(
    value: '100 TL',
    confidence: 0.92,
    securityFeatures: ['Test özelliği'],
  );

  test('başarılı taramada işleniyor ve sonuç durumlarını yayınlar', () async {
    final bloc = ScannerBloc(
      repository: _FakeBanknoteRepository(preferences, result),
    );
    final states = <ScannerState>[];
    final subscription = bloc.stream.listen(states.add);

    bloc.add(ScanRequested(XFile('test.jpg')));
    await bloc.stream.firstWhere((state) => state is ScannerResult);

    expect(states.first, isA<ScannerProcessing>());
    expect(states.last, isA<ScannerResult>());
    expect((states.last as ScannerResult).result.value, '100 TL');

    await subscription.cancel();
    await bloc.close();
  });

  test('banknot okunamazsa hata durumu yayınlar', () async {
    final bloc = ScannerBloc(
      repository: _FakeBanknoteRepository(preferences, null),
    );

    bloc.add(ScanRequested(XFile('test.jpg')));
    final state = await bloc.stream.firstWhere(
      (state) => state is ScannerError,
    );

    expect((state as ScannerError).message, contains('Banknot okunamadı'));

    await bloc.close();
  });
}
