import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

class CameraService extends ChangeNotifier with WidgetsBindingObserver {
  CameraService() {
    WidgetsBinding.instance.addObserver(this);
  }

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
    _notifyListeners();

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
      _notifyListeners();
    }
  }

  Future<XFile?> takePicture() async {
    final activeController = _controller;
    if (activeController == null || !activeController.value.isInitialized) {
      _errorMessage = 'Kamera hazır değil. Lütfen kamerayı yeniden başlatın.';
      _notifyListeners();
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

    _notifyListeners();
    return null;
  }

  Future<void> retry() async {
    await _disposeCurrentController();
    await initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
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
    _notifyListeners();

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

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    final activeController = _controller;
    _controller = null;
    if (activeController != null) {
      unawaited(activeController.dispose());
    }
    super.dispose();
  }
}
