// lib/features/demo/demo_library_screen.dart
//
// 動作示範庫 — 顯示 3D .glb 模型

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class DemoLibraryScreen extends StatelessWidget {
  const DemoLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE0F0)),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Color(0xFF374151), size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '動作示範庫',
            style: TextStyle(
              color: Color(0xFF1A1D2E),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // 動作名稱卡片
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDDE0F0)),
          ),
          child: const Row(
            children: [
              Text('🖐️', style: TextStyle(fontSize: 22)),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '手腕旋轉示範',
                    style: TextStyle(
                      color: Color(0xFF1A1D2E),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '拖曳旋轉・雙指縮放',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 3D 模型檢視器
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ModelViewer(
                src: 'assets/models/turn_Left_hand.glb',
                alt: '手腕旋轉示範',
                autoRotate: true,
                autoRotateDelay: 1000,
                autoPlay: true,
                cameraControls: true,
                backgroundColor: const Color(0xFF1A1D2E),
              ),
            ),
          ),
        ),
      ],
    );
  }
}