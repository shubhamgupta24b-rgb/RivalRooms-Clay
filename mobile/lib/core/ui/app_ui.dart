import 'package:flutter/material.dart';
import 'app_flavor.dart';
import 'app_theme_ext.dart';
import 'party_logo.dart';

export 'app_theme_ext.dart';
export 'party_logo.dart';

/// Colours taken from the app logo: deep navy, neon blue vs red, and gold.
/// The flat app swaps the navy for board-game blues (sky background, dark-blue panels).
/// Thin aliases to the design tokens (tokens.dart); new code reads `context.tk` instead.
class AppColors {
  static const navy = flatStyle ? FlatPalette.board : Brand.navy;
  static const night = flatStyle ? Color(0xFF1D5276) : Brand.night;
  static const deep = flatStyle ? Color(0xFF17435F) : Brand.deep;
  static const blue = Brand.blue;
  static const red = Brand.red;
  static const gold = Brand.gold;
  static const purple = Brand.purple;
  static const green = Brand.green;
  static const text = Colors.white;
  static const muted = flatStyle ? Color(0xFFEAF4FB) : NeonPalette.textMuted;
  static const glass = flatStyle ? Color(0x2EFFFFFF) : Color(0x1AFFFFFF);
  static const stroke = flatStyle ? Color(0x4DFFFFFF) : NeonPalette.stroke;
}

/// The token set for app screens in this build.
final appTokens = flatStyle ? GameTokens.flatSet : GameTokens.neon;

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.purple, brightness: Brightness.dark).copyWith(
    primary: AppColors.gold,
    onPrimary: AppColors.night,
    secondary: AppColors.blue,
    surface: AppColors.night,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: Fonts.body,
    colorScheme: scheme,
    extensions: [appTokens],
    scaffoldBackgroundColor: AppColors.deep,
    pageTransitionsTheme: Skin.pageTransitions,
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.night, foregroundColor: Colors.white, centerTitle: true),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.navy, contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.night),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Skin.fieldFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Skin.rChip), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Skin.rChip), borderSide: const BorderSide(color: Skin.fieldFocus, width: 2)),
      hintStyle: const TextStyle(color: Colors.white54),
    ),
  );
}

/// Every app page's background: the skin's world.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => flatStyle ? FlatBackground(child: child) : Skin.background(child: child);
}

/// The app logo with a soft neon glow behind it.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 180});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppColors.blue.withValues(alpha: 0.35), blurRadius: size * 0.3, offset: Offset(-size * 0.06, 0)),
            BoxShadow(color: AppColors.red.withValues(alpha: 0.3), blurRadius: size * 0.3, offset: Offset(size * 0.06, 0)),
          ],
        ),
        child: PartyLogoIcon(size: size),
      );
}

/// Small caps heading for a section of a page.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10, left: 2),
        child: Row(children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.6))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Rounded gradient card that sinks slightly when pressed.
class PressableCard extends StatefulWidget {
  final List<Color> colors;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  const PressableCard({super.key, required this.colors, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.semanticLabel});
  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? Skin.pressScale : 1,
          duration: const Duration(milliseconds: 110),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            padding: widget.padding,
            decoration: Skin.surface(tint: widget.colors.first, pressed: _down),
            child: Opacity(opacity: enabled ? 1 : 0.55, child: widget.child),
          ),
        ),
      ),
    );
  }
}
