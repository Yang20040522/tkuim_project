import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/app_colors.dart';
import '../account/account_api_service.dart';
import '../account/api_service.dart';
import '../account/app_session.dart';
import '../account/user_role.dart';
import '../chat/chat_backend.dart';
import '../chat/chat_models.dart';
import '../chat/remote_chat_screen.dart';
import '../chat/rest_chat_backend.dart';
import 'friend_api_service.dart';
import 'friend_models.dart';

typedef FriendAccountLoader = Future<AccountInfo> Function();

class FriendManagementScreen extends StatefulWidget {
  const FriendManagementScreen({
    super.key,
    this.friendApiService,
    this.chatBackend,
    this.accountLoader,
  });

  final FriendApiService? friendApiService;
  final ChatBackend? chatBackend;
  final FriendAccountLoader? accountLoader;

  @override
  State<FriendManagementScreen> createState() => _FriendManagementScreenState();
}

class _FriendManagementScreenState extends State<FriendManagementScreen> {
  final TextEditingController _friendCodeController = TextEditingController();
  final Set<String> _busyActions = <String>{};

  late final FriendApiService _friendApi;
  late final ChatBackend _chatBackend;
  late final FriendAccountLoader _accountLoader;
  late final bool _ownsFriendApi;
  late final bool _ownsChatBackend;

  List<FriendRequestItem> _pendingRequests = const [];
  List<SentFriendRequestItem> _sentRequests = const [];
  List<FriendItem> _friends = const [];
  String? _friendCode;
  String? _loadError;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _ownsFriendApi = widget.friendApiService == null;
    _friendApi = widget.friendApiService ?? FriendApiService();
    _ownsChatBackend = widget.chatBackend == null;
    _chatBackend = widget.chatBackend ?? RestChatBackend();
    _accountLoader = widget.accountLoader ?? AccountApiClient().getAccountInfo;

    if (AppSession.role != UserRole.patient) {
      _initialLoading = false;
      _loadError = '好友功能僅限病患使用';
      return;
    }
    unawaited(_loadAll());
  }

  Future<void> _loadAll({bool refreshAccount = false}) async {
    if (mounted) {
      setState(() => _loadError = null);
    }
    try {
      final results = await Future.wait<Object>([
        _friendApi.getPendingRequests(),
        _friendApi.getSentRequests(),
        _friendApi.getFriends(),
        _loadFriendCode(refreshAccount: refreshAccount),
      ]);
      if (!mounted) return;
      setState(() {
        _pendingRequests = results[0] as List<FriendRequestItem>;
        _sentRequests = results[1] as List<SentFriendRequestItem>;
        _friends = results[2] as List<FriendItem>;
        final code = results[3] as String;
        _friendCode = code.isEmpty ? null : code;
        _initialLoading = false;
        _loadError = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _loadError = _friendlyError(error);
      });
    }
  }

  Future<String> _loadFriendCode({required bool refreshAccount}) async {
    final saved = AppSession.friendCode?.trim();
    if (!refreshAccount && saved != null && saved.isNotEmpty) {
      return saved.toUpperCase();
    }

    final account = await _accountLoader();
    final code = account.friendCode?.trim().toUpperCase();
    final role = AppSession.role;
    if (role != null) {
      await AppSession.save(
        role: role,
        userId: AppSession.userId,
        name: AppSession.name,
        email: AppSession.email,
        accountId: AppSession.accountId,
        bindingCode: AppSession.bindingCode,
        friendCode: code,
        customExerciseToken: AppSession.customExerciseToken,
      );
    }
    return code == null || code.isEmpty ? '' : code;
  }

  Future<void> _sendRequest() async {
    final code = _friendCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showMessage('請輸入好友代碼', error: true);
      return;
    }
    await _runAction(
      'send',
      () async {
        await _friendApi.sendFriendRequest(code);
        final sent = await _friendApi.getSentRequests();
        if (!mounted) return;
        _friendCodeController.clear();
        setState(() => _sentRequests = sent);
        _showMessage('好友邀請已送出');
      },
    );
  }

  Future<void> _respond(FriendRequestItem request, {required bool accept}) {
    return _runAction(
      '${accept ? 'accept' : 'reject'}:${request.requestId}',
      () async {
        if (accept) {
          await _friendApi.acceptRequest(request.requestId);
          final results = await Future.wait<Object>([
            _friendApi.getPendingRequests(),
            _friendApi.getSentRequests(),
            _friendApi.getFriends(),
          ]);
          if (!mounted) return;
          setState(() {
            _pendingRequests = results[0] as List<FriendRequestItem>;
            _sentRequests = results[1] as List<SentFriendRequestItem>;
            _friends = results[2] as List<FriendItem>;
          });
          _chatBackend.refresh();
          _showMessage('已接受好友邀請');
        } else {
          await _friendApi.rejectRequest(request.requestId);
          final pending = await _friendApi.getPendingRequests();
          if (!mounted) return;
          setState(() => _pendingRequests = pending);
          _showMessage('已拒絕好友邀請');
        }
      },
    );
  }

  Future<void> _cancelRequest(SentFriendRequestItem request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('取消好友邀請'),
        content: Text('確定要取消送給 ${request.receiverName} 的好友邀請嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('保留'),
          ),
          FilledButton(
            key: const ValueKey('confirm-cancel-request'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('取消邀請'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runAction('cancel:${request.requestId}', () async {
      await _friendApi.cancelRequest(request.requestId);
      final sent = await _friendApi.getSentRequests();
      if (!mounted) return;
      setState(() => _sentRequests = sent);
      _showMessage('好友邀請已取消');
    });
  }

  Future<void> _removeFriend(FriendItem friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除好友'),
        content: Text('確定要刪除 ${friend.friendName} 嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('保留好友'),
          ),
          FilledButton(
            key: const ValueKey('confirm-remove-friend'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE24B4A),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runAction('remove:${friend.friendId}', () async {
      await _friendApi.removeFriend(friend.friendId);
      final friends = await _friendApi.getFriends();
      if (!mounted) return;
      setState(() => _friends = friends);
      _chatBackend.refresh();
      _showMessage('好友已刪除');
    });
  }

  Future<void> _openChat(FriendItem friend) async {
    final userId = AppSession.userId?.trim();
    if (userId == null || userId.isEmpty) {
      _showMessage('登入狀態已失效，請重新登入', error: true);
      return;
    }
    await _runAction('chat:${friend.friendId}', () async {
      final conversationId = await _chatBackend.getOrCreateConversation(
        myUserId: userId,
        otherUserId: friend.friendId,
        type: ConversationType.peer,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RemoteChatScreen(
            backend: _chatBackend,
            conversationId: conversationId,
            otherUserId: friend.friendId,
            otherUserName: friend.friendName,
            conversationType: ConversationType.peer,
          ),
        ),
      );
    });
  }

  Future<void> _runAction(
    String key,
    Future<void> Function() action,
  ) async {
    if (_busyActions.contains(key)) return;
    setState(() => _busyActions.add(key));
    try {
      await action();
    } on Object catch (error) {
      if (mounted) _showMessage(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busyActions.remove(key));
    }
  }

  Future<void> _copyFriendCode() async {
    final code = _friendCode;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) _showMessage('好友代碼已複製');
  }

  String _friendlyError(Object error) {
    if (error is FriendApiException) return error.message;
    if (error is AuthApiFailure) return error.message;
    return '好友服務暫時無法使用，請稍後再試';
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFE24B4A) : null,
      ),
    );
  }

  @override
  void dispose() {
    _friendCodeController.dispose();
    if (_ownsFriendApi) _friendApi.dispose();
    if (_ownsChatBackend) _chatBackend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        title: const Text('好友管理'),
        backgroundColor: AppColors.lightSurface,
      ),
      body: _initialLoading
          ? const Center(
              key: ValueKey('friend-initial-loading'),
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: () => _loadAll(refreshAccount: true),
              child: ListView(
                key: const ValueKey('friend-management-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (_loadError != null) ...[
                    _errorCard(_loadError!),
                    const SizedBox(height: 16),
                  ],
                  _friendCodeCard(),
                  const SizedBox(height: 16),
                  _addFriendCard(),
                  const SizedBox(height: 24),
                  _sectionTitle('收到的邀請'),
                  const SizedBox(height: 10),
                  if (_pendingRequests.isEmpty)
                    _emptyCard('目前沒有好友邀請')
                  else
                    ..._pendingRequests.map(_pendingCard),
                  const SizedBox(height: 24),
                  _sectionTitle('已送出的邀請'),
                  const SizedBox(height: 10),
                  if (_sentRequests.isEmpty)
                    _emptyCard('目前沒有已送出的邀請')
                  else
                    ..._sentRequests.map(_sentCard),
                  const SizedBox(height: 24),
                  _sectionTitle('我的好友'),
                  const SizedBox(height: 10),
                  if (_friends.isEmpty)
                    _emptyCard('還沒有好友')
                  else
                    ..._friends.map(_friendCard),
                ],
              ),
            ),
    );
  }

  Widget _friendCodeCard() {
    return _card(
      key: const ValueKey('my-friend-code-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '我的好友代碼',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  _friendCode ?? '尚未提供',
                  key: const ValueKey('my-friend-code'),
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('copy-friend-code'),
                onPressed: _friendCode == null ? null : _copyFriendCode,
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('複製'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '分享這組代碼給病友，對方即可傳送好友邀請。',
            style: TextStyle(color: AppColors.secondaryText, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _addFriendCard() {
    final busy = _busyActions.contains('send');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '加入病友',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('friend-code-input'),
            controller: _friendCodeController,
            enabled: !busy,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [_UpperCaseTextFormatter()],
            decoration: InputDecoration(
              labelText: '好友代碼',
              hintText: '例如 ABCD1234',
              filled: true,
              fillColor: AppColors.lightSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onSubmitted: (_) => _sendRequest(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('send-friend-request'),
              onPressed: busy ? null : _sendRequest,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('送出好友邀請'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingCard(FriendRequestItem request) {
    final acceptBusy = _busyActions.contains('accept:${request.requestId}');
    final rejectBusy = _busyActions.contains('reject:${request.requestId}');
    final busy = acceptBusy || rejectBusy;
    return _card(
      key: ValueKey('pending-request-${request.requestId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _nameAndDate(request.senderName, request.createdAt),
          if (request.senderFriendCode.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '代碼 ${request.senderFriendCode}',
              style: const TextStyle(color: AppColors.secondaryText),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                key: ValueKey('reject-request-${request.requestId}'),
                onPressed: busy ? null : () => _respond(request, accept: false),
                child: rejectBusy ? const _SmallProgress() : const Text('拒絕'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: ValueKey('accept-request-${request.requestId}'),
                onPressed: busy ? null : () => _respond(request, accept: true),
                child: acceptBusy ? const _SmallProgress() : const Text('接受'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sentCard(SentFriendRequestItem request) {
    final busy = _busyActions.contains('cancel:${request.requestId}');
    return _card(
      key: ValueKey('sent-request-${request.requestId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _nameAndDate(request.receiverName, request.createdAt),
                const SizedBox(height: 5),
                const Text(
                  '等待對方接受',
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          TextButton(
            key: ValueKey('cancel-request-${request.requestId}'),
            onPressed: busy ? null : () => _cancelRequest(request),
            child: busy ? const _SmallProgress() : const Text('取消邀請'),
          ),
        ],
      ),
    );
  }

  Widget _friendCard(FriendItem friend) {
    final chatBusy = _busyActions.contains('chat:${friend.friendId}');
    final removeBusy = _busyActions.contains('remove:${friend.friendId}');
    return _card(
      key: ValueKey('friend-${friend.friendId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            friend.friendName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (friend.friendCode.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '代碼 ${friend.friendCode}',
              style: const TextStyle(color: AppColors.secondaryText),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.tonalIcon(
                key: ValueKey('chat-friend-${friend.friendId}'),
                onPressed:
                    chatBusy || removeBusy ? null : () => _openChat(friend),
                icon: chatBusy
                    ? const _SmallProgress()
                    : const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('聊天'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                key: ValueKey('remove-friend-${friend.friendId}'),
                onPressed:
                    chatBusy || removeBusy ? null : () => _removeFriend(friend),
                icon: removeBusy
                    ? const _SmallProgress()
                    : const Icon(Icons.person_remove_outlined, size: 18),
                label: const Text('刪除好友'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE24B4A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nameAndDate(String name, DateTime? createdAt) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        if (createdAt != null)
          Text(
            _formatDate(createdAt),
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          color: AppColors.primaryText,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      );

  Widget _emptyCard(String message) => _card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.secondaryText),
            ),
          ),
        ),
      );

  Widget _errorCard(String message) => _card(
        key: const ValueKey('friend-load-error'),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE24B4A)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loadAll,
              child: const Text('重試'),
            ),
          ],
        ),
      );

  Widget _card({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      key: key,
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.month}/${local.day} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _SmallProgress extends StatelessWidget {
  const _SmallProgress();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
