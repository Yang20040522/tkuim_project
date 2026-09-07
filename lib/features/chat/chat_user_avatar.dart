import 'package:flutter/material.dart';

import '../account/remote_avatar_cache.dart';
import '../account/user_avatar_api_client.dart';

class ChatUserAvatar extends StatefulWidget {
  const ChatUserAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.size = 50,
    this.cache,
  });

  final String userId;
  final String name;
  final double size;
  final RemoteAvatarCache? cache;

  @override
  State<ChatUserAvatar> createState() => _ChatUserAvatarState();
}

class _ChatUserAvatarState extends State<ChatUserAvatar> {
  late Future<RemoteUserAvatar?> _avatar;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ChatUserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.cache != widget.cache) {
      _load();
    }
  }

  void _load() {
    _avatar = (widget.cache ?? RemoteAvatarCache.shared).get(widget.userId);
  }

  Widget _initials() => Container(
        alignment: Alignment.center,
        color: const Color(0xFF4A65FF).withValues(alpha: 0.12),
        child: Text(
          widget.name.trim().isEmpty ? '?' : widget.name.trim().substring(0, 1),
          style: TextStyle(
            color: const Color(0xFF4A65FF),
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ClipOval(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: FutureBuilder<RemoteUserAvatar?>(
            key: ObjectKey(_avatar),
            future: _avatar,
            builder: (context, snapshot) {
              final avatar = snapshot.data;
              if (avatar == null) return _initials();
              return Image.memory(
                avatar.bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initials(),
              );
            },
          ),
        ),
      );
}
