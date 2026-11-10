import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../audio/game_audio.dart';
import '../settings/app_settings.dart';
import 'app_theme_ext.dart';
import 'debug_gallery.dart';
import 'game_kit.dart';

export 'app_theme_ext.dart';
export 'game_kit.dart';

/// Shared building blocks. Every screen uses these instead of styling Material widgets
/// inline, so both flavours (neon, flat) and accessibility rules apply everywhere.
/// See docs/design-system.md.

enum ButtonVariant { primary, secondary, ghost, danger }

/// The chunky party-game button: sinks when pressed, 52dp tall, haptic + click on tap.
/// [color] overrides the primary fill (e.g. the game's own colour); text colour is picked
/// for contrast automatically.
class AppButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final Color? color;
  final Color? textColor;
  final bool compact;
  const AppButton(this.label,
      {super.key,
      this.icon,
      this.onPressed,
      this.variant = ButtonVariant.primary,
      this.color,
      this.textColor,
      this.compact = false});

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final height = widget.compact ? kTouchTarget : 54.0;
    final sink = _down && enabled;
    final duration = Motion.of(context, Motion.fast);
    final (Decoration deco, Color fg) = switch (widget.variant) {
      ButtonVariant.primary => (
          Skin.primary(
              enabled: enabled,
              pressed: sink,
              color: widget.color,
              radius: height / 2),
          widget.textColor != null && enabled
              ? widget.textColor!
              : Skin.primaryInk(enabled: enabled, color: widget.color)
        ),
      ButtonVariant.danger => (
          Skin.secondary(SkinButton.danger,
              pressed: sink, radius: height / 2, enabled: enabled),
          Skin.secondaryInk(SkinButton.danger, enabled: enabled)
        ),
      ButtonVariant.secondary => (
          Skin.secondary(SkinButton.soft,
              pressed: sink, radius: height / 2, enabled: enabled),
          Skin.secondaryInk(SkinButton.soft, enabled: enabled)
        ),
      ButtonVariant.ghost => (
          Skin.secondary(SkinButton.outline,
              pressed: sink, radius: height / 2, enabled: enabled),
          Skin.secondaryInk(SkinButton.outline, enabled: enabled)
        ),
    };
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
            constraints: BoxConstraints(minHeight: height),
            padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? Space.l : Space.xl,
                vertical: Space.s),
            decoration: deco,
            child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon,
                        color: fg, size: widget.compact ? 20 : 22),
                    const SizedBox(width: Space.s)
                  ],
                  Flexible(
                    child: Text(widget.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.tk.styles.button.copyWith(
                            color: fg, fontSize: widget.compact ? 14.5 : 16.5)),
                  ),
                ]),
          ),
        ),
      ),
    );
  }
}

/// Round icon button with a 48dp target, a tooltip and a semantics label.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  const AppIconButton(
      {super.key,
      required this.icon,
      required this.tooltip,
      required this.onPressed,
      this.color,
      this.size = 44});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final fill = color ?? (t.flat ? Colors.white : t.glassStrong);
    final fg =
        color != null ? onColor(color!) : (t.flat ? FlatPalette.board : t.onBg);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          width: math.max(size, kTouchTarget),
          height: math.max(size, kTouchTarget),
          child: Center(
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: Ink(
                decoration: color != null
                    ? BoxDecoration(color: fill, shape: BoxShape.circle)
                    : Skin.round(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed == null
                      ? null
                      : () {
                          haptic(HapticWeight.selection);
                          onPressed!();
                        },
                  child: SizedBox(
                      width: size,
                      height: size,
                      child: Icon(icon, color: fg, size: size * 0.56)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A selectable choice (player counts, modes, filters). 48dp tall.
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final String? semanticLabel;
  final bool round; // a circle for a single digit
  const AppChip(
      {super.key,
      required this.label,
      required this.selected,
      this.onTap,
      this.color,
      this.semanticLabel,
      this.round = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = color ?? t.accent;
    final fill = selected
        ? (color == null ? c : fillFor(c))
        : (t.flat ? Colors.white : t.glass);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                haptic(HapticWeight.selection);
                onTap!();
              },
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          curve: Motion.standard,
          constraints:
              BoxConstraints(minHeight: kTouchTarget, minWidth: kTouchTarget),
          padding: round
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: Space.l),
          alignment: Alignment.center,
          decoration:
              Skin.chip(selected: selected, color: color == null ? null : fill),
          child: Text(label,
              textAlign: TextAlign.center,
              style: t.styles.bodyStrong.copyWith(
                  color: Skin.chipInk(
                      selected: selected, color: color == null ? null : fill),
                  fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

enum SurfaceKind { glass, card, raised }

/// A rounded surface. Glass sits on the background (text: onBg); card is opaque (text: text).
class AppCard extends StatelessWidget {
  final Widget child;
  final SurfaceKind kind;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final double radius;
  const AppCard(
      {super.key,
      required this.child,
      this.kind = SurfaceKind.glass,
      this.padding = const EdgeInsets.all(Space.l),
      this.tint,
      this.radius = Radii.xl});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: padding,
      decoration: Skin.surface(
          tint: tint,
          radius: radius == Radii.xl ? null : radius,
          depth: kind == SurfaceKind.glass ? 0.8 : 1),
      child: kind == SurfaceKind.glass
          ? child
          : DefaultTextStyle.merge(
              style: TextStyle(color: t.text), child: child),
    );
  }
}

/// Small caps label above a group of controls.
class SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const SectionLabel(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.s, left: 2),
        child: Semantics(
            header: true,
            child: Text(text,
                style: context.tk.styles.label.copyWith(color: color))),
      );
}

/// A dialog in the app's style. Returns what an action pops with.
Future<T?> showAppDialog<T>(BuildContext context,
    {required String title,
    Widget? body,
    String? message,
    required List<Widget> actions,
    String? emoji}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: context.tk.scrim,
    transitionDuration: Motion.of(context, Motion.normal),
    pageBuilder: (ctx, _, __) => _AppDialog(
        title: title,
        body: body,
        message: message,
        actions: actions,
        emoji: emoji),
    transitionBuilder: (ctx, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0)
              .animate(CurvedAnimation(parent: a, curve: Motion.emphasized)),
          child: child),
    ),
  );
}

class _AppDialog extends StatelessWidget {
  final String title;
  final Widget? body;
  final String? message;
  final List<Widget> actions;
  final String? emoji;
  const _AppDialog(
      {required this.title,
      this.body,
      this.message,
      required this.actions,
      this.emoji});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: Colors.transparent,
              elevation: 0,
              child: Container(
                decoration: Skin.dialog(),
                padding: const EdgeInsets.fromLTRB(
                    Space.xl, Space.xl, Space.xl, Space.l),
                child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Callers still pass an emoji; it is drawn as the matching icon (or left out).
                        if (emoji != null &&
                            leadingRuleIcon(emoji!) != null) ...[
                          Center(
                              child: GameIcon(leadingRuleIcon(emoji!)!,
                                  size: 44, color: Brand.gold)),
                          const SizedBox(height: Space.s),
                        ],
                        Semantics(
                            header: true,
                            child: Text(title,
                                textAlign: TextAlign.center,
                                style: t.cardStyles.headline)),
                        if (message != null) ...[
                          const SizedBox(height: Space.s),
                          Text(message!,
                              textAlign: TextAlign.center,
                              style: t.cardStyles.body
                                  .copyWith(color: t.textMuted))
                        ],
                        if (body != null) ...[
                          const SizedBox(height: Space.l),
                          body!
                        ],
                        const SizedBox(height: Space.xl),
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(height: Space.m),
                          actions[i]
                        ],
                      ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks to confirm something destructive. True when confirmed.
Future<bool> confirmAction(BuildContext context,
    {required String title,
    required String message,
    required String confirm,
    String cancel = 'CANCEL',
    String? emoji = '⚠️'}) async {
  final ok = await showAppDialog<bool>(context,
      title: title,
      message: message,
      emoji: emoji,
      actions: [
        Builder(
            builder: (ctx) => AppButton(confirm,
                variant: ButtonVariant.danger,
                onPressed: () => Navigator.pop(ctx, true))),
        Builder(
            builder: (ctx) => AppButton(cancel,
                variant: ButtonVariant.secondary,
                onPressed: () => Navigator.pop(ctx, false))),
      ]);
  return ok ?? false;
}

/// A bottom sheet in the app's style.
Future<T?> showAppSheet<T>(BuildContext context,
    {required Widget Function(BuildContext) builder, String? title}) {
  final t = context.tk;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: t.scrim,
    builder: (ctx) => DecoratedBox(
      decoration: Skin.sheet(),
      child: SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                Space.xl, Space.m, Space.xl, Space.xl),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                              color: t.flat ? t.strokeStrong : t.strokeStrong,
                              borderRadius: Radii.rSm))),
                  if (title != null) ...[
                    const SizedBox(height: Space.l),
                    Semantics(
                        header: true,
                        child: Text(title,
                            textAlign: TextAlign.center,
                            style: t.cardStyles.headline))
                  ],
                  const SizedBox(height: Space.l),
                  DefaultTextStyle.merge(
                      style: TextStyle(color: t.text), child: builder(ctx)),
                ]),
          ),
        ),
      ),
    ),
  );
}

enum Tone { info, success, warn, danger }

Color _toneColor(GameTokens t, Tone tone) => switch (tone) {
      Tone.info => t.info,
      Tone.success => t.success,
      Tone.warn => t.warn,
      Tone.danger => t.danger,
    };

IconData _toneIcon(Tone tone) => switch (tone) {
      Tone.info => Icons.info_rounded,
      Tone.success => Icons.check_circle_rounded,
      Tone.warn => Icons.wifi_off_rounded,
      Tone.danger => Icons.error_rounded,
    };

/// A short, non-blocking message floating above the content.
void showToast(BuildContext context, String message,
    {Tone tone = Tone.info,
    Duration duration = const Duration(milliseconds: 1800)}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final t = context.tk;
  final c = fillFor(_toneColor(t, tone));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c,
      duration: duration,
      shape: const RoundedRectangleBorder(borderRadius: Radii.rLg),
      content: Row(children: [
        Icon(_toneIcon(tone), color: Colors.white),
        const SizedBox(width: Space.s),
        Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800))),
      ]),
    ));
}

/// A non-blocking strip for ongoing states (reconnecting, offline). Doesn't cover controls.
class AppBanner extends StatelessWidget {
  final String text;
  final Tone tone;
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;
  const AppBanner(
      {super.key,
      required this.text,
      this.tone = Tone.info,
      this.busy = false,
      this.actionLabel,
      this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = fillFor(_toneColor(context.tk, tone));
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: kTouchTarget),
        padding:
            const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.xs),
        decoration: BoxDecoration(color: c, borderRadius: Radii.rLg),
        child: Row(children: [
          if (busy)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
          else
            Icon(_toneIcon(tone), color: Colors.white, size: 20),
          const SizedBox(width: Space.s),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14))),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(kTouchTarget, kTouchTarget)),
              child: Text(actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
        ]),
      ),
    );
  }
}

/// A friendly empty or error state: emoji, a line, maybe an action. Never a raw error.
class EmptyState extends StatelessWidget {
  final String emoji, title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState(
      {super.key,
      required this.emoji,
      required this.title,
      this.message,
      this.actionLabel,
      this.onAction});

  /// The error flavour of [EmptyState].
  const EmptyState.error(
      {super.key,
      this.title = 'Something went wrong',
      this.message = 'Check your connection and try again.',
      this.actionLabel = 'TRY AGAIN',
      this.onAction})
      : emoji = '😕';

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GameIcon(leadingRuleIcon(emoji) ?? GameIcons.magnifier,
              size: 52, color: t.flat ? t.textMuted : t.onBgMuted),
          const SizedBox(height: Space.m),
          Text(title, textAlign: TextAlign.center, style: t.styles.title),
          if (message != null) ...[
            const SizedBox(height: Space.xs),
            Text(message!,
                textAlign: TextAlign.center,
                style: t.styles.body.copyWith(color: t.onBgMuted))
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.l),
            AppButton(actionLabel!, compact: true, onPressed: onAction)
          ],
        ]),
      ),
    );
  }
}

/// A pulsing placeholder block while something loads (static with reduce motion).
class Skeleton extends StatefulWidget {
  final double width, height;
  final double radius;
  const Skeleton(
      {super.key,
      this.width = double.infinity,
      required this.height,
      this.radius = Radii.md});
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
              color: Color.lerp(t.glass, t.glassStrong, _c.value),
              borderRadius: BorderRadius.circular(widget.radius)),
        ),
      ),
    );
  }
}

/// Draws a player's shape (circle, triangle, …) so identity never relies on colour alone.
class PlayerShapePainter extends CustomPainter {
  final PlayerShape shape;
  final Color color;
  final Color? outline;
  final double? outlineWidth; // absolute stroke width; default 10% of the size
  const PlayerShapePainter(this.shape, this.color,
      {this.outline, this.outlineWidth});

  static Path pathFor(PlayerShape shape, Rect r) {
    final c = r.center, w = r.width / 2, h = r.height / 2;
    Path poly(int n, double rot, [double inner = 1]) {
      final p = Path();
      final pts = inner == 1 ? n : n * 2;
      for (var i = 0; i < pts; i++) {
        final a = rot + i * 2 * math.pi / pts;
        final k = inner == 1 || i.isEven ? 1.0 : inner;
        final pt = c + Offset(math.cos(a) * w * k, math.sin(a) * h * k);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    }

    return switch (shape) {
      PlayerShape.circle => Path()..addOval(r.deflate(r.width * 0.06)),
      PlayerShape.triangle => poly(3, -math.pi / 2),
      PlayerShape.roundedSquare => Path()
        ..addRRect(RRect.fromRectAndRadius(
            r.deflate(r.width * 0.14), Radius.circular(r.width * 0.2))),
      PlayerShape.diamond => poly(4, -math.pi / 2),
      PlayerShape.star => poly(5, -math.pi / 2, 0.48),
      PlayerShape.hexagon => poly(6, 0),
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = pathFor(shape, Offset.zero & size);
    canvas.drawPath(path, Paint()..color = color);
    if (outline != null) {
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = outlineWidth ?? size.width * 0.1
            ..strokeJoin = StrokeJoin.round
            ..color = outline!);
    }
  }

  @override
  bool shouldRepaint(PlayerShapePainter old) =>
      old.shape != shape || old.color != color || old.outline != outline;
}

/// A player's seat: colour, shape and initial. [seat] picks the shape; when null it's found
/// from the colour (the default player colours map to seats).
class PlayerAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final int? seat;
  final double size;
  const PlayerAvatar(
      {super.key,
      required this.name,
      required this.color,
      this.seat,
      this.size = 40});

  @override
  Widget build(BuildContext context) {
    final s = seat ?? PlayerPalette.indexOf(color);
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                Color.lerp(color, Colors.white, 0.2)!,
                fillFor(color)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: Colors.white, width: size * 0.06),
            ),
            child: Text(initial,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.46,
                    fontWeight: FontWeight.w900,
                    height: 1)),
          ),
          if (s != null)
            Positioned(
              right: -size * 0.08,
              bottom: -size * 0.08,
              child: SizedBox(
                width: size * 0.42,
                height: size * 0.42,
                child: CustomPaint(
                    painter: PlayerShapePainter(PlayerPalette.shape(s), color,
                        outline: Colors.white)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// A player's name (and maybe score) on a contrast-safe fill, with their shape.
/// [active] lights it up (whose turn); [dim] for players who are out.
class PlayerChip extends StatelessWidget {
  final String name;
  final Color color;
  final int? score;
  final bool active;
  final bool dim;
  final int? seat;
  final String? suffix;
  const PlayerChip(
      {super.key,
      required this.name,
      required this.color,
      this.score,
      this.active = false,
      this.dim = false,
      this.seat,
      this.suffix});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final s = seat ?? PlayerPalette.indexOf(color);
    final fill = active ? fillFor(color) : (t.flat ? Colors.white : t.glass);
    final fg = active ? Colors.white : (t.flat ? t.text : t.onBg);
    final label =
        '${name}${score != null ? ', $score' : ''}${suffix != null ? ', $suffix' : ''}${active ? ', playing now' : ''}';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: dim ? 0.45 : 1,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.normal),
          curve: Motion.standard,
          padding: const EdgeInsets.fromLTRB(Space.s, 5, Space.m, 5),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: color, width: 2),
            boxShadow: active && !t.flat
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.5), blurRadius: 10)
                  ]
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (s != null) ...[
              SizedBox(
                  width: 13,
                  height: 13,
                  child: CustomPaint(
                      painter: PlayerShapePainter(PlayerPalette.shape(s),
                          active ? Colors.white : color))),
              const SizedBox(width: 5),
            ],
            Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: fg, fontWeight: FontWeight.w900, fontSize: 13))),
            if (score != null) ...[
              const SizedBox(width: 6),
              Text('$score',
                  style: t.styles.score.copyWith(color: fg, fontSize: 15)),
            ],
            if (suffix != null) ...[
              const SizedBox(width: 4),
              Text(suffix!,
                  style: TextStyle(
                      color: fg, fontWeight: FontWeight.w800, fontSize: 12))
            ],
          ]),
        ),
      ),
    );
  }
}

/// A ring that empties as time runs out, with the seconds in the middle.
class TimerRing extends StatelessWidget {
  final double fraction; // 1 = full time left
  final String label;
  final double size;
  final bool urgent;
  final Color? color;
  const TimerRing(
      {super.key,
      required this.fraction,
      required this.label,
      this.size = 44,
      this.urgent = false,
      this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = urgent ? t.danger : (color ?? t.accent);
    return Semantics(
      label: 'Time left $label',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
              fraction.clamp(0, 1), c, t.flat ? t.strokeStrong : t.stroke),
          child: Center(
              child: Text(label,
                  style: t.styles.score.copyWith(
                      fontSize: size * 0.32,
                      color: urgent ? t.danger : (t.flat ? t.text : t.onBg)))),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double f;
  final Color c, track;
  _RingPainter(this.f, this.c, this.track);
  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(3);
    canvas.drawArc(
        r,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = track);
    canvas.drawArc(
        r,
        -math.pi / 2,
        2 * math.pi * f,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = c);
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.f != f || o.c != c || o.track != track;
}

/// The turn / moment panel under the HUD or scene (spec 2.4): a big Lilita line, a small
/// Nunito line, the player's badge or an icon. [kind] picks the look: turn (the player's
/// colour), success (gold), miss (red, with a draining bar for the reveal time), info.
class TurnBanner extends StatelessWidget {
  final String text;
  final Color color;
  final int? seat;
  final bool compact;
  final String? sub; // the small line: what to do
  final TurnBannerKind kind;
  final GameIcons? icon; // instead of the badge
  final double? drain; // miss: 1 -> 0 while the cards show
  const TurnBanner(
      {super.key,
      required this.text,
      required this.color,
      this.seat,
      this.compact = false,
      this.sub,
      this.kind = TurnBannerKind.turn,
      this.icon,
      this.drain});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final s = seat ?? PlayerPalette.indexOf(color);
    final (Color line, Color edge, Color fill) = switch (kind) {
      TurnBannerKind.turn => (
          t.flat ? fillFor(color) : nameColor(color),
          color.withValues(alpha: 0.55),
          color.withValues(alpha: t.flat ? 0.12 : 0.10)
        ),
      TurnBannerKind.success => (
          t.flat ? const Color(0xFF8A5A00) : Brand.gold,
          Brand.gold.withValues(alpha: 0.7),
          Brand.gold.withValues(alpha: 0.14)
        ),
      TurnBannerKind.miss => (
          t.flat ? FlatPalette.close : const Color(0xFFFF8E8B),
          const Color(0xFFFF5E5B).withValues(alpha: 0.6),
          const Color(0xFFFF5E5B).withValues(alpha: 0.12)
        ),
      TurnBannerKind.info => (
          t.flat ? t.text : Colors.white,
          t.flat ? t.strokeStrong : t.stroke,
          t.flat ? Colors.white : t.surface
        ),
    };
    final Widget? lead = icon != null
        ? GameIcon(icon!, size: compact ? 20 : 24, color: line)
        : (kind == TurnBannerKind.turn && s != null
            ? PlayerBadge(index: s, size: compact ? 20 : 24, color: color)
            : null);
    return Semantics(
      liveRegion: true,
      label: stripEmoji(sub == null ? text : '$text. $sub'),
      excludeSemantics: true,
      child: AnimatedSwitcher(
        duration: Motion.of(context, Motion.normal),
        transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
                scale: Tween(begin: 0.94, end: 1.0).animate(a), child: child)),
        child: Container(
          key: ValueKey('$kind$text${sub ?? ''}'),
          constraints: BoxConstraints(minHeight: compact ? 36 : 44),
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14, vertical: compact ? 3 : 6),
          decoration: BoxDecoration(
            color: t.flat ? Color.alphaBlend(fill, Colors.white) : fill,
            borderRadius: BorderRadius.circular(compact ? 14 : 18),
            border: Border.all(
                color: edge, width: kind == TurnBannerKind.info ? 1 : 1.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (lead != null) ...[lead, SizedBox(width: compact ? 8 : 10)],
              Flexible(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: lead == null
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      Text(stripEmoji(text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: Fonts.display,
                              fontSize: compact ? 16 : 20,
                              height: 1.0,
                              color: line)),
                      if (sub != null)
                        Text(stripEmoji(sub!),
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: Fonts.body,
                                fontSize: compact ? 12 : 13,
                                fontWeight: FontWeight.w700,
                                color: t.flat
                                    ? t.textMuted
                                    : NeonPalette.textMuted)),
                    ]),
              ),
            ]),
            if (drain != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                    value: drain!.clamp(0, 1),
                    minHeight: 3,
                    color: line,
                    backgroundColor: line.withValues(alpha: 0.2)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// A room code in big, spaced, readable characters with a copy button.
class RoomCodeDisplay extends StatelessWidget {
  final String code;
  final double size;
  const RoomCodeDisplay(this.code, {super.key, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: Semantics(
          label: 'Room code ${code.split('').join(' ')}',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Space.l, vertical: Space.s),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: Radii.rLg,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35), width: 2)),
            child: FittedBox(
              child: Text(code,
                  style: t.styles.score.copyWith(
                      color: Colors.white,
                      fontSize: size,
                      letterSpacing: size * 0.22,
                      height: 1.1)),
            ),
          ),
        ),
      ),
      const SizedBox(width: Space.s),
      AppIconButton(
        icon: Icons.copy_rounded,
        tooltip: 'Copy room code',
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: code));
          if (context.mounted)
            showToast(context, 'Room code $code copied', tone: Tone.success);
        },
      ),
    ]);
  }
}

/// A server message the player can read: technical fallbacks become a plain sentence.
String friendlyError(String message) =>
    message.startsWith('Something went wrong (')
        ? 'Something went wrong. Please try again.'
        : message;

/// A labelled on/off row (settings, pause menu).
class SettingSwitch extends StatelessWidget {
  final String emoji, label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? color;
  const SettingSwitch(
      {super.key,
      required this.emoji,
      required this.label,
      this.hint,
      required this.value,
      required this.onChanged,
      this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kTouchTarget),
        child: Row(children: [
          SizedBox(
              width: 34,
              child: Text(emoji, style: const TextStyle(fontSize: 20))),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: t.cardStyles.bodyStrong),
                  if (hint != null) Text(hint!, style: t.cardStyles.caption),
                ]),
          ),
          Switch(
              value: value,
              activeTrackColor: fillFor(color ?? t.accent),
              onChanged: onChanged),
        ]),
      ),
    );
  }
}

/// Settings everyone can reach: sound, haptics, reduce motion (and, from the home screen,
/// the player's name and colour).
class SettingsPanel extends StatelessWidget {
  final bool showProfile;
  final Color? color;
  const SettingsPanel({super.key, this.showProfile = false, this.color});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppSettings.haptics,
        Motion.reduceSetting,
        AppSettings.playerName,
        AppSettings.playerColor,
        AppSettings.cpuLevel,
      ]),
      builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoundControls(color: color ?? context.tk.accent),
            SettingSwitch(
                emoji: '📳',
                label: 'Vibration',
                hint: 'Buzz on hits, wins and turns',
                value: AppSettings.haptics.value,
                onChanged: AppSettings.setHaptics,
                color: color),
            SettingSwitch(
                emoji: '🐢',
                label: 'Reduce motion',
                hint: 'Fewer animations and effects',
                value: Motion.reduceSetting.value,
                onChanged: AppSettings.setReduceMotion,
                color: color),
            const SizedBox(height: Space.m),
            Text('COMPUTER OPPONENT', style: context.tk.cardStyles.label),
            const SizedBox(height: Space.s),
            Text('Easy gives them more time and worse aim. Hard is sharp.',
                style: TextStyle(
                    fontFamily: Fonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.tk.textMuted)),
            const SizedBox(height: Space.s),
            Row(children: [
              for (var i = 0; i < AppSettings.cpuLabels.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: KitChip(AppSettings.cpuLabels[i],
                      selected: AppSettings.cpuLevel.value == i,
                      onTap: () => AppSettings.setCpuLevel(i)),
                ),
              ],
            ]),
            if (showProfile) const _ProfileEditor(),
          ]),
    );
  }
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor();
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final _name = TextEditingController(text: AppSettings.playerName.value);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final seat = AppSettings.playerColor.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: Space.l),
      Text('YOUR PLAYER (on this phone)', style: t.cardStyles.label),
      const SizedBox(height: Space.s),
      Row(children: [
        PlayerAvatar(
            name: _name.text.isEmpty ? 'You' : _name.text,
            color: PlayerPalette.color(seat),
            seat: seat,
            size: 48),
        const SizedBox(width: Space.m),
        Expanded(
          child: TextField(
            controller: _name,
            maxLength: 12,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: t.text, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: 'Your name',
              counterText: '',
              filled: true,
              fillColor: t.flat ? FlatPalette.option : t.glass,
              hintStyle: TextStyle(color: t.textMuted),
            ),
            onChanged: (v) {
              setState(() {});
              AppSettings.setPlayerName(v);
            },
          ),
        ),
      ]),
      const SizedBox(height: Space.m),
      Wrap(spacing: Space.s, runSpacing: Space.s, children: [
        for (var i = 0; i < PlayerPalette.colors.length; i++)
          Semantics(
            button: true,
            selected: i == seat,
            label: 'Colour ${i + 1}',
            child: GestureDetector(
              onTap: () => AppSettings.setPlayerColor(i),
              child: Container(
                width: kTouchTarget,
                height: kTouchTarget,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: i == seat ? t.text : Colors.transparent,
                        width: 3)),
                child: CustomPaint(
                    painter: PlayerShapePainter(
                        PlayerPalette.shape(i), PlayerPalette.color(i))),
              ),
            ),
          ),
      ]),
    ]);
  }
}

/// Opens the settings sheet.
Future<void> showSettingsSheet(BuildContext context, {bool profile = true}) =>
    showAppSheet<void>(context,
        title: 'Settings',
        builder: (ctx) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsPanel(showProfile: profile),
                  // Debug builds only: the design gallery (materials and icons).
                  if (kDebugMode) ...[
                    const SizedBox(height: Space.m),
                    AppButton('Design gallery (debug)',
                        variant: ButtonVariant.ghost,
                        compact: true,
                        onPressed: () => Navigator.push(
                            ctx,
                            MaterialPageRoute(
                                builder: (_) => const DebugGalleryScreen()))),
                  ],
                ]));

/// Haptic for an important moment, respecting the vibration setting.
void haptic([HapticWeight w = HapticWeight.light]) {
  if (!AppSettings.haptics.value) return;
  switch (w) {
    case HapticWeight.selection:
      HapticFeedback.selectionClick().ignore();
    case HapticWeight.light:
      HapticFeedback.lightImpact().ignore();
    case HapticWeight.medium:
      HapticFeedback.mediumImpact().ignore();
    case HapticWeight.heavy:
      HapticFeedback.heavyImpact().ignore();
  }
}

enum HapticWeight { selection, light, medium, heavy }

/// Wobbles its child sideways (an invalid move). Bump [trigger] to replay it.
class Shake extends StatelessWidget {
  final Object? trigger;
  final Widget child;
  const Shake({super.key, required this.trigger, required this.child});

  @override
  Widget build(BuildContext context) {
    if (trigger == null || Motion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 360),
      builder: (_, v, c) => Transform.translate(
          offset: Offset(math.sin(v * math.pi * 6) * 8 * v, 0), child: c),
      child: child,
    );
  }
}

/// A player's marker (spec 2.2): their shape filled with their colour and a 1.5 px white
/// outline, optionally with an initial inside (Lilita One, dark ink on light colours).
class PlayerBadge extends StatelessWidget {
  final int index; // seat, 0-based
  final double size;
  final String? initial;
  final Color? color; // defaults to the seat colour
  const PlayerBadge(
      {super.key,
      required this.index,
      this.size = 28,
      this.initial,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? PlayerPalette.color(index);
    return Semantics(
      label: 'Player ${index + 1}',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: PlayerShapePainter(PlayerPalette.shape(index), c,
              outline: Colors.white, outlineWidth: 1.5),
          child: initial == null
              ? null
              : Center(
                  child: Text(initial!.characters.first.toUpperCase(),
                      style: TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: size * 0.5,
                          height: 1,
                          color: onColor(c))),
                ),
        ),
      ),
    );
  }
}
