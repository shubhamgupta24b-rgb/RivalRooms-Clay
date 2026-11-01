import 'dart:math' as math;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../audio/game_audio.dart';
import 'app_ui.dart' show AppBackground;
import 'components.dart';

export 'icons/game_icons.dart';

/// The shared game kit (UI_SPEC sections 2.3-2.16): buttons, score cards, banners, chips,
/// frames, the countdown and the feedback layer. Measurements come from the mockups in
/// docs/ui-redesign/mockups.

/// A player's name colour on the night background: their colour, lifted a little
/// (mockups: #2E8BFF -> #6FB0FF, #FF8A1F -> #FFA552).
Color nameColor(Color c) => Color.lerp(c, Colors.white, 0.28)!;

/// Text on the night background for players who are not in focus (#E6E9FF).
const kIdleInk = Color(0xFFE6E9FF);

/// The big gold button (Resume, Start, Rematch): 56-58 px, radius 18, Lilita 22,
/// a 5 px deep-gold edge that sinks when pressed.
class GoldButton extends StatefulWidget {
  final String label;
  final GameIcons? icon;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  const GoldButton(this.label,
      {super.key,
      this.icon,
      this.onPressed,
      this.height = 56,
      this.fontSize = 22});

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final sink = _down && enabled;
    final ink = Skin.primaryInk(enabled: enabled);
    final duration = Motion.of(context, Motion.fast);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        onTap: enabled
            ? () {
                haptic(HapticWeight.selection);
                GameAudio.sfx('tap');
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: sink ? Skin.pressScale : 1,
          duration: duration,
          curve: Motion.standard,
          child: AnimatedContainer(
            duration: duration,
            curve: Motion.standard,
            height: widget.height,
            decoration: Skin.primary(enabled: enabled, pressed: sink),
            padding: const EdgeInsets.symmetric(horizontal: Space.l),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (widget.icon != null) ...[
                GameIcon(widget.icon!, size: 22, color: ink),
                const SizedBox(width: 10)
              ],
              Flexible(
                child: Text(widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: Fonts.display,
                        fontSize: widget.fontSize,
                        height: 1,
                        letterSpacing: widget.fontSize * 0.02,
                        color: ink)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

enum KitButtonStyle {
  /// 2 px light outline, transparent (Change players).
  outline,

  /// Soft fill, no border (All games).
  ghost,

  /// Soft fill with a hairline (Restart, How to play).
  soft,

  /// Red outline and text (Quit game).
  danger,
}

/// The secondary buttons of the mockups: Nunito 900 15, radius 16, 48-52 px.
class KitButton extends StatelessWidget {
  final String label;
  final GameIcons? icon;
  final VoidCallback? onPressed;
  final KitButtonStyle style;
  final double height;
  const KitButton(this.label,
      {super.key,
      this.icon,
      this.onPressed,
      this.style = KitButtonStyle.soft,
      this.height = 48});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final kind = switch (style) {
      KitButtonStyle.outline => SkinButton.outline,
      KitButtonStyle.ghost => SkinButton.ghost,
      KitButtonStyle.soft => SkinButton.soft,
      KitButtonStyle.danger => SkinButton.danger,
    };
    final fg = Skin.secondaryInk(kind, enabled: enabled);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Squash(
        enabled: enabled,
        onTap: enabled
            ? () {
                haptic(HapticWeight.selection);
                GameAudio.sfx('tap');
                onPressed!();
              }
            : null,
        builder: (down) => AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          height: height,
          decoration: Skin.secondary(kind,
              pressed: down, enabled: enabled, radius: height / 2),
          padding: const EdgeInsets.symmetric(horizontal: Space.m),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  GameIcon(icon!, size: 18, color: fg),
                  const SizedBox(width: Space.s)
                ],
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: Fonts.body,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: fg)),
                ),
              ]),
        ),
      ),
    );
  }
}

/// A skin surface (row, tile, option) that squashes when tapped. Replaces the old
/// Material + InkWell flat rows so every page shares the skin's surfaces.
class SkinPanel extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? tint;
  final Color? ring;
  final double? radius;
  final double depth;
  final EdgeInsetsGeometry? padding;
  final bool haptics;
  const SkinPanel(
      {super.key,
      required this.child,
      this.onTap,
      this.tint,
      this.ring,
      this.radius,
      this.depth = 1,
      this.padding,
      this.haptics = true});

  @override
  Widget build(BuildContext context) {
    Widget box(bool down) => AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          padding: padding,
          decoration: Skin.surface(
              tint: tint,
              ring: ring,
              radius: radius,
              pressed: down,
              depth: depth),
          child: child,
        );
    if (onTap == null) return box(false);
    return Squash(
      enabled: true,
      onTap: () {
        if (haptics) haptic(HapticWeight.selection);
        onTap!();
      },
      builder: box,
    );
  }
}

/// Tracks a press and squashes its child a little while held (skin press feedback).
class Squash extends StatefulWidget {
  final bool enabled;
  final VoidCallback? onTap;
  final Widget Function(bool down) builder;
  const Squash(
      {super.key,
      required this.enabled,
      required this.onTap,
      required this.builder});
  @override
  State<Squash> createState() => _SquashState();
}

class _SquashState extends State<Squash> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _set(true) : null,
        onTapUp: widget.enabled ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
            scale: _down ? Skin.pressScale : 1,
            duration: Motion.of(context, Motion.fast),
            child: widget.builder(_down)),
      );
}

/// The 44 px round button of every top bar (pause, help, close, back). [dark] is the
/// version that sits on a picture (intro art, driving scenes).
class RoundButton extends StatelessWidget {
  final GameIcons icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final bool dark;
  const RoundButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onPressed,
      this.size = 44,
      this.dark = false});

  @override
  Widget build(BuildContext context) {
    const ink = Colors.white;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: SizedBox(
          width: math.max(size, kTouchTarget),
          height: math.max(size, kTouchTarget),
          child: Center(
            child: Squash(
              enabled: onPressed != null,
              onTap: onPressed == null
                  ? null
                  : () {
                      haptic(HapticWeight.selection);
                      onPressed!();
                    },
              builder: (down) => AnimatedContainer(
                duration: Motion.of(context, Motion.fast),
                width: size,
                height: size,
                decoration: Skin.round(dark: dark, pressed: down),
                child: Center(
                    child: GameIcon(icon, size: size * 0.42, color: ink)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The on/off switch of the mockups: 44 x 26 (or 38 x 22 small), green when on.
class PillSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? color;
  final bool small;
  final String? semanticLabel;
  const PillSwitch(
      {super.key,
      required this.value,
      this.onChanged,
      this.color,
      this.small = false,
      this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final w = small ? 38.0 : 44.0,
        h = small ? 22.0 : 26.0,
        k = small ? 16.0 : 20.0;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      excludeSemantics: semanticLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null
            ? null
            : () {
                haptic(HapticWeight.selection);
                onChanged!(!value);
              },
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          width: w,
          height: h,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
              color: value
                  ? (color ?? StatusColors.success)
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(h / 2)),
          child: Container(
              width: k,
              height: k,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle)),
        ),
      ),
    );
  }
}

/// A short tag on the top edge of a card: AIMING, UP NEXT, MISSED, +10.
class EdgeTag extends StatelessWidget {
  final String text;
  final Color color;
  final bool score; // +10 style: Lilita on gold
  const EdgeTag(this.text,
      {super.key, required this.color, this.score = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: score
          ? const EdgeInsets.symmetric(horizontal: 9, vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: score ? Brand.gold : color,
        borderRadius: BorderRadius.circular(score ? 9 : 8),
        boxShadow: score
            ? const [
                BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 8,
                    offset: Offset(0, 3))
              ]
            : null,
      ),
      child: Text(text,
          style: score
              ? const TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 14,
                  height: 1.2,
                  color: Color(0xFF2A1A00))
              : TextStyle(
                  fontFamily: Fonts.body,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  height: 1.3,
                  color: onColor(color))),
    );
  }
}

/// A player's card in the HUD (spec 2.3): badge, name, score, an optional second row
/// (round boxes, lives, collected items), and a state: active, tagged, idle or out.
class PlayerScoreCard extends StatelessWidget {
  final int seat;
  final String name;
  final String? score; // null: no score shown
  final Color? color; // defaults to the seat colour
  final bool active;
  final bool out; // wrecked, eliminated
  final String? tag; // AIMING, YOUR TURN, UP NEXT, MISSED, +10
  final Color? tagColor;
  final bool compact; // 3+ players: 58 px tall, smaller text
  final Widget? detail; // the second row
  final bool highlightScore; // gold score after a big hit
  const PlayerScoreCard(
      {super.key,
      required this.seat,
      required this.name,
      this.score,
      this.color,
      this.active = false,
      this.out = false,
      this.tag,
      this.tagColor,
      this.compact = false,
      this.detail,
      this.highlightScore = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = color ?? PlayerPalette.color(seat);
    final flat = t.flat;
    final ink = flat ? t.text : (active ? Colors.white : kIdleInk);
    final scoreTag = tag != null && tag!.startsWith('+');
    final card = AnimatedContainer(
      duration: Motion.of(context, Motion.normal),
      curve: Motion.standard,
      constraints: BoxConstraints(minHeight: compact ? 58 : 0),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: Skin.surface(
          tint: active ? c : null,
          ring: active ? nameColor(c) : null,
          radius: compact ? 16 : 20,
          depth: active ? 1 : 0.6),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            compact
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    if (score != null)
                      Text(score!,
                          maxLines: 1,
                          style: t.styles.score.copyWith(
                              fontSize: 22,
                              color: highlightScore
                                  ? const Color(0xFFFFE08A)
                                  : ink)),
                    const SizedBox(height: 3),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      PlayerBadge(index: seat, size: 12, color: c),
                      const SizedBox(width: 5),
                      Flexible(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: Fonts.body,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: ink))),
                    ]),
                  ])
                : Row(children: [
                    PlayerBadge(
                        index: seat,
                        size: 30,
                        color: c,
                        initial: name.isEmpty ? null : name),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: Fonts.body,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: ink))),
                    if (score != null)
                      Text(score!,
                          style: t.styles.score.copyWith(
                              color: highlightScore
                                  ? const Color(0xFFFFE08A)
                                  : ink)),
                  ]),
            if (detail != null) ...[SizedBox(height: compact ? 4 : 8), detail!],
          ]),
    );
    final label =
        '$name${score != null ? ', $score' : ''}${active ? ', playing now' : ''}${out ? ', out' : ''}${tag != null ? ', $tag' : ''}';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: out ? 0.55 : 1,
        child: ColorFiltered(
          colorFilter: out
              ? const ColorFilter.matrix(_greyscale)
              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: Stack(clipBehavior: Clip.none, children: [
            card,
            if (tag != null)
              Positioned(
                top: scoreTag ? -10 : (compact ? -8 : -9),
                left: scoreTag ? null : (compact ? 6 : 12),
                right: scoreTag ? 10 : null,
                child: EdgeTag(tag!, color: tagColor ?? c, score: scoreTag),
              ),
          ]),
        ),
      ),
    );
  }
}

const _greyscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

/// Lays out one [PlayerScoreCard] per player (spec 2.3): 2 players in two columns,
/// 3-4 in one compact row, 5-6 in a compact 3 x 2 grid.
class PlayerScoreRow extends StatelessWidget {
  final int count;
  final Widget Function(int seat, bool compact) card;
  const PlayerScoreRow({super.key, required this.count, required this.card});

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    Widget row(Iterable<int> seats, bool compact) =>
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final i in seats) ...[
            if (i != seats.first) const SizedBox(width: gap),
            Expanded(child: card(i, compact))
          ],
        ]);
    final Widget body;
    if (count <= 2) {
      body = row(Iterable.generate(count), false);
    } else if (count <= 4) {
      body = row(Iterable.generate(count), true);
    } else {
      body = Column(children: [
        row(Iterable.generate(3), true),
        const SizedBox(height: gap + 4),
        row(Iterable.generate(count - 3, (i) => i + 3), true)
      ]);
    }
    return Padding(padding: const EdgeInsets.only(top: 10), child: body);
  }
}

/// The per-round boxes under a score (arrows shot, holes, rounds): filled, current, empty.
class RoundBoxes extends StatelessWidget {
  final List<String?> values; // null: not played yet
  final int? current; // the box being played now
  final Color color;
  final Set<int> gold; // best results (bullseyes)
  final double height;
  const RoundBoxes(
      {super.key,
      required this.values,
      this.current,
      required this.color,
      this.gold = const {},
      this.height = 22});

  @override
  Widget build(BuildContext context) {
    final flat = context.tk.flat;
    return ExcludeSemantics(
      child: Row(children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: _box(i, flat)),
        ],
      ]),
    );
  }

  Widget _box(int i, bool flat) {
    final v = values[i];
    final ink = flat ? FlatPalette.ink : Colors.white;
    if (v != null) {
      final g = gold.contains(i);
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: g
                ? Brand.gold
                : (flat
                    ? FlatPalette.option
                    : Colors.white.withValues(alpha: 0.14)),
            borderRadius: Radii.rTile),
        child: Text(v,
            style: TextStyle(
                fontFamily: Fonts.body,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: g ? const Color(0xFF2A1A00) : ink)),
      );
    }
    if (i == current) {
      return Container(
          height: height,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: Radii.rTile,
              border: Border.all(color: color, width: 1.5)));
    }
    return SizedBox(
        height: height,
        child: CustomPaint(
            painter: _DashedBox(flat
                ? FlatPalette.stroke
                : Colors.white.withValues(alpha: 0.25))));
  }
}

class _DashedBox extends CustomPainter {
  final Color color;
  const _DashedBox(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.75),
          const Radius.circular(Radii.tile)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox old) => old.color != color;
}

/// Small coloured markers for things a player collected or has left (lives, pairs).
class Pips extends StatelessWidget {
  final int filled, total;
  final Color color;
  final GameIcons? icon; // e.g. hearts; dots by default
  final GameIcons? emptyIcon;
  final double size;
  const Pips(
      {super.key,
      required this.filled,
      required this.total,
      required this.color,
      this.icon,
      this.emptyIcon,
      this.size = 12});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Wrap(spacing: 4, runSpacing: 4, children: [
          for (var i = 0; i < total; i++)
            if (icon != null)
              GameIcon(i < filled ? icon! : (emptyIcon ?? icon!),
                  size: size,
                  color:
                      i < filled ? color : Colors.white.withValues(alpha: 0.3))
            else
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < filled ? color : Colors.transparent,
                    border: Border.all(
                        color: i < filled
                            ? color
                            : Colors.white.withValues(alpha: 0.3),
                        width: 1.5)),
              ),
        ]),
      );
}

enum TurnBannerKind { turn, success, miss, info }

/// A chip floating on a scene (spec 2.7): small-caps label over a Lilita value, optional icon.
class OverlayChip extends StatelessWidget {
  final String label;
  final String? value;
  final GameIcons? icon;
  final Color? iconColor;
  final Widget? child; // e.g. a power bar
  final double? width;
  const OverlayChip(
      {super.key,
      required this.label,
      this.value,
      this.icon,
      this.iconColor,
      this.child,
      this.width});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label${value != null ? ' $value' : ''}',
      excludeSemantics: true,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
        decoration: Skin.pill(color: NeonPalette.overlay),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            GameIcon(icon!, size: 20, color: iconColor ?? Colors.white),
            const SizedBox(width: 8)
          ],
          Flexible(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: Fonts.body,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.26,
                          height: 1.1,
                          color: Color(0xFFCFD6FF))),
                  if (value != null)
                    Text(value!,
                        style: const TextStyle(
                            fontFamily: Fonts.display,
                            fontSize: 18,
                            height: 1.1,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  if (child != null) ...[const SizedBox(height: 4), child!],
                ]),
          ),
        ]),
      ),
    );
  }
}

/// A thin bar for power, charge or time inside an [OverlayChip] (gold to orange).
class MeterBar extends StatelessWidget {
  final double value; // 0..1
  final List<Color> colors;
  final double height;
  const MeterBar(
      {super.key,
      required this.value,
      this.colors = const [Brand.gold, Color(0xFFFF8A1F)],
      this.height = 8});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Stack(children: [
            Positioned.fill(
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.16))),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      borderRadius: BorderRadius.circular(height / 2))),
            ),
          ]),
        ),
      );
}

/// A rounded frame for a scene that doesn't fill the screen (spec 2.6): radius 24,
/// a large shadow and a 1 px light ring. [overlays] sit inside it (chips in corners).
class SceneFrame extends StatelessWidget {
  final Widget child;
  final List<Widget> overlays;
  final double radius;
  const SceneFrame(
      {super.key,
      required this.child,
      this.overlays = const [],
      this.radius = Radii.board});

  @override
  Widget build(BuildContext context) {
    final flat = context.tk.flat;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: flat ? 0.22 : 0.5),
              blurRadius: 34,
              offset: const Offset(0, 14)),
          BoxShadow(
              color: flat
                  ? FlatPalette.stroke
                  : Colors.white.withValues(alpha: 0.10),
              spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: overlays.isEmpty
            ? child
            : Stack(fit: StackFit.passthrough, children: [child, ...overlays]),
      ),
    );
  }
}

/// The 3 - 2 - 1 - GO before a real-time game (spec 2.9): Lilita 120, each number scales
/// 1.4 -> 1.0 and fades while a ring sweeps around it. [mirrored] also shows it upside
/// down for the far side of a phone lying flat.
class CountdownOverlay extends StatefulWidget {
  final VoidCallback onDone;
  final Color color;
  final bool mirrored;
  final ValueListenable<bool>? paused;
  const CountdownOverlay(
      {super.key,
      required this.onDone,
      required this.color,
      this.mirrored = false,
      this.paused});

  /// 3, 2 and 1 take this long each; GO a little less.
  static const step = Duration(milliseconds: 700);
  static const go = Duration(milliseconds: 450);
  static Duration get total => step * 3 + go;

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: CountdownOverlay.total)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        });
  int _last = -1;

  @override
  void initState() {
    super.initState();
    widget.paused?.addListener(_syncPause);
    _syncPause();
  }

  @override
  void didUpdateWidget(CountdownOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) {
      oldWidget.paused?.removeListener(_syncPause);
      widget.paused?.addListener(_syncPause);
      _syncPause();
    }
  }

  void _syncPause() {
    if (widget.paused?.value ?? false) {
      _c.stop();
    } else if (!_c.isCompleted && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    widget.paused?.removeListener(_syncPause);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final stepMs = CountdownOverlay.step.inMilliseconds.toDouble();
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final ms = _c.value * CountdownOverlay.total.inMilliseconds;
        final step = math.min(3, ms ~/ stepMs);
        final u = step < 3
            ? (ms - step * stepMs) / stepMs
            : ((ms - 3 * stepMs) / CountdownOverlay.go.inMilliseconds)
                .clamp(0.0, 1.0);
        if (step != _last) {
          _last = step;
          haptic(step == 3 ? HapticWeight.medium : HapticWeight.selection);
          GameAudio.sfx(step == 3 ? 'pop' : 'tap');
        }
        final label = const ['3', '2', '1', 'GO'][step];
        final scale = reduced ? 1.0 : 1.4 - Curves.easeOut.transform(u) * 0.4;
        final fade =
            reduced ? 1.0 : (u < 0.75 ? 1.0 : 1 - (u - 0.75) * 4 * 0.6);
        final go = step == 3;
        final number = Semantics(
          liveRegion: true,
          label: go ? 'Go' : label,
          excludeSemantics: true,
          child: SizedBox(
            width: 210,
            height: 210,
            child: CustomPaint(
              painter:
                  _Ring(reduced || go ? 1 : u, go ? Brand.gold : widget.color),
              child: Center(
                child: Opacity(
                  opacity: fade,
                  child: Transform.scale(
                    scale: scale,
                    child: Text(label,
                        style: TextStyle(
                            fontFamily: Fonts.display,
                            fontSize: go ? 96 : 120,
                            height: 1,
                            color: go ? Brand.gold : Colors.white,
                            shadows: [
                              Shadow(
                                  color: go
                                      ? const Color(0xFF7A4B00)
                                      : Color.lerp(
                                          widget.color, Colors.black, 0.35)!,
                                  offset: const Offset(0, 5))
                            ])),
                  ),
                ),
              ),
            ),
          ),
        );
        final ready = Text('Get ready',
            style: TextStyle(
                fontFamily: Fonts.display,
                fontSize: 22,
                color: nameColor(Brand.gold)));
        if (!widget.mirrored)
          return Center(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [number, const SizedBox(height: Space.l), ready]));
        return Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RotatedBox(quarterTurns: 2, child: number),
              ready,
              number
            ]);
      },
    );
  }
}

class _Ring extends CustomPainter {
  final double f;
  final Color color;
  _Ring(this.f, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(8);
    canvas.drawCircle(
        r.center, r.width / 2, Paint()..color = color.withValues(alpha: 0.14));
    canvas.drawCircle(
        r.center,
        r.width / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = Colors.white.withValues(alpha: 0.12));
    canvas.drawArc(
        r,
        -math.pi / 2,
        2 * math.pi * f,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(_Ring o) => o.f != f || o.color != color;
}

/// The connection states a game can be in (spec 2.15). Built from the existing socket,
/// room and LAN state by the caller; this only shows them.
enum LinkState {
  connecting,
  reconnecting,
  playerLeft,
  hostLeft,
  switchedToOnline
}

/// A non-blocking strip at the top for connection trouble. Never shows raw errors.
class ConnectionBanner extends StatelessWidget {
  final LinkState state;
  final String? who; // the player who left
  final List<(String, VoidCallback)> actions; // e.g. Wait, End
  const ConnectionBanner(
      {super.key, required this.state, this.who, this.actions = const []});

  String get text => switch (state) {
        LinkState.connecting => 'Connecting…',
        LinkState.reconnecting => 'Reconnecting…',
        LinkState.playerLeft => '${who ?? 'A player'} left · waiting for them…',
        LinkState.hostLeft =>
          'The host left · the game continues when they are back…',
        LinkState.switchedToOnline =>
          'Lost the Wi-Fi host · switched to online',
      };

  @override
  Widget build(BuildContext context) {
    final busy =
        state == LinkState.connecting || state == LinkState.reconnecting;
    final c = switch (state) {
      LinkState.connecting || LinkState.switchedToOnline => StatusColors.info,
      LinkState.reconnecting => StatusColors.warn,
      LinkState.playerLeft || LinkState.hostLeft => const Color(0xFFB07CFF),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: kTouchTarget),
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: Skin.surface(
            tint: c,
            ring: c.withValues(alpha: 0.7),
            radius: Radii.chip,
            depth: 0.7),
        child: Row(children: [
          if (busy)
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: c))
          else
            GameIcon(
                state == LinkState.switchedToOnline
                    ? GameIcons.globe
                    : GameIcons.wifi,
                size: 18,
                color: c),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontFamily: Fonts.body,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white))),
          for (final (label, onTap) in actions)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                  foregroundColor: Brand.gold,
                  minimumSize: const Size(kTouchTarget, kTouchTarget)),
              child: Text(label,
                  style: const TextStyle(
                      fontFamily: Fonts.body, fontWeight: FontWeight.w900)),
            ),
        ]),
      ),
    );
  }
}

/// One place for a game's key-moment effects (spec 2.16): score pops floating up in gold,
/// a big announcement (BULLSEYE!), hit flashes, a small screen shake and confetti.
/// Shake and confetti are off with Reduce motion. The shell puts one around every game;
/// games call `GameFeedback.of(context)?.pop('+10')`.
class FeedbackLayer extends StatefulWidget {
  final Widget child;
  const FeedbackLayer({super.key, required this.child});
  @override
  State<FeedbackLayer> createState() => GameFeedback();
}

class _Effect {
  final int id;
  final String kind; // pop, announce, flash, confetti
  final String text, sub;
  final Offset? at; // fraction of the layer (0..1)
  final Color color;
  final Duration life;
  _Effect(this.id, this.kind,
      {this.text = '',
      this.sub = '',
      this.at,
      this.color = Brand.gold,
      required this.life});
}

class GameFeedback extends State<FeedbackLayer> with TickerProviderStateMixin {
  static GameFeedback? of(BuildContext context) =>
      context.findAncestorStateOfType<GameFeedback>();

  final _effects = <_Effect>[];
  var _next = 0;
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
  double _shakeSize = 0;

  bool get _reduced => mounted && Motion.reduced(context);

  void _add(_Effect e) {
    if (!mounted) return;
    setState(() => _effects.add(e));
    Future.delayed(e.life, () {
      if (mounted) setState(() => _effects.remove(e));
    });
  }

  /// "+N" floating up in gold from [at] (a fraction of the screen; centre by default).
  void pop(String text, {Offset? at, Color color = Brand.gold}) =>
      _add(_Effect(_next++, 'pop',
          text: text,
          at: at,
          color: color,
          life: const Duration(milliseconds: 900)));

  /// A big centred line (BULLSEYE!, SMASH!) with an optional smaller line under it.
  void announce(String text, {String sub = '', Color color = Brand.gold}) =>
      _add(_Effect(_next++, 'announce',
          text: text,
          sub: sub,
          color: color,
          life: const Duration(milliseconds: 1300)));

  /// A quick full-screen flash (a hit), in [color].
  void flash([Color color = Colors.white]) => _add(_Effect(_next++, 'flash',
      color: color, life: const Duration(milliseconds: 260)));

  /// Confetti (40 pieces at most). Skipped with Reduce motion.
  void confetti() {
    if (_reduced) return;
    _add(
        _Effect(_next++, 'confetti', life: const Duration(milliseconds: 1800)));
  }

  /// Shakes the game up to 6 px. Skipped with Reduce motion.
  void shake([double size = 6]) {
    if (_reduced) return;
    _shakeSize = size.clamp(0, 6);
    _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      AnimatedBuilder(
        animation: _shake,
        builder: (_, child) {
          final v = _shake.value;
          if (v == 0 || v == 1) return child!;
          final k = (1 - v) * _shakeSize;
          return Transform.translate(
              offset: Offset(math.sin(v * math.pi * 8) * k,
                  math.cos(v * math.pi * 6) * k * 0.4),
              child: child);
        },
        child: widget.child,
      ),
      for (final e in _effects)
        Positioned.fill(
            key: ValueKey(e.id), child: IgnorePointer(child: _EffectView(e))),
    ]);
  }
}

class _EffectView extends StatelessWidget {
  final _Effect e;
  const _EffectView(this.e);

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: e.life,
      builder: (context, v, _) {
        switch (e.kind) {
          case 'flash':
            return ColoredBox(color: e.color.withValues(alpha: 0.35 * (1 - v)));
          case 'confetti':
            return CustomPaint(painter: _Confetti(v, e.id));
          case 'announce':
            final s = reduced
                ? 1.0
                : (v < 0.25
                    ? 0.6 + Curves.easeOutBack.transform(v / 0.25) * 0.4
                    : 1.0);
            final o = v > 0.8 ? (1 - v) / 0.2 : 1.0;
            return Semantics(
              liveRegion: true,
              label: '${e.text} ${e.sub}',
              child: Align(
                alignment: const Alignment(0, -0.35),
                child: Opacity(
                  opacity: o.clamp(0, 1),
                  child: Transform.scale(
                    scale: s,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(e.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: Fonts.display,
                              fontSize: 50,
                              height: 1,
                              color: e.color,
                              letterSpacing: 1,
                              shadows: [
                                Shadow(
                                    color:
                                        Color.lerp(e.color, Colors.black, 0.6)!,
                                    offset: const Offset(0, 4)),
                                Shadow(
                                    color: e.color.withValues(alpha: 0.55),
                                    blurRadius: 28),
                              ])),
                      if (e.sub.isNotEmpty)
                        Text(e.sub,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontFamily: Fonts.display,
                                fontSize: 26,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                      color: Color(0x59000000),
                                      offset: Offset(0, 2))
                                ])),
                    ]),
                  ),
                ),
              ),
            );
          default: // pop
            final at = e.at ?? const Offset(0.5, 0.45);
            return Align(
              alignment: Alignment(at.dx * 2 - 1, at.dy * 2 - 1),
              child: Transform.translate(
                offset:
                    Offset(0, reduced ? 0 : -60 * Curves.easeOut.transform(v)),
                child: Opacity(
                  opacity: v < 0.7 ? 1 : (1 - v) / 0.3,
                  child: Text(e.text,
                      style: TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 30,
                          color: e.color,
                          shadows: [
                            Shadow(
                                color: Color.lerp(e.color, Colors.black, 0.6)!,
                                offset: const Offset(0, 3))
                          ])),
                ),
              ),
            );
        }
      },
    );
  }
}

class _Confetti extends CustomPainter {
  final double t;
  final int seed;
  _Confetti(this.t, this.seed);
  static const _colors = Skin.confetti;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final p = Paint();
    for (var i = 0; i < 40; i++) {
      final x0 = rng.nextDouble() * size.width;
      final drift = (rng.nextDouble() - 0.5) * 80;
      final speed = 0.6 + rng.nextDouble() * 0.6;
      final y = -20 + t * speed * (size.height * 0.9);
      final spin = rng.nextDouble() * 6 + t * 10 * (rng.nextBool() ? 1 : -1);
      p.color = _colors[i % _colors.length]
          .withValues(alpha: t > 0.8 ? (1 - t) / 0.2 : 1);
      canvas.save();
      canvas.translate(x0 + drift * t, y);
      canvas.rotate(spin);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-3.5, -6, 7, 12), const Radius.circular(2)),
          p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Confetti old) => old.t != t;
}

/// Emoji that may appear in rule text, drawn as icons instead (spec 2.11). Anything not
/// listed is dropped from game UI text.
const ruleIconFor = <String, GameIcons>{
  '🎯': GameIcons.target,
  '🏹': GameIcons.bow,
  '💨': GameIcons.wind,
  '🌬': GameIcons.wind,
  '❤': GameIcons.heart,
  '💖': GameIcons.heart,
  '🛡': GameIcons.shield,
  '🚀': GameIcons.rocket,
  '💣': GameIcons.bomb,
  '⚡': GameIcons.bolt,
  '🔫': GameIcons.gun,
  '🎁': GameIcons.mysteryBox,
  '👑': GameIcons.crown,
  '🏆': GameIcons.trophy,
  '⭐': GameIcons.star,
  '🌟': GameIcons.star,
  '🪙': GameIcons.coin,
  '💰': GameIcons.coin,
  '⏱': GameIcons.clock,
  '⏰': GameIcons.clock,
  '⌛': GameIcons.clock,
  '🎲': GameIcons.dice5,
  '👀': GameIcons.eye,
  '👁': GameIcons.eye,
  '✅': GameIcons.check,
  '✔': GameIcons.check,
  '❌': GameIcons.cross,
  '✖': GameIcons.cross,
  '🔄': GameIcons.restart,
  '🔁': GameIcons.restart,
  '↩': GameIcons.undo,
  '🚩': GameIcons.flag,
  '🦆': GameIcons.duck,
  '🐰': GameIcons.rabbit,
  '🐹': GameIcons.mole,
  '👽': GameIcons.alien,
  '🛸': GameIcons.ufo,
  '🌵': GameIcons.cactus,
  '🐦': GameIcons.bird,
  '🐷': GameIcons.pig,
  '🪜': GameIcons.ladder,
  '🐍': GameIcons.snake,
  '✊': GameIcons.rock,
  '✋': GameIcons.paper,
  '✌': GameIcons.scissors,
  '🏏': GameIcons.bat,
  '🏀': GameIcons.ball,
  '⚽': GameIcons.football,
  '🧤': GameIcons.glove,
  '🍾': GameIcons.bottle,
  '🖌': GameIcons.paintBrush,
  '🎨': GameIcons.paintBrush,
  '✏': GameIcons.pencil,
  '💡': GameIcons.lightbulb,
  '🔒': GameIcons.lock,
  '🍎': GameIcons.apple,
  '🍉': GameIcons.watermelon,
  '🍓': GameIcons.strawberry,
  '🔨': GameIcons.hammer,
  '🌙': GameIcons.moon,
  '☀': GameIcons.sun,
  '🎭': GameIcons.mask,
  '🎬': GameIcons.clapper,
  '💬': GameIcons.speech,
  '🗣': GameIcons.speech,
  '👆': GameIcons.arrowUp,
  '👇': GameIcons.arrowDown,
  '👈': GameIcons.arrowLeft,
  '👉': GameIcons.arrowRight,
  '⬆': GameIcons.arrowUp,
  '⬇': GameIcons.arrowDown,
  '⬅': GameIcons.arrowLeft,
  '➡': GameIcons.arrowRight,
  '🔍': GameIcons.magnifier,
  '👥': GameIcons.people,
  '🤖': GameIcons.people,
  '🏠': GameIcons.home,
  '💧': GameIcons.drop,
};

final _emoji = RegExp(
    r'(?:[\u{1F000}-\u{1FAFF}]|[\u{2190}-\u{21FF}]|[\u{2300}-\u{23FF}]|[\u{2460}-\u{27BF}]|[\u{2B00}-\u{2BFF}]|[\u{3030}\u{303D}\u{3297}\u{3299}])[\u{FE0F}\u{200D}\u{1F3FB}-\u{1F3FF}\u{20E3}]*(?:\u{200D}[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}][\u{FE0F}]*)*',
    unicode: true);

/// The first emoji of [text] as an icon, if it has one.
GameIcons? leadingRuleIcon(String text) {
  for (final m in _emoji.allMatches(text)) {
    final key =
        m.group(0)!.replaceAll(RegExp('[\u{FE0F}\u{200D}]', unicode: true), '');
    for (final e in ruleIconFor.entries) {
      if (key.startsWith(e.key)) return e.value;
    }
  }
  return null;
}

/// [text] with emoji removed (game UI shows drawn icons, never emoji).
String stripEmoji(String text) => text
    .replaceAll(_emoji, '')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .replaceAll(RegExp(r'^\s*[·:,-]\s*'), '')
    .trim();

/// [text] as spans with each known emoji drawn as an inline icon, unknown ones dropped.
InlineSpan ruleSpan(String text, TextStyle style, {Color? iconColor}) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in _emoji.allMatches(text)) {
    if (m.start > last)
      spans.add(TextSpan(text: text.substring(last, m.start)));
    final key =
        m.group(0)!.replaceAll(RegExp('[\u{FE0F}\u{200D}]', unicode: true), '');
    GameIcons? icon;
    for (final e in ruleIconFor.entries) {
      if (key.startsWith(e.key)) {
        icon = e.value;
        break;
      }
    }
    if (icon != null) {
      final size = (style.fontSize ?? 15) * 1.15;
      spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GameIcon(icon,
              size: size, color: iconColor ?? style.color ?? Colors.white)));
    }
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return TextSpan(style: style, children: spans);
}

/// A one-off confetti burst over its area (40 pieces), nothing with Reduce motion.
class ConfettiBurst extends StatelessWidget {
  final int seed;
  const ConfettiBurst({super.key, this.seed = 7});

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 2200),
        builder: (_, v, __) => v >= 1
            ? const SizedBox.shrink()
            : CustomPaint(size: Size.infinite, painter: _Confetti(v, seed)),
      ),
    );
  }
}

/// The header of every app page (spec 4): back or close (44 px) · small caps label with an
/// optional Lilita title under it · an optional button on the right.
class PageHeader extends StatelessWidget {
  final String label;
  final String? title;
  final GameIcons backIcon;
  final VoidCallback? onBack; // default: pop
  final Widget? trailing;
  final bool showBack;
  const PageHeader(
      {super.key,
      required this.label,
      this.title,
      this.backIcon = GameIcons.back,
      this.onBack,
      this.trailing,
      this.showBack = true});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (showBack)
        RoundButton(
            icon: backIcon,
            label: backIcon == GameIcons.close ? 'Close' : 'Back',
            onPressed: onBack ?? () => Navigator.maybePop(context))
      else
        const SizedBox(width: kTouchTarget),
      Expanded(
        child: Semantics(
          header: true,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tk.styles.label),
            if (title != null)
              Text(title!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 22,
                      height: 1.15,
                      color: context.tk.onBg)),
          ]),
        ),
      ),
      trailing ?? const SizedBox(width: kTouchTarget),
    ]);
  }
}

/// A section title with a short gold bar ("FEATURED GAMES"), and an optional link.
class SectionHeader extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
                color: Brand.gold, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text.toUpperCase(),
                style: TextStyle(
                    fontFamily: Fonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.82,
                    color: context.tk.onBg)),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
                foregroundColor: context.tk.flat ? FlatPalette.ink : Brand.gold,
                minimumSize: const Size(kTouchTarget, kTouchTarget)),
            child: Text(action!,
                style: const TextStyle(
                    fontFamily: Fonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ),
      ]);
}

/// A selectable pill (categories: gold when picked; [outline] for the player-count row).
class KitChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool outline;
  const KitChip(this.label,
      {super.key,
      required this.selected,
      required this.onTap,
      this.outline = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          haptic(HapticWeight.selection);
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kTouchTarget),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              padding: outline
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: Skin.chip(selected: selected, outline: outline),
              child: Text(label,
                  style: TextStyle(
                      fontFamily: Fonts.body,
                      fontSize: outline ? 12 : 13,
                      fontWeight: FontWeight.w900,
                      color: Skin.chipInk(selected: selected))),
            ),
          ),
        ),
      ),
    );
  }
}

/// The search / text field of the app pages: 48 px, radius 16, soft fill, gold focus ring.
class KitField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final GameIcons? icon;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final TextCapitalization capitalization;
  final int? maxLength;
  const KitField(
      {super.key,
      required this.controller,
      required this.hint,
      this.icon,
      this.onChanged,
      this.suffix,
      this.capitalization = TextCapitalization.none,
      this.maxLength});

  @override
  Widget build(BuildContext context) {
    final flat = context.tk.flat;
    final ink = flat ? FlatPalette.ink : Colors.white;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: Radii.rLg, borderSide: BorderSide(color: c, width: w));
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLength: maxLength,
      textCapitalization: capitalization,
      cursorColor: Skin.fieldFocus,
      style: TextStyle(
          fontFamily: Fonts.body,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: ink),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        hintStyle: TextStyle(
            fontFamily: Fonts.body,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: flat ? FlatPalette.inkMuted : NeonPalette.label),
        filled: true,
        fillColor: flat ? Colors.white : Skin.fieldFill,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIcon: icon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: GameIcon(icon!,
                    size: 18,
                    color:
                        flat ? FlatPalette.inkMuted : NeonPalette.textMuted)),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        enabledBorder: border(
            flat ? FlatPalette.stroke : Colors.white.withValues(alpha: 0.14)),
        focusedBorder: border(flat ? FlatPalette.ink : Skin.fieldFocus, 2),
        border: border(
            flat ? FlatPalette.stroke : Colors.white.withValues(alpha: 0.14)),
      ),
    );
  }
}

/// An app page: the app background (night, or sky in the flat app) and the standard
/// 16 px gutters (spec 1.4).
class AppPage extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AppPage({super.key, required this.child, this.padding = Space.screen});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.tk.bg,
        body: AppBackground(
            child: SafeArea(child: Padding(padding: padding, child: child))),
      );
}

/// Opens the system share sheet with [text] (Android). Elsewhere, or if that fails, the
/// text is copied and a toast says so.
Future<void> shareText(BuildContext context, String text,
    {String copied = 'Copied'}) async {
  try {
    final ok = await const MethodChannel('party/device')
        .invokeMethod<bool>('share', {'text': text});
    if (ok == true) return;
  } catch (_) {}
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showToast(context, copied, tone: Tone.success);
}
