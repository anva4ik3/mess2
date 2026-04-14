import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api.dart';
import '../config.dart';

class WsService {
  WebSocketChannel? _channel;
  final _controllers = <String, StreamController<Map<String, dynamic>>>{};
  final _globalController = StreamController<Map<String, dynamic>>.broadcast();
  bool _connected = false;
  bool _disposed = false;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String? _currentUserId;

  Stream<Map<String, dynamic>> get messages => _globalController.stream;
  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_connected || _disposed) return;
    final token = await ApiService.getToken();
    if (token == null) return;

    try {
      final wsUrl = '${AppConfig.wsUrl}?token=$token';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _connected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;

            if (msg['type'] == 'connected') {
              _currentUserId = msg['userId'];
            }

            _globalController.add(msg);

            // Роутим по chatId
            final chatId = msg['message']?['chat_id'] ?? msg['chatId'];
            if (chatId != null && _controllers.containsKey(chatId)) {
              _controllers[chatId]!.add(msg);
            }
            // Также роутим typing, message_deleted, message_edited, reaction_updated по chatId в payload
            if (msg['chatId'] != null && _controllers.containsKey(msg['chatId'])) {
              _controllers[msg['chatId']]!.add(msg);
            }
          } catch (_) {}
        },
        onDone: () {
          _connected = false;
          _scheduleReconnect();
        },
        onError: (_) {
          _connected = false;
          _scheduleReconnect();
        },
      );

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (_connected) send({'type': 'ping'});
      });
    } catch (_) {
      _connected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), connect);
  }

  void send(Map<String, dynamic> data) {
    if (_connected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (_) {}
    }
  }

  void joinChat(String chatId) {
    if (!(_controllers.containsKey(chatId))) {
      _controllers[chatId] = StreamController<Map<String, dynamic>>.broadcast();
    }
    send({'type': 'join_chat', 'payload': {'chatId': chatId}});
  }

  void leaveChat(String chatId) {
    send({'type': 'leave_chat', 'payload': {'chatId': chatId}});
  }

  void sendMessage(String chatId, String content, {
    String? replyTo,
    String? forwardFromChatId,
    String? forwardFromMessageId,
    String? forwardFromUser,
    String type = 'text',
  }) {
    send({
      'type': 'send_message',
      'payload': {
        'chatId': chatId,
        'content': content,
        if (replyTo != null) 'replyTo': replyTo,
        if (forwardFromChatId != null) 'forwardFromChatId': forwardFromChatId,
        if (forwardFromMessageId != null) 'forwardFromMessageId': forwardFromMessageId,
        if (forwardFromUser != null) 'forwardFromUser': forwardFromUser,
        'type': type,
      },
    });
  }

  void sendTyping(String chatId, bool isTyping) {
    send({'type': 'typing', 'payload': {'chatId': chatId, 'isTyping': isTyping}});
  }

  void markRead(String chatId) {
    send({'type': 'mark_read', 'payload': {'chatId': chatId}});
  }

  void deleteMessage(String chatId, String messageId) {
    send({'type': 'delete_message', 'payload': {'chatId': chatId, 'messageId': messageId}});
  }

  void editMessage(String chatId, String messageId, String content) {
    send({'type': 'edit_message', 'payload': {'chatId': chatId, 'messageId': messageId, 'content': content}});
  }

  void reactToMessage(String chatId, String messageId, String emoji) {
    send({'type': 'react', 'payload': {'chatId': chatId, 'messageId': messageId, 'emoji': emoji}});
  }

  Stream<Map<String, dynamic>> chatStream(String chatId) {
    if (!_controllers.containsKey(chatId)) {
      _controllers[chatId] = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _controllers[chatId]!.stream;
  }

  void disconnect() {
    _disposed = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
  }

  void reset() {
    _disposed = false;
    _connected = false;
  }
}

final wsService = WsService();
