import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';
import '../models/banknote_result.dart';
import '../services/camera_service.dart';
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;

              if (isLandscape) {
                return Row(
                  children: [
                    const Expanded(flex: 3, child: ScannerCameraPreview()),
                    Expanded(flex: 2, child: _ControlsPanel()),
                  ],
                );
              }

              return Column(
                children: [
                  const Expanded(flex: 5, child: ScannerCameraPreview()),
                  Expanded(flex: 4, child: _ControlsPanel()),
                ],
              );
            },
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
      case ScannerProcessing():
        unawaited(
          ttsService.speak(
            'Banknot inceleniyor. Lütfen banknotu sabit tutun ve bekleyin.',
          ),
        );
      case ScannerResult(:final result):
        unawaited(ttsService.speak(_resultSpeech(result)));
      case ScannerError(:final message):
        unawaited(ttsService.speak(message));
    }
  }

  String _resultSpeech(BanknoteResult result) {
    final confidence = (result.confidence * 100).round();
    final buffer = StringBuffer()
      ..write('Tahmini banknot değeri: ${_spokenValue(result.value)}. ')
      ..write('Güven oranı: yüzde $confidence. ')
      ..write(
        'Güvenlik özelliklerini kontrol etmek için şu adımları izleyin. ',
      );

    for (final feature in result.securityFeatures) {
      buffer
        ..write(feature)
        ..write(' ');
    }

    buffer.write(
      'Bu uygulama banknotun gerçek mi sahte mi olduğuna karar vermez. '
      'Yalnızca değer tahmini ve güvenlik özelliği rehberliği sunar.',
    );

    return buffer.toString();
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

class _ControlsPanel extends StatelessWidget {
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
                  builder: (context, state) {
                    return _ScanStatus(state: state);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _ScanButton(),
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
        ScannerProcessing() => const _ProcessingStatus(),
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
        _StatusHeading(icon: Icons.info_outline, title: 'Banknotu hazırlayın'),
        SizedBox(height: 12),
        Text(
          'Banknotu kameranın önündeki çerçeveye yerleştirin. '
          'Hazır olduğunuzda Tara düğmesine dokunun.',
          style: TextStyle(fontSize: 19, height: 1.5),
        ),
        SizedBox(height: 16),
        Text(
          'Uygulama çevrimdışı çalışır. Banknotun değerini tahmin eder ve '
          'güvenlik özelliklerini sesli olarak anlatır. Gerçek veya sahte '
          'olduğuna karar vermez.',
          style: TextStyle(fontSize: 16, color: Color(0xFFBDBDBD), height: 1.4),
        ),
      ],
    );
  }
}

class _ProcessingStatus extends StatelessWidget {
  const _ProcessingStatus();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusHeading(icon: Icons.search, title: 'Banknot inceleniyor'),
        SizedBox(height: 16),
        LinearProgressIndicator(minHeight: 8),
        SizedBox(height: 16),
        Text(
          'Lütfen banknotu sabit tutun. İşlem birkaç saniye sürebilir.',
          style: TextStyle(fontSize: 19, height: 1.5),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tahmini banknot değeri',
          style: TextStyle(fontSize: 18, color: Color(0xFFBDBDBD)),
        ),
        const SizedBox(height: 4),
        Text(
          result.value,
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Güven oranı: %$confidence',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const Divider(height: 28),
        const Text(
          'Güvenlik özellikleri',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (final feature in result.securityFeatures)
          _SecurityFeature(text: feature),
        const SizedBox(height: 12),
        const _SafetyNotice(),
      ],
    );
  }
}

class _SecurityFeature extends StatelessWidget {
  const _SecurityFeature({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 24,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 17, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF263238),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 24, color: Color(0xFF80CBC4)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bu uygulama banknotun gerçek veya sahte olduğuna karar vermez. '
              'Yalnızca değer tahmini ve güvenlik özelliği rehberliği sunar.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
          ),
        ],
      ),
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
          'Banknotu düz bir zemine koyup ışığın yeterli olduğundan emin olun '
          've yeniden Tara düğmesine dokunun.',
          style: TextStyle(fontSize: 17, color: Color(0xFFBDBDBD), height: 1.4),
        ),
      ],
    );
  }
}

class _StatusHeading extends StatelessWidget {
  const _StatusHeading({required this.icon, required this.title, this.color});

  final IconData icon;
  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 30,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton();

  @override
  Widget build(BuildContext context) {
    final cameraService = context.read<CameraService>();

    return BlocBuilder<ScannerBloc, ScannerState>(
      builder: (context, state) {
        return ValueListenableBuilder<CameraServiceState>(
          valueListenable: cameraService.state,
          builder: (context, cameraState, _) {
            final isProcessing = state is ScannerProcessing;
            final cameraReady = cameraState.isReady;
            final canScan = cameraReady && !isProcessing;
            final label = isProcessing ? 'Taranıyor...' : 'Tara';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: canScan
                      ? () => unawaited(_captureAndScan(context))
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isProcessing) ...[
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFFBDBDBD),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ] else ...[
                        const Icon(Icons.camera_alt, size: 32),
                        const SizedBox(width: 12),
                      ],
                      Flexible(child: Text(label, textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                if (isProcessing)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton(
                      onPressed: () {
                        context.read<ScannerBloc>().add(const ScanReset());
                      },
                      child: const Text(
                        'Taramayı İptal Et',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _captureAndScan(BuildContext context) async {
    final cameraService = context.read<CameraService>();
    final ttsService = context.read<TtsService>();
    final scannerBloc = context.read<ScannerBloc>();

    final images = await cameraService.takePictureBurst();
    if (images.isEmpty) {
      final message =
          cameraService.errorMessage ??
          'Fotoğraf çekilemedi. Lütfen kamerayı yeniden başlatın.';
      unawaited(ttsService.speak(message));
      return;
    }

    scannerBloc.add(ScanRequested(images));
  }
}
