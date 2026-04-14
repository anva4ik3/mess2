import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/chat.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/avatar.dart';
import '../chats/chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];
  List<Contact> _filtered = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getContacts();
      if (!mounted) return;
      setState(() {
        _contacts = data.map((j) => Contact.fromJson(j as Map<String, dynamic>)).toList();
        _applyFilter();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _search.toLowerCase();
    _filtered = q.isEmpty
        ? List.from(_contacts)
        : _contacts.where((c) =>
            c.displayLabel.toLowerCase().contains(q) ||
            c.username.toLowerCase().contains(q)).toList();
  }

  void _addContact() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _AddContactSheet(onAdded: () {
        Navigator.pop(context);
        _load();
      }),
    );
  }

  void _openContact(Contact c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ContactActions(
        contact: c,
        onOpenChat: () async {
          Navigator.pop(context);
          final result = await ApiService.openDirectChat(c.userId);
          if (!mounted) return;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChatScreen(chatId: result['chatId']),
          ));
        },
        onRemove: () async {
          Navigator.pop(context);
          await ApiService.removeContact(c.userId);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = _filtered.where((c) => c.isOnline).toList();
    final offline = _filtered.where((c) => !c.isOnline).toList();

    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        title: const Text('Контакты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined, color: AppColors.primary),
            onPressed: _addContact,
            tooltip: 'Добавить контакт',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    onChanged: (q) { setState(() { _search = q; _applyFilter(); }); },
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Поиск контактов...',
                      fillColor: AppColors.bg3,
                      prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    backgroundColor: AppColors.bg2,
                    onRefresh: _load,
                    child: _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: AppColors.textMuted.withOpacity(0.4)),
                                const SizedBox(height: 16),
                                Text(
                                  _search.isEmpty ? 'Нет контактов' : 'Ничего не найдено',
                                  style: const TextStyle(color: AppColors.textMuted),
                                ),
                                if (_search.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: _addContact,
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Добавить'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView(
                            children: [
                              if (online.isNotEmpty) ...[
                                _SectionHeader(title: 'В сети (${online.length})'),
                                ...online.map((c) => _ContactTile(contact: c, onTap: () => _openContact(c))),
                              ],
                              if (offline.isNotEmpty) ...[
                                _SectionHeader(title: 'Не в сети (${offline.length})'),
                                ...offline.map((c) => _ContactTile(contact: c, onTap: () => _openContact(c))),
                              ],
                            ],
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  const _ContactTile({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String subtitle = '@${contact.username}';
    if (contact.statusText != null && contact.statusText!.isNotEmpty) {
      subtitle = contact.statusText!;
    } else if (!contact.isOnline && contact.lastSeenAt != null) {
      subtitle = 'Был(а) ${timeago.format(contact.lastSeenAt!, locale: 'ru')}';
    } else if (contact.isOnline) {
      subtitle = 'В сети';
    }

    return ListTile(
      onTap: onTap,
      leading: AppAvatar(
        name: contact.displayLabel,
        url: contact.avatarUrl,
        size: 48,
        showOnline: true,
        isOnline: contact.isOnline,
      ),
      title: Text(contact.displayLabel, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(
        color: contact.isOnline ? AppColors.green : AppColors.textSecondary,
        fontSize: 12,
      )),
      trailing: IconButton(
        icon: const Icon(Icons.message_outlined, color: AppColors.primary, size: 20),
        onPressed: onTap,
      ),
    );
  }
}

class _ContactActions extends StatelessWidget {
  final Contact contact;
  final VoidCallback onOpenChat;
  final VoidCallback onRemove;
  const _ContactActions({required this.contact, required this.onOpenChat, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAvatar(name: contact.displayLabel, url: contact.avatarUrl, size: 72),
          const SizedBox(height: 12),
          Text(contact.displayLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text('@${contact.username}', style: const TextStyle(color: AppColors.textSecondary)),
          if (contact.bio != null) ...[
            const SizedBox(height: 8),
            Text(contact.bio!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          _ActionButton(icon: Icons.chat_bubble_outline, label: 'Открыть чат', onTap: onOpenChat),
          _ActionButton(icon: Icons.person_remove_outlined, label: 'Удалить из контактов', color: AppColors.red, onTap: onRemove),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.primary),
      title: Text(label, style: TextStyle(color: color ?? AppColors.textPrimary)),
      onTap: onTap,
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddContactSheet({required this.onAdded});
  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.textMuted.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Добавить контакт', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              onChanged: _search,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Поиск @username или имени',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: _loading
                ? const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final u = _results[i];
                      return ListTile(
                        leading: AppAvatar(name: u['display_name'] ?? u['username'], url: u['avatar_url'], size: 44),
                        title: Text(u['display_name'] ?? u['username'], style: const TextStyle(color: AppColors.textPrimary)),
                        subtitle: Text('@${u['username']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_add, color: AppColors.primary),
                          onPressed: () async {
                            await ApiService.addContact(u['id'] as String);
                            widget.onAdded();
                          },
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
