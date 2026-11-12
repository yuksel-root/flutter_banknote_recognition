import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart';

import '../models/video_frame.dart';

class CameraServiceState {
  const CameraServiceState({
    this.controller,
    this.isInitializing = false,
    this.errorMessage,
  });

  final CameraController? controller;
  final bool isInitializing;
  final String? errorMessage;

  bool get isReady => controller?.value.isInitialized ?? false;
}

abstract interface class ScannerFrameSource {
  bool get isReady;

  int get frameRotationDegrees;

  Future<void> startImageStream();

  Future<VideoFrame?> nextFrame();

  Future<void> stopImageStream();
}

class CameraService implements ScannerFrameSource {
  CameraService() {
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  static const Duration frameInterval = Duration(milliseconds: 200);

  final ValueNotifier<CameraServiceState> _state = ValueNotifier(
    const CameraServiceState(),
  );

  ValueListenable<CameraServiceState> get state => _state;

  late final _CameraLifecycleObserver _lifecycleObserver =
      _CameraLifecycleObserver(this);

  CameraController? _controller;
  Future<void>? _initialization;
  bool _isInitializing = false;
  bool _disposed = false;
  String? _errorMessage;
  Timer? _frameTimer;
  CameraImage? _latestImage;
  Completer<VideoFrame?>? _pendingFrame;
  bool _streaming = false;

  CameraController? get controller => _controller;
  bool get isInitializing => _isInitializing;
  @override
  bool get isReady => _controller?.value.isInitialized ?? false;
  String? get errorMessage => _errorMessage;

  @override
  int get frameRotationDegrees {
    final activeController = _controller;
    if (activeController == null || !activeController.value.isInitialized) {
      return 0;
    }

    final deviceDegrees = switch (activeController.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final sensorDegrees = activeController.description.sensorOrientation;

    if (activeController.description.lensDirection ==
        CameraLensDirection.front) {
      return (sensorDegrees + deviceDegrees) % 360;
    }

    return (sensorDegrees - deviceDegrees + 360) % 360;
  }

  Future<void> initialize() {
    if (_disposed) {
      return Future<void>.value();
    }
    if (isReady) {
      return Future<void>.value();
    }

    return _initialization ??= _initialize().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _initialize() async {
    if (_disposed) {
      return;
    }

    _isInitializing = true;
    _errorMessage = null;
    _publish();

    CameraController? newController;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _errorMessage = 'Bu cihazda kullanılabilir bir kamera bulunamadı.';
        return;
      }

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      newController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await newController.initialize();

      if (_disposed) {
        return;
      }

      await _disposeCurrentController();
      _controller = newController;
      _errorMessage = null;
    } on CameraException catch (error) {
      _errorMessage = _cameraErrorMessage(error);
    } catch (_) {
      _errorMessage = 'Kamera başlatılamadı. Lütfen tekrar deneyin.';
    } finally {
      if (newController != null && !identical(newController, _controller)) {
        await newController.dispose();
      }
      _isInitializing = false;
      _publish();
    }
  }

  @override
  Future<void> startImageStream() async {
    final activeController = _controller;
    if (activeController == null || !activeController.value.isInitialized) {
      _errorMessage = 'Kamera hazır değil. Lütfen kamerayı yeniden başlatın.';
      _publish();
      throw StateError('Camera is not ready.');
    }

    if (_streaming) {
      return;
    }

    _streaming = true;
    _latestImage = null;

    try {
      await activeController.startImageStream(_onImageAvailable);
      _frameTimer = Timer.periodic(frameInterval, _onFrameTick);
    } catch (_) {
      _streaming = false;
      rethrow;
    }
  }

  @override
  Future<VideoFrame?> nextFrame() {
    if (!_streaming) {
      return Future<VideoFrame?>.value();
    }

    final existing = _pendingFrame;
    if (existing != null) {
      return existing.future;
    }

    final completer = Completer<VideoFrame?>();
    _pendingFrame = completer;
    return completer.future;
  }

  @override
  Future<void> stopImageStream() async {
    _frameTimer?.cancel();
    _frameTimer = null;
    _latestImage = null;

    final pending = _pendingFrame;
    _pendingFrame = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(null);
    }

    final activeController = _controller;
    if (!_streaming) {
      return;
    }

    _streaming = false;
    if (activeController != null && activeController.value.isStreamingImages) {
      try {
        await activeController.stopImageStream();
      } on CameraException {
        _errorMessage = 'Kamera görüntüsü durdurulamadı.';
      }
    }
  }

  void _onImageAvailable(CameraImage image) {
    if (!_streaming) {
      return;
    }
    _latestImage = image;
  }

  void _onFrameTick(Timer timer) {
    final image = _latestImage;
    final pending = _pendingFrame;
    if (image == null || pending == null || pending.isCompleted) {
      return;
    }

    _latestImage = null;
    _pendingFrame = null;

    try {
      pending.complete(_toVideoFrame(image));
    } catch (_) {
      pending.complete(null);
    }
  }

  VideoFrame _toVideoFrame(CameraImage image) {
    final format = image.format.group == ImageFormatGroup.bgra8888
        ? FrameFormat.bgra8888
        : FrameFormat.yuv420;

    return VideoFrame(
      width: image.width,
      height: image.height,
      planes: image.planes
          .map(
            (plane) => FramePlane(
              bytes: plane.bytes,
              bytesPerRow: plane.bytesPerRow,
              pixelStride: plane.bytesPerPixel ?? 1,
            ),
          )
          .toList(growable: false),
      format: format,
      rotationDegrees: frameRotationDegrees,
    );
  }

  Future<void> retry() async {
    await _disposeCurrentController();
    await initialize();
  }

  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      if (_controller == null) {
        unawaited(initialize());
      }
    } else {
      unawaited(_disposeCurrentController());
    }
  }

  Future<void> _disposeCurrentController() async {
    await stopImageStream();
    final previousController = _controller;
    _controller = null;
    _publish();

    if (previousController != null) {
      await previousController.dispose();
    }
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Kamera izni verilmedi. Kamera iznini ayarlardan açın.';
      default:
        return 'Kamera başlatılamadı. Lütfen tekrar deneyin.';
    }
  }

  void _publish() {
    if (_disposed) {
      return;
    }

    _state.value = CameraServiceState(
      controller: _controller,
      isInitializing: _isInitializing,
      errorMessage: _errorMessage,
    );
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _frameTimer?.cancel();
    _frameTimer = null;

    final pending = _pendingFrame;
    _pendingFrame = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(null);
    }

    final activeController = _controller;
    _controller = null;
    _streaming = false;
    if (activeController != null) {
      unawaited(activeController.dispose());
    }
  }
}

class _CameraLifecycleObserver with WidgetsBindingObserver {
  _CameraLifecycleObserver(this._cameraService);

  final CameraService _cameraService;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _cameraService.didChangeAppLifecycleState(state);
  }
}
