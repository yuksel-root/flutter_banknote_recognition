import 'package:camera/camera.dart';

sealed class ScannerEvent {
  const ScannerEvent();
}

final class ScanRequested extends ScannerEvent {
  const ScanRequested(this.images);

  final List<XFile> images;
}

final class ScanReset extends ScannerEvent {
  const ScanReset();
}
