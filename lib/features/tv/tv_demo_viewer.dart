import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../core/ui/tv_ui.dart';
import '../demo/rehab_demo_camera.dart';
import '../training/training_preview_screen.dart';

/// Uses the existing model-viewer WebView and existing model/camera definitions.
class TvDemoViewer extends StatefulWidget {
  final ActionDemo3D demo;
  final String title;
  final String description;
  final VoidCallback start;
  const TvDemoViewer(
      {super.key,
      required this.demo,
      required this.title,
      required this.description,
      required this.start});
  @override
  State<TvDemoViewer> createState() => _TvDemoViewerState();
}

class _TvDemoViewerState extends State<TvDemoViewer> {
  bool enabled = false;
  bool ready = false;
  bool playing = true;
  String? error;
  int index = 0;
  int generation = 0;
  Timer? watchdog;
  Future<void> Function(String)? runJs;
  Future<Object> Function(String)? readJs;

  void load() {
    watchdog?.cancel();
    runJs = null;
    readJs = null;
    setState(() {
      generation++;
      enabled = true;
      playing = true;
      ready = false;
      error = null;
    });
    int attempts = 0;
    final current = generation;
    watchdog = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || current != generation) return;
      try {
        final status = await readJs
            ?.call("document.querySelector('model-viewer')?.loaded === true");
        if (!mounted || current != generation) return;
        if (status == true || status == 'true') {
          watchdog?.cancel();
          setState(() => ready = true);
          return;
        }
      } catch (exception) {
        debugPrint('TV 3D readiness: $exception');
      }
      if (++attempts >= 20 && mounted && current == generation) {
        watchdog?.cancel();
        setState(() {
          enabled = false;
          error = '3D 示教暫時無法載入。可重試，或依動作說明繼續。';
        });
      }
    });
  }

  Future<void> command(String script) async {
    try {
      await runJs?.call(
          "(() => { const m = document.querySelector('model-viewer'); if(m) { $script } })();");
    } catch (exception, stack) {
      debugPrint('TV 3D controls: $exception\n$stack');
      if (mounted) {
        setState(() {
          error = '3D 控制無法使用，請重新載入';
          enabled = false;
          ready = false;
        });
      }
    }
  }

  @override
  void dispose() {
    watchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modelSrc = widget.demo.modelSrcs[index];
    final camera = rehabDemoCameraFor(modelSrc);
    final cameraOrbit =
        camera?.cameraOrbit ?? widget.demo.cameraOrbit ?? '0deg 75deg 105%';
    final cameraTarget = camera?.cameraTarget ?? widget.demo.cameraTarget;
    final fieldOfView = camera?.fieldOfView ?? widget.demo.fieldOfView;

    return TvPage(
        title: '${widget.title} · 動作示教',
        child: Row(children: [
          Expanded(
              flex: 3,
              child: Stack(fit: StackFit.expand, children: [
                if (enabled)
                  ExcludeFocus(
                      child: IgnorePointer(
                          child: ModelViewer(
                    key: ValueKey('$index-$generation'),
                    src: modelSrc,
                    autoPlay: true,
                    autoRotate: false,
                    cameraControls: false,
                    cameraOrbit: cameraOrbit,
                    cameraTarget: cameraTarget,
                    fieldOfView: fieldOfView,
                    minCameraOrbit: camera?.minCameraOrbit,
                    backgroundColor: const Color(0xFF1A1D2E),
                    onWebViewCreated: (controller) {
                      runJs = controller.runJavaScript;
                      readJs = controller.runJavaScriptReturningResult;
                    },
                  )))
                else
                  TvWaitingView(message: error ?? '按「載入 3D 示教」觀看示範'),
                if (enabled && !ready)
                  const Align(
                      alignment: Alignment.topCenter,
                      child: Card(
                          child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('示教載入中…')))),
              ])),
          const SizedBox(width: 24),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Expanded(
                    child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                      Text(widget.description,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 16),
                      FilledButton(
                          autofocus: true,
                          onPressed: load,
                          child: Text(enabled ? '重新載入' : '載入 3D 示教')),
                      for (int i = 0; i < widget.demo.modelSrcs.length; i++)
                        if (widget.demo.modelSrcs.length > 1)
                          TextButton(
                              onPressed: () {
                                index = i;
                                load();
                              },
                              child: Text(widget.demo.tabLabels[i])),
                      OutlinedButton(
                          onPressed: !ready
                              ? null
                              : () => command(
                                  'const o=m.getCameraOrbit(); m.cameraOrbit=`\${o.theta*180/Math.PI-30}deg \${o.phi*180/Math.PI}deg \${o.radius}m`;'),
                          child: const Text('向左旋轉')),
                      OutlinedButton(
                          onPressed: !ready
                              ? null
                              : () => command(
                                  'const o=m.getCameraOrbit(); m.cameraOrbit=`\${o.theta*180/Math.PI+30}deg \${o.phi*180/Math.PI}deg \${o.radius}m`;'),
                          child: const Text('向右旋轉')),
                      OutlinedButton(
                          onPressed: !ready
                              ? null
                              : () => command(
                                  'm.fieldOfView=`\${m.getFieldOfView()*0.85}deg`;'),
                          child: const Text('放大')),
                      OutlinedButton(
                          onPressed: !ready
                              ? null
                              : () => command(
                                  'm.fieldOfView=`\${m.getFieldOfView()*1.15}deg`;'),
                          child: const Text('縮小')),
                      OutlinedButton(
                          onPressed: !ready
                              ? null
                              : () => command(
                                  'm.cameraOrbit=${jsonEncode(cameraOrbit)}; m.cameraTarget=${jsonEncode(cameraTarget ?? 'auto auto auto')}; m.fieldOfView=${jsonEncode(fieldOfView ?? 'auto')};'),
                          child: const Text('重設視角')),
                      OutlinedButton(
                          onPressed: !ready
                              ? null
                              : () {
                                  command(playing ? 'm.pause();' : 'm.play();');
                                  setState(() => playing = !playing);
                                },
                          child: Text(playing ? '暫停示教' : '播放示教')),
                    ]))),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: widget.start, child: const Text('開始訓練')),
              ])),
        ]));
  }
}
