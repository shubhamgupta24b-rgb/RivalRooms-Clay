import 'package:flutter/material.dart';
import '../../../core/ui/tokens.dart';

class GpPlayer {
  final String name;
  final Color color;
  int score;
  GpPlayer({required this.name, required this.color, this.score = 0});

  /// "YOUR" for the player called "You" (vs computer), otherwise "NAME'S".
  String get whose => name == 'You' ? 'YOUR' : "${name.toUpperCase()}'S";
}

/// Defaults for up to 6 players: blue, vermilion, green, amber, violet, pink. Each seat also
/// has a shape (PlayerPalette.shapes) so players are never told apart by colour alone.
const gpPlayerColors = PlayerPalette.colors;

List<GpPlayer> defaultPlayers([int count = 2]) => [
      for (var i = 0; i < count; i++)
        GpPlayer(
            name: 'Player ${i + 1}',
            color: gpPlayerColors[i % gpPlayerColors.length])
    ];
