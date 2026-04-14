import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/avatar.dart';

class ChannelScreen extends StatefulWidget {
  final Channel channel;
  const ChannelScreen({super.key, required this.channel});
  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  late Channel _channel;
  List<dynamic> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
    _loadPosts();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 && !_loadingMore && _posts.isNotEmpty) {
      _loadMorePosts();
    }
  }

  Future<void> _loadPosts() async {
    try {
      final data = await ApiService.getChannelPosts(_channel.id);
      if (!mounted) return;
      setState(() { _posts = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final oldest = _posts.last['created_at'] as String;
      final more = await ApiService.getChannelPosts(_channel.id, before: oldest);
      if (!mounted) return;
      setState(() => _posts.addAll(more));
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleSubscribe() async {
    try {
      final result = await ApiService.subscribeChannel(_channel.id);
      setState(() {
        _channel = Channel(
          id: _channel.id,
          username: _channel.username,
          name: _channel.name,
          description: _channel.description,
          avatarUrl: _channel.avatarUrl,
          ownerName: _channel.ownerName,
          subscriberCount: _channel.subscriberCount + (result['subscribed'] ? 1 : -1),
          isPublic: _channel.isPublic,
          monthlyPrice: _channel.monthlyPrice,
          isSubscribed: result['subscribed'],
          isOwner: _channel.isOwner,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red),
      );
    }
  }

  void _createPost() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Новый пост', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 6,
              minLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Напишите пост...'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                await ApiService.createPost(_channel.id, ctrl.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadPosts();
              },
              child: const Text('Опубликовать'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.bg2,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
              title: Text(_channel.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.bg3, AppColors.bg2],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      AppAvatar(name: _channel.name, url: _channel.avatarUrl, size: 72),
                      const SizedBox(height: 8),
                      Text('@${_channel.username}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              if (_channel.isOwner)
                IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.primary), onPressed: _createPost)
              else
                TextButton(
                  onPressed: _toggleSubscribe,
                  child: Text(
                    _channel.isSubscribed ? 'Отписаться' : 'Подписаться',
                    style: TextStyle(color: _channel.isSubscribed ? AppColors.textMuted : AppColors.primary),
                  ),
                ),
            ],
          ),
          // Channel info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text('${_channel.subscriberCount} подписчиков', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const Spacer(),
                      if (_channel.monthlyPrice > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.yellow.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text('₽${_channel.monthlyPrice.toStringAsFixed(0)}/мес', style: const TextStyle(color: AppColors.yellow, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  if (_channel.description != null && _channel.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_channel.description!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                  ],
                  const Divider(height: 24),
                ],
              ),
            ),
          ),
          // Posts
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_posts.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.article_outlined, size: 56, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('Нет постов', style: TextStyle(color: AppColors.textMuted)),
                ],
              )),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  if (i == _posts.length) {
                    return _loadingMore
                        ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
                        : const SizedBox.shrink();
                  }
                  final post = _posts[i];
                  return _PostCard(post: post, isOwner: _channel.isOwner, onDelete: () async {
                    await ApiService.deletePost(_channel.id, post['id'] as String);
                    _loadPosts();
                  });
                },
                childCount: _posts.length + 1,
              ),
            ),
        ],
      ),
      floatingActionButton: _channel.isOwner
          ? FloatingActionButton(
              onPressed: _createPost,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isOwner;
  final VoidCallback onDelete;
  const _PostCard({required this.post, required this.isOwner, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.parse(post['created_at'] as String).toLocal();
    final formatted = DateFormat('d MMM y, HH:mm', 'ru_RU').format(createdAt);
    final isPaid = post['is_paid'] == true;
    final views = post['views'] ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: isPaid ? Border.all(color: AppColors.yellow.withOpacity(0.3)) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPaid)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.yellow.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.star, color: AppColors.yellow, size: 12),
                  SizedBox(width: 4),
                  Text('Платный контент', style: TextStyle(color: AppColors.yellow, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            Text(post['content'] as String, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, height: 1.45)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.visibility_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text('$views', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const Spacer(),
                Text(formatted, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                if (isOwner) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
