sealed class ScannerEvent {
  const ScannerEvent();
}

final class ScanStarted extends ScannerEvent {
  const ScanStarted();
}

final class ScanReset extends ScannerEvent {
  const ScanReset();
}
