import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/chat.dart';
import '../../services/api.dart';
import '../../services/ws.dart';
import '../../theme.dart';
import '../../widgets/avatar.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<Chat> _chats = [];
  List<Chat> _filtered = [];
  bool _loading = true;
  String _search = '';
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ru', timeago.RuMessages());
    _load();
    _wsSub = wsService.messages.listen(_onWsMsg);
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getChats();
      if (!mounted) return;
      setState(() {
        _chats = data.map((j) => Chat.fromJson(j as Map<String, dynamic>)).toList();
        _applyFilter();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onWsMsg(Map<String, dynamic> msg) {
    final type = msg['type'];
    if (type == 'new_message') {
      _load();
    } else if (type == 'user_status') {
      final userId = msg['userId'] as String;
      final isOnline = msg['isOnline'] as bool;
      setState(() {
        _chats = _chats.map((c) {
          if (c.otherUserId == userId) return c.copyWith(otherUserOnline: isOnline);
          return c;
        }).toList();
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    final q = _search.toLowerCase();
    _filtered = q.isEmpty
        ? List.from(_chats)
        : _chats.where((c) => c.displayName.toLowerCase().contains(q)).toList();
  }

  void _onSearch(String q) {
    setState(() { _search = q; _applyFilter(); });
  }

  void _openNewChat(BuildContext context) async {
    final data = await ApiService.searchUsersGlobal('');
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _NewChatSheet(onStart: (userId) async {
        final result = await ApiService.openDirectChat(userId);
        if (!context.mounted) return;
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: result['chatId']),
        ));
        _load();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        title: const Text('Сообщения'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: AppColors.primary),
            onPressed: () => _openNewChat(context),
            tooltip: 'Новый чат',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: _onSearch,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Поиск чатов...',
                fillColor: AppColors.bg3,
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18), onPressed: () { setState(() { _search = ''; _applyFilter(); }); })
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty
                    ? _EmptyState(hasSearch: _search.isNotEmpty)
                    : RefreshIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.bg2,
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _ChatTile(chat: _filtered[i], onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ChatScreen(chatId: _filtered[i].id),
                            ));
                            _load();
                          }),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;
  const _ChatTile({required this.chat, required this.onTap});

  String get _preview {
    if (chat.lastMessage == null) return 'Нет сообщений';
    if (chat.lastMessageType == 'image') return '📷 Изображение';
    if (chat.lastMessageType == 'file') return '📎 Файл';
    if (chat.lastMessageType == 'ai') return '🤖 ${chat.lastMessage!}';
    return chat.lastMessage!;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            AppAvatar(
              name: chat.displayName,
              url: chat.displayAvatar,
              size: 52,
              showOnline: chat.type == 'direct',
              isOnline: chat.otherUserOnline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.displayName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.lastMessageAt != null)
                        Text(
                          timeago.format(chat.lastMessageAt!, locale: 'ru'),
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (chat.isMuted)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.volume_off, size: 13, color: AppColors.textMuted),
                        ),
                      Expanded(
                        child: Text(
                          _preview,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: chat.isMuted ? AppColors.textMuted : AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hasSearch ? Icons.search_off : Icons.chat_bubble_outline_rounded,
              size: 64, color: AppColors.textMuted.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'Ничего не найдено' : 'Нет чатов\nНажмите ✏️ чтобы начать',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NewChatSheet extends StatefulWidget {
  final Future<void> Function(String userId) onStart;
  const _NewChatSheet({required this.onStart});
  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  List<dynamic> _results = [];
  bool _loading = false;
  Timer? _debounce;

  void _search(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) { setState(() => _results = []); return; }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _loading = true);
      try {
        final r = await ApiService.searchUsersGlobal(q.trim());
        if (mounted) setState(() { _results = r; _loading = false; });
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.textMuted.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Новый чат', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              onChanged: _search,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Поиск по имени или @username',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    controller: ctrl,
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final u = _results[i];
                      return ListTile(
                        leading: AppAvatar(
                          name: u['display_name'] ?? u['username'],
                          url: u['avatar_url'],
                          size: 44,
                          showOnline: true,
                          isOnline: u['is_online'] ?? false,
                        ),
                        title: Text(u['display_name'] ?? u['username'], style: const TextStyle(color: AppColors.textPrimary)),
                        subtitle: Text('@${u['username']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        onTap: () => widget.onStart(u['id']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
