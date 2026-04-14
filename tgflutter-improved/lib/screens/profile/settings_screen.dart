import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/api.dart';

class SettingsScreen extends StatefulWidget {
  final String initialSection; // 'security' | 'notifications' | 'appearance'
  const SettingsScreen({super.key, required this.initialSection});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notifications
  bool _notifyMessages = true;
  bool _notifyMentions = true;
  bool _notifyChannels = false;
  bool _vibration = true;
  bool _sound = true;

  // Appearance
  bool _darkMode = true; // app is dark-only for now
  double _fontSize = 14.5;

  // Security
  bool _biometric = false;
  bool _twoStep = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialSection == 'security'
          ? 0
          : widget.initialSection == 'notifications'
              ? 1
              : 2,
      child: Scaffold(
        backgroundColor: AppColors.bg1,
        appBar: AppBar(
          title: const Text('Настройки'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            tabs: [
              Tab(icon: Icon(Icons.security_outlined), text: 'Безопасность'),
              Tab(icon: Icon(Icons.notifications_outlined), text: 'Уведомления'),
              Tab(icon: Icon(Icons.palette_outlined), text: 'Оформление'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SecurityTab(biometric: _biometric, twoStep: _twoStep,
              onBiometric: (v) => setState(() => _biometric = v),
              onTwoStep: (v) => setState(() => _twoStep = v),
            ),
            _NotificationsTab(
              messages: _notifyMessages,
              mentions: _notifyMentions,
              channels: _notifyChannels,
              vibration: _vibration,
              sound: _sound,
              onMessages: (v) => setState(() => _notifyMessages = v),
              onMentions: (v) => setState(() => _notifyMentions = v),
              onChannels: (v) => setState(() => _notifyChannels = v),
              onVibration: (v) => setState(() => _vibration = v),
              onSound: (v) => setState(() => _sound = v),
            ),
            _AppearanceTab(
              darkMode: _darkMode,
              fontSize: _fontSize,
              onDarkMode: (v) => setState(() => _darkMode = v),
              onFontSize: (v) => setState(() => _fontSize = v),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Security Tab ───────────────────────────────────────────────────────────

class _SecurityTab extends StatelessWidget {
  final bool biometric;
  final bool twoStep;
  final ValueChanged<bool> onBiometric;
  final ValueChanged<bool> onTwoStep;
  const _SecurityTab({required this.biometric, required this.twoStep, required this.onBiometric, required this.onTwoStep});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader('Вход'),
        _SwitchTile(
          icon: Icons.fingerprint,
          title: 'Биометрический вход',
          subtitle: 'Использовать отпечаток пальца или Face ID',
          value: biometric,
          onChanged: onBiometric,
        ),
        _SwitchTile(
          icon: Icons.lock_outline,
          title: 'Двухшаговая проверка',
          subtitle: 'Дополнительный пароль при входе',
          value: twoStep,
          onChanged: (v) {
            if (v) {
              _showTwoStepDialog(context);
            } else {
              onTwoStep(false);
            }
          },
        ),
        const SizedBox(height: 24),
        _SectionHeader('Сессии'),
        _ActionTile(
          icon: Icons.devices_outlined,
          title: 'Активные сессии',
          subtitle: 'Управление устройствами',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Скоро будет доступно'), backgroundColor: AppColors.bg3),
          ),
        ),
        _ActionTile(
          icon: Icons.logout_rounded,
          title: 'Завершить все сессии',
          subtitle: 'Выйти на всех устройствах',
          color: AppColors.red,
          onTap: () => showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppColors.bg3,
              title: const Text('Завершить все сессии?', style: TextStyle(color: AppColors.textPrimary)),
              content: const Text('Вы будете разлогинены на всех устройствах.', style: TextStyle(color: AppColors.textSecondary)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Завершить', style: TextStyle(color: AppColors.red))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTwoStepDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg3,
        title: const Text('Двухшаговая проверка', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Эта функция пока в разработке.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОК')),
        ],
      ),
    );
  }
}

// ─── Notifications Tab ───────────────────────────────────────────────────────

class _NotificationsTab extends StatelessWidget {
  final bool messages, mentions, channels, vibration, sound;
  final ValueChanged<bool> onMessages, onMentions, onChannels, onVibration, onSound;
  const _NotificationsTab({
    required this.messages, required this.mentions, required this.channels,
    required this.vibration, required this.sound,
    required this.onMessages, required this.onMentions, required this.onChannels,
    required this.onVibration, required this.onSound,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader('Уведомления'),
        _SwitchTile(icon: Icons.chat_bubble_outline, title: 'Сообщения', subtitle: 'Уведомлять о новых сообщениях', value: messages, onChanged: onMessages),
        _SwitchTile(icon: Icons.alternate_email, title: 'Упоминания', subtitle: 'Уведомлять при упоминании в группах', value: mentions, onChanged: onMentions),
        _SwitchTile(icon: Icons.rss_feed_rounded, title: 'Каналы', subtitle: 'Уведомлять о новых постах', value: channels, onChanged: onChannels),
        const SizedBox(height: 24),
        _SectionHeader('Звук и вибрация'),
        _SwitchTile(icon: Icons.volume_up_outlined, title: 'Звук', subtitle: 'Воспроизводить звук уведомлений', value: sound, onChanged: onSound),
        _SwitchTile(icon: Icons.vibration, title: 'Вибрация', subtitle: 'Вибрировать при уведомлениях', value: vibration, onChanged: onVibration),
      ],
    );
  }
}

// ─── Appearance Tab ──────────────────────────────────────────────────────────

class _AppearanceTab extends StatelessWidget {
  final bool darkMode;
  final double fontSize;
  final ValueChanged<bool> onDarkMode;
  final ValueChanged<double> onFontSize;
  const _AppearanceTab({required this.darkMode, required this.fontSize, required this.onDarkMode, required this.onFontSize});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader('Тема'),
        _SwitchTile(
          icon: Icons.dark_mode_outlined,
          title: 'Тёмная тема',
          subtitle: 'Сейчас используется тёмная тема',
          value: darkMode,
          onChanged: (v) {
            onDarkMode(v);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Смена темы будет доступна в следующей версии'), backgroundColor: AppColors.bg3),
            );
          },
        ),
        const SizedBox(height: 24),
        _SectionHeader('Текст'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.format_size, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  const Text('Размер текста', style: TextStyle(color: AppColors.textPrimary)),
                  const Spacer(),
                  Text('${fontSize.round()}px', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
              Slider(
                value: fontSize,
                min: 12,
                max: 18,
                divisions: 6,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.bg4,
                onChanged: onFontSize,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('A', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text('Пример текста', style: TextStyle(color: AppColors.textSecondary, fontSize: fontSize)),
                  const Text('A', style: TextStyle(color: AppColors.textMuted, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader('Пузырьки сообщений'),
        _ActionTile(
          icon: Icons.chat_bubble_outline,
          title: 'Стиль пузырьков',
          subtitle: 'Скоро будет доступно',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Скоро будет доступно'), backgroundColor: AppColors.bg3),
          ),
        ),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title.toUpperCase(), style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppColors.primary, size: 22),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppColors.primary, size: 22),
        title: Text(title, style: TextStyle(color: color ?? AppColors.textPrimary, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        onTap: onTap,
      ),
    );
  }
}
