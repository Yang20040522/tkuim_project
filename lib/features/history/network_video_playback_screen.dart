import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/ui/tv_ui.dart';

/// Authenticated HTTP Range playback for training-history videos on Android TV.
class NetworkVideoPlaybackScreen extends StatefulWidget {
  const NetworkVideoPlaybackScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    this.httpHeaders = const {},
  });

  final String videoUrl;
  final String title;
  final Map<String, String> httpHeaders;

  @override
  State<NetworkVideoPlaybackScreen> createState() =>
      _NetworkVideoPlaybackScreenState();
}

class _NetworkVideoPlaybackScreenState
    extends State<NetworkVideoPlaybackScreen> {
  VideoPlayerController? _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      httpHeaders: widget.httpHeaders,
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_refresh);
      setState(() => _controller = controller);
      await controller.play();
    } on Object {
      await controller.dispose();
      if (mounted) {
        setState(() => _errorMessage = '影片載入失敗，請確認網路或存取權限');
      }
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _seek(Duration offset) async {
    final controller = _controller;
    if (controller == null) return;
    final duration = controller.value.duration;
    final next = controller.value.position + offset;
    final bounded = next < Duration.zero
        ? Duration.zero
        : next > duration
            ? duration
            : next;
    await controller.seekTo(bounded);
  }

  @override
  void dispose() {
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return TvRemoteScope(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.title),
        ),
        body: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _seek(const Duration(seconds: -10));
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _seek(const Duration(seconds: 10));
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter) {
              _togglePlayback();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Center(
            child: _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 24),
                    ),
                  )
                : controller == null || !controller.value.isInitialized
                    ? const CircularProgressIndicator(color: Colors.white)
                    : AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            VideoPlayer(controller),
                            Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '← / → 快轉 10 秒',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(width: 24),
                                  TvTap(
                                    autofocus: true,
                                    onTap: _togglePlayback,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 12,
                                      ),
                                      child: Icon(
                                        controller.value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: Colors.white,
                                        size: 42,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}
