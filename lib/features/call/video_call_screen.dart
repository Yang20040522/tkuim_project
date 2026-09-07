import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import 'zego_call_config.dart';

class VideoCallScreen extends StatelessWidget {
  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.currentUserId,
    required this.currentUserName,
  });

  final String callId;
  final String currentUserId;
  final String currentUserName;

  @override
  Widget build(BuildContext context) {
    return ZegoUIKitPrebuiltCall(
      appID: ZegoCallConfig.appId,
      appSign: ZegoCallConfig.appSign,
      userID: currentUserId,
      userName: currentUserName,
      callID: callId,
      config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall(),
    );
  }
}
