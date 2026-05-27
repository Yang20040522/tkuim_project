// lib/services/voice_service.dart
//
// ══════════════════════════════════════════════════════════════════
//  語音主控 — 全 App 唯一的語音出口
//
//  全身、手部兩邊都呼叫這裡。要換語音 / 改語速 / 改規則,只改這個檔。
//
//  功能:
//    1. TTS 設定集中(語速、語言)
//    2. 智慧過濾 — 只念「重要」的話,狀態提示不念(解決吵)
//    3. 防打斷 — 重要的話念完前,不被普通的話插隊(解決念一半)
//    4. 防重複 — 同一句剛念過就跳過
// ══════════════════════════════════════════════════════════════════

import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static String _lastSpoken = '';
  static DateTime _lastSpeakTime = DateTime.now();

  // 「正在念重要句子」的鎖。重要句念完前,普通句不插隊。
  static bool _speakingImportant = false;

  // ── 不該念的字 — 含這些關鍵字就跳過(狀態提示,會吵) ──
  static const List<String> _skipKeywords = [
    '已向外轉',
    '已向內轉',
    '已張開',
    '捏緊完成',
  ];

  // ── 初始化 (App 啟動時呼叫一次即可,重複呼叫也安全) ──
  static Future<void> init() async {
    if (_ready) return;
    await _tts.setLanguage('zh-TW');
    await _tts.setSpeechRate(0.5);   // 語速,適合復健的慢速
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // 重要句念完時,解開鎖
    _tts.setCompletionHandler(() {
      _speakingImportant = false;
    });

    _ready = true;
  }

  // ── 對外:念一句話 ──
  // 畫面層直接把 feedback 丟進來,VoiceService 自己決定要不要念。
  static Future<void> speak(String text) async {
    if (!_ready) await init();
    if (text.isEmpty) return;

    // 過濾 1:含「狀態提示」關鍵字 → 不念
    for (final kw in _skipKeywords) {
      if (text.contains(kw)) return;
    }

    final clean = _stripEmoji(text);
    if (clean.isEmpty) return;

    final now = DateTime.now();

    // 過濾 2:同一句 2 秒內不重複念
    if (clean == _lastSpoken &&
        now.difference(_lastSpeakTime).inSeconds < 2) {
      return;
    }

    // 判斷這句重不重要
    final important = _isImportant(clean);

    // 過濾 3:正在念重要句 → 普通句不插隊(解決念一半)
    if (_speakingImportant && !important) {
      return;
    }

    _lastSpoken = clean;
    _lastSpeakTime = now;

    if (important) {
      _speakingImportant = true;   // 上鎖,念完由 CompletionHandler 解開
      await _tts.stop();           // 重要句可以打斷別人
    }

    await _tts.speak(clean);
  }

  // ── 立刻停止並清狀態 (畫面 dispose 時呼叫) ──
  static Future<void> stop() async {
    _speakingImportant = false;
    await _tts.stop();
  }

  // ── 私有:判斷是不是「重要句」 ──
  static bool _isImportant(String text) {
    const importantKeywords = [
      '完成', '捏緊了', '訓練結束', '太快',
      '歪', '通過', '開始翻掌', '解鎖', '難度',
    ];
    for (final kw in importantKeywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  // ── 私有:濾掉 emoji 跟符號,只留乾淨文字給 TTS 念 ──
  static String _stripEmoji(String text) {
    // 移除常見 emoji / 符號,保留中文、英數、基本標點
    return text
        .replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z0-9，。！？、\s]'), '')
        .trim();
  }
}