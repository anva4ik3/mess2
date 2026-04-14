import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';

class AppAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;
  final bool showOnline;
  final bool isOnline;

  const AppAvatar({
    super.key,
    required this.name,
    this.url,
    required this.size,
    this.showOnline = false,
    this.isOnline = false,
  });

  Color get _avatarColor {
    final colors = [
      AppColors.primary,
      const Color(0xFF4DB266),
      const Color(0xFFEB459E),
      const Color(0xFFFF7043),
      const Color(0xFF7C4DFF),
      const Color(0xFF00BCD4),
    ];
    if (name.isEmpty) return AppColors.primary;
    return colors[name.codeUnitAt(0) % colors.length];
  }

  String get _initials {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    if (url != null && url!.isNotEmpty) {
      avatar = ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _InitialsAvatar(initials: _initials, color: _avatarColor, size: size),
          errorWidget: (_, __, ___) => _InitialsAvatar(initials: _initials, color: _avatarColor, size: size),
        ),
      );
    } else {
      avatar = _InitialsAvatar(initials: _initials, color: _avatarColor, size: size);
    }

    if (!showOnline) return SizedBox(width: size, height: size, child: avatar);

    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        children: [
          SizedBox(width: size, height: size, child: avatar),
          if (showOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.green : AppColors.textMuted,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg2, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;

  const _InitialsAvatar({required this.initials, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}
