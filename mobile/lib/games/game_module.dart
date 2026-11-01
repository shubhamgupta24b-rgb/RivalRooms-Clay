import 'package:flutter/material.dart';
import '../features/local_games/nitro_knockout/nitro_online_screen.dart';
import '../features/local_games/local_games_hub_screen.dart';
import '../features/local_games/online/relay_play.dart';
import 'guess_person/guess_person_screen.dart';
import 'guess_who/guess_who_screen.dart';
import 'memory/memory_screen.dart';
import 'crush_it/crush_it_screen.dart';
import 'fruit_duel/fruit_duel_screen.dart';
import 'paint_fight/paint_fight_screen.dart';
import 'raja_mantri/raja_mantri_screen.dart';

Widget? gameScreenFor(String gameType) {
  switch (gameType) {
    case 'nitro_knockout':
      return const NitroOnlineScreen();
    case 'guess_who':
      return const GuessWhoScreen();
    case 'guess_person':
      return const GuessPersonScreen();
    case 'memory':
      return const MemoryScreen();
    case 'crush_it':
      return const CrushItScreen();
    case 'fruit_duel':
      return const FruitDuelScreen();
    case 'paint_fight':
      return const PaintFightScreen();
    case 'raja_mantri':
      return const RajaMantriScreen();
  }
  // Everything else runs the one-device game on the host's phone and mirrors it.
  for (final g in allLocalGames) {
    if (g.id == gameType && g.online != null) return RelayPlay(game: g);
  }
  return null;
}
