import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Pure, bounded speech text policy shared by the native voice UI.
class VoicePolicy {
  static const maxSpeechChars = 8000;

  static String boundedSpeechText(String text, {int maxChars = maxSpeechChars}) {
    if (maxChars <= 0) return '';
    final runes = text.runes;
    if (runes.length <= maxChars) return text;
    return String.fromCharCodes(runes.take(maxChars));
  }
}

class VoiceService {
  VoiceService({FlutterTts? tts, stt.SpeechToText? speech})
      : _tts = tts ?? FlutterTts(),
        _speech = speech ?? stt.SpeechToText();

  final FlutterTts _tts;
  final stt.SpeechToText _speech;
  bool _ttsReady = false;
  bool _speechReady = false;
  bool _disposed = false;
  bool _listening = false;
  String _language = 'ml-IN';
  String _ttsLanguage = 'ml-IN';
  String _recognitionLanguage = 'ml-IN';
  double _rate = .5;
  double _volume = 1.0;
  String? _error;

  bool get speechAvailable => _ttsReady;
  bool get recognitionAvailable => _speechReady;
  bool get isListening => _listening;
  String? get error => _error;
  String get language => _language;
  double get rate => _rate;
  double get volume => _volume;

  void clearError() => _error = null;

  Future<void> initialize() async {
    if (_disposed) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _selectAvailableTtsLanguage();
      _ttsReady = true;
    } catch (error) {
      _error = 'Text-to-speech is unavailable on this device: $error';
    }
    try {
      _speechReady = await _speech.initialize(
        onError: (error) => _error = 'Microphone error: ${error.errorMsg}',
        onStatus: (status) => _listening = status == 'listening',
      );
      if (_speechReady) await _selectAvailableRecognitionLanguage();
    } catch (error) {
      _speechReady = false;
      _error = 'Speech recognition is unavailable on this device: $error';
    }
  }

  void configure({String? language, double? rate, double? volume}) {
    _language = language == 'en-IN' ? 'en-IN' : 'ml-IN';
    _ttsLanguage = _language;
    _recognitionLanguage = _language;
    _rate = (rate ?? _rate).clamp(.1, 1.0).toDouble();
    _volume = (volume ?? _volume).clamp(0.0, 1.0).toDouble();
  }

  Future<void> _selectAvailableRecognitionLanguage() async {
    try {
      final available = await _speech.locales();
      final languages = available.map((locale) => locale.localeId.toLowerCase()).toSet();
      final preferred = <String>[
        _language,
        if (_language == 'ml-IN') 'en-IN' else 'ml-IN',
        'en-US',
      ];
      _recognitionLanguage = preferred.firstWhere(
        (candidate) => languages.contains(candidate.toLowerCase()),
        orElse: () => _language,
      );
    } catch (_) {
      _recognitionLanguage = _language;
    }
  }

  Future<void> _selectAvailableTtsLanguage() async {
    try {
      final available = await _tts.getLanguages;
      final languages = available is Iterable
          ? available.map((value) => value.toString().toLowerCase()).toSet()
          : <String>{};
      final preferred = <String>[
        _language,
        if (_language == 'ml-IN') 'en-IN' else 'ml-IN',
        'en-US',
      ];
      _ttsLanguage = preferred.firstWhere(
        (candidate) => languages.isEmpty || languages.contains(candidate.toLowerCase()),
        orElse: () => _language,
      );
    } catch (_) {
      // A platform can support TTS without exposing its language inventory.
      _ttsLanguage = _language;
    }
  }

  Future<void> speak(String text) async {
    if (_disposed) return;
    final bounded = VoicePolicy.boundedSpeechText(text);
    if (bounded.trim().isEmpty) return;
    if (!_ttsReady) {
      _error = 'Text-to-speech is unavailable on this device.';
      return;
    }
    try {
      await _tts.stop();
      await _selectAvailableTtsLanguage();
      await _tts.setLanguage(_ttsLanguage);
      await _tts.setSpeechRate(_rate);
      await _tts.setVolume(_volume);
      await _tts.speak(bounded);
    } catch (error) {
      _error = 'Could not speak this reply: $error';
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    try {
      await _tts.stop();
    } catch (error) {
      _error = 'Could not stop speech: $error';
    }
  }

  Future<void> startListening(void Function(String transcript, bool finalResult) onResult) async {
    if (_disposed) return;
    if (!_speechReady) {
      _error = 'Microphone speech recognition is unsupported or permission was denied.';
      return;
    }
    try {
      await _selectAvailableRecognitionLanguage();
      await _speech.listen(
        onResult: (result) => onResult(result.recognizedWords, result.finalResult),
        localeId: _recognitionLanguage,
      );
      _listening = true;
    } catch (error) {
      _listening = false;
      _error = 'Could not start the microphone: $error';
    }
  }

  Future<void> stopListening() async {
    if (_disposed) return;
    try {
      await _speech.stop();
    } catch (error) {
      _error = 'Could not stop the microphone: $error';
    } finally {
      _listening = false;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _speech.cancel();
      await _tts.stop();
    } catch (_) {
      // Platform channels can already be gone during app shutdown.
    }
  }
}
