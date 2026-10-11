import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_shell.dart' show PauseButton, HelpButton, LeaveGameScope;

/// Common layout for the party games: the game top bar (pause, title, state, help) and a body.
class PartyFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  const PartyFrame({super.key, required this.title, this.subtitle, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.l),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GameTopBar(title: title, subtitle: subtitle, trailing: trailing),
          const SizedBox(height: Space.m),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: Space.xs), child: child)),
        ]),
      );
}

/// The game top bar (spec 2.5): pause · the game name in small caps with the state line in
/// Lilita under it ("Arrow 3 of 5", "6 pairs left") · help. [trailing] sits before help.
/// The state line also shows on the pause sheet.
class GameTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool help;
  const GameTopBar({super.key, required this.title, this.subtitle, this.trailing, this.help = true});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    LeaveGameScope.stateOf(context)?.value = subtitle == null ? null : stripEmoji(subtitle!);
    final label = stripEmoji(title).toUpperCase();
    return Row(children: [
      const PauseButton(),
      const SizedBox(width: Space.xs),
      Expanded(
        child: Semantics(
          header: true,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: t.styles.label.copyWith(color: t.flat ? t.onBg : null)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(stripEmoji(subtitle!), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: t.styles.h3.copyWith(color: t.onBg, letterSpacing: 0.4, height: 1.1)),
            ],
          ]),
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: Space.xs), trailing!],
      const SizedBox(width: Space.xs),
      if (help) const HelpButton() else const SizedBox(width: kTouchTarget),
    ]);
  }
}

/// "Pass the phone to NAME" with their badge (spec 2.14). The secret shows only after a
/// press-and-hold, so a stray tap never shows it to the table, and this screen never shows
/// the last player's secret. [onDone] hides it again and passes on.
class PassAndReveal extends StatelessWidget {
  final GpPlayer player;
  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback? onDone; // null: not yet (e.g. a choice must be made first)
  final Widget secret;
  final String doneLabel;
  const PassAndReveal({super.key, required this.player, required this.revealed, required this.onReveal, required this.onDone, required this.secret, this.doneLabel = 'Hide & pass'});

  @override
  Widget build(BuildContext context) {
    if (!revealed) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: Space.l),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _Handoff(player: player, holdLabel: 'Hold to see your secret', onReveal: onReveal),
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: Center(child: SingleChildScrollView(child: secret))),
      const SizedBox(height: Space.s),
      GoldButton(sentenceCase(doneLabel), icon: GameIcons.eye, onPressed: onDone),
    ]);
  }
}

/// "GOT IT · HIDE & PASS" -> "Got it · hide & pass": buttons read in sentence case.
String sentenceCase(String s) => s == s.toUpperCase() && s.length > 1 ? s[0] + s.substring(1).toLowerCase() : s;

/// The hand-off itself: the next player's badge and name, the look-away note, the hold button.
class _Handoff extends StatelessWidget {
  final GpPlayer player;
  final String holdLabel;
  final String note;
  final VoidCallback onReveal;
  const _Handoff({required this.player, required this.holdLabel, required this.onReveal, this.note = 'Everyone else, look away!'});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = player.color;
    final seat = PlayerPalette.indexOf(c) ?? 0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 132,
        height: 132,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0)])),
        child: PlayerBadge(index: seat, size: 88, color: c, initial: player.name),
      ),
      const SizedBox(height: Space.s),
      Text('PASS THE PHONE TO', style: t.styles.label.copyWith(color: t.flat ? t.onBg : null)),
      const SizedBox(height: 2),
      Semantics(
        liveRegion: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(player.name, style: t.styles.h1.copyWith(color: t.flat ? fillFor(c) : nameColor(c))),
        ),
      ),
      const SizedBox(height: Space.xs),
      Text(stripEmoji(note), textAlign: TextAlign.center, style: t.styles.body.copyWith(color: t.flat ? t.onBg : NeonPalette.textMuted)),
      const SizedBox(height: Space.xl),
      HoldToReveal(label: holdLabel, color: c, onRevealed: onReveal),
    ]);
  }
}

/// Covers a private screen (a card, a fleet) until the player whose turn it is holds the
/// button: the same hand-off as [PassAndReveal], over a whole game screen.
class PassCover extends StatelessWidget {
  final GpPlayer player;
  final VoidCallback onReveal;
  final String holdLabel;
  final String note;
  const PassCover({super.key, required this.player, required this.onReveal, this.holdLabel = 'Hold to see your cards', this.note = 'Everyone else, look away!'});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Positioned.fill(
      child: ColoredBox(
        color: t.bgBottom, // fully opaque: nothing of the last player's screen shows through
        child: SafeArea(
          child: Column(children: [
            const Padding(padding: EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, 0), child: Align(alignment: Alignment.centerLeft, child: PauseButton())),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Space.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _Handoff(player: player, holdLabel: sentenceCase(holdLabel), note: note, onReveal: onReveal),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A button you hold down: it fills up, and when full [onRevealed] runs. Letting go early
/// empties it again. Screen readers get a plain "activate" instead.
class HoldToReveal extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onRevealed;
  final Duration hold;
  const HoldToReveal({super.key, required this.label, required this.color, required this.onRevealed, this.hold = const Duration(milliseconds: 650)});
  @override
  State<HoldToReveal> createState() => _HoldToRevealState();
}

class _HoldToRevealState extends State<HoldToReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.hold)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        haptic(HapticWeight.medium);
        widget.onRevealed();
      }
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    haptic(HapticWeight.selection);
    _c.forward();
  }

  void _cancel() {
    if (_c.status != AnimationStatus.completed) _c.animateBack(0, duration: Motion.fast);
  }

  @override
  Widget build(BuildContext context) {
    final fill = fillFor(widget.color);
    final label = sentenceCase(widget.label);
    return Semantics(
      button: true,
      label: label.replaceFirst(RegExp('^hold to', caseSensitive: false), 'Tap to'),
      hint: 'Shows your secret',
      onTap: widget.onRevealed,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _cancel(),
        onTapCancel: _cancel,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Container(
            height: 58,
            transform: Matrix4.translationValues(0, _c.value > 0 ? 3 : 0, 0),
            decoration: BoxDecoration(borderRadius: Radii.rButton, boxShadow: Shadows.edge(Color.lerp(fill, Colors.black, 0.45)!, depth: _c.value > 0 ? 2 : 5)),
            child: ClipRRect(
              borderRadius: Radii.rButton,
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(child: ColoredBox(color: Color.lerp(fill, Colors.black, 0.3)!)),
                Positioned.fill(child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: _c.value, child: ColoredBox(color: fill))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.l),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const GameIcon(GameIcons.eye, size: 22),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: Fonts.display, fontSize: 20, color: Colors.white)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The card for words, prompts, roles and secrets (spec 2.14): paper, a category label in
/// the card colour, large Lilita text and an optional drawn [icon] (or an [emoji] key that
/// maps to one). [dark] makes a night card for hidden roles (the spy, the mafia).
class PromptCard extends StatelessWidget {
  final String header;
  final String text;
  final String? emoji; // drawn as its icon when there is one, otherwise left out
  final GameIcons? icon;
  final String? footer;
  final Color color;
  final bool dark;
  const PromptCard({super.key, required this.header, required this.text, this.emoji, this.icon, this.footer, this.color = const Color(0xFF7B4DFF), this.dark = false});

  @override
  Widget build(BuildContext context) {
    final band = fillFor(color);
    final icon = this.icon ?? (emoji == null ? null : leadingRuleIcon(emoji!));
    final ink = dark ? Colors.white : Brand.onGold;
    return TweenAnimationBuilder<double>(
      key: ValueKey(header + text),
      tween: Tween(begin: Motion.reduced(context) ? 1 : 0.88, end: 1),
      duration: Motion.of(context, Motion.slow),
      curve: Motion.pop,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: Semantics(
        label: '${stripEmoji(header)}: ${stripEmoji(text)}${footer != null ? '. ${stripEmoji(footer!)}' : ''}',
        excludeSemantics: true,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: dark ? const [Color(0xFF2A2350), Color(0xFF14102E)] : const [Color(0xFFFFFDF6), Color(0xFFF5E9D2)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: band, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x59000000), offset: Offset(0, 6), blurRadius: 14)],
          ),
          padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.l, Space.l),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: band, borderRadius: BorderRadius.circular(9)),
              child: Text(stripEmoji(header).toUpperCase(),
                  textAlign: TextAlign.center, style: TextStyle(fontFamily: Fonts.body, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.6, color: onColor(band))),
            ),
            const SizedBox(height: Space.m),
            if (icon != null) ...[GameIcon(icon, size: 56, color: dark ? Colors.white : band), const SizedBox(height: Space.s)],
            Text(stripEmoji(text), textAlign: TextAlign.center, style: TextStyle(fontFamily: Fonts.display, fontSize: 30, height: 1.1, color: ink)),
            if (footer != null) ...[
              const SizedBox(height: Space.s),
              Text(stripEmoji(footer!), textAlign: TextAlign.center, style: TextStyle(fontFamily: Fonts.body, color: dark ? NeonPalette.textMuted : FlatPalette.inkMuted, fontWeight: FontWeight.w800, fontSize: 13.5, height: 1.3)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Players as tappable chips, e.g. for voting (spec 2.14): badge + name; the picked one is
/// filled in their colour with a check. [disabled] players can't be picked; [counts] shows a
/// number per player (votes); [notes] a small line under a name, e.g. "OUT".
class PlayerPicker extends StatelessWidget {
  final List<GpPlayer> players;
  final Set<int> disabled;
  final Map<int, int> counts;
  final int? highlight;
  final void Function(int index)? onPick;
  final Map<int, String> notes;
  const PlayerPicker({super.key, required this.players, this.disabled = const {}, this.counts = const {}, this.highlight, this.onPick, this.notes = const {}});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Wrap(alignment: WrapAlignment.center, spacing: Space.s, runSpacing: Space.m, children: [
      for (var i = 0; i < players.length; i++) _chip(context, t, i),
    ]);
  }

  Widget _chip(BuildContext context, GameTokens t, int i) {
    final p = players[i];
    final picked = highlight == i;
    final off = disabled.contains(i);
    final seat = PlayerPalette.indexOf(p.color) ?? i;
    final ink = picked ? onColor(fillFor(p.color)) : (t.flat ? t.text : Colors.white);
    return Semantics(
      button: onPick != null && !off,
      enabled: !off,
      selected: picked,
      label: '${p.name}${notes[i] != null ? ', ${notes[i]}' : ''}${(counts[i] ?? 0) > 0 ? ', ${counts[i]} votes' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPick == null || off
            ? null
            : () {
                haptic(HapticWeight.selection);
                onPick!(i);
              },
        child: Opacity(
          opacity: off ? 0.4 : 1,
          child: AnimatedScale(
            duration: Motion.of(context, Motion.fast),
            scale: picked ? 1.05 : 1,
            child: Stack(clipBehavior: Clip.none, children: [
              AnimatedContainer(
                duration: Motion.of(context, Motion.normal),
                width: 96,
                constraints: const BoxConstraints(minHeight: 96),
                padding: const EdgeInsets.fromLTRB(6, Space.m, 6, Space.s),
                decoration: Skin.surface(tint: picked ? fillFor(p.color) : p.color, ring: picked ? Colors.white : p.color.withValues(alpha: 0.8), radius: Radii.button, depth: picked ? 1 : 0.7),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  PlayerBadge(index: seat, size: 40, color: p.color, initial: p.name),
                  const SizedBox(height: 6),
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Fonts.body, color: ink, fontWeight: FontWeight.w900, fontSize: 13)),
                  if (notes[i] != null)
                    Text(notes[i]!, maxLines: 1, style: TextStyle(fontFamily: Fonts.body, color: picked ? ink : (t.flat ? t.textMuted : NeonPalette.textMuted), fontWeight: FontWeight.w900, fontSize: 11)),
                ]),
              ),
              if (picked)
                Positioned(
                  left: -6,
                  top: -6,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: fillFor(p.color), width: 2)),
                    child: GameIcon(GameIcons.check, size: 14, color: fillFor(p.color)),
                  ),
                ),
              if ((counts[i] ?? 0) > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: fillFor(t.danger), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: Text('${counts[i]}', style: const TextStyle(fontFamily: Fonts.display, color: Colors.white, fontSize: 14)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Seconds-left chip with a clock; red near the end.
class TimeChip extends StatelessWidget {
  final int msLeft;
  const TimeChip(this.msLeft, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final s = (msLeft / 1000).ceil();
    final urgent = s <= 10;
    final text = s >= 60 ? '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}' : '${s}s';
    final ink = urgent ? Colors.white : (t.flat ? t.text : Colors.white);
    return Semantics(
      label: '$s seconds left',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: Skin.pill(color: urgent ? fillFor(t.danger) : NeonPalette.overlay),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          GameIcon(GameIcons.clock, size: 16, color: ink),
          const SizedBox(width: 5),
          Text(text, style: t.styles.score.copyWith(fontSize: 18, color: ink)),
        ]),
      ),
    );
  }
}

/// Shown on online phones while another player acts: "Waiting for NAME…" with a spinner.
class WaitingNote extends StatelessWidget {
  final String text;
  const WaitingNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Center(
      child: Semantics(
        liveRegion: true,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 34, height: 34, child: CircularProgressIndicator(color: Brand.gold, strokeWidth: 3.5, backgroundColor: Brand.gold.withValues(alpha: 0.18))),
          const SizedBox(height: Space.m),
          Text(stripEmoji(text), textAlign: TextAlign.center, style: t.styles.h3.copyWith(color: t.onBg)),
        ]),
      ),
    );
  }
}

/// The player with the most votes, or -1 for no votes or a tie.
int voteWinner(List<int?> votes) {
  final tally = <int, int>{};
  for (final v in votes) {
    if (v != null) tally[v] = (tally[v] ?? 0) + 1;
  }
  if (tally.isEmpty) return -1;
  final best = tally.values.reduce((a, b) => a > b ? a : b);
  final top = tally.entries.where((e) => e.value == best).map((e) => e.key).toList();
  return top.length == 1 ? top.single : -1; // tie: nobody
}
