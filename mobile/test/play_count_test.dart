import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/home/play_count.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';

void main() {
  test('3+ is every game whose max is more than 3, with no 5–6 bucket', () {
    expect(
        supportsPlayCount(minPlayers: 2, maxPlayers: 2, count: PlayCount.threePlus),
        isFalse);
    expect(
        supportsPlayCount(minPlayers: 2, maxPlayers: 4, count: PlayCount.threePlus),
        isTrue);
    expect(
        supportsPlayCount(minPlayers: 4, maxPlayers: 6, count: PlayCount.threePlus),
        isTrue);
    expect(
        supportsPlayCount(minPlayers: 1, maxPlayers: 1, count: PlayCount.threePlus),
        isFalse);
    expect(
        supportsPlayCount(minPlayers: 2, maxPlayers: 6, count: PlayCount.two),
        isTrue);
    expect(
        supportsPlayCount(minPlayers: 2, maxPlayers: 6, count: PlayCount.three),
        isTrue);
    expect(
        supportsPlayCount(minPlayers: 1, maxPlayers: 1, count: PlayCount.solo),
        isTrue);

    final moreThanThree = localGames
        .where((g) => supportsPlayCount(
            minPlayers: g.minPlayers,
            maxPlayers: g.maxPlayers,
            count: PlayCount.threePlus))
        .toList();
    expect(moreThanThree, isNotEmpty);
    expect(moreThanThree.every((g) => g.maxPlayers > 3), isTrue);
    expect(moreThanThree.any((g) => g.maxPlayers == 2), isFalse);
  });
}
