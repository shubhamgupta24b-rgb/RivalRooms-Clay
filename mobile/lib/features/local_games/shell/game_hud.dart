import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../../core/ui/materials/materials.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/audio/game_audio.dart';
import '../party/party_widgets.dart' show GameTopBar;
import 'local_game_shell.dart' show PauseButton;

/// The shared in-game header for turn-based and score games: pause, one chip per player
/// (name, shape, score and an optional extra like 🏹3), whose turn lit up, and an optional
/// widget on the right (round, timer).
class GameHud extends StatelessWidget {
  final List<GpPlayer> players;
  final List<int>? scores;
  final int? turn; // lit-up player; null: nobody's turn (finished, or everyone at once)
  final String Function(int i)? extra; // e.g. arrows left, tokens home
  final String Function(int i)? nameOf; // e.g. team letters
  final Set<int> dimmed; // players who are out
  final Widget? trailing;
  const GameHud({super.key, required this.players, this.scores, this.turn, this.extra, this.nameOf, this.dimmed = const {}, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const PauseButton(),
      const SizedBox(width: Space.xs),
      Expanded(
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < players.length; i++)
            PlayerChip(
              name: nameOf?.call(i) ?? players[i].name,
              color: players[i].color,
              score: scores?[i],
              suffix: extra?.call(i),
              active: turn == i,
              dim: dimmed.contains(i),
            ),
        ]),
      ),
      if (trailing != null) ...[const SizedBox(width: Space.s), trailing!],
    ]);
  }
}

/// A small label for the HUD's right side (ROUND 2/4, HOLE 3/6).
class HudLabel extends StatelessWidget {
  final String text;
  const HudLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 5),
      decoration: Skin.pill(),
      child: Text(text, style: t.styles.label.copyWith(color: t.onBg, letterSpacing: 0.8)),
    );
  }
}

/// The status line under (or over) the play area: whose turn it is, or a message.
/// One style everywhere; [message] wins over the turn banner while it's set.
class GameStatus extends StatelessWidget {
  final GpPlayer? player; // whose turn
  final String? turnText; // e.g. "PLAYER 1'S TURN · pull back & let go"
  final String? message; // e.g. "🎯 BULLSEYE! +10"
  final double height;
  const GameStatus({super.key, this.player, this.turnText, this.message, this.height = 48});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final Widget child;
    if (message != null) {
      child = Text(stripEmoji(message!),
          key: ValueKey('m$message'),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: t.styles.h2.copyWith(color: t.flat ? const Color(0xFF8A5A00) : Brand.gold, shadows: t.flat ? null : const [Shadow(color: Color(0xFF7A4B00), offset: Offset(0, 3))]));
    } else if (player != null && turnText != null) {
      child = TurnBanner(key: ValueKey('t$turnText'), text: turnText!, color: player!.color);
    } else if (turnText != null) {
      child = Text(stripEmoji(turnText!), key: ValueKey('x$turnText'), textAlign: TextAlign.center, style: t.styles.bodyStrong.copyWith(color: t.onBgMuted));
    } else {
      child = const SizedBox.shrink();
    }
    return SizedBox(
      height: height,
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: AnimatedSwitcher(
            duration: Motion.of(context, Motion.normal),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: a, curve: Motion.emphasized)), child: c)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The bottom tray of the dice games (spec 5.1): whose roll it is in their colour, the last
/// event under it, and the dice on the right.
class DiceTray extends StatelessWidget {
  final String message;
  final GpPlayer player;
  final String turnText;
  final Widget dice;
  const DiceTray({super.key, required this.message, required this.player, required this.turnText, required this.dice});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final seat = PlayerPalette.indexOf(player.color) ?? 0;
    return Semantics(
      liveRegion: true,
      label: '${stripEmoji(turnText)}. ${stripEmoji(message)}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: Skin.surface(tint: player.color, ring: player.color.withValues(alpha: 0.7), radius: Radii.button, depth: 0.8),
        child: Row(children: [
          PlayerBadge(index: seat, size: 26, color: player.color, initial: player.name),
          const SizedBox(width: 10),
          Expanded(
            child: ExcludeSemantics(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(sentence(stripEmoji(turnText)), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Fonts.display, fontSize: 19, height: 1.1, color: t.flat ? fillFor(player.color) : Colors.white)),
                if (message.isNotEmpty)
                  Text(stripEmoji(message), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Fonts.body, fontSize: 12.5, fontWeight: FontWeight.w700, color: t.flat ? FlatPalette.inkMuted : NeonPalette.textMuted)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          dice,
        ]),
      ),
    );
  }
}

/// "PLAYER 1'S ROLL" -> "Player 1's roll": banners read in sentence case, names kept.
String sentence(String s) => s == s.toUpperCase() && s.length > 1 ? s[0] + s.substring(1).toLowerCase() : s;

/// The board-game header (spec 2.3, 2.5): the game top bar, then one [PlayerScoreCard] per
/// player (two columns for 2 players, a compact row for 3-4, a grid for 5-6).
class ScoreHud extends StatelessWidget {
  final String title;
  final String? state;
  final List<GpPlayer> players;
  final int? turn; // lit up; null: nobody's turn
  final String? Function(int i)? score;
  final String? Function(int i)? tag;
  final Widget? Function(int i, bool compact)? detail;
  final Set<int> out;
  final Widget? trailing;
  final String Function(int i)? nameOf;
  const ScoreHud(
      {super.key, required this.title, this.state, required this.players, this.turn, this.score, this.tag, this.detail, this.out = const {}, this.trailing, this.nameOf});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GameTopBar(title: title, subtitle: state, trailing: trailing),
      const SizedBox(height: 6),
      PlayerScoreRow(
        count: players.length,
        card: (i, compact) => PlayerScoreCard(
          seat: PlayerPalette.indexOf(players[i].color) ?? i,
          color: players[i].color,
          name: nameOf?.call(i) ?? players[i].name,
          score: score?.call(i),
          active: turn == i,
          out: out.contains(i),
          tag: tag?.call(i),
          compact: compact,
          detail: detail?.call(i, compact),
        ),
      ),
    ]);
  }
}

/// Calls [onChange] (after the frame) whenever [value] changes: how a game view turns a
/// change in its state (a message, a score) into a key-moment announcement, sound and buzz.
class MomentWatcher<T> extends StatefulWidget {
  final T value;
  final void Function(GameFeedback? fx, T before, T now) onChange;
  final Widget child;
  const MomentWatcher({super.key, required this.value, required this.onChange, required this.child});
  @override
  State<MomentWatcher<T>> createState() => _MomentWatcherState<T>();
}

class _MomentWatcherState<T> extends State<MomentWatcher<T>> {
  @override
  void didUpdateWidget(MomentWatcher<T> old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final before = old.value, now = widget.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChange(GameFeedback.of(context), before, now);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A key moment (spec 3.4): a big announcement, a sound and a buzz in one call.
void keyMoment(GameFeedback? fx, String text, {String sub = '', String sound = 'pop', HapticWeight buzz = HapticWeight.medium, Color color = Brand.gold, bool confetti = false, bool shake = false}) {
  fx?.announce(text, sub: sub, color: color);
  if (confetti) fx?.confetti();
  if (shake) fx?.shake();
  GameAudio.sfx(sound);
  haptic(buzz);
}

/// A raised wooden rim around a game board so it sits on the table, not the screen.
/// [colors] tints the rim (default: the shared wood material).
class BoardFrame extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final double rim;
  const BoardFrame({super.key, required this.child, this.colors, this.rim = 8});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(borderRadius: Radii.rLg, boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 20, offset: Offset(0, 10))]),
        child: ClipRRect(
          borderRadius: Radii.rLg,
          child: CustomPaint(
            painter: colors == null ? const WoodPainter(radius: Radii.lg) : null,
            child: Container(
              padding: EdgeInsets.all(rim),
              decoration: colors == null
                  ? BoxDecoration(borderRadius: Radii.rLg, border: Border.all(color: Colors.white.withValues(alpha: 0.18)))
                  : BoxDecoration(gradient: LinearGradient(colors: colors!, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: Radii.rLg),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(borderRadius: Radii.rSm, border: Border.all(color: const Color(0x66000000), width: 1.5)),
                child: ClipRRect(borderRadius: Radii.rSm, child: child),
              ),
            ),
          ),
        ),
      );
}

/// "Your" for the lone person (named You), otherwise "Name's".
String possessive(String name) => name == 'You' ? 'Your' : "$name's";
