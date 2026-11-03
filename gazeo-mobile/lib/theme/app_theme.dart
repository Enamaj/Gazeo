import 'package:flutter/material.dart';

/// Système de design officiel GAZEO inspiré des tokens Tailwind CSS
/// Reproduisant fidèlement les 12 écrans de la maquette utilisateur.
class AppColors {
  // Bleus Royaux (Brand GAZEO)
  static const Color primary = Color(0xFF1D4ED8); // Tailwind blue-700 / Royal Blue
  static const Color primaryLight = Color(0xFF3B82F6); // Tailwind blue-500
  static const Color primaryDark = Color(0xFF1E3A8A); // Tailwind blue-900
  static const Color blue50 = Color(0xFFEFF6FF); // Fond badges & icônes
  static const Color blue100 = Color(0xFFDBEAFE);

  // Orange d'action (CTA accueil, badges, notes)
  static const Color orange = Color(0xFFF97316); // Tailwind orange-500
  static const Color orangeDark = Color(0xFFEA580C);
  static const Color orangeLight = Color(0xFFFB923C);
  static const Color orange50 = Color(0xFFFFF7ED);

  // Thème Sombre (Écran d'accueil & Choix du compte)
  static const Color darkNavy = Color(0xFF0A192F);
  static const Color darkNavyDeep = Color(0xFF071120);
  static const Color darkCard = Color(0xFF132F5C);
  static const Color darkCardBorder = Color(0xFF1E40AF);

  // Neutres & Toile (Fond clair épuré)
  static const Color background = Color(0xFFF8FAFC); // Tailwind slate-50
  static const Color card = Colors.white;
  static const Color slate900 = Color(0xFF0F172A); // Texte principal
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569); // Texte secondaire
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8); // Bordures légères & placeholder
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);

  // Statuts & Badges
  static const Color success = Color(0xFF10B981); // Tailwind emerald-500 (Ouvert, À venir)
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.orange,
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.slate900, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.slate600, fontSize: 14),
        titleLarge: TextStyle(color: AppColors.slate900, fontWeight: FontWeight.w700, fontSize: 18),
        titleMedium: TextStyle(color: AppColors.slate900, fontWeight: FontWeight.w600, fontSize: 16),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.slate900,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.slate100, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}

