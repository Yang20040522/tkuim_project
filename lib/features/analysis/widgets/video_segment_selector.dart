import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/video_segment.dart';

class VideoSegmentSelector extends StatefulWidget {
  const VideoSegmentSelector({
    super.key,
    required this.videoPath,
    required this.onSegmentChanged,
    this.enabled = true,
  });

  final String videoPath;
  final ValueChanged<VideoSegment> onSegmentChanged;
  final bool enabled;

  @override
  State<VideoSegmentSelector> createState() => _VideoSegmentSelectorState();
}

class _VideoSegmentSelectorState extends State<VideoSegmentSelector> {
  VideoPlayerController? _controller;
  Duration _start = Duration.zero;
  Duration _end = Duration.zero;
  bool _previewing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant VideoSegmentSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _initialize();
    } else if (oldWidget.enabled && !widget.enabled) {
      _previewing = false;
      _controller?.pause();
    }
  }

  Future<void> _initialize() async {
    final previous = _controller;
    if (previous != null) {
      previous.removeListener(_onControllerChanged);
      await previous.dispose();
    }
    if (!mounted) return;
    setState(() {
      _controller = null;
      _start = Duration.zero;
      _end = Duration.zero;
      _previewing = false;
      _error = null;
    });

    final controller = VideoPlayerController.file(File(widget.videoPath));
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onControllerChanged);
      final segment = VideoSegment.whole(controller.value.duration);
      final validationError =
          segment.validationError(controller.value.duration);
      setState(() {
        _controller = controller;
        _end = controller.value.duration;
        _error = validationError;
      });
      if (validationError == null) widget.onSegmentChanged(segment);
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _error = '影片無法播放，請重新選擇檔案。');
    }
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    if (_previewing && controller.value.position >= _end) {
      controller.pause();
      controller.seekTo(_end);
      _previewing = false;
    }
    setState(() {});
  }

  @override
  void dispose() {
    final controller = _controller;
    controller?.removeListener(_onControllerChanged);
    controller?.dispose();
    super.dispose();
  }

  void _notifySegment() {
    final controller = _controller;
    if (controller == null) return;
    final segment = VideoSegment(startTime: _start, endTime: _end);
    final error = segment.validationError(controller.value.duration);
    setState(() => _error = error);
    if (error == null) widget.onSegmentChanged(segment);
  }

  void _setStart() {
    final position = _controller!.value.position;
    if (position >= _end) {
      setState(() => _error = '開始時間必須早於結束時間。');
      return;
    }
    _start = position;
    _notifySegment();
  }

  void _setEnd() {
    final position = _controller!.value.position;
    if (position <= _start) {
      setState(() => _error = '結束時間必須晚於開始時間。');
      return;
    }
    _end = position;
    _notifySegment();
  }

  Future<void> _togglePlay() async {
    final controller = _controller!;
    _previewing = false;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >= controller.value.duration) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
  }

  Future<void> _previewSegment() async {
    final controller = _controller!;
    await controller.pause();
    await controller.seekTo(_start);
    _previewing = true;
    await controller.play();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _controller == null) {
      return _messageCard(_error!, Colors.red.shade700);
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final durationMs = controller.value.duration.inMilliseconds;
    final positionMs = controller.value.position.inMilliseconds
        .clamp(0, durationMs)
        .toDouble();
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.65,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDE0F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio == 0
                      ? 16 / 9
                      : controller.value.aspectRatio,
                  child: ColoredBox(
                    color: Colors.black,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
              Slider(
                value: positionMs,
                min: 0,
                max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                onChanged: (value) =>
                    controller.seekTo(Duration(milliseconds: value.round())),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: controller.value.isPlaying ? '暫停' : '播放',
                    onPressed: _togglePlay,
                    icon: Icon(controller.value.isPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle),
                  ),
                  Text(
                    '${_format(controller.value.position)} / '
                    '${_format(controller.value.duration)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _previewSegment,
                    child: const Text('預覽選取片段'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _setStart,
                    child: const Text('設為開始'),
                  ),
                  OutlinedButton(
                    onPressed: _setEnd,
                    child: const Text('設為結束'),
                  ),
                  _timeChip('開始', _start),
                  _timeChip('結束', _end),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeChip(String label, Duration value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF1FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$label ${_format(value)}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _messageCard(String message, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(message, style: TextStyle(color: color)),
      );

  String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final tenths = (value.inMilliseconds.remainder(1000) ~/ 100);
    return '$minutes:$seconds.$tenths';
  }
}
