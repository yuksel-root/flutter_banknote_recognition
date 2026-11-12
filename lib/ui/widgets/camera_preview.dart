import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/camera_service.dart';

class ScannerCameraPreview extends StatelessWidget {
  const ScannerCameraPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final cameraService = context.read<CameraService>();

    return ColoredBox(
      color: Colors.black,
      child: ValueListenableBuilder<CameraServiceState>(
        valueListenable: cameraService.state,
        builder: (context, state, _) {
          if (state.errorMessage != null) {
            return _CameraError(
              message: state.errorMessage!,
              onRetry: cameraService.retry,
            );
          }

          final controller = state.controller;
          if (controller == null || !controller.value.isInitialized) {
            return const _CameraLoading();
          }

          final isLandscape =
              MediaQuery.of(context).orientation == Orientation.landscape;
          final aspectRatio = isLandscape
              ? controller.value.aspectRatio
              : 1 / controller.value.aspectRatio;

          return Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  camera.CameraPreview(controller),
                  const IgnorePointer(child: _CameraGuide()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CameraLoading extends StatelessWidget {
  const _CameraLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Kamera başlatılıyor, lütfen bekleyin.',
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Kamera başlatılıyor...',
              style: TextStyle(fontSize: 20, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_photography_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 20, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Kamerayı Yeniden Başlat',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraGuide extends StatelessWidget {
  const _CameraGuide();

  @override
  Widget build(BuildContext context) {
    final guideColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Banknotu çerçeve içine yerleştirin',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          FractionallySizedBox(
            widthFactor: 0.95,
            child: AspectRatio(
              aspectRatio: 2,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: guideColor, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
