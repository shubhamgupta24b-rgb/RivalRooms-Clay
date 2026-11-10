import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import 'bots.dart';
import 'local_game_logic.dart';

export 'bots.dart'
    show BotSeat, BotTurn, botFor, BotScope, CpuDifficulty, CpuSkill;

typedef PlayBuilder = Widget Function(
    List<GpPlayer> players, void Function(List<int> scores) onFinished);

/// How a game is played online: the host's phone runs [create]d logic; everyone else
/// mirrors the host's [save]d state with [load]. Every player's actions (including the
/// host's own) go through [apply], which must ignore actions that aren't theirs to make.
abstract class RelayGame {
  LocalGameLogic create(int players);
  Map<String, dynamic> save(LocalGameLogic g);
  void load(LocalGameLogic g, Map<String, dynamic> state, int me);
  void apply(LocalGameLogic g, int from, String name, List<Object?> args);
  Widget view(
      BuildContext context, LocalGameLogic g, List<GpPlayer> players, int me);

  /// Actions sent many times a second (paddle moves); only the latest is sent, ~20 a second.
  Set<String> get continuous;

  /// Host-side housekeeping after each change, e.g. skipping pass-the-phone screens.
  void hostAuto(LocalGameLogic g);

  /// State published to every phone. Defaults to [save]. Games with hidden information
  /// override this so opponents never receive private cards, ships, or roles.
  Map<String, dynamic> wireState(LocalGameLogic g) => save(g);

  /// Per-seat secrets merged into that player's copy only (`_seat` on the payload).
  List<Map<String, dynamic>>? seatViews(LocalGameLogic g) => null;
}

class RelaySpec<T extends LocalGameLogic> implements RelayGame {
  final T Function(int players) _create;
  final Map<String, dynamic> Function(T g) _save;
  final void Function(T g, Map<String, dynamic> s, int me) _load;
  final void Function(T g, int from, String name, List<Object?> args) _apply;
  final Widget Function(
      BuildContext context, T g, List<GpPlayer> players, int me) _view;
  final void Function(T g)? _hostAuto;
  final Map<String, dynamic> Function(T g)? _wire;
  final List<Map<String, dynamic>>? Function(T g)? _views;
  @override
  final Set<String> continuous;

  RelaySpec({
    required T Function(int players) create,
    required Map<String, dynamic> Function(T g) save,
    required void Function(T g, Map<String, dynamic> s, int me) load,
    required void Function(T g, int from, String name, List<Object?> args)
        apply,
    required Widget Function(
            BuildContext context, T g, List<GpPlayer> players, int me)
        view,
    void Function(T g)? hostAuto,
    Map<String, dynamic> Function(T g)? wire,
    List<Map<String, dynamic>>? Function(T g)? views,
    this.continuous = const {},
  })  : _create = create,
        _save = save,
        _load = load,
        _apply = apply,
        _view = view,
        _hostAuto = hostAuto,
        _wire = wire,
        _views = views;

  @override
  LocalGameLogic create(int players) => _create(players);
  @override
  Map<String, dynamic> save(LocalGameLogic g) => _save(g as T);
  @override
  void load(LocalGameLogic g, Map<String, dynamic> state, int me) =>
      _load(g as T, state, me);
  @override
  void apply(LocalGameLogic g, int from, String name, List<Object?> args) =>
      _apply(g as T, from, name, args);
  @override
  Widget view(BuildContext context, LocalGameLogic g, List<GpPlayer> players,
          int me) =>
      _view(context, g as T, players, me);
  @override
  void hostAuto(LocalGameLogic g) => _hostAuto?.call(g as T);
  @override
  Map<String, dynamic> wireState(LocalGameLogic g) =>
      _wire != null ? _wire(g as T) : save(g);
  @override
  List<Map<String, dynamic>>? seatViews(LocalGameLogic g) =>
      _views?.call(g as T);
}

/// JSON helpers for [RelaySpec.save]/[RelaySpec.load].
List<int> ints(Object? v) => [for (final x in v as List) (x as num).toInt()];
List<int?> nInts(Object? v) =>
    [for (final x in v as List) (x as num?)?.toInt()];
List<double> doubles(Object? v) =>
    [for (final x in v as List) (x as num).toDouble()];
int? nInt(Object? v) => (v as num?)?.toInt();
int asInt(Object? v) => (v as num).toInt();
double asDouble(Object? v) => (v as num).toDouble();

/// Minutes each player can choose for a "take turns" match.
const turnMinuteOptions = [1, 2, 3, 5];

/// "Take turns" on one phone: instead of a shrunken split screen, each player gets the whole
/// screen for the chosen time, one after another. Highest score wins.
class TurnsSpec {
  /// One player's turn, full screen, lasting [durationMs]; calls [onDone] with the score.
  final Widget Function(
      GpPlayer player, int durationMs, void Function(int score) onDone) play;

  /// A computer player's turn, played instantly without a screen; returns its score.
  final int Function(int durationMs, Random rng) simulate;
  const TurnsSpec({required this.play, required this.simulate});
}

/// Plays one seat of [g] with [bot] for [durationMs] of game time, as fast as possible.
int simulateTurn(LocalGameLogic g, BotTurn bot, int durationMs, Random rng) {
  final seat = BotSeat(0, rng);
  for (var t = 0; t <= durationMs && !g.finished; t += 50) {
    g.update(t);
    bot(g, seat, t);
  }
  return g.scores.first;
}

/// Everything the shared shell needs to present one game.
class LocalGameInfo {
  final String id;
  final String title;
  final String emoji;
  final Color color;
  final String tagline;
  final List<String> rules;
  final String scoreUnit; // "taps", "points", "pairs", "cells"
  final bool splitScreen; // players sit at opposite ends of the phone
  final int minPlayers; // fewest players the game works with (1 for solo games)
  bool get solo => maxPlayers == 1;
  final int maxPlayers; // 2-6; the intro screen lets players pick how many
  final PlayBuilder play;
  final RelayGame? online; // how to play it over the internet, if it can be
  final BotTurn? bot; // how the computer plays a seat, if it can
  /// A 2 vs 2 version (4 players), offered as a TEAMS switch on this game's start screen.
  final LocalGameInfo? teamVariant;

  /// Offers "take turns" (full screen, one player at a time) instead of a split screen.
  final TurnsSpec? turns;

  /// Hidden from the one-phone hub. Played only from an online room (two devices).
  final bool remoteOnly;
  const LocalGameInfo({
    this.bot,
    this.teamVariant,
    this.turns,
    this.remoteOnly = false,
    this.minPlayers = 2,
    this.maxPlayers = 2,
    this.online,
    required this.id,
    required this.title,
    required this.emoji,
    required this.color,
    required this.tagline,
    required this.rules,
    required this.scoreUnit,
    required this.splitScreen,
    required this.play,
  });
}
