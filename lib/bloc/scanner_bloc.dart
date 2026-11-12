import 'package:flutter_bloc/flutter_bloc.dart';

import '../repository/banknote_repository.dart';
import '../services/camera_service.dart';
import '../services/tflite_service.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';
import 'stable_frame_tracker.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  ScannerBloc({
    required BanknoteRepository repository,
    required ScannerFrameSource frameSource,
  }) : _repository = repository,
       _frameSource = frameSource,
       super(const ScannerIdle()) {
    on<ScanStarted>(_onScanStarted);
    on<ScanReset>(_onScanReset);
  }

  static const int stableFrameCount = 3;
  static const int maximumConsecutiveFailures = 10;

  final BanknoteRepository _repository;
  final ScannerFrameSource _frameSource;

  Future<void> _onScanStarted(
    ScanStarted event,
    Emitter<ScannerState> emit,
  ) async {
    if (state is! ScannerIdle) {
      return;
    }

    if (!_frameSource.isReady) {
      emit(
        const ScannerError(
          'Kamera hazır değil. Lütfen kamerayı yeniden başlatın.',
        ),
      );
      return;
    }

    final tracker = StableFrameTracker(
      requiredFrames: stableFrameCount,
      minimumConfidence: _repository.confidenceThreshold,
    );

    emit(
      ScannerScanning(
        ranked: const <RankedPrediction>[],
        elapsed: Duration.zero,
        matchedFrames: 0,
      ),
    );

    var consecutiveFailures = 0;

    try {
      await _frameSource.startImageStream();

      while (!emit.isDone && state is ScannerScanning) {
        final frame = await _frameSource.nextFrame();
        if (emit.isDone || state is! ScannerScanning) {
          break;
        }

        if (frame == null) {
          emit(
            const ScannerError(
              'Kamera görüntüsü alınamadı. Lütfen tekrar deneyin.',
            ),
          );
          break;
        }

        final LivePrediction prediction;
        try {
          prediction = await _repository.analyzeFrame(frame);
          consecutiveFailures = 0;
        } catch (_) {
          consecutiveFailures += 1;
          if (consecutiveFailures >= maximumConsecutiveFailures) {
            emit(
              const ScannerError(
                'Banknot incelenirken bir hata oluştu. Lütfen tekrar deneyin.',
              ),
            );
            break;
          }
          continue;
        }

        final stable = tracker.add(prediction);
        if (emit.isDone || state is! ScannerScanning) {
          break;
        }

        emit(
          ScannerScanning(
            ranked: prediction.ranked,
            elapsed: prediction.elapsed,
            matchedFrames: tracker.matchedFrames,
          ),
        );

        if (stable == null) {
          continue;
        }

        final result = await _repository.createResult(stable);
        if (emit.isDone || state is! ScannerScanning) {
          break;
        }

        emit(
          ScannerResult(
            result: result,
            ranked: stable.ranked,
            elapsed: stable.elapsed,
          ),
        );
        break;
      }
    } catch (_) {
      if (!emit.isDone && state is ScannerScanning) {
        emit(
          const ScannerError(
            'Kamera görüntüsü başlatılamadı. Lütfen tekrar deneyin.',
          ),
        );
      }
    } finally {
      try {
        await _frameSource.stopImageStream();
      } catch (_) {}
    }
  }

  void _onScanReset(ScanReset event, Emitter<ScannerState> emit) {
    emit(const ScannerIdle());
  }
}
