import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:stomp_dart_client/stomp_dart_client.dart';

class ChatRealtimeEvent {
  const ChatRealtimeEvent(this.type, this.conversationId);
  final String type;
  final String conversationId;

  static ChatRealtimeEvent? parse(String body) {
    try {
      final value = jsonDecode(body);
      if (value is! Map ||
          !const {
            'MESSAGE_CREATED',
            'MESSAGE_READ',
            'CONVERSATION_CREATED',
            'CONVERSATION_UPDATED'
          }.contains(value['type']) ||
          !RegExp(r'^[1-9][0-9]*$').hasMatch('${value['conversationId']}')) {
        return null;
      }
      return ChatRealtimeEvent(
          value['type'] as String, '${value['conversationId']}');
    } on FormatException {
      return null;
    }
  }
}

/// Injectable wire boundary. REST remains usable when this transport fails.
abstract interface class ChatRealtimeTransport {
  void start();
  void stop();
}

typedef ChatRealtimeTransportFactory = ChatRealtimeTransport Function({
  required Uri url,
  required Map<String, String> headers,
  required void Function() onConnected,
  required void Function(ChatRealtimeEvent) onEvent,
  required void Function(bool unauthorized) onDisconnected,
});

class StompChatTransport implements ChatRealtimeTransport {
  StompChatTransport({
    required Uri url,
    required Map<String, String> headers,
    required void Function() onConnected,
    required void Function(ChatRealtimeEvent) onEvent,
    required void Function(bool unauthorized) onDisconnected,
  }) {
    _client = StompClient(
        config: StompConfig(
      url: url.toString(),
      stompConnectHeaders: headers,
      reconnectDelay: Duration.zero, // The owner implements bounded backoff.
      connectionTimeout: const Duration(seconds: 20),
      heartbeatIncoming: const Duration(seconds: 25),
      heartbeatOutgoing: const Duration(seconds: 25),
      onConnect: (_) {
        if (_stopped) return;
        _client.subscribe(
            destination: '/user/queue/chat-events',
            callback: (frame) {
              if (_stopped || frame.body == null) return;
              try {
                final payload = jsonDecode(frame.body!);
                if (payload is Map && payload['type'] == 'CONNECTION_READY') {
                  onConnected();
                  return;
                }
              } on FormatException {
                return;
              }
              final event = ChatRealtimeEvent.parse(frame.body!);
              if (event != null) onEvent(event);
            });
      },
      onStompError: (_) {
        if (!_stopped) onDisconnected(true);
      },
      onWebSocketError: (_) {
        if (!_stopped) onDisconnected(false);
      },
      onWebSocketDone: () {
        if (!_stopped) onDisconnected(false);
      },
      // No debug callback: STOMP diagnostics can include credential headers.
    ));
  }
  late final StompClient _client;
  bool _stopped = false;
  @override
  void start() => _client.activate();
  @override
  void stop() {
    _stopped = true;
    _client.deactivate();
  }
}

/// One connection/private subscription per backend, never a DB polling timer.
class ChatRealtimeConnection {
  ChatRealtimeConnection({
    required this.url,
    required this.headers,
    required this.isCurrentSession,
    required this.onConnected,
    required this.onEvent,
    this.transportFactory = StompChatTransport.new,
    this.retryBase = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(seconds: 30),
    this.maxRetries = 8,
    this.connectionTimeout = const Duration(seconds: 20),
  });
  final Uri url;
  final Map<String, String> headers;
  final bool Function() isCurrentSession;
  final void Function() onConnected;
  final void Function(ChatRealtimeEvent) onEvent;
  final ChatRealtimeTransportFactory transportFactory;
  final Duration retryBase;
  final Duration maxRetryDelay;
  final int maxRetries;
  final Duration connectionTimeout;
  ChatRealtimeTransport? _transport;
  Timer? _retry;
  Timer? _stable;
  Timer? _handshake;
  bool _active = false;
  bool _disposed = false;
  int _generation = 0;
  int _attempts = 0;

  static Uri urlFromBase(String baseUrl) {
    final base = Uri.parse(baseUrl);
    if (!const {'http', 'https'}.contains(base.scheme) ||
        base.userInfo.isNotEmpty ||
        base.host.isEmpty) {
      throw ArgumentError('聊天室網址設定無效');
    }
    return Uri(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/ws/chat');
  }

  void resume() {
    if (_disposed || !isCurrentSession()) return;
    _active = true;
    if (_transport != null || _retry != null) return;
    _attempts = 0;
    _connect();
  }

  void _connect() {
    if (!_active || _disposed || !isCurrentSession()) return;
    final generation = ++_generation;
    var ready = false;
    bool current() =>
        !_disposed &&
        _active &&
        generation == _generation &&
        isCurrentSession();
    void lost(bool unauthorized) {
      if (!current()) return;
      _disconnect();
      if (!unauthorized) _retryLater();
    }

    try {
      _transport = transportFactory(
        url: url,
        headers: headers,
        onConnected: () {
          if (!current() || ready) return;
          ready = true;
          _handshake?.cancel();
          _handshake = null;
          // Short-lived connections do not reset backoff and cause reconnect storms.
          _stable?.cancel();
          _stable = Timer(const Duration(seconds: 60), () => _attempts = 0);
          onConnected(); // REST catches up after every successful reconnect.
        },
        onEvent: (event) {
          if (current()) onEvent(event);
        },
        onDisconnected: lost,
      );
      _handshake = Timer(connectionTimeout, () => lost(false));
      _transport!.start();
    } on Object {
      lost(false);
    }
  }

  void _retryLater() {
    if (!_active || _disposed || _attempts >= maxRetries) return;
    final delay = min(maxRetryDelay.inMilliseconds,
        retryBase.inMilliseconds * (1 << _attempts++));
    _retry = Timer(Duration(milliseconds: delay), () {
      _retry = null;
      _connect();
    });
  }

  void _disconnect() {
    ++_generation;
    _stable?.cancel();
    _stable = null;
    _handshake?.cancel();
    _handshake = null;
    final previous = _transport;
    _transport = null;
    previous?.stop();
  }

  void pause() {
    _active = false;
    _retry?.cancel();
    _retry = null;
    _disconnect();
  }

  void dispose() {
    _disposed = true;
    pause();
  }
}
