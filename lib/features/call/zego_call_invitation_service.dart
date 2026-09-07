import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import 'call_invitation_lifecycle.dart';
import 'zego_call_config.dart';
import 'zego_call_id.dart';

class ZegoCallInvitationService {
  ZegoCallInvitationService._() : _gateway = _ZegoCallInvitationGateway() {
    _lifecycle = CallInvitationLifecycle(_gateway);
  }

  static final ZegoCallInvitationService instance =
      ZegoCallInvitationService._();

  final _ZegoCallInvitationGateway _gateway;
  late CallInvitationLifecycle _lifecycle;

  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);
  }

  void setScaffoldMessengerKey(
    GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
  ) {
    _gateway.scaffoldMessengerKey = scaffoldMessengerKey;
  }

  Future<void> synchronizeSession({String? userId, String? userName}) async {
    if (!Platform.isAndroid || !ZegoCallConfig.isConfigured) return;
    try {
      final safeUserId = userId == null ? null : buildZegoUserId(userId);
      await _lifecycle.synchronize(userId: safeUserId, userName: userName);
    } on Object catch (error) {
      debugPrint(
        'ZEGO invitation lifecycle failed: ${error.runtimeType}',
      );
    }
  }

  Future<bool> sendVideoInvitation({
    required String targetUserId,
    required String targetUserName,
    required String callId,
  }) async {
    if (!Platform.isAndroid || !ZegoCallConfig.isConfigured) return false;
    final service = ZegoUIKitPrebuiltCallInvitationService();
    if (!service.isInit || service.isInCalling || service.isInCall) {
      return false;
    }
    return service.send(
      invitees: [ZegoCallUser(targetUserId, targetUserName)],
      isVideoCall: true,
      callID: callId,
      timeoutSeconds: 60,
    );
  }
}

class _ZegoCallInvitationGateway implements CallInvitationLifecycleGateway {
  GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  Future<void> initialize({
    required String userId,
    required String userName,
  }) {
    return ZegoUIKitPrebuiltCallInvitationService().init(
      appID: ZegoCallConfig.appId,
      appSign: ZegoCallConfig.appSign,
      userID: userId,
      userName: userName,
      plugins: [ZegoUIKitSignalingPlugin()],
      config: ZegoCallInvitationConfig(permissions: const []),
      requireConfig: (_) => ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall(),
      innerText: ZegoCallInvitationInnerText(
        incomingVideoCallDialogMessage: '邀請你進行視訊通話',
        incomingVideoCallPageMessage: '邀請你進行視訊通話',
        incomingCallPageDeclineButton: '拒絕',
        incomingCallPageAcceptButton: '接聽',
        outgoingVideoCallPageMessage: '等待對方接聽…',
        outgoingCallPageACancelButton: '取消',
      ),
      invitationEvents: ZegoUIKitPrebuiltCallInvitationEvents(
        onOutgoingCallDeclined: (_, __, ___) => _showMessage('對方已拒絕視訊通話'),
        onOutgoingCallRejectedCauseBusy: (_, __, ___) =>
            _showMessage('對方目前忙碌中'),
        onOutgoingCallTimeout: (_, __, ___) => _showMessage('對方未接聽視訊通話'),
      ),
    );
  }

  @override
  Future<void> uninitialize() {
    return ZegoUIKitPrebuiltCallInvitationService().uninit();
  }

  void _showMessage(String message) {
    scaffoldMessengerKey?.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
