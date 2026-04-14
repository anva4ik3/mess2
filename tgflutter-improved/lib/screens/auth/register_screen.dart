import 'package:flutter/material.dart';
import '../../services/api.dart';
import '../../services/ws.dart';
import '../../theme.dart';
import '../home_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String email;
  const RegisterScreen({super.key, required this.email});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _usernameError;

  void _validateUsername(String v) {
    final val = v.toLowerCase();
    if (val.length < 3) {
      setState(() => _usernameError = 'Минимум 3 символа');
    } else if (!RegExp(r'^[a-z0-9_]+$').hasMatch(val)) {
      setState(() => _usernameError = 'Только латиница, цифры и _');
    } else {
      setState(() => _usernameError = null);
    }
  }

  Future<void> _register() async {
    if (_usernameError != null || _usernameCtrl.text.trim().length < 3) return;
    setState(() => _loading = true);
    try {
      await ApiService.register(
        widget.email,
        _usernameCtrl.text.trim().toLowerCase(),
        _nameCtrl.text.trim().isEmpty ? _usernameCtrl.text.trim() : _nameCtrl.text.trim(),
      );
      if (!mounted) return;
      wsService.reset();
      wsService.connect();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(backgroundColor: Colors.transparent, leading: const BackButton()),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Создать аккаунт',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Придумайте имя пользователя',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 40),
            const Text('Имя пользователя', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _usernameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'username',
                prefixText: '@',
                prefixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
                errorText: _usernameError,
                errorStyle: const TextStyle(color: AppColors.red),
              ),
              onChanged: _validateUsername,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
            const Text('Отображаемое имя (необязательно)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Как вас зовут?'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _register(),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Создать аккаунт'),
            ),
          ],
        ),
      ),
    );
  }
}
