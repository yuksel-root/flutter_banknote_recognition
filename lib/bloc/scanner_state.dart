import '../models/banknote_result.dart';
import '../services/tflite_service.dart';

sealed class ScannerState {
  const ScannerState();
}

final class ScannerIdle extends ScannerState {
  const ScannerIdle();
}

final class ScannerScanning extends ScannerState {
  const ScannerScanning({
    required this.ranked,
    required this.elapsed,
    required this.matchedFrames,
  });

  final List<RankedPrediction> ranked;
  final Duration elapsed;
  final int matchedFrames;
}

final class ScannerResult extends ScannerState {
  const ScannerResult({
    required this.result,
    required this.ranked,
    required this.elapsed,
  });

  final BanknoteResult result;
  final List<RankedPrediction> ranked;
  final Duration elapsed;
}

final class ScannerError extends ScannerState {
  const ScannerError(this.message);

  final String message;
}
