// lib/features/demo/standard_analysis_screen.dart
//
// ══════════════════════════════════════════════════════════════════
//  動作標準分析
//
//  用途:分析治療師示範影片,產生「標準動作角度序列」模板
//  現況:畫面殼子先搭好,實際影片逐幀分析邏輯之後再接
// ══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class StandardAnalysisScreen extends StatefulWidget {
  const StandardAnalysisScreen({super.key});

  @override
  State<StandardAnalysisScreen> createState() =>
      _StandardAnalysisScreenState();
}

class _StandardAnalysisScreenState extends State<StandardAnalysisScreen> {
  String? _selectedVideoPath;
  bool _isAnalyzing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('動作標準分析'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '從治療師示範影片,分析出標準動作角度',
              style: TextStyle(
                color: Color(0xFF1A1D2E),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '選擇一支示範影片,AI 會逐幀分析骨架角度,建立動作標準模板',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 24),

            // ── 選影片區塊 ──
            GestureDetector(
              onTap: _isAnalyzing ? null : _pickVideo,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFDDE0F0),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedVideoPath == null
                          ? Icons.video_call_outlined
                          : Icons.check_circle,
                      color: _selectedVideoPath == null
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF4CAF50),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedVideoPath == null
                          ? '點擊選擇治療師示範影片'
                          : '已選擇影片,準備分析',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── 分析按鈕 ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _selectedVideoPath == null || _isAnalyzing
                    ? null
                    : _startAnalysis,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A65FF),
                  disabledBackgroundColor: const Color(0xFFEDEFF7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isAnalyzing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        '開始分析',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // ── 提示區塊(功能尚未完整實作) ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB74D)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.construction, color: Color(0xFFF57C00), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '此功能開發中:目前僅完成畫面框架,\n影片逐幀骨架分析邏輯尚未接入。',
                      style: TextStyle(
                        color: Color(0xFFE65100),
                        fontSize: 12,
                        height: 1.4,
                      ),
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

  void _pickVideo() {
    // TODO: 接入 file_picker 或 image_picker 選影片
    setState(() {
      _selectedVideoPath = 'placeholder_video.mp4';
    });
  }

  void _startAnalysis() {
    // TODO: 接入影片逐幀截圖 + 骨架偵測邏輯
    setState(() => _isAnalyzing = true);

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('分析邏輯尚未實作,敬請期待')),
      );
    });
  }
}