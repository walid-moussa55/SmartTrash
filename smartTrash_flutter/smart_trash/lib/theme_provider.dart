import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? true;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  // ── Themes ──
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppTheme.primary,
      secondary: AppTheme.mid,
      surface: AppTheme.surface,
      onPrimary: Colors.white,
      onSurface: AppTheme.textPrimary,
      error: AppTheme.alert,
    ),
    scaffoldBackgroundColor: AppTheme.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppTheme.bg,
      foregroundColor: AppTheme.textPrimary,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: AppTheme.primary),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border, width: 1.2),
      ),
      color: AppTheme.surface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppTheme.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.mid, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.alert, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.alert, width: 1.8),
      ),
      errorStyle: const TextStyle(color: AppTheme.alert, fontSize: 12),
      prefixIconColor: AppTheme.mid,
      labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
    ),
    dividerTheme: const DividerThemeData(color: AppTheme.border, thickness: 1),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8, color: AppTheme.primary),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
      headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
      bodyLarge: TextStyle(fontSize: 16, color: AppTheme.textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppTheme.pale,
      selectedColor: AppTheme.light,
      labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.primary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: const BorderSide(color: AppTheme.light, width: 1),
      ),
    ),
    iconTheme: const IconThemeData(color: AppTheme.mid),
  );

  static ThemeData get darkTheme {
    const darkBg = Color(0xFF151B16);
    const darkSurface = Color(0xFF1D261F);
    const darkBorder = Color(0xFF2E3D31);
    const textPrimary = AppTheme.bg; // #F5F3EE
    const textSecondary = AppTheme.light; // #8EBF93
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppTheme.light,
        secondary: AppTheme.pale,
        surface: darkSurface,
        onPrimary: darkBg,
        onSurface: textPrimary,
        error: AppTheme.alert,
      ),
      scaffoldBackgroundColor: darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppTheme.light),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1.2),
        ),
        color: darkSurface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.light,
          foregroundColor: darkBg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.light, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.alert, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.alert, width: 1.8),
        ),
        errorStyle: const TextStyle(color: AppTheme.alert, fontSize: 12),
        prefixIconColor: AppTheme.light,
        labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8, color: AppTheme.light),
        headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: AppTheme.primary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.pale),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: darkSurface,
      ),
      iconTheme: const IconThemeData(color: AppTheme.light),
    );
  }
}
