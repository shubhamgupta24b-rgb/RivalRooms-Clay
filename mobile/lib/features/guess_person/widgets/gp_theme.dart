import 'package:flutter/material.dart';
import '../../../core/ui/app_flavor.dart';
import '../../../core/ui/components.dart';
import '../../../core/ui/materials/materials.dart';

/// Guess the Person's colours, now aliases to the design tokens.
class GpColors {
  static const bgTop = NeonPalette.bgTop;
  static const bgBottom = NeonPalette.bgBottom;
  static const card = Color(0xFFFFF8EC);
  static const ink = Brand.ink;
  static const accent = Brand.gold;
  static const yes = StatusColors.success;
  static const no = StatusColors.danger;
  static const muted = flatStyle ? Color(0xFFEAF4FB) : NeonPalette.textMuted;
  static const panel = NeonPalette.glassStrong;
  static const portraitBgs = [
    Color(0xFFFFD6A5), Color(0xFFCAFFBF), Color(0xFF9BF6FF), Color(0xFFBDB2FF),
    Color(0xFFFFC6FF), Color(0xFFFDFFB6), Color(0xFFA0C4FF), Color(0xFFFFADAD),
  ];
}

/// Guess the Person's board look (spec 4.12): the night table with a felt board, or sky
/// blue with the dark-blue board in the flat app.
class GpCoral {
  static const bg = flatStyle ? FlatColors.sky : NeonPalette.bg;
  static const mark = Color(0x22FFFFFF); // faint "?" shapes (flat app)
  static const board = flatStyle ? FlatColors.board : FeltPainter.mid;
  static const nameStrip = Color(0xFF3A3846);
  static const tile = Colors.white;
  static const tileInk = Color(0xFF2B2A35);
  static const panel = Color(0xF2121640); // the sheet colour, for text-heavy panels
  static const closeBlue = Color(0xFF7FA8E8);
}

/// The background of every Guess the Person screen: night (or sky with "?" marks when flat).
class CoralBackground extends StatelessWidget {
  final Widget child;
  const CoralBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => flatStyle
      ? DecoratedBox(decoration: const BoxDecoration(color: GpCoral.bg), child: CustomPaint(painter: const _QuestionMarks(), child: child))
      : DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.45, 1], colors: [NeonPalette.bgTop, NeonPalette.bg, NeonPalette.bgBottom]),
          ),
          child: child,
        );
}

class _QuestionMarks extends CustomPainter {
  const _QuestionMarks();
  // (x, y, size, rotation) as fractions of the screen.
  static const _marks = [
    (0.85, 0.06, 0.28, 0.3),
    (0.08, 0.3, 0.22, -0.4),
    (0.9, 0.45, 0.2, 0.5),
    (0.15, 0.7, 0.3, 0.2),
    (0.75, 0.88, 0.26, -0.3),
    (0.45, 0.55, 0.16, 0.6),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, s, rot) in _marks) {
      final tp = TextPainter(
        text: TextSpan(text: '?', style: TextStyle(fontFamily: Fonts.display, color: GpCoral.mark, fontSize: size.width * s)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(size.width * x, size.height * y);
      canvas.rotate(rot);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The 44 px round close button of the game top bar.
class CircleCloseButton extends StatelessWidget {
  final VoidCallback onPressed;
  const CircleCloseButton({super.key, required this.onPressed});
  @override
  Widget build(BuildContext context) => RoundButton(icon: GameIcons.close, label: 'Leave game', onPressed: onPressed);
}

/// A sheet-coloured rounded panel that keeps text readable over the table.
class DarkPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const DarkPanel({super.key, required this.child, this.padding = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: GpCoral.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: Shadows.large,
        ),
        child: child,
      );
}

/// Full-screen gradient used behind every Guess the Person screen.
class GpBackground extends StatelessWidget {
  final Widget child;
  const GpBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => flatStyle
      ? FlatBackground(child: child)
      : DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [GpColors.bgTop, GpColors.bgBottom]),
          ),
          child: child,
        );
}

/// Chunky party-game button (Lilita, a deeper bottom edge that sinks when pressed). Kept
/// for its many callers: gold by default, any [color] fill, or a light outline. Icons are
/// left out: the shared buttons use drawn icons only.
class GpButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final bool outlined;
  const GpButton(this.label,
      {super.key, this.onPressed, this.color = GpColors.accent, this.textColor = GpColors.ink, this.icon, this.outlined = false});

  @override
  State<GpButton> createState() => _GpButtonState();
}

class _GpButtonState extends State<GpButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    if (w.outlined) return KitButton(w.label, style: KitButtonStyle.outline, height: 54, onPressed: w.onPressed);
    if (w.color == Colors.white || w.color == Colors.white24) return KitButton(w.label, style: KitButtonStyle.soft, height: 54, onPressed: w.onPressed);
    final gold = w.color == GpColors.accent;
    final fill = gold ? Brand.gold : fillFor(w.color);
    final ink = gold ? Brand.onGold : (w.textColor == GpColors.ink ? onColor(fill) : w.textColor);
    final enabled = w.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: w.label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTapCancel: () => setState(() => _down = false),
          onTap: enabled
              ? () {
                  haptic(HapticWeight.selection);
                  w.onPressed!();
                }
              : null,
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            constraints: const BoxConstraints(minHeight: 54),
            transform: Matrix4.translationValues(0, _down ? 4 : 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: Radii.rButton,
              boxShadow: _down || !enabled ? Shadows.edge(gold ? Brand.goldDeep : Color.lerp(fill, Colors.black, 0.4)!, depth: 1) : Shadows.edge(gold ? Brand.goldDeep : Color.lerp(fill, Colors.black, 0.4)!),
            ),
            child: Text(w.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Fonts.display, fontSize: 20, height: 1.1, color: ink)),
          ),
        ),
      ),
    );
  }
}

/// A player and what they are doing: their badge, name and an optional role.
class PlayerTag extends StatelessWidget {
  final String name;
  final Color color;
  final String? role;
  const PlayerTag({super.key, required this.name, required this.color, this.role});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: Radii.rChip, border: Border.all(color: color, width: 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          PlayerBadge(index: PlayerPalette.indexOf(color) ?? 0, size: 20, color: color, initial: name),
          const SizedBox(width: 6),
          Flexible(
            child: Text(name.toUpperCase(),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: Fonts.body, color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
          ),
          if (role != null) ...[
            const SizedBox(width: 6),
            Flexible(child: Text('· $role', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: Fonts.body, color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
          ],
        ]),
      );
}
