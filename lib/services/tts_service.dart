import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService({FlutterTts? flutterTts}) : _tts = flutterTts ?? FlutterTts();

  final FlutterTts _tts;

  bool _initialized = false;
  bool _turkishAvailable = false;
  String? _errorMessage;

  bool get turkishAvailable => _turkishAvailable;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      final availability = await _tts.isLanguageAvailable('tr-TR');
      _turkishAvailable = availability == true || availability == 1;

      if (_turkishAvailable) {
        await _tts.setLanguage('tr-TR');
        await _tts.setSpeechRate(0.45);
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
      } else {
        _errorMessage = 'Cihazınızda Türkçe seslendirme bulunamadı.';
      }
    } catch (_) {
      _errorMessage = 'Seslendirme başlatılamadı.';
    } finally {
      _initialized = true;
    }
  }

  Future<void> speak(String text) async {
    final content = text.trim();
    if (content.isEmpty || !_turkishAvailable) {
      return;
    }

    try {
      await _tts.stop();
      await _tts.speak(content);
    } catch (_) {
      _errorMessage = 'Seslendirme sırasında bir hata oluştu.';
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Sessizce yok sayılır; durdurma hatası taramayı engellememeli.
    }
  }
}
