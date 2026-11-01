import 'package:flutter/material.dart';
import '../features/local_games/local_games_hub_screen.dart';

enum GameCategory {
  cards('CARDS'),
  board('BOARD'),
  action('ACTION'),
  party('PARTY');

  final String label;
  const GameCategory(this.label);
}

/// A game you can create an online room for.
class GameInfo {
  final String id;
  final String name;
  final bool playable;
  final int minPlayers;
  final int maxPlayers;
  final String emoji;
  final Color color;
  final String tagline;
  final GameCategory category;
  const GameInfo(this.id, this.name,
      {this.playable = false,
      this.minPlayers = 2,
      this.maxPlayers = 4,
      this.emoji = '🎮',
      this.color = const Color(0xFF7B4DFF),
      this.tagline = '',
      this.category = GameCategory.party});

  String get playersLabel =>
      minPlayers == maxPlayers ? '$maxPlayers' : '$minPlayers–$maxPlayers';
}

/// Online version of a one-device game, using its look. [max] caps the room size where
/// the online version supports fewer players than the one-device one.
GameInfo _local(String id, GameCategory category, {int? max}) {
  final g = allLocalGames.firstWhere((x) => x.id == id);
  return GameInfo(id, g.title,
      playable: true,
      emoji: g.emoji,
      color: g.color,
      tagline: g.tagline,
      minPlayers: g.minPlayers,
      maxPlayers: max ?? g.maxPlayers,
      category: category);
}

final List<GameInfo> gameCatalog = [
  _local('colour_clash', GameCategory.cards),
  const GameInfo('raja_mantri', 'Raja Mantri Chor Sipahi',
      playable: true,
      minPlayers: 4,
      maxPlayers: 4,
      emoji: '👑',
      color: Color(0xFF8A1C3A),
      tagline: 'Can the Mantri catch the Chor?',
      category: GameCategory.cards),
  _local('ludo', GameCategory.board),
  _local('ludo_teams', GameCategory.board),
  _local('bingo', GameCategory.board),
  _local('battleship', GameCategory.board),
  _local('checkers', GameCategory.board),
  _local('snakes_ladders', GameCategory.board),
  _local('dots_boxes', GameCategory.board),
  _local('connect_four', GameCategory.board),
  _local('tic_tac_toe', GameCategory.board),
  _local('memory', GameCategory.board, max: 4),
  const GameInfo('guess_who', 'Guess Who',
      playable: true,
      maxPlayers: 2,
      emoji: '🕵️',
      color: Color(0xFFE0A800),
      tagline: 'Ask yes/no questions, find their person',
      category: GameCategory.board),
  _local('chess', GameCategory.board),
  const GameInfo('nitro_knockout', 'Nitro Knockout',
      playable: true,
      minPlayers: 2,
      maxPlayers: 10,
      emoji: '🏎️',
      color: Color(0xFFFF5722),
      tagline: '3D arena kart combat · most knockouts wins',
      category: GameCategory.action),
  _local('air_hockey', GameCategory.action),
  _local('ping_pong', GameCategory.action),
  _local('basketball_hoops', GameCategory.action, max: 4),
  _local('paint_fight', GameCategory.action, max: 4),
  _local('reaction_tap', GameCategory.action),
  _local('math_duel', GameCategory.action),
  _local('hand_cricket', GameCategory.action),
  _local('quiz_battle', GameCategory.action),
  _local('fruit_merge_battle', GameCategory.action),
  _local('ring_sort', GameCategory.action),
  _local('mini_golf', GameCategory.action),
  _local('slingshot', GameCategory.action),
  _local('archery', GameCategory.action),
  _local('shooting_gallery', GameCategory.action),
  _local('bottle_smash', GameCategory.action),
  _local('tug_of_war', GameCategory.action),
  _local('darts', GameCategory.action),
  _local('knife_hit', GameCategory.action),
  _local('cup_pong', GameCategory.action),
  _local('hungry_hippos', GameCategory.action),
  _local('penguin_push', GameCategory.action),
  _local('find_spy', GameCategory.party),
  _local('mafia', GameCategory.party),
  _local('undercover', GameCategory.party),
  _local('charades', GameCategory.party),
  _local('heads_up', GameCategory.party),
  _local('draw_guess', GameCategory.party),
  _local('most_likely', GameCategory.party),
  _local('would_rather', GameCategory.party),
  _local('truth_dare', GameCategory.party),
  _local('rock_paper_scissors', GameCategory.party),
  _local('hot_potato', GameCategory.party),
  _local('minesweeper', GameCategory.action),
  _local('color_switch', GameCategory.action),
  _local('fruit_cut', GameCategory.action),
  _local('chicken_jump', GameCategory.action),
  _local('carrom', GameCategory.board),
  _local('eight_ball', GameCategory.board),
  _local('bike_race', GameCategory.action),
];

String gameName(String id) => gameCatalog
    .firstWhere((g) => g.id == id, orElse: () => GameInfo(id, id))
    .name;
