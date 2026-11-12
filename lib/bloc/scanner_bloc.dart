import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/banknote_result.dart';
import '../repository/banknote_repository.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  ScannerBloc({required BanknoteRepository repository})
    : _repository = repository,
      super(const ScannerIdle()) {
    on<ScanRequested>(_onScanRequested);
    on<ScanReset>(_onScanReset);
  }

  static const int minimumStableFrames = 2;

  final BanknoteRepository _repository;

  Future<void> _onScanRequested(
    ScanRequested event,
    Emitter<ScannerState> emit,
  ) async {
    if (state is ScannerProcessing) {
      return;
    }

    emit(const ScannerProcessing());

    final results = <BanknoteResult>[];
    var hadError = false;

    for (final image in event.images) {
      try {
        final result = await _repository.recognize(
          image,
          applyThreshold: false,
        );
        if (result != null) {
          results.add(result);
        }
      } catch (_) {
        hadError = true;
      }

      if (emit.isDone || state is! ScannerProcessing) {
        return;
      }
    }

    if (results.isEmpty) {
      emit(
        ScannerError(
          hadError
              ? 'Banknot incelenirken bir hata oluştu. Lütfen tekrar deneyin.'
              : 'Banknot okunamadı. Lütfen banknotu düz bir zemine koyup tekrar deneyin.',
        ),
      );
      return;
    }

    final counts = <String, int>{};
    for (final result in results) {
      counts[result.value] = (counts[result.value] ?? 0) + 1;
    }

    String? stableValue;
    var stableCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > stableCount) {
        stableValue = entry.key;
        stableCount = entry.value;
      }
    }

    if (stableCount < minimumStableFrames ||
        results.length < minimumStableFrames) {
      emit(
        const ScannerError(
          'Banknot yeterince net okunamadı. Lütfen banknotu sabit tutup tekrar deneyin.',
        ),
      );
      return;
    }

    final stableResult = results
        .where((result) => result.value == stableValue)
        .reduce(
          (best, result) => result.confidence > best.confidence ? result : best,
        );

    if (stableResult.confidence < _repository.confidenceThreshold) {
      emit(
        const ScannerError(
          'Banknot yeterince net okunamadı. Lütfen banknotu sabit tutup tekrar deneyin.',
        ),
      );
      return;
    }

    emit(ScannerResult(stableResult));
  }

  void _onScanReset(ScanReset event, Emitter<ScannerState> emit) {
    emit(const ScannerIdle());
  }
}
