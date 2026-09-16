import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// A per-training-session gate. Pose prompts play only when their text changes.
class TrainingVoiceGate {
  static String selectedHand({required bool isLeft}) =>
      '已選擇${isLeft ? '左' : '右'}手，請將手自然放下';

  static String selectedLeg({required bool isLeft}) =>
      '已選擇${isLeft ? '左' : '右'}腳為訓練腳';

  static String selectedMode(String mode, String initialHint) =>
      '已選擇$mode。$initialHint';

  static String autoLevel(String level) => '已自動升級至$level，請繼續訓練';

  TrainingVoiceGate({
    required Future<void> Function(String, {bool important}) speak,
    required Future<void> Function() stop,
    DateTime Function()? now,
  })  : _speak = speak,
        _stop = stop,
        _now = now ?? DateTime.now;

  final Future<void> Function(String, {bool important}) _speak;
  final Future<void> Function() _stop;
  final DateTime Function() _now;
  final Map<String, DateTime> _recent = {};
  String? _currentPrompt;
  bool _active = true;
  bool _disposed = false;
  bool _finished = false;
  int _generation = 0;

  void prompt(String text) {
    final value = text.trim();
    if (!_active || _disposed || value.isEmpty || value == _currentPrompt) {
      return;
    }
    _currentPrompt = value;
    event(value);
  }

  void event(String text, {bool important = false}) {
    final value = text.trim();
    if (!_active || _disposed || value.isEmpty) return;
    final now = _now();
    final previous = _recent[value];
    if (previous != null &&
        now.difference(previous) < const Duration(seconds: 2)) {
      return;
    }
    _recent[value] = now;
    final generation = _generation;
    // Never wait on the platform channel in the pose callback.
    Future<void>(() async {
      if (_disposed || !_active || generation != _generation) return;
      await _speak(value, important: important);
    }).catchError((Object error, StackTrace stack) {
      debugPrint('[TrainingVoiceGate] speak failed: $error\n$stack');
    });
  }

  Future<void> pause() async {
    _active = false;
    _generation++;
    try {
      await _stop();
    } catch (error) {
      debugPrint('[TrainingVoiceGate] stop on pause failed: $error');
    }
  }

  void resume() {
    if (_disposed) return;
    _active = true;
    _currentPrompt = null;
  }

  Future<void> finish() async {
    if (_disposed || _finished) return;
    _finished = true;
    _active = false;
    _generation++;
    final generation = _generation;
    try {
      await _stop();
    } catch (error) {
      debugPrint('[TrainingVoiceGate] stop on finish failed: $error');
    }
    if (!_disposed && generation == _generation) {
      try {
        await _speak('訓練完成', important: true);
      } catch (error) {
        debugPrint('[TrainingVoiceGate] completion speech failed: $error');
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    _generation++;
    try {
      await _stop();
    } catch (error) {
      debugPrint('[TrainingVoiceGate] stop on dispose failed: $error');
    }
  }
}

/// Shared app TTS output; no second native TTS instance is created.
class VoiceService {
  static final FlutterTts _tts = FlutterTts();
  static Future<void>? _initializing;
  static bool _ready = false;
  static bool _speaking = false;
  static String? _pendingNormal;
  static int _suppressPendingDrain = 0;
  static Future<void>? _stopping;
  static String _lastSpoken = '';
  static DateTime _lastSpeakTime = DateTime.fromMillisecondsSinceEpoch(0);
  static int _stopGeneration = 0;

  static const _skipKeywords = ['已向外轉', '已向內轉', '已張開', '捏緊完成'];

  static Future<void> init() {
    if (_ready) return Future<void>.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  static Future<void> _initialize() async {
    try {
      try {
        _tts.setCompletionHandler(_onSpeechEnded);
        _tts.setCancelHandler(_onSpeechEnded);
        _tts.setErrorHandler((message) {
          debugPrint('[VoiceService] TTS engine error: $message');
          _onSpeechEnded();
        });
      } catch (error, stack) {
        debugPrint('[VoiceService] TTS handlers unavailable: $error\n$stack');
      }
      await _configureLanguage();
      try {
        await _tts.setSpeechRate(0.5);
        await _tts.setVolume(1.0);
        await _tts.setPitch(1.0);
      } catch (error, stack) {
        debugPrint('[VoiceService] TTS settings unavailable: $error\n$stack');
      }
      // A device with no Chinese voice can still use its system default.
      _ready = true;
    } catch (error, stack) {
      debugPrint('[VoiceService] TTS initialization failed: $error\n$stack');
      _ready = true; // Native TTS may still speak with system defaults.
    }
  }

  static Future<void> _configureLanguage() async {
    final candidates = <String>['zh-TW'];
    List<dynamic> voices = const [];
    try {
      final available = await _tts.getLanguages;
      if (available is List) {
        for (final language in available) {
          final locale = language.toString();
          if (_isChinese(locale) && !candidates.contains(locale)) {
            candidates.add(locale);
          }
        }
      } else {
        debugPrint('[VoiceService] getLanguages returned no language list');
      }
    } catch (error, stack) {
      debugPrint('[VoiceService] getLanguages failed: $error\n$stack');
    }
    try {
      final available = await _tts.getVoices;
      if (available is List) {
        voices = available;
      } else {
        debugPrint('[VoiceService] getVoices returned no voice list');
      }
    } catch (error, stack) {
      debugPrint('[VoiceService] getVoices failed: $error\n$stack');
    }
    for (final voice in voices.whereType<Map>()) {
      final locale = voice['locale']?.toString();
      if (locale != null &&
          _isChinese(locale) &&
          !candidates.contains(locale)) {
        candidates.add(locale);
      }
    }

    String? selected;
    for (final locale in candidates) {
      try {
        final result = await _tts.setLanguage(locale);
        if (result == false || result == 0) {
          debugPrint('[VoiceService] TTS language unavailable: $locale');
          continue;
        }
        selected = locale;
        break;
      } catch (error, stack) {
        debugPrint(
            '[VoiceService] setLanguage($locale) failed: $error\n$stack');
      }
    }
    if (selected == null) {
      debugPrint(
          '[VoiceService] No Chinese TTS language; using system default');
      return;
    }
    final matches = voices
        .whereType<Map>()
        .where(
          (voice) =>
              voice['locale']?.toString().toLowerCase() ==
              selected!.toLowerCase(),
        )
        .toList();
    if (matches.isNotEmpty) {
      matches.sort((a, b) => _voiceScore(b).compareTo(_voiceScore(a)));
      final best = matches.first;
      try {
        final result = await _tts.setVoice({
          'name': best['name'].toString(),
          'locale': best['locale'].toString(),
        });
        if (result == false || result == 0) {
          debugPrint(
              '[VoiceService] setVoice rejected; using $selected default');
        }
      } catch (error, stack) {
        debugPrint(
            '[VoiceService] setVoice failed; using $selected default: $error\n$stack');
      }
    }
    debugPrint('[VoiceService] TTS language: $selected');
  }

  static bool _isChinese(String locale) {
    final lower = locale.toLowerCase();
    return lower.startsWith('zh') || lower.startsWith('cmn');
  }

  static int _voiceScore(Map voice) {
    final quality = voice['quality']?.toString().toLowerCase() ?? '';
    final name = voice['name']?.toString().toLowerCase() ?? '';
    var score = 0;
    if (quality.contains('very high')) score += 100;
    if (quality == 'high') score += 60;
    if (name.contains('neural') ||
        name.contains('wavenet') ||
        name.contains('network')) {
      score += 80;
    }
    if (name.contains('female') || name.contains('女')) score += 20;
    return score;
  }

  static void _onSpeechEnded() {
    _speaking = false;
    if (_suppressPendingDrain > 0) return;
    final pending = _pendingNormal;
    _pendingNormal = null;
    if (pending != null) {
      Future<void>(() => speak(pending));
    }
  }

  static Future<void> speak(String text, {bool important = false}) async {
    final generation = _stopGeneration;
    await init();
    await _stopping;
    if (generation != _stopGeneration || text.trim().isEmpty) return;
    if (_skipKeywords.any(text.contains)) return;
    final clean = _stripEmoji(text);
    if (clean.isEmpty) return;
    final now = DateTime.now();
    if (clean == _lastSpoken &&
        now.difference(_lastSpeakTime) < const Duration(seconds: 2)) {
      return;
    }
    final priority = important || _isImportant(clean);
    if (_speaking && !priority) {
      _pendingNormal =
          clean; // Replace old hints; never queue stale pose frames.
      return;
    }
    if (priority && _speaking) {
      _pendingNormal = null;
      _suppressPendingDrain++;
      try {
        await _tts.stop();
      } catch (error) {
        debugPrint('[VoiceService] interrupt failed: $error');
      } finally {
        _suppressPendingDrain--;
      }
      if (generation != _stopGeneration) return;
    }
    _lastSpoken = clean;
    _lastSpeakTime = now;
    _speaking = true;
    try {
      await _tts.speak(clean);
    } catch (error, stack) {
      debugPrint('[VoiceService] speak failed: $error\n$stack');
      _onSpeechEnded();
    }
  }

  static Future<void> stop() async {
    _stopGeneration++;
    _pendingNormal = null;
    _suppressPendingDrain++;
    _onSpeechEnded();
    final previous = _stopping;
    final stopping = () async {
      await previous;
      await _stopNative();
    }();
    _stopping = stopping;
    await stopping;
    if (identical(_stopping, stopping)) _stopping = null;
    _suppressPendingDrain--;
  }

  static Future<void> _stopNative() async {
    try {
      await _tts.stop();
    } catch (error, stack) {
      debugPrint('[VoiceService] stop failed: $error\n$stack');
    }
  }

  static bool _isImportant(String text) {
    const keywords = ['完成', '捏緊了', '訓練結束', '太快', '歪', '通過', '開始翻掌', '解鎖', '難度'];
    return keywords.any(text.contains);
  }

  static String _stripEmoji(String text) =>
      text.replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z0-9,。!?、\s]'), '').trim();
}
