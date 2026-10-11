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

  static bool containsMalayalam(String text) => text.runes.any(
        (rune) => rune >= 0x0d00 && rune <= 0x0d7f,
      );

  /// Selects a platform locale while accepting common `ml`, `ml_IN`, and
  /// regional variants exposed by different speech engines.
  static String selectAvailableLocale(
    Iterable<String> available,
    String preferred, {
    String? fallback,
  }) {
    final values = available.where((value) => value.trim().isNotEmpty).toList();
    if (values.isEmpty) return fallback ?? preferred;
    final candidates = _localeCandidates(preferred);
    for (final candidate in candidates) {
      final exact = values.cast<String?>().firstWhere(
        (value) => _normaliseLocale(value!) == _normaliseLocale(candidate),
        orElse: () => null,
      );
      if (exact != null) return exact;
      final language = _normaliseLocale(candidate).split('-').first;
      final family = values.cast<String?>().firstWhere(
        (value) => _normaliseLocale(value!).split('-').first == language,
        orElse: () => null,
      );
      if (family != null) return family;
    }
    return fallback ?? preferred;
  }

  /// Malayalam script in an otherwise English reply gets a Malayalam-capable
  /// voice when one is installed; English-only replies retain the preference.
  static String localeForSpeechText(
    String text, {
    required String preferred,
    required Iterable<String> available,
    String? fallback,
  }) => selectAvailableLocale(
        available,
        containsMalayalam(text) ? 'ml-IN' : preferred,
        fallback: fallback,
      );

  static List<String> _localeCandidates(String preferred) {
    final normalised = _normaliseLocale(preferred);
    final candidates = <String>[preferred];
    if (normalised.startsWith('ml')) candidates.add('ml-IN');
    if (normalised.startsWith('en')) candidates.add('en-IN');
    candidates.addAll(['ml-IN', 'en-IN', 'en-US']);
    return candidates.toSet().toList();
  }

  static String _normaliseLocale(String value) => value.trim().toLowerCase().replaceAll('_', '-');
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
  List<String> _ttsLanguages = const [];
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
      _recognitionLanguage = VoicePolicy.selectAvailableLocale(
        available.map((locale) => locale.localeId),
        _language,
      );
    } catch (_) {
      _recognitionLanguage = _language;
    }
  }

  Future<void> _selectAvailableTtsLanguage() async {
    try {
      final available = await _tts.getLanguages;
      _ttsLanguages = available is Iterable
          ? available.map((value) => value.toString()).toList()
          : const [];
      _ttsLanguage = VoicePolicy.selectAvailableLocale(
        _ttsLanguages,
        _language,
      );
    } catch (_) {
      // A platform can support TTS without exposing its language inventory.
      _ttsLanguages = const [];
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
      final speechLanguage = VoicePolicy.localeForSpeechText(
        bounded,
        preferred: _language,
        available: _ttsLanguages,
        fallback: _ttsLanguage,
      );
      await _tts.setLanguage(speechLanguage);
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
        onResult: (result) => onResult(
          VoicePolicy.boundedSpeechText(result.recognizedWords),
          result.finalResult,
        ),
        listenOptions: stt.SpeechListenOptions(localeId: _recognitionLanguage),
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
