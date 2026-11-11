import 'package:camera/camera.dart';

sealed class ScannerEvent {
  const ScannerEvent();
}

final class ScanRequested extends ScannerEvent {
  const ScanRequested(this.image);

  final XFile image;
}

final class ScanReset extends ScannerEvent {
  const ScanReset();
}
