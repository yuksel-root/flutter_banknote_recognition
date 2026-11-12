import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';
import '../models/banknote_result.dart';
import '../services/camera_service.dart';
import '../services/tflite_service.dart';
import '../services/tts_service.dart';
import 'widgets/camera_preview.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScannerBloc, ScannerState>(
      listenWhen: (previous, current) => previous != current,
      listener: _handleStateChange,
      child: Scaffold(
        appBar: AppBar(title: const Text('Banknot Tanıma')),
        body: SafeArea(
          child: _AutoStartScan(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape =
                    constraints.maxWidth > constraints.maxHeight;

                if (isLandscape) {
                  return const Row(
                    children: [
                      Expanded(flex: 3, child: ScannerCameraPreview()),
                      Expanded(flex: 2, child: _ControlsPanel()),
                    ],
                  );
                }

                return const Column(
                  children: [
                    Expanded(flex: 4, child: ScannerCameraPreview()),
                    Expanded(flex: 5, child: _ControlsPanel()),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _handleStateChange(BuildContext context, ScannerState state) {
    final ttsService = context.read<TtsService>();

    switch (state) {
      case ScannerIdle():
        unawaited(ttsService.stop());
      case ScannerScanning():
        break;
      case ScannerResult(:final result):
        unawaited(ttsService.speak(_spokenValue(result.value)));
      case ScannerError(:final message):
        unawaited(ttsService.speak(message));
    }
  }

  String _spokenValue(String value) {
    return switch (value) {
      '5 TL' => 'beş Türk lirası',
      '10 TL' => 'on Türk lirası',
      '20 TL' => 'yirmi Türk lirası',
      '50 TL' => 'elli Türk lirası',
      '100 TL' => 'yüz Türk lirası',
      '200 TL' => 'iki yüz Türk lirası',
      _ => value.replaceAll('TL', 'Türk lirası'),
    };
  }
}

class _AutoStartScan extends StatelessWidget {
  const _AutoStartScan({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cameraService = context.read<CameraService>();
    final scannerBloc = context.read<ScannerBloc>();

    return ValueListenableBuilder<CameraServiceState>(
      valueListenable: cameraService.state,
      builder: (context, cameraState, child) {
        if (cameraState.isReady && scannerBloc.state is ScannerIdle) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) {
              return;
            }
            if (cameraService.state.value.isReady &&
                scannerBloc.state is ScannerIdle) {
              scannerBloc.add(const ScanStarted());
            }
          });
        }

        return child!;
      },
      child: child,
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ttsService = context.read<TtsService>();

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!ttsService.turkishAvailable) ...[
              _TtsWarning(
                message:
                    ttsService.errorMessage ??
                    'Türkçe seslendirme kullanılamıyor.',
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: BlocBuilder<ScannerBloc, ScannerState>(
                  builder: (context, state) => _ScanStatus(state: state),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _ScanActionButton(),
          ],
        ),
      ),
    );
  }
}

class _TtsWarning extends StatelessWidget {
  const _TtsWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF4E342E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFB74D), width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.volume_off, color: Color(0xFFFFB74D), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 17, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanStatus extends StatelessWidget {
  const _ScanStatus({required this.state});

  final ScannerState state;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: switch (state) {
        ScannerIdle() => const _IdleStatus(),
        ScannerScanning(:final ranked, :final elapsed) => _ScanningStatus(
          ranked: ranked,
          elapsed: elapsed,
        ),
        ScannerResult(:final result) => _ResultStatus(result: result),
        ScannerError(:final message) => _ErrorStatus(message: message),
      },
    );
  }
}

class _IdleStatus extends StatelessWidget {
  const _IdleStatus();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusHeading(
          icon: Icons.center_focus_strong,
          title: 'Banknotu kameraya gösterin',
        ),
        SizedBox(height: 12),
        Text(
          'Tarama otomatik olarak başlar. Uygulama çevrimdışı çalışır, '
          'banknot değerini canlı olarak analiz eder ve sonucu sesli söyler.',
          style: TextStyle(fontSize: 19, height: 1.5),
        ),
        SizedBox(height: 16),
        Text(
          'Uygulama banknotun gerçek veya sahte olduğuna karar vermez. '
          'Yalnızca değer tahmini yapar.',
          style: TextStyle(fontSize: 16, color: Color(0xFFBDBDBD), height: 1.4),
        ),
      ],
    );
  }
}

class _ScanningStatus extends StatelessWidget {
  const _ScanningStatus({required this.ranked, required this.elapsed});

  final List<RankedPrediction> ranked;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StatusHeading(
          icon: Icons.graphic_eq,
          title: 'Canlı analiz',
          trailing: _FpsBadge(),
        ),
        const SizedBox(height: 12),
        if (ranked.isEmpty)
          const _WaitingForFrame()
        else
          _PredictionList(ranked: ranked),
        const SizedBox(height: 10),
        _ElapsedRow(elapsed: elapsed),
      ],
    );
  }
}

class _WaitingForFrame extends StatelessWidget {
  const _WaitingForFrame();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'İlk kare bekleniyor...',
            style: TextStyle(fontSize: 17, color: Color(0xFFBDBDBD)),
          ),
        ),
      ],
    );
  }
}

class _PredictionList extends StatelessWidget {
  const _PredictionList({required this.ranked});

  final List<RankedPrediction> ranked;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < ranked.length; index++)
          _PredictionRow(rank: index + 1, prediction: ranked[index]),
      ],
    );
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow({required this.rank, required this.prediction});

  final int rank;
  final RankedPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (prediction.confidence * 100).toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF263238),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank:',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              prediction.value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '(%$percentage)',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB0BEC5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ElapsedRow extends StatelessWidget {
  const _ElapsedRow({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final seconds = (elapsed.inMicroseconds / 1000000).toStringAsFixed(5);

    return Row(
      children: [
        const Expanded(
          child: Text(
            'Geçen süre',
            style: TextStyle(fontSize: 16, color: Color(0xFFBDBDBD)),
          ),
        ),
        Text(
          '$seconds s',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB0BEC5),
          ),
        ),
      ],
    );
  }
}

class _ResultStatus extends StatelessWidget {
  const _ResultStatus({required this.result});

  final BanknoteResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidence = (result.confidence * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StatusHeading(
          icon: Icons.check_circle_outline,
          title: 'Banknot tanındı',
        ),
        const SizedBox(height: 8),
        Text(
          result.value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 58,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          'Güven oranı: %$confidence',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        const Text(
          'Bu uygulama banknotun gerçek veya sahte olduğuna karar vermez.',
          style: TextStyle(fontSize: 15, color: Color(0xFFBDBDBD), height: 1.4),
        ),
      ],
    );
  }
}

class _ErrorStatus extends StatelessWidget {
  const _ErrorStatus({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusHeading(
          icon: Icons.error_outline,
          title: 'Tarama tamamlanamadı',
          color: colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(fontSize: 19, height: 1.5)),
        const SizedBox(height: 12),
        const Text(
          'Banknotu kameraya sabit tutup ışığın yeterli olduğundan emin olun '
          've yeniden deneyin.',
          style: TextStyle(fontSize: 17, color: Color(0xFFBDBDBD), height: 1.4),
        ),
      ],
    );
  }
}

class _StatusHeading extends StatelessWidget {
  const _StatusHeading({
    required this.icon,
    required this.title,
    this.color,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 28,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _FpsBadge extends StatelessWidget {
  const _FpsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 16, color: Color(0xFFA5D6A7)),
          SizedBox(width: 4),
          Text(
            '5 FPS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFA5D6A7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanActionButton extends StatelessWidget {
  const _ScanActionButton();

  @override
  Widget build(BuildContext context) {
    final cameraService = context.read<CameraService>();

    return BlocBuilder<ScannerBloc, ScannerState>(
      builder: (context, state) {
        return ValueListenableBuilder<CameraServiceState>(
          valueListenable: cameraService.state,
          builder: (context, cameraState, _) {
            final isScanning = state is ScannerScanning;
            final cameraReady = cameraState.isReady;
            final isRetry = state is ScannerResult || state is ScannerError;
            final label = isRetry ? 'Yeniden Tara' : 'Taramayı Başlat';

            if (isScanning) {
              return const SizedBox.shrink();
            }

            return ElevatedButton(
              onPressed: !cameraReady
                  ? null
                  : () {
                      final scannerBloc = context.read<ScannerBloc>();
                      if (isRetry) {
                        scannerBloc.add(const ScanReset());
                      }
                      scannerBloc.add(const ScanStarted());
                    },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isRetry ? Icons.refresh : Icons.play_arrow, size: 30),
                  const SizedBox(width: 10),
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
