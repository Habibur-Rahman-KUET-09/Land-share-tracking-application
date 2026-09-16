import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kistify's visual identity — teal accent, navy text, soft off-white
/// background, flat white cards. Colors extracted from the design mockups
/// the app's owner supplied (dashboard/report/members/payment-entry/
/// builder-payment/everyone's-account/activity-log/groups-list).
class AppColors {
  AppColors._();

  static const primary = Color(0xFF0F6E5C);
  static const background = Color(0xFFF4F6F5);
  static const surface = Colors.white;
  static const heading = Color(0xFF1B2A4A);
  static const bodyText = Color(0xFF444444);
  static const mutedText = Color(0xFF666666);
  static const border = Color(0xFFDDDDDD);
  static const divider = Color(0xFFEEEEEE);
  static const negative = Color(0xFFA32D2D);

  // Status badge pastel pairs (background, foreground).
  static const approvedBg = Color(0xFFE3F4EC);
  static const approvedFg = Color(0xFF1B6B44);
  static const pendingBg = Color(0xFFFFF3E0);
  static const pendingFg = Color(0xFF8A5300);
  static const rejectedBg = Color(0xFFFCEBEB);
  static const rejectedFg = Color(0xFF791F1F);
  static const cancelledBg = Color(0xFFEDEDED);
  static const cancelledFg = Color(0xFF5A5A5A);
  static const lateBg = Color(0xFFFDECEC);
  static const lateFg = Color(0xFFA32D2D);
  static const partialBg = Color(0xFFFFF3E0);
  static const partialFg = Color(0xFF8A5300);
  static const dueBg = Color(0xFFECEFF1);
  static const dueFg = Color(0xFF546E7A);

  // Role badge pastel pairs.
  static const roleCreatorBg = Color(0xFFEDE7F6);
  static const roleCreatorFg = Color(0xFF4527A0);
  static const roleAdminBg = Color(0xFFE8EAF6);
  static const roleAdminFg = Color(0xFF283593);
  static const roleCollectorBg = Color(0xFFE0F2F1);
  static const roleCollectorFg = Color(0xFF00695C);
  static const roleMemberBg = Color(0xFFECEFF1);
  static const roleMemberFg = Color(0xFF546E7A);

  // General-purpose pastel accent palette — used for per-item leading icon
  // circles (group cards, member avatars, payment-method icons, ...) so
  // lists of similar items don't all read as one flat color.
  static const accentPairs = [
    (Color(0xFFE0F2F1), Color(0xFF00695C)), // teal
    (Color(0xFFFFF3E0), Color(0xFF8A5300)), // amber
    (Color(0xFFEDE7F6), Color(0xFF4527A0)), // purple
    (Color(0xFFFCE4EC), Color(0xFFAD1457)), // rose
    (Color(0xFFE3F2FD), Color(0xFF1565C0)), // blue
    (Color(0xFFE8F5E9), Color(0xFF2E7D32)), // green
  ];

  static (Color, Color) accentFor(Object key) => accentPairs[key.hashCode.abs() % accentPairs.length];
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
      error: AppColors.negative,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.heading,
      displayColor: AppColors.heading,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.heading,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: AppColors.heading, fontSize: 17, fontWeight: FontWeight.w500),
      iconTheme: IconThemeData(color: AppColors.heading),
      // Explicit instead of relying on AppBar's brightness-based default —
      // pins the status bar to the same off-white as the header itself and
      // dark icons/text so it reads as one continuous branded bar, on every
      // screen, instead of occasionally falling back to a plain black strip.
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: const TextStyle(color: AppColors.mutedText, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.heading),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.mutedText,
      indicatorColor: AppColors.primary,
      dividerColor: AppColors.divider,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 13),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: Color(0xFFEEEEEE),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 0.6, space: 1),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    listTileTheme: const ListTileThemeData(
      titleTextStyle: TextStyle(color: AppColors.heading, fontSize: 14, fontWeight: FontWeight.w500),
      subtitleTextStyle: TextStyle(color: AppColors.mutedText, fontSize: 12.5),
    ),
  );
}
