import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/chat.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/avatar.dart';
import 'channel_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});
  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Channel> _myChannels = [];
  List<Channel> _exploreChannels = [];
  bool _loadingMy = true;
  bool _loadingExplore = false;
  String _search = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging && _tabCtrl.index == 1) _loadExplore(''); });
    _loadMy();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadMy() async {
    try {
      final data = await ApiService.myChannels();
      if (!mounted) return;
      setState(() {
        _myChannels = data.map((j) => Channel.fromJson(j as Map<String, dynamic>)).toList();
        _loadingMy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMy = false);
    }
  }

  Future<void> _loadExplore([String q = '']) async {
    setState(() => _loadingExplore = true);
    try {
      final data = await ApiService.exploreChannels(q: q.isEmpty ? null : q);
      if (!mounted) return;
      setState(() { _exploreChannels = data.map((j) => Channel.fromJson(j as Map<String, dynamic>)).toList(); });
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingExplore = false);
    }
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _loadExplore(q));
  }

  void _createChannel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateChannelSheet(onCreate: () {
        Navigator.pop(context);
        _loadMy();
      }),
    );
  }

  void _openChannel(Channel c) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelScreen(channel: c))).then((_) {
      _loadMy();
      if (_tabCtrl.index == 1) _loadExplore(_search);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        title: const Text('Каналы'),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.primary), onPressed: _createChannel),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [Tab(text: 'Мои подписки'), Tab(text: 'Обзор')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // My channels
          _loadingMy
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.bg2,
                  onRefresh: _loadMy,
                  child: _myChannels.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.rss_feed, size: 64, color: AppColors.textMuted.withOpacity(0.4)),
                              const SizedBox(height: 16),
                              const Text('Нет подписок', style: TextStyle(color: AppColors.textMuted)),
                              TextButton(onPressed: () => _tabCtrl.animateTo(1), child: const Text('Найти каналы')),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _myChannels.length,
                          itemBuilder: (_, i) => _ChannelTile(channel: _myChannels[i], onTap: () => _openChannel(_myChannels[i])),
                        ),
                ),
          // Explore
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  onChanged: _onSearch,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Поиск каналов...',
                    fillColor: AppColors.bg3,
                    prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  ),
                ),
              ),
              Expanded(
                child: _loadingExplore
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _exploreChannels.isEmpty
                        ? const Center(child: Text('Каналы не найдены', style: TextStyle(color: AppColors.textMuted)))
                        : ListView.builder(
                            itemCount: _exploreChannels.length,
                            itemBuilder: (_, i) => _ChannelTile(channel: _exploreChannels[i], onTap: () => _openChannel(_exploreChannels[i]), showSubscribe: true, onSubscribe: () async {
                              await ApiService.subscribeChannel(_exploreChannels[i].id);
                              _loadExplore(_search);
                              _loadMy();
                            }),
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final bool showSubscribe;
  final VoidCallback? onSubscribe;
  const _ChannelTile({required this.channel, required this.onTap, this.showSubscribe = false, this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: AppAvatar(name: channel.name, url: channel.avatarUrl, size: 48),
      title: Row(
        children: [
          Expanded(child: Text(channel.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          if (channel.isOwner) Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: const Text('Мой', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          if (channel.monthlyPrice > 0) Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.yellow.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Text('₽${channel.monthlyPrice.toStringAsFixed(0)}/мес', style: const TextStyle(color: AppColors.yellow, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Icon(Icons.people, size: 12, color: AppColors.textMuted.withOpacity(0.7)),
          const SizedBox(width: 4),
          Text('${channel.subscriberCount}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          if (channel.lastPost != null) ...[
            const Text('  ·  ', style: TextStyle(color: AppColors.textMuted)),
            Expanded(child: Text(channel.lastPost!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ],
      ),
      trailing: showSubscribe && !channel.isOwner
          ? GestureDetector(
              onTap: onSubscribe,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: channel.isSubscribed ? AppColors.bg4 : AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  channel.isSubscribed ? 'Подписан' : 'Подписаться',
                  style: TextStyle(
                    color: channel.isSubscribed ? AppColors.textSecondary : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _CreateChannelSheet extends StatefulWidget {
  final VoidCallback onCreate;
  const _CreateChannelSheet({required this.onCreate});
  @override
  State<_CreateChannelSheet> createState() => _CreateChannelSheetState();
}

class _CreateChannelSheetState extends State<_CreateChannelSheet> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty || _usernameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Название и @username обязательны');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.createChannel(
        _usernameCtrl.text.trim().toLowerCase(),
        _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      widget.onCreate();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Создать канал', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          TextField(controller: _nameCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'Название канала'), textInputAction: TextInputAction.next),
          const SizedBox(height: 12),
          TextField(controller: _usernameCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: '@username', prefixText: '@', prefixStyle: TextStyle(color: AppColors.primary)), textInputAction: TextInputAction.next),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'Описание (необязательно)'), maxLines: 3, textInputAction: TextInputAction.done),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12))),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _loading ? null : _create, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Создать')),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
