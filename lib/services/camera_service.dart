import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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

class CameraService {
  CameraService() {
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

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

  CameraController? get controller => _controller;
  bool get isInitializing => _isInitializing;
  bool get isReady => _controller?.value.isInitialized ?? false;
  String? get errorMessage => _errorMessage;

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

  Future<XFile?> takePicture() async {
    final activeController = _controller;
    if (activeController == null || !activeController.value.isInitialized) {
      _errorMessage = 'Kamera hazır değil. Lütfen kamerayı yeniden başlatın.';
      _publish();
      return null;
    }

    if (activeController.value.isTakingPicture) {
      return null;
    }

    try {
      return await activeController.takePicture();
    } on CameraException catch (error) {
      _errorMessage = _cameraErrorMessage(error);
    } catch (_) {
      _errorMessage = 'Fotoğraf çekilemedi. Lütfen tekrar deneyin.';
    }

    _publish();
    return null;
  }

  Future<List<XFile>> takePictureBurst({
    int count = 3,
    Duration interval = const Duration(milliseconds: 250),
  }) async {
    if (count <= 0) {
      return const <XFile>[];
    }

    final images = <XFile>[];

    for (var index = 0; index < count; index++) {
      final image = await takePicture();
      if (image != null) {
        images.add(image);
      }
      if (index < count - 1) {
        await Future<void>.delayed(interval);
      }
    }

    return images;
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
    final activeController = _controller;
    _controller = null;
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
