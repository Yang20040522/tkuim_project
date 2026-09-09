import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 治療師播放後端串流影片的畫面；本機影片仍由 VideoPlaybackScreen 處理。
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
      controller.addListener(_refreshControls);
      setState(() => _controller = controller);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() => _errorMessage = '影片載入失敗，請確認網路或存取權限');
      }
    }
  }

  void _refreshControls() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_refreshControls);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Center(
        child: _errorMessage != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
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
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VideoProgressIndicator(
                              controller,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            IconButton(
                              icon: Icon(
                                controller.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 36,
                              ),
                              onPressed: () {
                                controller.value.isPlaying
                                    ? controller.pause()
                                    : controller.play();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
