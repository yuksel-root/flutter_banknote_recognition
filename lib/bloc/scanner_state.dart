import '../models/banknote_result.dart';

sealed class ScannerState {
  const ScannerState();
}

final class ScannerIdle extends ScannerState {
  const ScannerIdle();
}

final class ScannerProcessing extends ScannerState {
  const ScannerProcessing();
}

final class ScannerResult extends ScannerState {
  const ScannerResult(this.result);

  final BanknoteResult result;
}

final class ScannerError extends ScannerState {
  const ScannerError(this.message);

  final String message;
}
