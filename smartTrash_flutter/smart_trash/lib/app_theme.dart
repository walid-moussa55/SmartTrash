import 'package:flutter/material.dart';

class AppTheme {
  // ── Fonds & Surfaces ──
  static const Color bg = Color(0xFFF5F3EE);
  static const Color surface = Color(0xFFDCF0E0);
  static const Color border = Color(0xFFE2DDD5);

  // ── Verts - Primaire ──
  static const Color primary = Color(0xFF2A4A30);
  static const Color mid = Color(0xFF5C8E60);
  static const Color light = Color(0xFF8EBF93);
  static const Color pale = Color(0xFFDCF0E0);

  // ── Alerte - Ocre Naturel ──
  static const Color alert = Color(0xFFB86B2A);
  static const Color alertPale = Color(0xFFF0E8DC);

  // ── Textes ──
  static const Color textPrimary = Color(0xFF2A4A30);
  static const Color textSecondary = Color(0xFF7A8A7C);
  static const Color textMuted = Color(0xFF9EAC9F);

  static Route slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
          child: child,
        );
      },
    );
  }
}
