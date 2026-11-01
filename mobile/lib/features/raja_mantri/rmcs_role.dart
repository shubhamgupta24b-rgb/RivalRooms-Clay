import 'package:flutter/material.dart';

/// The four cards. Points match the server (server/src/games/raja_mantri).
enum RmcsRole {
  raja(
      'RAJA',
      'THE KING',
      '👑',
      'R',
      [Color(0xFFFFE9A8), Color(0xFFF5B72E), Color(0xFFB07A10)],
      Color(0xFF4A2C00),
      Color(0xFFFFD34D)),
  mantri(
      'MANTRI',
      'THE STRATEGIST',
      '🧠',
      'M',
      [Color(0xFF5EC8F2), Color(0xFF2E6FD8), Color(0xFF1A2F7A)],
      Colors.white,
      Color(0xFF7FD3FF)),
  sipahi(
      'SIPAHI',
      'THE GUARD',
      '👮',
      'S',
      [Color(0xFF8FA6C4), Color(0xFF4D6587), Color(0xFF233247)],
      Colors.white,
      Color(0xFFB8CCE6)),
  chor(
      'CHOR',
      'THE THIEF',
      '🕵️',
      'C',
      [Color(0xFF5B3A7A), Color(0xFF2A1D3D), Color(0xFF0D0A14)],
      Color(0xFFE6D7FF),
      Color(0xFFB57BFF));

  final String title;
  final String subtitle;
  final String emoji;
  final String letter;
  final List<Color> gradient;
  final Color ink;
  final Color glow;
  const RmcsRole(this.title, this.subtitle, this.emoji, this.letter,
      this.gradient, this.ink, this.glow);

  static RmcsRole parse(String s) =>
      RmcsRole.values.firstWhere((r) => r.name == s);

  /// Points this role scores in a round where the Chor was [caught] (or not).
  int points({required bool caught}) => switch (this) {
        RmcsRole.raja => 1000,
        RmcsRole.sipahi => 300,
        RmcsRole.mantri => caught ? 500 : 0,
        RmcsRole.chor => caught ? 0 : 500,
      };

  String get pointsLine => switch (this) {
        RmcsRole.raja => '+1000 EVERY ROUND',
        RmcsRole.sipahi => '+300 EVERY ROUND',
        RmcsRole.mantri => '+500 IF YOU CATCH THE CHOR',
        RmcsRole.chor => '+500 IF YOU ESCAPE',
      };
}
