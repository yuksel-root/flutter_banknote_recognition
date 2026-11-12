import 'dart:typed_data';

enum FrameFormat { yuv420, bgra8888 }

class FramePlane {
  const FramePlane({
    required this.bytes,
    required this.bytesPerRow,
    required this.pixelStride,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int pixelStride;
}

class VideoFrame {
  const VideoFrame({
    required this.width,
    required this.height,
    required this.planes,
    required this.format,
    required this.rotationDegrees,
  });

  final int width;
  final int height;
  final List<FramePlane> planes;
  final FrameFormat format;
  final int rotationDegrees;
}
