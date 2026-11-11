import 'package:flutter_bloc/flutter_bloc.dart';

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

  final BanknoteRepository _repository;

  Future<void> _onScanRequested(
    ScanRequested event,
    Emitter<ScannerState> emit,
  ) async {
    if (state is ScannerProcessing) {
      return;
    }

    emit(const ScannerProcessing());

    try {
      final result = await _repository.recognize(event.image);

      if (emit.isDone || state is! ScannerProcessing) {
        return;
      }

      if (result == null) {
        emit(
          const ScannerError(
            'Banknot okunamadı. Lütfen banknotu düz bir zemine koyup tekrar deneyin.',
          ),
        );
        return;
      }

      emit(ScannerResult(result));
    } catch (_) {
      if (!emit.isDone && state is ScannerProcessing) {
        emit(
          const ScannerError(
            'Banknot incelenirken bir hata oluştu. Lütfen tekrar deneyin.',
          ),
        );
      }
    }
  }

  void _onScanReset(ScanReset event, Emitter<ScannerState> emit) {
    emit(const ScannerIdle());
  }
}
