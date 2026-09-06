import 'dart:async';

import 'package:flutter/material.dart';

import '../account/app_session.dart';
import 'chat_backend.dart';
import 'chat_models.dart';

class RemoteChatScreen extends StatefulWidget {
  const RemoteChatScreen({
    super.key,
    required this.backend,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.conversationType,
  });

  final ChatBackend backend;
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final ConversationType conversationType;

  @override
  State<RemoteChatScreen> createState() => _RemoteChatScreenState();
}

class _RemoteChatScreenState extends State<RemoteChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<List<RemoteChatMessage>>? _messageSubscription;

  List<RemoteChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  bool _markingRead = false;
  String? _error;

  String? get _myUserId {
    final value = AppSession.userId?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  void initState() {
    super.initState();
    final userId = _myUserId;
    if (userId == null) {
      _loading = false;
      _error = '找不到登入使用者，請重新登入。';
      return;
    }
    _messageSubscription = widget.backend
        .watchMessages(widget.conversationId)
        .listen(_receiveMessages, onError: _receiveError);
    unawaited(_markAsRead());
  }

  void _receiveMessages(List<RemoteChatMessage> messages) {
    if (!mounted) return;
    final previousLastId = _messages.isEmpty ? null : _messages.last.id;
    final nextLastId = messages.isEmpty ? null : messages.last.id;
    final hasNewMessage = previousLastId != nextLastId;
    setState(() {
      _messages = messages;
      _loading = false;
      _error = null;
    });
    if (hasNewMessage) {
      _scrollToBottom();
    }
    if (messages.any(
      (message) => message.senderId != _myUserId && !message.isRead,
    )) {
      unawaited(_markAsRead());
    }
  }

  void _receiveError(Object error, StackTrace stackTrace) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error.toString();
    });
  }

  Future<void> _markAsRead() async {
    final userId = _myUserId;
    if (userId == null || _markingRead) return;
    _markingRead = true;
    try {
      await widget.backend.markAsRead(
        conversationId: widget.conversationId,
        myUserId: userId,
      );
    } on Object {
      // Polling remains active; a later incoming update retries the read marker.
    } finally {
      _markingRead = false;
    }
  }

  Future<void> _send() async {
    final userId = _myUserId;
    final text = _textController.text.trim();
    if (userId == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.backend.sendMessage(
        conversationId: widget.conversationId,
        senderId: userId,
        text: text,
      );
      _textController.clear();
      _scrollToBottom();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    unawaited(_messageSubscription?.cancel());
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName),
            Text(
              widget.conversationType == ConversationType.therapist
                  ? '照護對話'
                  : '好友對話',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageArea()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageArea() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFEF4444)),
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          '還沒有訊息，開始打聲招呼吧！',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildBubble(_messages[index]),
    );
  }

  Widget _buildBubble(RemoteChatMessage message) {
    final mine = message.senderId == _myUserId;
    return Align(
      key: ValueKey('remote-message-${message.id}-${mine ? 'mine' : 'other'}'),
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF4A65FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: mine
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: mine ? Colors.white : const Color(0xFF1A1D2E),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(message.sentAt),
              style: TextStyle(
                color: mine
                    ? Colors.white.withValues(alpha: 0.75)
                    : const Color(0xFF9CA3AF),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('remote-chat-input'),
                controller: _textController,
                enabled: _myUserId != null && !_sending,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                buildCounter: (
                  context, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) =>
                    null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '輸入訊息…',
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const ValueKey('remote-chat-send'),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
