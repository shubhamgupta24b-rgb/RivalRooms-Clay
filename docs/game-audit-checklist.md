# Current game audit checklist

Snapshot: 2026-10-30, current working-tree metadata. **Inventory/reference research only; no game was redesigned, launched, or runtime-tested in this task.** All per-game redesign acceptance and validation remain open until the parent final suite records evidence against the final tree.

## Scope and evidence

- Inventory authority: `mobile/lib/features/local_games/local_games_hub_screen.dart` (`localGames`, `allLocalGames`, `_entries`) and the imported `LocalGameInfo` definition headers/rules/player limits. Defaults in `shell/local_game_info.dart`: 2–2 players, no online adapter, not remote-only; `solo` means `maxPlayers == 1`.
- Online selection authority: `mobile/lib/games/game_catalog.dart`. Selection is a declaration, **not proof that the route, adapter, server, or devices work**.
- Specials: `features/guess_person/screens/guess_person_menu_screen.dart`, `features/raja_mantri/rmcs_screen.dart`, and `games/guess_who/guess_who_screen.dart` under `mobile/lib/`.
- Current counts: **70 shell-list entries**, including online-only Colour Clash; **69 visible shell games + 2 special local flows = 71 visible one-device games**. `totalGameCount` now returns 71 and excludes `remoteOnly`. There are **54 online catalog entries**. The checklist covers **74 distinct IDs**: 70 shell IDs + Guess the Person + Raja Mantri + online Guess Who + Ludo teams. Ludo teams is a variant, not an extra base hub tile.
- Source inspection was bounded to metadata windows and short catalog/special-flow excerpts, well below the 15,000-line source-read limit; game implementations were not audited end-to-end.

### Historical findings, not current passes

Read `docs/ui-audit.md`, `docs/ui-overhaul-report.md`, and `reports/audit/{game_inventory,game_test_results,final_summary,nitro-backend-current}.md`. Their older counts (62, 71, etc.), removed games, screenshots, aggregate test totals, APK builds, and backend test claims describe earlier snapshots/tasks. **None establishes a current per-game pass here.**

Inherited findings to recheck: shared chrome/SoloFrame updates often left play areas unchanged; incomplete token/style migration; separate Guess Person/Raja flows; weak feedback/score integration in some games; dense-grid touch targets; unreviewed landscape, real-device accessibility/performance, LAN, and reconnect behavior. Raja's current top imports shared results, so the historical statement that it had entirely separate results must not be treated as current proof. No inherited “Done” label closes the redesign checklist below.

## Reference families (research, not exact clones)

Actual URLs surfaced by web research in this task. These are **design/mechanics comparison references, not evidence of provenance, identical rules, visual parity, affiliation, licensing, or completed testing**. No reference app was installed or played. Generic/traditional families below deliberately do not invent a commercial original. Preserve original assets/branding and review potentially confusing names (including Candy Crush, Color Switch, Knife Hit and Guess Who) before release.

| Key | Reference URL | Useful comparison, not a parity claim |
|---|---|---|
| J2 | [JindoBlu: 2 Player Games](https://www.jindoblu.com/2-player-games-the-challenge/) · [store description](https://play.google.com/store/apps/details?id=com.JindoBlu.TwoPlayerGamesChallenge) | Same-device duels, readable opposing controls; listing names ping pong, air hockey, pool, tic-tac-toe, minigolf and chess. |
| J4 | [JindoBlu: 1 2 3 4 Player Games](https://1234player.games/) · [store description](https://play.google.com/store/apps/details?id=com.JindoBlu.FourPlayers) | 2/3/4-player layouts, 2v2 and solo/AI; listing names paint fight, memory, maths, archery, tug of war and whack-a-mole. Not a claim every row occurs in that collection. |
| LK | [Ludo King](https://ludoking.com/) | Board readability, token/dice feedback and local/online setup; not its exact rules or feature set. |
| UNO | [Official UNO mobile](https://www.letsplayuno.com/) | Colour/number/action-card readability and private hands; Colour Clash has its own two-phone rules. |
| FN | [Halfbrick: Fruit Ninja Classic](https://www.halfbrick.com/games/fruit-ninja-classic) | Swipe trails, fruit/bomb separation, impact feedback. |
| SU | [Aladdin X: Suika Game](https://suikagame.jp/) | Drop/merge hierarchy, container boundary and overflow feedback. |
| 2048 | [Original 2048](https://www.2048original.com/) | Legible values, swipe/merge feedback and no-move state. |
| AB | [Rovio: Angry Birds 2](https://www.rovio.com/games/angry-birds-2/) | Pull/release aiming and readable destruction; no exact physics/assets claim. |
| CC | [King: Candy Crush Saga listing](https://play.google.com/store/apps/details?id=com.king.candycrushsaga) | Match-3 swaps, cascades, objectives and progression. |
| TT | [Official Tetris](https://tetris.com/) | Falling-block controls, rotation/landing clarity and line clears. |
| KH | [Ketchapp: Knife Hit](https://www.ketchappgames.com/game-knife-hit) | Rotating-target timing and collision feedback. |
| ST | [Ketchapp: Stack](https://www.ketchappgames.com/game-stack) | Alignment, overhang cuts and perfect-hit feedback. |
| CS | [Color Switch](https://colorswitch.co/) | Colour-gated obstacle readability; provide non-colour cues. |
| DJ | [Lima Sky: Doodle Jump](https://limasky.com/doodlejump/download/) | Auto-bounce climbing and platform differentiation. |
| GW | [Hasbro: Guess Who rules](https://instructions.hasbro.com/en-us/instruction/guess-who-classic-game) | Yes/no character deduction; the app's local and online flows are distinct. |
| UC | [Undercover: Word Party Game](https://www.yanstarstudio.com/) | Secret-word social deduction; app rules are a smaller variant, not full reference parity. |
| ZIP | Supplied local `C:/Users/sg857/Downloads/Two-player-online-nitro-knockout-420626f.zip` | **Nitro's actual supplied reference, not a marketplace game and not Smash Karts.** Archive SHA-256 reported by the historical Nitro audit: `e73a823b144af84817276b10c02c537c0f8d8e95eac80cd80898f3ea68d02f84`. Archive/hash not independently reopened or verified here. |

## Per-game checklist

**Mode legend:** offline = one device/no game server, as exposed by hub/metadata; online = room catalog declaration. Counts are metadata seat limits, not tested human/bot combinations. `C` = catalogued, runtime support unverified; `—` = not offered in that catalog, not a request to add it. `C!` = explicit catalog/adapter mismatch. `M` = metadata exposes 1–2 seats, but the two-seat local path renders a single `me: 0` viewpoint; usable two-human same-device play is **not established**. Online ranges marked `*` retain catalog `minPlayers: 1`; actual multiplayer needs at least two participants and single-seat online acceptance is unresolved. `I` = internet-only in `LanHost.internetOnly`; other online entries are LAN-advertised, **not LAN-tested**.

**Every row's `[ ] R / U` means: inherited/current UI not accepted as a completed per-game redesign; redesign/review outstanding; current gameplay, visual and supported-mode validation UNVERIFIED pending the parent final suite.** The identity/reference column supplies a game-specific redesign/test focus, not a verified implementation review. Shared shell improvements alone cannot tick R.

### Shell entries (current hub list order)

Paths below are relative to `mobile/lib/features/local_games/`; paired entries may share a file.

| # | Current title / ID · metadata file | Identity / reference and focused review | Offline seats | Online seats | Redesign / validation |
|---|---|---|---|---|---|
| 1 | Colour Clash `colour_clash` · `colour_clash/colour_clash_game.dart` | UNO reference; private hands, action cards, ONE call. | **No**, `remoteOnly` | C 2 | [ ] R / U |
| 2 | Find the Spy `find_spy` · `find_spy/find_spy_game.dart` | Spyfall-style location deduction family; secret reveal, voting, spy's final guess. | 3–6 | C 3–6 | [ ] R / U |
| 3 | Ludo `ludo` · `ludo/ludo_game.dart` | LK reference; legal moves, safe squares, captures, home path and dice feedback. | 2–4 | C 2–4 | [ ] R / U |
| 4 | Mafia `mafia` · `mafia/mafia_game.dart` | Traditional Mafia/Werewolf family; private night actions and day elimination. | 4–6 | C 4–6 | [ ] R / U |
| 5 | Undercover `undercover` · `undercover/undercover_game.dart` | UC reference; near-match words, clue order and elimination privacy. | 3–6 | C 3–6 | [ ] R / U |
| 6 | Dumb Charades `charades` · `charades/charades_game.dart` | Traditional acted-word/movie guessing; actor-only prompt, skip and timer. | 2–6 | C 2–6 | [ ] R / U |
| 7 | Snakes & Ladders `snakes_ladders` · `snakes_ladders/snakes_ladders_game.dart` | Traditional race board; ladder/snake endpoints, stacked tokens, exact finish. | 2–6 | C 2–6 | [ ] R / U |
| 8 | Draw & Guess `draw_guess` · `draw_guess/draw_guess_game.dart` | Pictionary-style family, not exact clone; secret word, ink, typed online guesses. | 2–6 | C 2–6 | [ ] R / U |
| 9 | Heads Up `heads_up` · `heads_up/heads_up_game.dart` | Forehead word-guessing family; outward-facing prompts, got-it/skip and timing. | 2–6 | C 2–6 | [ ] R / U |
| 10 | Quiz Battle `quiz_battle` · `quiz_battle/quiz_battle_game.dart` | Quiz/reflex family; readable questions, fair answer lockout, J4 layout reference. | 2–4 | C 2–4 | [ ] R / U |
| 11 | Hand Cricket `hand_cricket` · `hand_cricket/hand_cricket_game.dart` | Traditional number cricket; concealed picks, wicket/innings/target clarity. | 2 | C 2 | [ ] R / U |
| 12 | Basketball Hoops `basketball_hoops` · `basketball/basketball_game.dart` | Swipe-shot arcade basketball; moving hoop, swish scoring, split/turns layout (J4 reference). | 2–4 | C 2–4 | [ ] R / U |
| 13 | Memory `memory` · `memory/memory_game.dart` | Pair-matching family/J4 reference; flip delay, extra turns and matched ownership. | 2–6 | **C! 2–4** | [ ] R / U |
| 14 | Paint Fight `paint_fight` · `paint_fight/paint_fight_game.dart` | J4 reference; stroke origin, territory stealing and coverage feedback. | 2 | **C! 2–4** | [ ] R / U |
| 15 | Tic-Tac-Toe `tic_tac_toe` · `tic_tac_toe/tic_tac_toe_game.dart` | Traditional/J2 reference; invalid taps, win/draw and alternating starter. | 2 | C 2 | [ ] R / U |
| 16 | Air Hockey `air_hockey` · `air_hockey/air_hockey_game.dart` | J2 reference; mallet boundaries, puck collisions and goal/reset clarity. | 2 | C 2 | [ ] R / U |
| 17 | Ping Pong `ping_pong` · `ping_pong/ping_pong_game.dart` | J2 reference; opposing paddles, angled hits, serve and accelerating ball. | 2 | C 2 | [ ] R / U |
| 18 | Reaction Tap `reaction_tap` · `reaction_tap/reaction_tap_game.dart` | Reflex duel/J4 layout reference; wait/go cues beyond colour, false-start penalty. | 2–6 | C 2–6 | [ ] R / U |
| 19 | Math Duel `math_duel` · `math_duel/math_duel_game.dart` | J4 maths reference; shared question, answer lockout and integrated scores. | 2–4 | C 2–4 | [ ] R / U |
| 20 | Connect Four `connect_four` · `connect_four/connect_four_game.dart` | Traditional four-in-row; drop animation, full-column feedback and diagonal wins. | 2 | C 2 | [ ] R / U |
| 21 | Dots & Boxes `dots_boxes` · `dots_boxes/dots_boxes_game.dart` | Traditional line-claiming; edge hit areas, double boxes and retained turns. | 2–4 | C 2–4 | [ ] R / U |
| 22 | Most Likely To `most_likely` · `most_likely/most_likely_game.dart` | Party voting family; concealed votes, ties and crown reveal. | 3–6 | C 3–6 | [ ] R / U |
| 23 | Would You Rather `would_rather` · `would_rather/would_rather_game.dart` | A/B party voting; readable choices, private vote and majority/tie feedback. | 2–6 | C 2–6 | [ ] R / U |
| 24 | Truth or Dare `truth_dare` · `truth_dare/truth_dare_game.dart` | Traditional bottle-spin party; selected seat, consent/skip and round progress. | 2–6 | C 2–6 | [ ] R / U |
| 25 | Rock Paper Scissors `rock_paper_scissors` · `rps/rps_game.dart` | Traditional simultaneous picks; locked-choice privacy and multiplayer scoring. | 2–6 | C 2–6 | [ ] R / U |
| 26 | Fruit Merge Battle `fruit_merge_battle` · `fruit_merge/fruit_merge_game.dart` | SU reference adapted to score race; per-seat jars, overflow and split/turns. | 2–4 | C 2–4 | [ ] R / U |
| 27 | Bingo `bingo` · `bingo/bingo_game.dart` | 1–25 five-line Bingo variant; call history, private cards and simultaneous wins. | 2–6 | C 2–6 | [ ] R / U |
| 28 | Battleship `battleship` · `battleship/battleship_game.dart` | Hidden-fleet family; own/enemy grids, pass cover, hit-again rule and sunk state. | 2 | C 2 | [ ] R / U |
| 29 | Checkers `checkers` · `checkers/checkers_game.dart` | Traditional/J2 board reference; compulsory chains, king cues and blocked-player end. | 2 | C 2 | [ ] R / U |
| 30 | Mini Golf `mini_golf` · `mini_golf/mini_golf_game.dart` | J2 reference; pull/power preview, six-hole scorecard, wall/sand feedback. | 1–4 | C 1–4* | [ ] R / U |
| 31 | Slingshot `slingshot` · `slingshot/slingshot_game.dart` | AB reference; dotted aim, limited shots, material damage and destruction scores. | 1–4 | C 1–4* | [ ] R / U |
| 32 | Archery `archery` · `archery/archery_game.dart` | J4 reference; draw strength, wind, ring values and arrows remaining. | 1–4 | C 1–4* | [ ] R / U |
| 33 | Shooting Gallery `shooting_gallery` · `shooting_gallery/shooting_gallery_game.dart` | Carnival target family; target/bomb separation, ammo/reload and timed handoff. | 1–4 | C 1–4* | [ ] R / U |
| 34 | Bottle Smash `bottle_smash` · `bottle_smash/bottle_smash_game.dart` | Carnival knockdown family; throw preview, supported stacks and round bonuses. | 1–4 | C 1–4* | [ ] R / U |
| 35 | Chess `chess` · `chess/chess_game.dart` | Traditional/J2 reference; legal/check cues, promotion, checkmate/stalemate. | 2 | C 2 | [ ] R / U |
| 36 | Tug of War `tug_of_war` · `tug_of_war/tug_of_war_game.dart` | J4 reference; opposing tap zones, knot position and timeout result. | 2 | C 2 | [ ] R / U |
| 37 | Darts `darts` · `darts/darts_game.dart` | Arcade target darts, not assumed 501; drifting aim, multipliers and round totals. | 2–4 | C 2–4 | [ ] R / U |
| 38 | Hot Potato `hot_potato` · `hot_potato/hot_potato_game.dart` | Traditional passing game; holder/fuse cues, burns and fewest-burns result. | 2–6 | C 2–6 | [ ] R / U |
| 39 | Knife Hit `knife_hit` · `knife_hit/knife_hit_game.dart` | KH reference adapted to race; spinning logs, knife collisions and penalty feedback. | 2–4 | C 2–4 | [ ] R / U |
| 40 | Cup Pong `cup_pong` · `cup_pong/cup_pong_game.dart` | Tabletop cup-toss family; landing ring, removed cups and retained turn. | 2 | C 2 | [ ] R / U |
| 41 | Hungry Hippos `hungry_hippos` · `hungry_hippos/hungry_hippos_game.dart` | Marble-chomping tabletop family; reach, gold-marble value and seat ownership. | 2–4 | C 2–4 | [ ] R / U |
| 42 | Penguin Push `penguin_push` · `penguin_push/penguin_push_game.dart` | Arena knockoff/sumo family (J2 comparison); direction arrow, dash and elimination. | 2–4 | C 2–4 | [ ] R / U |
| 43 | Ring Sort Race `ring_sort` · `ring_sort/ring_sort_game.dart` | Colour-sort race family; legal peg moves, undo/reset, equal puzzles and timer. | 2–4 | C 2–4 | [ ] R / U |
| 44 | Fruit Merge `fruit_merge` · `fruit_merge/fruit_merge_game.dart` | SU reference; merge hierarchy, next fruit, drop control and overflow warning. | 1 | — | [ ] R / U |
| 45 | 2048 `game_2048` · `solo/game_2048.dart` | 2048 reference; one merge per move, value legibility and terminal board. | 1 | — | [ ] R / U |
| 46 | Flappy Jump `flappy_jump` · `solo/flappy_jump.dart` | Flappy-style gap flight; tap response, pipe collision and score crossing. | 1 | — | [ ] R / U |
| 47 | Minesweeper `minesweeper` · `solo/minesweeper.dart` | Classic minefield + race; safe first tap, flags, dense grids and progression. | M 1–2 | C 1–2* | [ ] R / U |
| 48 | Brick Breaker `brick_breaker` · `solo/brick_breaker.dart` | Breakout-style family; paddle response, launch, life loss and wall reset. | 1 | — | [ ] R / U |
| 49 | Whack-a-Mole `whack_mole` · `solo/whack_mole.dart` | J4 reference; pop/hide windows, gold/bomb distinction and countdown. | 1 | — | [ ] R / U |
| 50 | Piano Tiles `piano_tiles` · `solo/piano_tiles.dart` | Falling black-tile rhythm/reflex family; tile order, missed taps and speed. | 1 | — | [ ] R / U |
| 51 | Word Scramble `word_scramble` · `solo/word_scramble.dart` | Anagram family; selected letters, duplicate letters, skip and timed score. | 1 | — | [ ] R / U |
| 52 | Stack Tower `stack_tower` · `solo/stack_tower.dart` | ST reference; alignment, cut widths, perfect hit and miss feedback. | 1 | — | [ ] R / U |
| 53 | Simon Says `simon_says` · `solo/simon_says.dart` | Electronic sequence-memory family; playback/input phases and accessible pad cues. | 1 | — | [ ] R / U |
| 54 | Fruit Cut `fruit_cut` · `fruit_cut/fruit_cut_game.dart` | FN reference; swipe hit detection, bombs/lives and equal-duration online race. | M 1–2 | C 1–2* | [ ] R / U |
| 55 | Chicken Jump `chicken_jump` · `chicken_jump/chicken_jump_game.dart` | Tap-to-flap platform race, not assumed Crossy Road; gaps, moving platforms, finish. | M 1–2 | C 1–2* | [ ] R / U |
| 56 | Carrom `carrom` · `carrom/carrom_game.dart` | Traditional tabletop; striker aim, queen cover, fouls and pocket feedback. | 2 | C 2 | [ ] R / U |
| 57 | Eight Ball `eight_ball` · `eight_ball/eight_ball_game.dart` | Pool family/J2 reference; groups, ball-in-hand, scratch and early-eight loss. | 2 | C 2 | [ ] R / U |
| 58 | Candy Crush `candy_crush` · `candy/candy_game.dart` | CC reference; valid swaps, cascades, special clears and move-limited levels. | 1 | — | [ ] R / U |
| 59 | Bike Racing `bike_race` · `bike/bike_game.dart` | Obstacle/track racing family (J4 comparison); gas/brake, steering, track locks/finish. | M 1–2 | C 1–2* | [ ] R / U |
| 60 | Nitro Knockout `nitro_knockout` · `nitro_knockout/nitro_knockout_game.dart` | ZIP reference; 3D kart combat, weapons, health/respawn, 90-second KO match. | 1 human + 7 built-in bots | C 2–10 I | [ ] R / U |
| 61 | Ball Sort `ball_sort` · `solo/ball_sort.dart` | Colour sorting in hexagonal rings, not assumed tubes; legal pours, hints/undo, unlocks. | 1 | — | [ ] R / U |
| 62 | Sliding Puzzle `sliding_puzzle` · `solo/sliding_puzzle.dart` | Traditional 8/15-puzzle; gap adjacency, solvable shuffle and move score. | 1 | — | [ ] R / U |
| 63 | Sudoku `sudoku` · `solo/sudoku.dart` | Traditional 9×9; givens/notes, number-pad access and mistake limit. | 1 | — | [ ] R / U |
| 64 | Hangman `hangman` · `solo/hangman.dart` | Traditional word guessing; letter keyboard, repeated picks and six-error limit. | 1 | — | [ ] R / U |
| 65 | Dino Run `dino_run` · `solo/dino_run.dart` | Offline-dinosaur endless-runner family; jump arcs, obstacle cues and speed growth. | 1 | — | [ ] R / U |
| 66 | Block Drop `block_drop` · `solo/block_drop.dart` | TT reference; rotate/move/drop gestures, line clears and top-out. | 1 | — | [ ] R / U |
| 67 | Bubble Shooter `bubble_shooter` · `solo/bubble_shooter.dart` | Aim-and-match-three bubble family; wall bounces, hanging clusters, swap and danger line. | 1 | — | [ ] R / U |
| 68 | Sky Jumper `sky_jumper` · `solo/sky_jumper.dart` | DJ reference; auto-bounce, steer, moving/breaking/spring platforms and camera. | 1 | — | [ ] R / U |
| 69 | Space Shooter `space_shooter` · `solo/space_shooter.dart` | Vertical alien-wave shooter family; auto-fire, enemy shots, upgrades and lives. | 1 | — | [ ] R / U |
| 70 | Color Switch `color_switch` · `solo/color_switch.dart` | CS reference; ring segments, matching cues, shared course and tied results. | M 1–2 | C 1–2* | [ ] R / U |

### Special flows and variant (not additional base shell tiles)

| # | Current title / ID · source under `mobile/lib/` | Identity / reference and focused review | Offline seats | Online seats | Redesign / validation |
|---|---|---|---|---|---|
| 71 | Guess the Person `guess_person` · `features/guess_person/screens/guess_person_menu_screen.dart` | GW reference adapted to local pass-and-play; settings, private handoff, portraits/questions and results. | 2–6 | —; online identity is `guess_who`, not this ID | [ ] R / U |
| 72 | Raja Mantri Chor Sipahi `raja_mantri` · `features/raja_mantri/rmcs_screen.dart` | Traditional four-role Indian deduction; secret deals, Mantri accusation, role points and round totals. | 4 | C 4 I | [ ] R / U |
| 73 | Guess Who `guess_who` · `games/guess_who/guess_who_screen.dart` | GW reference; two-phone, server-held secrets/answers; local crossings-out and final-guess confirmation. | — | C 2 I | [ ] R / U |
| 74 | Ludo 2 vs 2 `ludo_teams` · `features/local_games/ludo/ludo_game.dart` | LK/team-board comparison; seats 1+3 vs 2+4, no partner capture, partner moves after own finish. | 4 via Ludo TEAMS switch | C 4 | [ ] R / U |

## Current availability discrepancies / special gates

- [ ] **Colour Clash:** preserve explicit online-only/two-phone intent; do not claim inherited offline 2–6/pass-and-play support. Verify it is absent from the one-device hub and reachable through rooms with private hands.
- [ ] **Memory:** catalog offers 2–4 online, metadata offers 2–6 local, but its inspected `LocalGameInfo` closes without `online`. Resolve/verify the actual online route or stop advertising it; catalog presence alone is not support.
- [ ] **Paint Fight:** local metadata defaults to exactly two and has no `online` adapter. Catalog passes `max: 4` to `_local`; despite its cap-oriented comment, the helper uses an override (`max ?? g.maxPlayers`), advertising 2–4 online against a two-seat local definition. Resolve both adapter and count mismatch; do not infer four-player gameplay.
- [ ] **Mixed solo/online games (M):** Minesweeper, Fruit Cut, Chicken Jump, Bike Racing and Color Switch advertise 1–2 seats locally and online. Verify setup limits, local two-seat usability, remote seat ownership and minimum room size; do not mistake a one-view race path for supported same-device multiplayer.
- [x] **Hub count:** exclude remote-only entries; `totalGameCount == 71` now matches the visible local catalogue. Regression assertions cover visible versus registered entries.
- [ ] **Guess Person vs Guess Who:** audit separate local/online setup, turn rules, private state, results and rematch; shared portraits do not establish flow parity. Check online identity against authenticated user IDs (the inspected screen derives an ID by splitting a token string).
- [ ] **Raja:** independently validate its own menu/secret-role flow and shared-result integration; generic shell tests do not cover it automatically.
- [ ] **Nitro provenance:** parent should reopen/hash the supplied ZIP before asserting archive parity. Current metadata describes bundled offline assets and a separate 2–10-human online catalog route; a null generic `online` field is expected for that dedicated route, unlike Memory/Paint Fight.
- [ ] **Nitro lifecycle:** verify exact server roster/order, 2 and 10 seats, 90-second end/terminal snapshot before finish, scores/ties, rematch, transient reconnect and explicit abort on permanent departure. No seamless live-host migration, faithful physics restore, cheat-proof scoring, or server-authoritative physics is established by metadata or historical backend protocol tests.
- [ ] **LAN:** current `core/lan/lan_host.dart` excludes `guess_who`, `raja_mantri`, `nitro_knockout`; other online entries are merely advertised. Test generic LAN games separately from internet rooms. Nitro must not silently fall back to generic relay.
- [ ] **Historical-only titles:** Crush It, Fruit Duel, Snake Duel, Penalty Shootout, Classic Snake and Smash Karts are not in the current hub list read here; do not add them to this current checklist just because source files or older reports mention them.

## Parent final-suite acceptance (apply to every row)

Record final-tree revision/build or working-tree fingerprint, game ID, mode, seats/bots/teams, device/OS, date, command/scenario, actual result and evidence path. Keep failures and unexecuted scenarios visible. Aggregate suite success does not replace a per-game full match.

- [ ] **Per-game redesign:** review/redesign the actual play surface and game-specific setup/HUD/controls, not just hub art, shared shell or result chrome. Capture before/after and reviewed small-phone/tablet layouts; test both supported visual styles, long names, large text, safe areas and orientation policy. Label intentional retained UI with explicit review evidence rather than “all redesigned.”
- [ ] **Offline:** airplane-mode cold start, rules/setup boundaries, valid/invalid input, full match/run, win/loss/draw/tie where applicable, scoring/records, pause/resume, background/foreground, restart/rematch and back/quit. Exercise levels/unlocks, hints/undo, bots, split-screen, take-turns and teams only where actually offered; verify secrets stay concealed at handoff.
- [ ] **Internet:** host/guest on distinct devices at supported min/max seats, authenticated identity, ready/start, all player inputs, state/score convergence, private payloads, spectator/late-join rejection policy, action rejection and usable errors, result/party totals and fresh rematch. Test lag/loss, duplicate/out-of-order actions, transient reconnect and host/guest departure with the implemented abort policy.
- [ ] **LAN separately:** offline discovery/join and full matches for advertised games; reconnect/dropout and unsupported internet-only choices hidden. Never equate internet socket/unit tests with phone-hosted LAN validation.
- [ ] **Accessibility/feel:** non-colour player/state cues, readable contrast/text, reachable touch targets or a documented dense-grid interaction, screen-reader labels/focus, sound/vibration toggles and reduce-motion behavior; check gesture cancellation and simultaneous touches where relevant.
- [ ] **Physics/performance:** frame-time and memory checks on a real target phone; repeated sessions without ticker/listener/WebView leaks; collision/scoring edge cases for projectile, ball, merge, racing and arena families. Nitro additionally needs offline asset/WASM boot without network, controls/audio, WebView lifecycle and multi-device render checks.
- [ ] **Automated final gates:** run the parent's final Flutter analyze/unit/widget/integration and server suites plus final APK/build checks from the appropriate project directories; attach actual commands/logs and failures. Reconcile catalog IDs/counts, routes/adapters, server registrations and LAN exclusions on the final tree.
- [ ] **Close rows only with evidence:** replace U with dated per-mode results only after execution; tick R only after a specific play-area redesign/review is accepted. Until then every row stays inherited UI / redesign outstanding / unverified.

## Validation of this document task

Performed bounded static inventory/count reconciliation and web URL research only. No Flutter, Node, build, device, browser-game, archive-runtime, physics or multiplayer suite was run. Historical reports were read for leads and caveats, not promoted to current results. Only this Markdown file is created by this task; source changes and the parent final suite remain outside this task.
