import 'package:camera/camera.dart';
import 'package:flutter_banknote_recognition/bloc/scanner_bloc.dart';
import 'package:flutter_banknote_recognition/bloc/scanner_event.dart';
import 'package:flutter_banknote_recognition/bloc/scanner_state.dart';
import 'package:flutter_banknote_recognition/models/banknote_result.dart';
import 'package:flutter_banknote_recognition/repository/banknote_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SequenceBanknoteRepository extends BanknoteRepository {
  _SequenceBanknoteRepository(SharedPreferences preferences, this.results)
    : super(preferences: preferences);

  final List<BanknoteResult?> results;
  int _index = 0;

  @override
  Future<BanknoteResult?> recognize(
    XFile image, {
    bool applyThreshold = true,
  }) async {
    final index = _index;
    _index += 1;
    if (index >= results.length) {
      return null;
    }
    return results[index];
  }
}

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  const result100 = BanknoteResult(
    value: '100 TL',
    confidence: 0.92,
    securityFeatures: ['Test özelliği'],
  );
  const result50 = BanknoteResult(
    value: '50 TL',
    confidence: 0.88,
    securityFeatures: ['Test özelliği'],
  );
  const result200 = BanknoteResult(
    value: '200 TL',
    confidence: 0.84,
    securityFeatures: ['Test özelliği'],
  );

  final images = [XFile('first.jpg'), XFile('second.jpg'), XFile('third.jpg')];

  test('emits processing and result states on a successful scan', () async {
    final bloc = ScannerBloc(
      repository: _SequenceBanknoteRepository(preferences, [
        result100,
        result100,
        result100,
      ]),
    );
    final states = <ScannerState>[];
    final subscription = bloc.stream.listen(states.add);

    bloc.add(ScanRequested(images));
    await bloc.stream.firstWhere((state) => state is ScannerResult);

    expect(states.first, isA<ScannerProcessing>());
    expect(states.last, isA<ScannerResult>());
    expect((states.last as ScannerResult).result.value, '100 TL');

    await subscription.cancel();
    await bloc.close();
  });

  test('accepts a result when two frames agree', () async {
    final bloc = ScannerBloc(
      repository: _SequenceBanknoteRepository(preferences, [
        null,
        result100,
        result100,
      ]),
    );

    bloc.add(ScanRequested(images));
    final state = await bloc.stream.firstWhere(
      (state) => state is ScannerResult,
    );

    expect((state as ScannerResult).result.value, '100 TL');

    await bloc.close();
  });

  test('rejects a stable result below the confidence threshold', () async {
    const lowConfidence100 = BanknoteResult(
      value: '100 TL',
      confidence: 0.5,
      securityFeatures: ['Test özelliği'],
    );
    final bloc = ScannerBloc(
      repository: _SequenceBanknoteRepository(preferences, [
        lowConfidence100,
        lowConfidence100,
        lowConfidence100,
      ]),
    );

    bloc.add(ScanRequested(images));
    final state = await bloc.stream.firstWhere(
      (state) => state is ScannerError,
    );

    expect((state as ScannerError).message, contains('yeterince net'));

    await bloc.close();
  });

  test('rejects a scan when frames disagree', () async {
    final bloc = ScannerBloc(
      repository: _SequenceBanknoteRepository(preferences, [
        result100,
        result50,
        result200,
      ]),
    );

    bloc.add(ScanRequested(images));
    final state = await bloc.stream.firstWhere(
      (state) => state is ScannerError,
    );

    expect((state as ScannerError).message, contains('yeterince net'));

    await bloc.close();
  });

  test('emits an error state when the banknote cannot be read', () async {
    final bloc = ScannerBloc(
      repository: _SequenceBanknoteRepository(preferences, [null, null, null]),
    );

    bloc.add(ScanRequested(images));
    final state = await bloc.stream.firstWhere(
      (state) => state is ScannerError,
    );

    expect((state as ScannerError).message, contains('Banknot okunamadı'));

    await bloc.close();
  });
}
