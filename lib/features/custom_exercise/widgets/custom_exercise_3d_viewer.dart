import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../models/joint_definition.dart';
import '../../../models/joint_rotation.dart';
import '../../../models/joint_type.dart';

class CustomExercise3dViewer extends StatefulWidget {
  final JointType selectedJoint;
  final Map<JointType, JointRotation> jointRotations;

  const CustomExercise3dViewer({
    super.key,
    required this.selectedJoint,
    required this.jointRotations,
  });

  @override
  State<CustomExercise3dViewer> createState() => _CustomExercise3dViewerState();
}

class _CustomExercise3dViewerState extends State<CustomExercise3dViewer> {
  InAppWebViewController? _webController;
  bool _viewerReady = false;
  String _status = '正在載入人體模型…';
  String? _restQuaternion;

  @override
  void didUpdateWidget(covariant CustomExercise3dViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedJoint != widget.selectedJoint ||
        !mapEquals(oldWidget.jointRotations, widget.jointRotations)) {
      _sendPose();
    }
  }

  Future<void> _sendPose() async {
    if (!_viewerReady || _webController == null) return;
    final payload = jsonEncode({
      'selectedJoint': widget.selectedJoint.name,
      'rotations': {
        for (final entry in widget.jointRotations.entries)
          entry.key.name: entry.value.toJson(),
      },
    });
    await _webController!.evaluateJavascript(
      source: 'window.setEditorPose($payload);',
    );
  }

  void _onViewerReady(List<dynamic> arguments) {
    final payload = arguments.isNotEmpty && arguments.first is Map
        ? Map<String, dynamic>.from(arguments.first as Map)
        : const <String, dynamic>{};
    final rest = payload['restQuaternion'];
    if (!mounted) return;
    setState(() {
      _viewerReady = true;
      _status = '已連接 ${payload['controllableBoneCount'] ?? 0} 個主要關節';
      if (rest is Map) {
        final values = Map<String, dynamic>.from(rest);
        _restQuaternion =
            'rest q: ${_short(values['x'])}, ${_short(values['y'])}, '
            '${_short(values['z'])}, ${_short(values['w'])}';
      } else {
        _restQuaternion = '各關節 rest quaternion 已保存 · local XYZ';
      }
    });
    _sendPose();
  }

  String _short(dynamic value) {
    return value is num ? value.toStringAsFixed(3) : '?';
  }

  void _onViewerError(List<dynamic> arguments) {
    final payload = arguments.isNotEmpty && arguments.first is Map
        ? Map<String, dynamic>.from(arguments.first as Map)
        : const <String, dynamic>{};
    if (!mounted) return;
    setState(() => _status = payload['message']?.toString() ?? '3D 模型載入失敗');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: InAppWebViewPlatform.instance == null
                ? const _WebViewUnavailablePlaceholder()
                : InAppWebView(
                    key: const Key('custom-exercise-3d-webview'),
                    initialFile: 'assets/custom_exercise_viewer/index.html',
                    initialSettings: InAppWebViewSettings(
                      allowFileAccessFromFileURLs: true,
                      allowUniversalAccessFromFileURLs: true,
                      javaScriptEnabled: true,
                      transparentBackground: true,
                    ),
                    onWebViewCreated: (controller) {
                      _webController = controller;
                      controller.addJavaScriptHandler(
                        handlerName: 'EditorViewerReady',
                        callback: (arguments) {
                          _onViewerReady(arguments);
                          return null;
                        },
                      );
                      controller.addJavaScriptHandler(
                        handlerName: 'EditorViewerError',
                        callback: (arguments) {
                          _onViewerError(arguments);
                          return null;
                        },
                      );
                    },
                    onReceivedError: (controller, request, error) {
                      if (mounted) {
                        setState(
                            () => _status = 'Viewer 載入失敗：${error.description}');
                      }
                    },
                    onConsoleMessage: (controller, message) {
                      if (kDebugMode) {
                        debugPrint('[CustomExerciseViewer] ${message.message}');
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
      color: const Color(0xFF24283B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _viewerReady ? Icons.check_circle : Icons.view_in_ar,
                color: _viewerReady
                    ? const Color(0xFF34D399)
                    : const Color(0xFF93C5FD),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _viewerReady
                      ? '$_status · ${JointDefinitions.of(widget.selectedJoint).displayName}'
                      : _status,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          if (_restQuaternion != null) ...[
            const SizedBox(height: 4),
            Text(
              _restQuaternion!,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _WebViewUnavailablePlaceholder extends StatelessWidget {
  const _WebViewUnavailablePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '此測試環境未提供 WebView',
        style: TextStyle(color: Color(0xFF9CA3AF)),
      ),
    );
  }
}
