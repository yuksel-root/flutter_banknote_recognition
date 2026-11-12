import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/camera_service.dart';
import '../app_colors.dart';

class ScannerCameraPreview extends StatelessWidget {
  const ScannerCameraPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final cameraService = context.read<CameraService>();

    return ValueListenableBuilder<CameraServiceState>(
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

        return Stack(
          fit: StackFit.expand,
          children: [
            const _CameraBackdrop(),
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppColors.borderStrong),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 28,
                          offset: Offset(0, 14),
                        ),
                        BoxShadow(
                          color: Color(0x26FFD166),
                          blurRadius: 36,
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: AspectRatio(
                        aspectRatio: aspectRatio,
                        child: camera.CameraPreview(controller),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(top: 12, left: 18, child: _LiveChip()),
            const Positioned(top: 12, right: 18, child: _FpsChip()),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 72,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.background.withAlpha(0),
                        AppColors.backgroundRaised.withAlpha(210),
                        AppColors.panel,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CameraBackdrop extends StatelessWidget {
  const _CameraBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B141D),
                AppColors.background,
                Color(0xFF0A1016),
              ],
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x24FFD166), Color(0x00FFD166)],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x1A63E6D5), Color(0x0063E6D5)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return _CameraChip(
      color: AppColors.secondary,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(color: AppColors.secondary),
          SizedBox(width: 6),
          Text(
            'CANLI',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FpsChip extends StatelessWidget {
  const _FpsChip();

  @override
  Widget build(BuildContext context) {
    return _CameraChip(
      color: AppColors.primary,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 13, color: AppColors.primary),
          SizedBox(width: 3),
          Text(
            '5 FPS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraChip extends StatelessWidget {
  const _CameraChip({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background.withAlpha(210),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: child,
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withAlpha(120), blurRadius: 6)],
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _CameraBackdrop(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(
                        width: 76,
                        height: 76,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x1FFFD166),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Kamera başlatılıyor...',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Görüntü işleme hazırlanıyor',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _CameraBackdrop(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.errorSurface,
                    ),
                    child: const Icon(
                      Icons.no_photography_outlined,
                      size: 34,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Kamerayı Yeniden Başlat'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
