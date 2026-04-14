import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/chat.dart';
import '../../models/user.dart';
import '../../services/api.dart';
import '../../services/ws.dart';
import '../../theme.dart';
import '../../widgets/avatar.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Message> _messages = [];
  Chat? _chat;
  User? _me;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  String? _typing;
  Timer? _typingTimer;
  StreamSubscription? _wsSub;
  Message? _replyTo;
  Message? _editingMessage;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _init();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    wsService.leaveChat(widget.chatId);
    _wsSub?.cancel();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final meData = await ApiService.getMe();
      _me = User.fromJson(meData);

      final chatData = await ApiService.getChatInfo(widget.chatId);
      _chat = Chat.fromJson(chatData);

      final msgs = await ApiService.getMessages(widget.chatId);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(msgs.map((j) => Message.fromJson(j as Map<String, dynamic>)));
        _loading = false;
      });

      wsService.joinChat(widget.chatId);
      wsService.markRead(widget.chatId);
      _wsSub = wsService.chatStream(widget.chatId).listen(_onWsMsg);
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels <= 100 && !_loadingMore && _messages.isNotEmpty) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final oldest = _messages.first.createdAt.toIso8601String();
      final older = await ApiService.getMessages(widget.chatId, before: oldest);
      if (!mounted) return;
      if (older.isNotEmpty) {
        final oldScroll = _scrollCtrl.position.pixels;
        setState(() {
          _messages.insertAll(0, older.map((j) => Message.fromJson(j as Map<String, dynamic>)));
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.pixels + (older.length * 72.0));
          }
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onWsMsg(Map<String, dynamic> msg) {
    if (!mounted) return;
    final type = msg['type'];

    switch (type) {
      case 'new_message':
        final m = Message.fromJson(msg['message'] as Map<String, dynamic>);
        setState(() => _messages.add(m));
        wsService.markRead(widget.chatId);
        _scrollToBottom();
        break;

      case 'typing':
        final uid = msg['userId'] as String?;
        if (uid != _me?.id) {
          final displayName = msg['displayName'] as String? ?? uid ?? 'Кто-то';
          final isTyping = msg['isTyping'] as bool? ?? false;
          setState(() => _typing = isTyping ? displayName : null);
        }
        break;

      case 'message_deleted':
        final mid = msg['messageId'] as String;
        setState(() => _messages.removeWhere((m) => m.id == mid));
        break;

      case 'message_edited':
        final edited = Message.fromJson(msg['message'] as Map<String, dynamic>);
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == edited.id);
          if (idx >= 0) _messages[idx] = edited;
        });
        break;

      case 'reaction_updated':
        final mid = msg['messageId'] as String;
        final rawReactions = msg['reactions'] as List?;
        final reactions = rawReactions?.map((r) => Reaction.fromJson(r as Map<String, dynamic>)).toList() ?? [];
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == mid);
          if (idx >= 0) _messages[idx] = _messages[idx].copyWith(reactions: reactions);
        });
        break;

      case 'message_pinned':
        final mid = msg['messageId'] as String;
        final isPinned = msg['isPinned'] as bool? ?? false;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == mid);
          if (idx >= 0) _messages[idx] = _messages[idx].copyWith(isPinned: isPinned);
        });
        break;

      case 'user_status':
        if (msg['userId'] == _chat?.otherUserId) {
          setState(() { _chat = _chat?.copyWith(otherUserOnline: msg['isOnline']); });
        }
        break;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTyping(String value) {
    wsService.sendTyping(widget.chatId, value.isNotEmpty);
    _typingTimer?.cancel();
    if (value.isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        wsService.sendTyping(widget.chatId, false);
      });
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _ctrl.clear();
    wsService.sendTyping(widget.chatId, false);

    if (_editingMessage != null) {
      wsService.editMessage(widget.chatId, _editingMessage!.id, text);
      setState(() { _editingMessage = null; _replyTo = null; });
    } else {
      wsService.sendMessage(
        widget.chatId,
        text,
        replyTo: _replyTo?.id,
        forwardFromUser: _replyTo?.forwardFromUser,
      );
      setState(() => _replyTo = null);
    }

    setState(() => _sending = false);
  }

  void _deleteMessage(Message msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg3,
        title: const Text('Удалить сообщение?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Это действие нельзя отменить.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (confirm == true) wsService.deleteMessage(widget.chatId, msg.id);
  }

  void _showReactionPicker(Message msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        children: [
          const SizedBox(height: 12),
          const Text('Реакция', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['👍', '❤️', '😂', '😮', '😢', '🔥', '👏', '🎉'].map((e) =>
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    wsService.reactToMessage(widget.chatId, msg.id, e);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(e, style: const TextStyle(fontSize: 30)),
                  ),
                ),
              ).toList(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) {
                Navigator.pop(context);
                wsService.reactToMessage(widget.chatId, msg.id, emoji.emoji);
              },
              config: const Config(
                emojiViewConfig: EmojiViewConfig(backgroundColor: Colors.transparent),
                categoryViewConfig: CategoryViewConfig(backgroundColor: AppColors.bg2),
                searchViewConfig: SearchViewConfig(backgroundColor: AppColors.bg3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(Message msg) {
    final isOwn = msg.senderId == _me?.id;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OptionTile(icon: Icons.emoji_emotions_outlined, label: 'Реакция', onTap: () { Navigator.pop(context); _showReactionPicker(msg); }),
            _OptionTile(icon: Icons.reply_rounded, label: 'Ответить', onTap: () { Navigator.pop(context); setState(() => _replyTo = msg); }),
            _OptionTile(icon: Icons.copy_rounded, label: 'Копировать', onTap: () { Navigator.pop(context); Clipboard.setData(ClipboardData(text: msg.content)); }),
            if (isOwn) _OptionTile(icon: Icons.edit_outlined, label: 'Редактировать', onTap: () {
              Navigator.pop(context);
              setState(() { _editingMessage = msg; _ctrl.text = msg.content; });
              _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
            }),
            _OptionTile(icon: Icons.push_pin_outlined, label: msg.isPinned ? 'Открепить' : 'Закрепить', onTap: () async {
              Navigator.pop(context);
              await ApiService.pinMessage(widget.chatId, msg.id);
            }),
            if (isOwn) _OptionTile(icon: Icons.delete_outline, label: 'Удалить', color: AppColors.red, onTap: () { Navigator.pop(context); _deleteMessage(msg); }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGroup = _chat?.type == 'group';

    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        titleSpacing: 0,
        leading: const BackButton(),
        title: _chat == null
            ? const SizedBox.shrink()
            : InkWell(
                onTap: () {},
                child: Row(
                  children: [
                    AppAvatar(
                      name: _chat!.displayName,
                      url: _chat!.displayAvatar,
                      size: 38,
                      showOnline: !isGroup,
                      isOnline: _chat?.otherUserOnline ?? false,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_chat!.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        if (_typing != null)
                          Text('$_typing печатает...', style: const TextStyle(color: AppColors.primary, fontSize: 12))
                        else if (!isGroup)
                          Text(
                            (_chat?.otherUserOnline ?? false) ? 'В сети' : 'Не в сети',
                            style: TextStyle(
                              fontSize: 12,
                              color: (_chat?.otherUserOnline ?? false) ? AppColors.green : AppColors.textMuted,
                            ),
                          )
                        else
                          const Text('Группа', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
        actions: [
          PopupMenuButton<String>(
            color: AppColors.bg3,
            icon: const Icon(Icons.more_vert, color: AppColors.primary),
            onSelected: (v) async {
              if (v == 'summarize') {
                final summary = await ApiService.summarizeChat(widget.chatId);
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.bg3,
                    title: const Text('Резюме чата', style: TextStyle(color: AppColors.textPrimary)),
                    content: Text(summary, style: const TextStyle(color: AppColors.textSecondary)),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОК'))],
                  ),
                );
              } else if (v == 'mute') {
                final result = await ApiService.toggleMuteChat(widget.chatId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['isMuted'] ? 'Уведомления отключены' : 'Уведомления включены'), backgroundColor: AppColors.bg3),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'summarize', child: ListTile(leading: Icon(Icons.auto_awesome, color: AppColors.primary), title: Text('AI-резюме', style: TextStyle(color: AppColors.textPrimary)))),
              const PopupMenuItem(value: 'mute', child: ListTile(leading: Icon(Icons.volume_off_outlined, color: AppColors.textSecondary), title: Text('Отключить звук', style: TextStyle(color: AppColors.textPrimary)))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Pinned message
          if (_messages.any((m) => m.isPinned))
            _PinnedBanner(message: _messages.lastWhere((m) => m.isPinned)),
          // Messages
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    itemCount: _messages.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (_loadingMore && i == 0) {
                        return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)));
                      }
                      final idx = _loadingMore ? i - 1 : i;
                      final msg = _messages[idx];
                      return _MessageBubble(
                        message: msg,
                        isOwn: msg.senderId == _me?.id,
                        isGroup: isGroup,
                        onLongPress: () => _showMessageOptions(msg),
                        onReply: () => setState(() => _replyTo = msg),
                        currentUserId: _me?.id ?? '',
                      );
                    },
                  ),
          ),
          // Reply / Edit bar
          if (_replyTo != null || _editingMessage != null)
            _ReplyBar(
              replyTo: _replyTo,
              editing: _editingMessage,
              onCancel: () => setState(() { _replyTo = null; _editingMessage = null; _ctrl.clear(); }),
            ),
          // Input bar
          _InputBar(
            controller: _ctrl,
            sending: _sending,
            onTyping: _onTyping,
            onSend: _send,
            onEmojiToggle: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
          ),
          if (_showEmojiPicker)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                textEditingController: _ctrl,
                config: const Config(
                  emojiViewConfig: EmojiViewConfig(backgroundColor: AppColors.bg2),
                  categoryViewConfig: CategoryViewConfig(backgroundColor: AppColors.bg2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PinnedBanner extends StatelessWidget {
  final Message message;
  const _PinnedBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(width: 3, height: 32, color: AppColors.primary, margin: const EdgeInsets.only(right: 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Закреплено', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                Text(message.content, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwn;
  final bool isGroup;
  final VoidCallback onLongPress;
  final VoidCallback onReply;
  final String currentUserId;

  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.isGroup,
    required this.onLongPress,
    required this.onReply,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        onHorizontalDragEnd: (d) {
          if ((isOwn && d.primaryVelocity! < -100) || (!isOwn && d.primaryVelocity! > 100)) {
            onReply();
          }
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Container(
            margin: EdgeInsets.only(top: 2, bottom: 2, left: isOwn ? 60 : 0, right: isOwn ? 0 : 60),
            child: Column(
              crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (isGroup && !isOwn)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 2),
                    child: Text(message.senderName, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isOwn && isGroup)
                      Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 4),
                        child: AppAvatar(name: message.senderName, url: message.senderAvatar, size: 28),
                      ),
                    Flexible(child: _Bubble(message: message, isOwn: isOwn, currentUserId: currentUserId)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  final bool isOwn;
  final String currentUserId;

  const _Bubble({required this.message, required this.isOwn, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final isAi = message.type == 'ai';
    final isForwarded = message.forwardFromUser != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: isOwn
            ? const LinearGradient(colors: [AppColors.myBubble, AppColors.myBubbleDark], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: isOwn ? null : (isAi ? AppColors.aiBubble : AppColors.otherBubble),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isOwn ? 16 : 4),
          bottomRight: Radius.circular(isOwn ? 4 : 16),
        ),
        border: isAi ? Border.all(color: AppColors.aiAccent.withOpacity(0.3), width: 1) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Forwarded indicator
          if (isForwarded)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: isOwn ? Colors.white38 : AppColors.primary, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Переслано от ${message.forwardFromUser}', style: TextStyle(color: isOwn ? Colors.white70 : AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          // Reply
          if (message.replyTo != null && message.replyContent != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: isOwn ? Colors.white54 : AppColors.primary, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.replySender ?? 'Ответ', style: TextStyle(color: isOwn ? Colors.white70 : AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  Text(message.replyContent!, style: TextStyle(color: isOwn ? Colors.white60 : AppColors.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          // AI label
          if (isAi)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.auto_awesome, color: AppColors.aiAccent, size: 13),
                const SizedBox(width: 4),
                Text('AI-ответ', style: const TextStyle(color: AppColors.aiAccent, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          // Content
          Text(
            message.content,
            style: TextStyle(
              color: isOwn ? Colors.white : AppColors.textPrimary,
              fontSize: 14.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          // Time + edited
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (message.editedAt != null)
                Text('изменено  ', style: TextStyle(color: isOwn ? Colors.white54 : AppColors.textMuted, fontSize: 10)),
              Text(
                _formatTime(message.createdAt),
                style: TextStyle(color: isOwn ? Colors.white54 : AppColors.textMuted, fontSize: 10.5),
              ),
              if (isOwn) ...[
                const SizedBox(width: 4),
                Icon(Icons.done_all, size: 14, color: Colors.white54),
              ],
            ],
          ),
          // Reactions
          if (message.reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: message.reactions.map((r) {
                  final myReaction = r.users.contains(currentUserId);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: myReaction
                          ? AppColors.primary.withOpacity(0.25)
                          : Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: myReaction ? Border.all(color: AppColors.primary.withOpacity(0.5)) : null,
                    ),
                    child: Text('${r.emoji} ${r.count}', style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ReplyBar extends StatelessWidget {
  final Message? replyTo;
  final Message? editing;
  final VoidCallback onCancel;
  const _ReplyBar({this.replyTo, this.editing, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final isEdit = editing != null;
    final msg = isEdit ? editing! : replyTo!;
    return Container(
      color: AppColors.bg3,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(isEdit ? Icons.edit : Icons.reply, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Container(width: 2, height: 32, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Редактирование' : 'Ответить ${msg.senderName}', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(msg.content, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(onPressed: onCancel, icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18)),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onTyping;
  final VoidCallback onSend;
  final VoidCallback onEmojiToggle;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onTyping,
    required this.onSend,
    required this.onEmojiToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg2,
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined, color: AppColors.textMuted),
            onPressed: onEmojiToggle,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              maxLines: 5,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Сообщение...',
                fillColor: AppColors.bg3,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(22)), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: onTyping,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 6),
          AnimatedBuilder(
            animation: controller,
            builder: (_, __) => GestureDetector(
              onTap: sending ? null : onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: controller.text.trim().isEmpty ? null : const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  color: controller.text.trim().isEmpty ? AppColors.bg4 : null,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: controller.text.trim().isEmpty ? AppColors.textMuted : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _OptionTile({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.primary, size: 22),
      title: Text(label, style: TextStyle(color: color ?? AppColors.textPrimary)),
      onTap: onTap,
    );
  }
}
