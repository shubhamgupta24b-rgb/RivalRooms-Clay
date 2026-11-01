# Game inventory

## Catalog count

`mobile/lib/games/game_catalog.dart` is the online room selection catalog. It contained 54 entries before removal and now contains 53. The broader one-device hub has 70 shell entries before removal and now has 69, plus Guess the Person and Raja Mantri (71 total local games). Game names and player limits are defined by references to `allLocalGames` plus explicit game records.

The local one-device screen is a separate catalog in `mobile/lib/features/local_games/local_games_hub_screen.dart` and includes additional solo titles; the online catalog count must not be mistaken for the total number of local experiences. Local games share the shell, game art, audio, controls, and result components.

## Smash Karts removal

Removed from both catalogs, featured home selection, audio mapping, game art/tile scene, server relay game list, and online test expectations. Deleted the Smash Karts implementation, logic, and dedicated test. Added mobile catalog/search and server registry regression assertions. No active Smash Karts route remains. The string `smash_karts` is intentionally retained only in these negative regression assertions and the audit records.

## Multiplayer architecture

The mobile app runs a host-authoritative relay for many local game implementations. The Node registry also includes server-authoritative games and a broad relay protocol. `RoomManager` checks the registry and player limits; room actions are sequence checked and game handlers validate actions. Relay state itself is host supplied, so it is not independently authoritative for score integrity.

## Remaining game validation

Automated tests exercise game logic and widgets in aggregate, but this request's complete per-game real-device launch, setup boundary, full match, restart, and multi-device scenarios were not run. See `game_test_results.md` for honest scope.
