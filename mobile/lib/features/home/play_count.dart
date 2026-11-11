/// How many people the home screen is gathering a game for.
enum PlayCount { solo, two, three, threePlus }

/// Titles for the filtered grid that follows a count card.
String playCountTitle(PlayCount count) => switch (count) {
      PlayCount.solo => 'Solo games',
      PlayCount.two => '2-player games',
      PlayCount.three => '3-player games',
      PlayCount.threePlus => '3+ player games',
    };

/// Whether a game can be played at [count].
///
/// Solo is one-player games. Two and three are games whose player range
/// includes that number. 3+ is every game whose maximum is more than 3
/// (4, 5 or 6), with no separate 5–6 bucket.
bool supportsPlayCount({
  required int minPlayers,
  required int maxPlayers,
  required PlayCount count,
}) {
  final solo = maxPlayers <= 1;
  return switch (count) {
    PlayCount.solo => solo,
    PlayCount.two => !solo && minPlayers <= 2 && maxPlayers >= 2,
    PlayCount.three => !solo && minPlayers <= 3 && maxPlayers >= 3,
    PlayCount.threePlus => maxPlayers > 3,
  };
}
