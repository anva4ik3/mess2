import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds — глубокий тёмный как у Telegram, но с синим подтоном
  static const bg1 = Color(0xFF0F1923); // самый тёмный
  static const bg2 = Color(0xFF17212B); // панели (Telegram-like)
  static const bg3 = Color(0xFF1C2733); // карточки
  static const bg4 = Color(0xFF242F3D); // input / hover

  // Акценты
  static const primary = Color(0xFF2AABEE);       // Telegram blue
  static const primaryDark = Color(0xFF1A8EC0);
  static const primaryLight = Color(0xFF5CC8FF);
  static const green = Color(0xFF4DB266);
  static const red = Color(0xFFE53935);
  static const yellow = Color(0xFFFFB300);
  static const purple = Color(0xFF7C4DFF);

  // Текст
  static const textPrimary = Color(0xFFE8EDF2);
  static const textSecondary = Color(0xFF8FA3B1);
  static const textMuted = Color(0xFF516A82);

  // Пузыри сообщений
  static const myBubble = Color(0xFF2AABEE);
  static const myBubbleDark = Color(0xFF1A8EC0);
  static const otherBubble = Color(0xFF1C2733);
  static const aiBubble = Color(0xFF0D2133);
  static const aiAccent = Color(0xFF00B4D8);

  // Системные цвета
  static const divider = Color(0xFF1F2E3A);
  static const badge = Color(0xFF2AABEE);
}

class AppGradients {
  static const primary = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const myMessage = LinearGradient(
    colors: [Color(0xFF2AABEE), Color(0xFF1A8EC0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const splash = LinearGradient(
    colors: [Color(0xFF0F1923), Color(0xFF17212B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

ThemeData buildTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg1,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.primaryLight,
      surface: AppColors.bg2,
      error: AppColors.red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg2,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: AppColors.primary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bg2,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg4,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 50),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
      ),
    ),
    dividerColor: AppColors.divider,
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 0.5),
    listTileTheme: const ListTileThemeData(
      tileColor: Colors.transparent,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 15),
      bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    ),
  );
}
