import 'package:flutter/material.dart';

enum TrainingCameraSource { phone, raspberryPi }

class TrainingCameraSelection {
  final TrainingCameraSource source;
  final String? raspberryPiIp;

  const TrainingCameraSelection.phone()
      : source = TrainingCameraSource.phone,
        raspberryPiIp = null;

  const TrainingCameraSelection.raspberryPi(String ip)
      : source = TrainingCameraSource.raspberryPi,
        raspberryPiIp = ip;

  bool get usesRaspberryPi => source == TrainingCameraSource.raspberryPi;

  bool get isValid =>
      !usesRaspberryPi ||
      (raspberryPiIp != null && raspberryPiIp!.trim().isNotEmpty);
}

class TrainingRestartGuard {
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<bool> run(Future<void> Function() restart) async {
    if (_isRunning) return false;
    _isRunning = true;
    try {
      await restart();
      return true;
    } finally {
      _isRunning = false;
    }
  }
}

String formatRepProgress(int currentReps, int targetReps) =>
    '$currentReps/$targetReps';

class CameraConnectionErrorOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const CameraConnectionErrorOverlay({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white, size: 44),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重新連線'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
