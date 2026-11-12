import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';
import '../models/banknote_result.dart';
import '../services/camera_service.dart';
import '../services/tflite_service.dart';
import '../services/tts_service.dart';
import 'app_colors.dart';
import 'widgets/camera_preview.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScannerBloc, ScannerState>(
      listenWhen: (previous, current) => previous != current,
      listener: _handleStateChange,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A1118),
                  AppColors.background,
                  Color(0xFF090E13),
                ],
              ),
            ),
            child: SafeArea(
              child: _AutoStartScan(
                child: Column(
                  children: [
                    const _AppHeader(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isLandscape =
                              constraints.maxWidth > constraints.maxHeight;

                          if (isLandscape) {
                            return const Row(
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: ScannerCameraPreview(),
                                ),
                                Expanded(flex: 5, child: _ControlsPanel()),
                              ],
                            );
                          }

                          return const Column(
                            children: [
                              Expanded(flex: 11, child: ScannerCameraPreview()),
                              Expanded(flex: 9, child: _ControlsPanel()),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
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

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 18, 8),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFE29A), AppColors.primaryDeep],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3DFFD166),
                  blurRadius: 20,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.payments_outlined,
              size: 25,
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Banknot Tanıma',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Çevrimdışı • Sesli sonuç',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x1263E6D5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x3363E6D5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 12,
                  color: AppColors.secondary,
                ),
                SizedBox(width: 4),
                Text(
                  'YEREL',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    final ttsService = context.read<TtsService>();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.panel, Color(0xFF0B1219)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.borderStrong)),
        boxShadow: [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PanelHandle(),
            if (!ttsService.turkishAvailable) ...[
              _TtsWarning(
                message:
                    ttsService.errorMessage ??
                    'Türkçe seslendirme kullanılamıyor.',
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: BlocBuilder<ScannerBloc, ScannerState>(
                  builder: (context, state) => _ScanStatus(state: state),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _ScanActionButton(),
          ],
        ),
      ),
    );
  }
}

class _PanelHandle extends StatelessWidget {
  const _PanelHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: AppColors.borderStrong,
          borderRadius: BorderRadius.circular(4),
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0x1FFFB74D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x40FFB74D)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x2EFFB74D),
              ),
              child: const Icon(
                Icons.volume_off_rounded,
                color: Color(0xFFFFB74D),
                size: 17,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  color: AppColors.textPrimary,
                ),
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
        ScannerScanning(:final ranked, :final elapsed, :final matchedFrames) =>
          _ScanningStatus(
            ranked: ranked,
            elapsed: elapsed,
            matchedFrames: matchedFrames,
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
          icon: Icons.center_focus_strong_rounded,
          title: 'Banknotu kameraya gösterin',
        ),
        SizedBox(height: 8),
        Text(
          'Tarama otomatik olarak başlar. Banknot değeri canlı olarak analiz '
          'edilir ve sonuç Türkçe seslendirilir.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _FeatureChip(icon: Icons.wifi_off_rounded, label: 'Çevrimdışı'),
            _FeatureChip(icon: Icons.bolt_rounded, label: '5 FPS'),
            _FeatureChip(icon: Icons.volume_up_rounded, label: 'Sesli sonuç'),
          ],
        ),
        SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: AppColors.textFaint,
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Yalnızca değer tahmini yapılır; gerçeklik kontrolü yapılmaz.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColors.textFaint,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.panelRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.secondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanningStatus extends StatelessWidget {
  const _ScanningStatus({
    required this.ranked,
    required this.elapsed,
    required this.matchedFrames,
  });

  final List<RankedPrediction> ranked;
  final Duration elapsed;
  final int matchedFrames;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusHeading(
          icon: Icons.graphic_eq_rounded,
          title: 'Canlı analiz',
          trailing: _MatchIndicator(matchedFrames: matchedFrames),
        ),
        const SizedBox(height: 9),
        if (ranked.isEmpty)
          const _WaitingForFrame()
        else
          _PredictionList(ranked: ranked),
        const SizedBox(height: 7),
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
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'İlk kare bekleniyor...',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
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
          Padding(
            padding: EdgeInsets.only(
              bottom: index == ranked.length - 1 ? 0 : 4,
            ),
            child: _PredictionRow(rank: index + 1, prediction: ranked[index]),
          ),
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
    final isTop = rank == 1;
    final accent = isTop ? AppColors.primary : AppColors.secondary;
    final percentage = (prediction.confidence * 100).toStringAsFixed(2);

    return Semantics(
      label: '$rank. ${prediction.value}, yüzde $percentage',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: isTop ? const Color(0xFF201C10) : AppColors.panelRaised,
              ),
            ),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: prediction.confidence.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent.withAlpha(58), accent.withAlpha(12)],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isTop
                          ? AppColors.primary
                          : const Color(0xFF22303D),
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isTop
                            ? AppColors.onPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prediction.value,
                      style: TextStyle(
                        fontSize: isTop ? 16 : 15,
                        fontWeight: isTop ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: -0.1,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '%$percentage',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isTop ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchIndicator extends StatelessWidget {
  const _MatchIndicator({required this.matchedFrames});

  final int matchedFrames;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Kare doğrulaması $matchedFrames bölü 3',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < 3; index++)
            Container(
              width: 12,
              height: 4,
              margin: EdgeInsets.only(left: index == 0 ? 0 : 3),
              decoration: BoxDecoration(
                color: index < matchedFrames
                    ? AppColors.secondary
                    : AppColors.borderStrong,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          const SizedBox(width: 6),
          Text(
            '$matchedFrames/3',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
              color: AppColors.textFaint,
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
        const Icon(Icons.timer_outlined, size: 14, color: AppColors.textFaint),
        const SizedBox(width: 5),
        const Text(
          'Geçen süre',
          style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
        ),
        const SizedBox(width: 5),
        Text(
          '$seconds s',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
            color: AppColors.textMuted,
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
    final confidence = (result.confidence * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StatusHeading(
          icon: Icons.verified_rounded,
          title: 'Banknot tanındı',
        ),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF211D10), Color(0xFF141B22)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x40FFD166)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1FFFD166),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TAHMİN EDİLEN DEĞER',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.textFaint,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      result.value,
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        height: 1,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x14FFD166),
                  border: Border.all(color: const Color(0x4DFFD166)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '%$confidence',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'güven',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: AppColors.textFaint,
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Yalnızca değer tahmini yapılır; gerçeklik kontrolü yapılmaz.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColors.textFaint,
                ),
              ),
            ),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StatusHeading(
          icon: Icons.error_outline_rounded,
          title: 'Tarama tamamlanamadı',
          color: AppColors.error,
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppColors.errorSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x33FF8A80)),
          ),
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 14,
              color: AppColors.textFaint,
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Banknotu kameraya sabit tutun, ışığın yeterli olduğundan emin '
                'olun ve yeniden deneyin.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColors.textFaint,
                ),
              ),
            ),
          ],
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
    final accent = color ?? AppColors.primary;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withAlpha(46)),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.25,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ),
        ?trailing,
      ],
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

            return SizedBox(
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cameraReady ? null : const Color(0xFF1A242F),
                  gradient: cameraReady
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFE29A), AppColors.primaryDeep],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: cameraReady
                      ? const [
                          BoxShadow(
                            color: Color(0x3DFFD166),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: AppColors.onPrimary,
                    disabledForegroundColor: AppColors.textFaint,
                    minimumSize: const Size.fromHeight(54),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: !cameraReady
                      ? null
                      : () {
                          unawaited(HapticFeedback.selectionClick());
                          final scannerBloc = context.read<ScannerBloc>();
                          if (isRetry) {
                            scannerBloc.add(const ScanReset());
                          }
                          scannerBloc.add(const ScanStarted());
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isRetry
                            ? Icons.refresh_rounded
                            : Icons.play_arrow_rounded,
                        size: 21,
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: Text(label, textAlign: TextAlign.center)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
