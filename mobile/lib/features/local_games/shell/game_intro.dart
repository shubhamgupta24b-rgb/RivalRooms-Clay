import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import 'game_art.dart';
import 'how_to_play.dart';
import 'local_game_info.dart';

/// The game's start screen (spec 4.5, mockup app/Intro.dc.html): art header, title and
/// tagline, the first rules with "All rules", player count and rows (badge, editable name,
/// Person / Computer), options (teams, play mode) and Start pinned at the bottom.
class GameIntro extends StatelessWidget {
  final LocalGameInfo game;
  final List<GpPlayer> players;
  final int botCount; // the last [botCount] seats are computer players
  final VoidCallback onStart;
  final ValueChanged<int> onPlayerCount;
  final void Function(int seat, String name) onName;
  final ValueChanged<int>?
      onBotCount; // null: this game has no computer players
  final int? cpuLevel; // 0 easy, 1 medium, 2 hard; null when there is no bot
  final ValueChanged<int>? onCpuLevel;
  final bool? teams; // null: no team version for this game / player count
  final ValueChanged<bool>? onTeams;
  final (bool, int)? turns; // (take turns?, minutes each); null: not offered
  final void Function(bool on, int minutes)? onTurns;
  const GameIntro(
      {super.key,
      required this.game,
      required this.players,
      required this.botCount,
      required this.onStart,
      required this.onPlayerCount,
      required this.onName,
      this.onBotCount,
      this.cpuLevel,
      this.onCpuLevel,
      this.teams,
      this.onTeams,
      this.turns,
      this.onTurns});

  int get count => players.length;
  int get people => count - botCount;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final t = context.tk;
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Column(children: [
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            SizedBox(
              height: 200 + top,
              child: Stack(fit: StackFit.expand, children: [
                GameArt(id: game.id, color: game.color),
                Positioned(
                    left: 16,
                    top: top + 14,
                    child: RoundButton(
                        icon: GameIcons.back,
                        label: 'Back',
                        dark: true,
                        onPressed: () => Navigator.maybePop(context))),
              ]),
            ),
            Transform.translate(
              offset: const Offset(0, -26),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                              header: true,
                              child: Text(game.title, style: t.styles.h1)),
                          const SizedBox(height: 2),
                          Text(stripEmoji(game.tagline),
                              style: const TextStyle(
                                  fontFamily: Fonts.body,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD6DAF7))),
                          const SizedBox(height: 14),
                          _rules(context),
                          if (!game.solo) ...[
                            const SizedBox(height: 14),
                            _playersHeader(context),
                            const SizedBox(height: 8),
                            for (var i = 0; i < count; i++) ...[
                              if (i > 0) const SizedBox(height: 8),
                              _PlayerRow(
                                key: ValueKey('seat$i·${i >= people}'),
                                seat: i,
                                player: players[i],
                                computer: i >= people,
                                // Seat 1 is always a person; the computer takes the last seats.
                                onComputer: onBotCount == null || i == 0
                                    ? null
                                    : (on) => onBotCount!(
                                        on ? count - i : count - i - 1),
                                onName: (name) => onName(i, name),
                              ),
                            ],
                          ],
                          if (onBotCount != null &&
                              botCount > 0 &&
                              cpuLevel != null &&
                              onCpuLevel != null) ...[
                            const SizedBox(height: 14),
                            Text('COMPUTER', style: t.styles.label),
                            const SizedBox(height: 8),
                            Row(children: [
                              for (var i = 0; i < 3; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                Expanded(
                                  child: _ModeTile(
                                      title: const ['Easy', 'Medium', 'Hard'][i],
                                      hint: const [
                                        'Slow, misses',
                                        'A fair match',
                                        'Sharp aim'
                                      ][i],
                                      selected: cpuLevel == i,
                                      onTap: () => onCpuLevel!(i)),
                                ),
                              ],
                            ]),
                          ],
                          if (teams != null && onTeams != null) ...[
                            const SizedBox(height: 14),
                            _OptionRow(
                              icon: GameIcons.people,
                              title: 'Teams 2 vs 2',
                              subtitle: teams!
                                  ? '${players[0].name} + ${players[2].name} vs ${players[1].name} + ${players[3].name}'
                                  : 'Partners sit in opposite corners and win together',
                              value: teams!,
                              onChanged: onTeams!,
                            ),
                          ],
                          if (turns != null && onTurns != null) ...[
                            const SizedBox(height: 14),
                            Text('PLAY MODE', style: t.styles.label),
                            const SizedBox(height: 8),
                            Row(children: [
                              for (final (on, title, hint) in const [
                                (false, 'Split screen', 'Everyone at once'),
                                (
                                  true,
                                  'Take turns',
                                  'Whole screen, one at a time'
                                )
                              ]) ...[
                                if (on) const SizedBox(width: 8),
                                Expanded(
                                    child: _ModeTile(
                                        title: title,
                                        hint: hint,
                                        selected: turns!.$1 == on,
                                        onTap: () => onTurns!(on, turns!.$2))),
                              ],
                            ]),
                            if (turns!.$1) ...[
                              const SizedBox(height: 8),
                              Row(children: [
                                for (final m in turnMinuteOptions) ...[
                                  if (m != turnMinuteOptions.first)
                                    const SizedBox(width: 8),
                                  Expanded(
                                      child: _MinuteChip(
                                          minutes: m,
                                          selected: m == turns!.$2,
                                          onTap: () => onTurns!(true, m))),
                                ],
                              ]),
                            ],
                          ],
                          if (game.splitScreen &&
                              people > 1 &&
                              !game.solo &&
                              !(turns?.$1 ?? false)) ...[
                            const SizedBox(height: 12),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const GameIcon(GameIcons.rotate,
                                      size: 16, color: NeonPalette.textMuted),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                        count == 2
                                            ? 'Lay the phone flat · Player 1 bottom, Player 2 top'
                                            : 'Lay the phone flat · everyone sits at their own zone',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontFamily: Fonts.body,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: NeonPalette.textMuted)),
                                  ),
                                ]),
                          ],
                        ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: GoldButton('Start',
                  height: 58, fontSize: 24, onPressed: onStart),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _rules(BuildContext context) {
    final shown = game.rules.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: Skin.surface(radius: Radii.button, depth: 0.85),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          RuleStep(index: i, rule: shown[i])
        ],
        Padding(
          padding: const EdgeInsets.only(left: 34),
          child: TextButton(
            onPressed: () => showHowToPlay(context, game),
            style: TextButton.styleFrom(
                foregroundColor: Brand.gold,
                minimumSize: const Size(kTouchTarget, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: Text(game.rules.length > 3 ? 'All rules' : 'How to play',
                style: const TextStyle(
                    fontFamily: Fonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
    );
  }

  Widget _playersHeader(BuildContext context) {
    final canChange = game.maxPlayers > game.minPlayers;
    Widget step(String glyph, String label, VoidCallback? onTap) => Semantics(
          key: ValueKey('players$glyph'),
          button: true,
          enabled: onTap != null,
          label: label,
          excludeSemantics: true,
          child: Opacity(
            opacity: onTap == null ? 0.35 : 1,
            child: Squash(
              enabled: onTap != null,
              onTap: onTap == null
                  ? null
                  : () {
                      haptic(HapticWeight.selection);
                      onTap();
                    },
              builder: (down) => Container(
                width: kTouchTarget,
                height: kTouchTarget,
                decoration: Skin.round(pressed: down),
                child: Center(
                    child: GameIcon(
                        glyph == '-' ? GameIcons.minus : GameIcons.plus,
                        size: 18)),
              ),
            ),
          ),
        );
    return Row(children: [
      const Expanded(
          child: Text('PLAYERS',
              style: TextStyle(
                  fontFamily: Fonts.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.82,
                  color: Colors.white))),
      if (canChange) ...[
        step('-', 'Fewer players',
            count > game.minPlayers ? () => onPlayerCount(count - 1) : null),
        const SizedBox(width: 6),
        Semantics(
          label: '$count players',
          liveRegion: true,
          excludeSemantics: true,
          child: SizedBox(
              width: 24,
              child: Text('$count',
                  key: const ValueKey('playerCount'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 24,
                      color: Colors.white))),
        ),
        const SizedBox(width: 6),
        step('+', 'More players',
            count < game.maxPlayers ? () => onPlayerCount(count + 1) : null),
      ],
    ]);
  }
}

/// A player's row: badge, editable name, and Person / Computer.
class _PlayerRow extends StatefulWidget {
  final int seat;
  final GpPlayer player;
  final bool computer;
  final ValueChanged<bool>? onComputer; // null: can't be the computer
  final ValueChanged<String> onName;
  const _PlayerRow(
      {super.key,
      required this.seat,
      required this.player,
      required this.computer,
      required this.onComputer,
      required this.onName});

  @override
  State<_PlayerRow> createState() => _PlayerRowState();
}

class _PlayerRowState extends State<_PlayerRow> {
  late final _name = TextEditingController(text: widget.player.name);

  final _focus = FocusNode();

  @override
  void didUpdateWidget(_PlayerRow old) {
    super.didUpdateWidget(old);
    // A default name changed (You / Player 1) while nobody is typing here.
    if (!_focus.hasFocus && widget.player.name != _name.text)
      _name.text = widget.player.name;
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.player.color;
    final shape = PlayerPalette.indexOf(c) ?? widget.seat;
    const nameStyle = TextStyle(
        fontFamily: Fonts.body,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: Colors.white);
    return Container(
      height: 54,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: Skin.surface(radius: Radii.lg, depth: 0.7),
      child: Row(children: [
        PlayerBadge(
            index: shape, size: 26, color: c, initial: widget.player.name),
        const SizedBox(width: 10),
        Expanded(
          child: widget.computer
              ? Text(widget.player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nameStyle)
              : TextField(
                  controller: _name,
                  focusNode: _focus,
                  maxLength: 12,
                  textCapitalization: TextCapitalization.words,
                  style: nameStyle,
                  cursorColor: Brand.gold,
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => widget.onName(v.trim()),
                  onSubmitted: (v) => widget.onName(v.trim()),
                ),
        ),
        const SizedBox(width: 8),
        if (widget.onComputer == null)
          const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Text('Person',
                  style: TextStyle(
                      fontFamily: Fonts.body,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: NeonPalette.textMuted)))
        else
          Semantics(
            key: ValueKey('cpu${widget.seat}'),
            toggled: widget.computer,
            label: 'Player ${widget.seat + 1} is the computer',
            onTap: () => widget.onComputer!(!widget.computer),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: Radii.rChip,
              onTap: () {
                haptic(HapticWeight.selection);
                widget.onComputer!(!widget.computer);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kTouchTarget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.computer ? 'Computer' : 'Person',
                        style: TextStyle(
                            fontFamily: Fonts.body,
                            fontSize: 12,
                            fontWeight: widget.computer
                                ? FontWeight.w900
                                : FontWeight.w800,
                            color: widget.computer
                                ? PlayerPalette.tintFor(c)
                                : NeonPalette.textMuted)),
                    const SizedBox(width: 6),
                    IgnorePointer(
                        child: PillSwitch(
                            value: widget.computer,
                            small: true,
                            color: c,
                            onChanged: (_) {})),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// An on/off option row (Teams).
class _OptionRow extends StatelessWidget {
  final GameIcons icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _OptionRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: SkinPanel(
        radius: Radii.lg,
        depth: 0.75,
        ring: value ? Brand.gold.withValues(alpha: 0.75) : null,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(children: [
            GameIcon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontFamily: Fonts.body,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontFamily: Fonts.body,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: NeonPalette.textMuted)),
                  ]),
            ),
            const SizedBox(width: 8),
            PillSwitch(value: value, onChanged: onChanged, color: Brand.gold),
          ]),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final String title, hint;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTile(
      {required this.title,
      required this.hint,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          haptic(HapticWeight.selection);
          onTap();
        },
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: Skin.surface(
              radius: Radii.lg,
              ring: selected ? Brand.gold : null,
              depth: selected ? 1 : 0.6,
              tint: selected ? Brand.gold : null),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 17,
                    color: selected ? Brand.gold : Colors.white)),
            Text(hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: Fonts.body,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: NeonPalette.textMuted)),
          ]),
        ),
      ),
    );
  }
}

class _MinuteChip extends StatelessWidget {
  final int minutes;
  final bool selected;
  final VoidCallback onTap;
  const _MinuteChip(
      {required this.minutes, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$minutes minutes each',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          haptic(HapticWeight.selection);
          onTap();
        },
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          height: kTouchTarget,
          alignment: Alignment.center,
          decoration: Skin.chip(selected: selected),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                GameIcon(GameIcons.clock,
                    size: 16, color: selected ? Brand.onGold : Colors.white),
                const SizedBox(width: 6),
                Text('$minutes min',
                    style: TextStyle(
                        fontFamily: Fonts.body,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: selected ? Brand.onGold : Colors.white)),
              ])),
        ),
      ),
    );
  }
}
