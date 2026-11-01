import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/records/records.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/ui/app_flavor.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import 'game_intro.dart';
import 'game_pause.dart';
import 'game_style.dart';
import 'how_to_play.dart';
import 'local_game_info.dart';
import 'pause_sheet.dart';
import 'result_screen.dart';
import 'turns_play.dart';

export 'game_pause.dart';
export 'game_style.dart';
export 'result_screen.dart' show ResultExtras, ResultScope;

enum _ShellPhase { intro, countdown, playing, result }

/// Lets a game place its own pause (and help) button wherever it fits its layout.
/// [onLeave] opens the pause sheet, [onHelp] How to play; [state] is the game's current
/// state line ("Arrow 3 of 5"), shown on the pause sheet.
class LeaveGameScope extends InheritedWidget {
  final VoidCallback onLeave;
  final VoidCallback? onHelp;
  final ValueNotifier<String?>? state;
  const LeaveGameScope({
    super.key,
    required this.onLeave,
    this.onHelp,
    this.state,
    required super.child,
  });
  static VoidCallback? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LeaveGameScope>()?.onLeave;
  static VoidCallback? helpOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LeaveGameScope>()?.onHelp;
  static ValueNotifier<String?>? stateOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LeaveGameScope>()?.state;
  @override
  bool updateShouldNotify(LeaveGameScope old) => false;
}

/// The pause button every game shows: 44 px round glass. Opens the shell's pause sheet.
class PauseButton extends StatelessWidget {
  final bool dark; // on a picture (driving scenes)
  const PauseButton({super.key, this.dark = false});
  @override
  Widget build(BuildContext context) {
    final open = LeaveGameScope.of(context);
    if (open == null) return const SizedBox.shrink();
    return RoundButton(
      icon: GameIcons.pause,
      label: 'Pause',
      onPressed: open,
      dark: dark,
    );
  }
}

/// The help button of the game top bar: opens How to play and pauses the game.
class HelpButton extends StatelessWidget {
  final bool dark;
  const HelpButton({super.key, this.dark = false});
  @override
  Widget build(BuildContext context) {
    final open = LeaveGameScope.helpOf(context);
    if (open == null) return const SizedBox.shrink();
    return RoundButton(
      icon: GameIcons.help,
      label: 'How to play',
      onPressed: open,
      dark: dark,
    );
  }
}

/// Shared flow for every 1-device game: intro -> 3-2-1 -> play -> result -> play again.
/// Match wins are tallied for as long as the players stay on this screen.
class LocalGameShell extends StatefulWidget {
  final LocalGameInfo game;
  const LocalGameShell({super.key, required this.game});
  @override
  State<LocalGameShell> createState() => _LocalGameShellState();
}

class _LocalGameShellState extends State<LocalGameShell>
    with WidgetsBindingObserver {
  final _names = <int, String>{}; // names typed on the intro, by seat
  late var players = _makePlayers(widget.game.minPlayers);
  int? best; // solo games: best score on this phone
  bool newBest = false;
  late var wins = List.filled(players.length, 0);
  var phase = _ShellPhase.intro;
  var matchNo = 0;
  int botCount =
      0; // computer players (the last seats); 0 = everyone is a person
  bool get vsComputer => botCount > 0;
  List<BotSeat> _bots = const [];
  final _paused = ValueNotifier(false);
  final _stateLine = ValueNotifier<String?>(null);
  var _extras = ResultExtras();
  bool _menuOpen = false;
  bool _helpOpen = false;
  bool _background = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _background = lifecycle != null && lifecycle != AppLifecycleState.resumed;
    _syncPause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    _syncPause();
  }

  void _syncPause() => _paused.value = _background || _menuOpen || _helpOpen;

  /// People take the first seats, computer players the rest. A lone person is "You"
  /// (or the name set in Settings); the colour picked in Settings goes to seat 1.
  /// Names typed on the intro win over the defaults.
  List<GpPlayer> _makePlayers(int n) {
    final myName = AppSettings.playerName.value;
    final colours = [
      for (var i = 0; i < math.max(n, 1); i++)
        gpPlayerColors[i % gpPlayerColors.length],
    ];
    final mine = PlayerPalette.color(AppSettings.playerColor.value);
    final swap = colours.indexOf(mine);
    if (swap > 0) colours[swap] = colours[0];
    colours[0] = mine;
    if (widget.game.solo)
      return [
        GpPlayer(
          name: _names[0] ?? (myName.isEmpty ? 'You' : myName),
          color: colours[0],
        ),
      ];
    final people = n - botCount;
    return [
      for (var i = 0; i < n; i++)
        GpPlayer(
          name: i < people && (_names[i]?.isNotEmpty ?? false)
              ? _names[i]!
              : i == 0 && myName.isNotEmpty
                  ? myName
                  : (i < people
                      ? (people == 1 ? 'You' : 'Player ${i + 1}')
                      : 'CPU ${i - people + 1}'),
          color: colours[i],
        ),
    ];
  }

  /// Changing the player count (or who's playing) starts a fresh tally.
  void _setPlayerCount(int n) => setState(() {
        botCount = botCount.clamp(0, n - 1);
        players = _makePlayers(n);
        wins = List.filled(n, 0);
      });

  void _setBotCount(int n) {
    botCount = n.clamp(0, players.length - 1);
    _setPlayerCount(players.length);
  }

  void _setName(int seat, String name) => setState(() {
        if (name.isEmpty) {
          _names.remove(seat);
        } else {
          _names[seat] = name;
        }
        players = _makePlayers(players.length);
      });

  bool teams =
      false; // 2 vs 2, for games that have a team version and 4 players

  /// The game being played: its team version when TEAMS is on.
  LocalGameInfo get _game =>
      teams && players.length == 4 && widget.game.teamVariant != null
          ? widget.game.teamVariant!
          : widget.game;
  bool get _teamsOn => !identical(_game, widget.game);

  bool takeTurns =
      true; // full screen, one player at a time (games that offer it)
  int turnMinutes = 1;
  bool get _turnsOn => takeTurns && _game.turns != null && players.length > 1;

  // No 3-2-1 for solo games (you start when you're ready) or take turns (each turn has its START).
  void _start() {
    setState(() {
      // Invalidate the previous game's callbacks before the countdown starts.
      matchNo++;
      phase = _ShellPhase.countdown;
      best = null;
      newBest = false;
    });
    if (_turnsOn || widget.game.solo) _go(matchNo);
  }

  void _go(int match) {
    if (!mounted || match != matchNo || phase != _ShellPhase.countdown) return;
    setState(() {
      _syncPause();
      _stateLine.value = null;
      _extras = ResultExtras();
      // Fresh computer players every match (their memory and timing start over).
      _bots = vsComputer && _game.bot != null
          ? [
              for (var i = players.length - botCount; i < players.length; i++)
                BotSeat(i, null, players.length - botCount == 1),
            ]
          : const [];
      phase = _ShellPhase.playing;
      GameAudio.music(GameAudio.musicFor(widget.game.id));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GameAudio.stopMusic();
    _paused.dispose();
    _stateLine.dispose();
    super.dispose();
  }

  Widget _play(LocalGameInfo g) {
    final match = matchNo;
    void onFinished(List<int> scores) => _finished(match, scores);
    if (_turnsOn) {
      return TurnsPlay(
        spec: g.turns!,
        players: players,
        botSeats: vsComputer
            ? {
                for (var i = players.length - botCount; i < players.length; i++)
                  i,
              }
            : const {},
        durationMs: turnMinutes * 60000,
        onFinished: onFinished,
      );
    }
    final game = g.play(players, onFinished);
    if (_bots.isEmpty) return game;
    return BotScope(
      seats: _bots,
      turn: g.bot!,
      people: players.length - botCount,
      child: game,
    );
  }

  void _finished(int match, List<int> scores) {
    if (!mounted ||
        match != matchNo ||
        phase != _ShellPhase.playing ||
        scores.length != players.length ||
        scores.isEmpty) return;
    // Games may reuse their score list after reporting a result.
    scores = List<int>.of(scores);
    final top = scores.reduce(math.max);
    final humanLost =
        vsComputer && players.length - botCount == 1 && scores[0] < top;
    setState(() {
      for (var i = 0; i < players.length; i++) {
        players[i].score = scores[i];
      }
      final leaders = [
        for (var i = 0; i < scores.length; i++)
          if (scores[i] == top) i,
      ];
      // One winner, or a whole team (2 vs 2) winning together.
      if (leaders.length == 1 || _teamsOn && leaders.length == 2) {
        for (final i in leaders) {
          wins[i]++;
        }
      }
      phase = _ShellPhase.result;
      best = null;
      newBest = false;
    });
    haptic(HapticWeight.medium);
    GameAudio.stopMusic();
    GameAudio.sfx(humanLost ? 'lose' : 'win');
    if (_menuOpen || _helpOpen) {
      Navigator.of(context).popUntil((r) => r is! PopupRoute);
    }
    _record(match, scores);
  }

  /// My Records on this phone: solo and "you vs the computer" count as yours (with wins);
  /// a game shared by several people records the best score made on this phone.
  /// Solo games show the best score so far and a NEW BEST badge.
  Future<void> _record(int match, List<int> scores) async {
    final top = scores.reduce((a, b) => a > b ? a : b);
    final people = players.length - botCount;
    if (widget.game.solo) {
      final score = scores.single;
      var prev = 0;
      try {
        prev = (await Records.all())[widget.game.id]?.best ?? 0;
      } catch (_) {}
      await Records.add(widget.game.id, score: score);
      if (!mounted || match != matchNo || phase != _ShellPhase.result) return;
      setState(() {
        newBest = score > prev;
        best = math.max(score, prev);
      });
    } else if (vsComputer && people == 1) {
      final leaders = [
        for (var i = 0; i < scores.length; i++)
          if (scores[i] == top) i,
      ];
      final won = scores[0] == top &&
          (leaders.length == 1 || _teamsOn && leaders.length == 2);
      Records.add(_game.id, score: scores[0], won: won).ignore();
    } else {
      Records.add(_game.id, score: top).ignore();
    }
  }

  /// The pause sheet: the game clock stops while it's open.
  Future<void> _openMenu() async {
    if (_menuOpen || _helpOpen) return;
    if (phase != _ShellPhase.playing && phase != _ShellPhase.countdown) {
      Navigator.maybePop(context);
      return;
    }
    _menuOpen = true;
    _syncPause();
    haptic(HapticWeight.selection);
    final action = await showPauseSheet(
      context,
      game: _game,
      state: _stateLine.value,
    );
    if (!mounted) return;
    if (phase != _ShellPhase.playing && phase != _ShellPhase.countdown) {
      _menuOpen = false;
      _syncPause();
      return;
    }
    switch (action) {
      case PauseAction.restart:
        if (await confirmAction(
          context,
          title: 'Restart?',
          message: 'This match starts again from the beginning.',
          confirm: 'Restart',
          emoji: null,
        )) {
          if (mounted &&
              (phase == _ShellPhase.playing || phase == _ShellPhase.countdown))
            _start();
        }
      case PauseAction.quit:
        if (await confirmAction(
          context,
          title: 'Leave game?',
          message: 'This match will be lost.',
          confirm: 'Leave',
          cancel: 'Stay',
          emoji: null,
        )) {
          if (mounted) Navigator.pop(context);
          return;
        }
      case PauseAction.resume || null:
        break;
    }
    if (mounted) {
      _menuOpen = false;
      _syncPause();
    }
  }

  /// How to play from the game's help button. Pauses the game while it's open.
  Future<void> _openHelp() async {
    if (_menuOpen || _helpOpen) return;
    _helpOpen = true;
    _syncPause();
    await showHowToPlay(context, _game);
    if (mounted) {
      _helpOpen = false;
      _syncPause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final match = matchNo;
    final flat = isFlatGame(g.id) &&
        phase == _ShellPhase.playing; // intro and results keep the night look
    final Widget body = switch (phase) {
      _ShellPhase.intro => GameIntro(
          game: g,
          players: players,
          botCount: botCount,
          onStart: _start,
          onPlayerCount: _setPlayerCount,
          onName: _setName,
          onBotCount: g.bot == null ? null : _setBotCount,
          teams: g.teamVariant != null && players.length == 4 ? teams : null,
          onTeams: (on) => setState(() {
            teams = on;
            wins = List.filled(
              players.length,
              0,
            ); // a new kind of match: fresh tally
          }),
          turns: g.turns != null && players.length > 1
              ? (takeTurns, turnMinutes)
              : null,
          onTurns: (on, minutes) => setState(() {
            takeTurns = on;
            turnMinutes = minutes;
          }),
        ),
      _ShellPhase.countdown => CountdownOverlay(
          onDone: () => _go(match),
          paused: _paused,
          color: g.color,
          mirrored: g.splitScreen && players.length - botCount > 1,
        ),
      // A new key per match guarantees fresh game state on Play Again.
      _ShellPhase.playing => KeyedSubtree(
          key: ValueKey('match$matchNo'),
          child: ResultScope(
            extras: _extras,
            child: FeedbackLayer(
              child: GamePause(paused: _paused, child: _play(_game)),
            ),
          ),
        ),
      _ShellPhase.result => ResultScreen(
          game: _game,
          teams: _teamsOn,
          players: players,
          wins: wins,
          extras: _extras,
          best: best,
          newBest: newBest,
          onRematch: _start,
          onChangePlayers:
              g.solo ? null : () => setState(() => phase = _ShellPhase.intro),
          onExit: () => Navigator.pop(context),
        ),
    };
    return PopScope(
      canPop: phase != _ShellPhase.playing && phase != _ShellPhase.countdown,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _openMenu();
      },
      child: Scaffold(
        // Each game glows in its own colour (the flat app draws word games on a sky-blue board).
        body: TokenScope(
          flat: flat,
          child: GameTheme(
            color: g.color,
            emoji: g.emoji,
            flat: flat,
            id: g.id,
            child: GameBackground(
              color: g.color,
              flat: flat,
              // The intro's art runs up under the status bar; everything else stays inside it.
              child: SafeArea(
                top: phase != _ShellPhase.intro,
                child: LeaveGameScope(
                  onLeave: _openMenu,
                  onHelp: _openHelp,
                  state: _stateLine,
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.normal),
                    switchInCurve: Motion.standard,
                    child: KeyedSubtree(
                      key: ValueKey('$phase$matchNo'),
                      child: body,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
