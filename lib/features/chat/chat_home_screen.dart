// lib/features/chat/chat_home_screen.dart
//
// 聊天分頁首頁(列表)— 三區:
//   1. AI 助手(漸層卡,置頂)
//   2. 我的照護團隊(治療師)
//   3. 一起加油的夥伴(病友)
//
// 真人 contact、最後訊息與未讀數由 ChatBackend 提供；AI 對話維持獨立畫面。

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ui/app_colors.dart';
import '../account/app_session.dart';
import '../account/user_role.dart';
import '../friends/friend_management_screen.dart';
import 'chat_backend.dart';
import 'chat_models.dart';
import 'chat_screen.dart';
import 'remote_chat_screen.dart';
import 'rest_chat_backend.dart';

typedef FriendManagementBuilder = Widget Function(ChatBackend backend);

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({
    super.key,
    this.backend,
    this.friendManagementBuilder,
  });

  final ChatBackend? backend;
  final FriendManagementBuilder? friendManagementBuilder;

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen>
    with WidgetsBindingObserver {
  late final ChatBackend _backend;
  StreamSubscription<List<RemoteConversation>>? _conversationSubscription;
  StreamSubscription<List<UnreadCount>>? _unreadSubscription;

  List<ChatContact> _contacts = const [];
  List<RemoteConversation> _conversations = const [];
  Map<String, int> _unreadByConversation = const {};
  bool _loadingContacts = true;
  bool _appIsActive = true;
  String? _error;
  String? _openingContactId;

  String? get _myUserId {
    final value = AppSession.userId?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get _isTherapist => AppSession.role == UserRole.therapist;

  List<ChatContact> get _therapists => _contacts
      .where((contact) => contact.type == ConversationType.therapist)
      .toList(growable: false);

  List<ChatContact> get _peers => _contacts
      .where((contact) => contact.type == ConversationType.peer)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _backend = widget.backend ?? RestChatBackend();
    final userId = _myUserId;
    if (userId == null) {
      _loadingContacts = false;
      _error = '找不到登入使用者，請重新登入後再使用真人聊天室。';
      return;
    }
    _conversationSubscription = _backend
        .watchConversations(userId)
        .listen(_setConversations, onError: _handleStreamError);
    _unreadSubscription = _backend
        .watchUnreadCounts(userId)
        .listen(_setUnreadCounts, onError: _handleStreamError);
    unawaited(_loadContacts());
  }

  Future<void> _loadContacts() async {
    if (mounted) {
      setState(() {
        _loadingContacts = true;
        _error = null;
      });
    }
    try {
      final contacts = await _backend.getContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loadingContacts = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingContacts = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _refreshAll() async {
    _backend.refresh();
    await _loadContacts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_appIsActive && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _appIsActive = true;
        unawaited(_refreshAll());
      }
      return;
    }
    _appIsActive = false;
  }

  Future<void> _openFriendManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            widget.friendManagementBuilder?.call(_backend) ??
            FriendManagementScreen(chatBackend: _backend),
      ),
    );
    if (!mounted) return;
    await _refreshAll();
  }

  void _setConversations(List<RemoteConversation> conversations) {
    if (!mounted) return;
    setState(() => _conversations = conversations);
  }

  void _setUnreadCounts(List<UnreadCount> counts) {
    if (!mounted) return;
    setState(() {
      _unreadByConversation = {
        for (final count in counts) count.conversationId: count.count,
      };
    });
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (!mounted || _contacts.isNotEmpty) return;
    setState(() => _error = error.toString());
  }

  void _openAiChat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  Future<void> _openContact(ChatContact contact) async {
    final userId = _myUserId;
    if (userId == null || _openingContactId != null) return;
    setState(() => _openingContactId = contact.userId);
    try {
      final conversationId = await _backend.getOrCreateConversation(
        myUserId: userId,
        otherUserId: contact.userId,
        type: contact.type,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RemoteChatScreen(
            backend: _backend,
            conversationId: conversationId,
            otherUserId: contact.userId,
            otherUserName: contact.name,
            conversationType: contact.type,
          ),
        ),
      );
      if (mounted) await _refreshAll();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _openingContactId = null);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_conversationSubscription?.cancel());
    unawaited(_unreadSubscription?.cancel());
    _backend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _buildAiCard(),
                    const SizedBox(height: 24),
                    if (_loadingContacts && _contacts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null && _contacts.isEmpty)
                      _buildError(_error!)
                    else ...[
                      _buildSectionTitle(
                        _isTherapist ? '我的病患' : '我的照護團隊',
                      ),
                      const SizedBox(height: 12),
                      if (_therapists.isEmpty)
                        _buildEmpty(
                          _isTherapist ? '還沒有已綁定病患' : '還沒有治療師',
                          _isTherapist ? '完成病患綁定後即可開始聊天' : '完成治療師綁定後即可開始聊天',
                        )
                      else
                        ..._therapists.map(_buildTherapistCard),
                      if (!_isTherapist) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          '一起加油的夥伴',
                          actionLabel: '尋找病友',
                          onAction: _openFriendManagement,
                        ),
                        const SizedBox(height: 12),
                        if (_peers.isEmpty)
                          _buildEmpty('還沒有夥伴', '成為好友後即可在這裡開始聊天')
                        else
                          ..._peers.map(_buildPeerCard),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 頁面標題 ──
  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '訊息',
            style: TextStyle(
              color: Color(0xFF1A1D2E),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'AI、治療師、夥伴,陪你一起復健',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── AI 助手卡片 ──
  Widget _buildAiCard() {
    return GestureDetector(
      onTap: _openAiChat,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A65FF), Color(0xFF7B5EA7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A65FF).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'AI 復健助手',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '隨時在線',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '有任何訓練問題都可以問我',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.8), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    String title, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1A1D2E),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            key: const ValueKey('open-friend-management'),
            onPressed: onAction,
            child: Text(actionLabel),
          ),
      ],
    );
  }

  // ── 治療師卡片 ──
  Widget _buildTherapistCard(ChatContact contact) => _buildContactCard(contact);

  // ── 病友卡片 ──
  Widget _buildPeerCard(ChatContact contact) => _buildContactCard(contact);

  Widget _buildContactCard(ChatContact contact) {
    final conversation = _conversationFor(contact);
    final unread = conversation == null
        ? 0
        : (_unreadByConversation[conversation.id] ?? 0);
    final opening = _openingContactId == contact.userId;
    return GestureDetector(
      key: ValueKey('chat-contact-${contact.type.name}-${contact.userId}'),
      onTap: opening ? null : () => _openContact(contact),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            _avatar(contact.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(contact.name, style: _nameStyle()),
                      ),
                      const SizedBox(width: 6),
                      _tag(_contactLabel(contact)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation?.lastMessageText ?? '開始聊天',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _previewStyle(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (opening)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              _trailing(_formatListTime(conversation?.lastMessageAt), unread),
          ],
        ),
      ),
    );
  }

  RemoteConversation? _conversationFor(ChatContact contact) {
    final myUserId = _myUserId;
    if (myUserId == null) return null;
    for (final conversation in _conversations) {
      if (conversation.type == contact.type &&
          conversation.otherParticipantId(myUserId) == contact.userId) {
        return conversation;
      }
    }
    return null;
  }

  String _contactLabel(ChatContact contact) {
    if (contact.type == ConversationType.peer) return '好友';
    return contact.role.toUpperCase() == 'PATIENT' ? '病患' : '治療師';
  }

  String _formatListTime(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.month}/${local.day}';
  }

  // ── 共用小元件 ──
  Widget _avatar(String text,
      {bool online = false, Color avatarColor = const Color(0xFF4A65FF)}) {
    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: avatarColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            text.trim().isEmpty ? '?' : text.trim().substring(0, 1),
            style: TextStyle(
              color: avatarColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _trailing(String time, int unread) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
              )),
          const SizedBox(height: 6),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text('$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      );

  TextStyle _nameStyle() => const TextStyle(
        color: Color(0xFF1A1D2E),
        fontSize: 15,
        fontWeight: FontWeight.w700,
      );

  TextStyle _previewStyle() => const TextStyle(
        color: AppColors.secondaryText,
        fontSize: 12,
      );

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  Widget _buildEmpty(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.group_outlined,
              size: 36, color: const Color(0xFF9CA3AF).withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
              )),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadContacts, child: const Text('重試')),
        ],
      ),
    );
  }
}
