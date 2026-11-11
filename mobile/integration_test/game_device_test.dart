import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:multiplayer_game/core/audio/game_audio.dart';
import 'package:multiplayer_game/core/settings/app_settings.dart';
import 'package:multiplayer_game/core/ui/app_ui.dart';
import 'package:multiplayer_game/core/ui/components.dart';
import 'package:multiplayer_game/features/guess_person/screens/guess_person_game_screen.dart';
import 'package:multiplayer_game/features/guess_person/screens/guess_person_menu_screen.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/game_intro.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_info.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'package:multiplayer_game/features/local_games/shell/pause_sheet.dart';
import 'package:multiplayer_game/features/local_games/shell/result_screen.dart';
import 'package:multiplayer_game/features/raja_mantri/rmcs_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Do not invoke app.main(): authentication, sockets and ads are outside this audit.
// Only preferences are in-memory; audio/device channels and any WebView stay native.
final _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
final _visible = localGames.where((game) => !game.remoteOnly).toList();
final _cases = <String, Object?>{};
const _includeNitro = bool.fromEnvironment('DEVICE_SMOKE_NITRO');

Map<String, Object?> _metadata(LocalGameInfo game) => {
  'id': game.id,
  'title': game.title,
  'minPlayers': game.minPlayers,
  'maxPlayers': game.maxPlayers,
  'solo': game.solo,
  'splitScreen': game.splitScreen,
  'hasTakeTurns': game.turns != null,
  'parentOwnsNativeVerification': game.id == 'nitro_knockout',
};

void _note(Map<String, Object?> result, String stage, [Object? detail]) {
  final event = <String, Object?>{
    'stage': stage,
    if (detail != null) 'detail': detail,
  };
  (result['events'] as List<Object?>).add(event);
  debugPrint('DEVICE_SMOKE ${result['id']} ${jsonEncode(event)}');
}

void _noExceptions(WidgetTester tester, String stage) {
  final errors = <String>[];
  Object? error;
  while ((error = tester.takeException()) != null) {
    errors.add(error.toString());
  }
  expect(errors, isEmpty, reason: 'Framework exceptions at $stage');
}

// Real native frame pumping, bounded even for games with perpetual tickers.
// Never pumpAndSettle on a game or on the animated Guess Person menu.
Future<void> _frames(WidgetTester tester, int milliseconds) async {
  for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pump();
}

Future<void> _case(
  WidgetTester tester,
  String id,
  Widget screen,
  Future<void> Function(Map<String, Object?> result) body,
) async {
  final result = <String, Object?>{
    'id': id,
    'status': 'running',
    'events': <Object?>[],
  };
  _cases[id] = result;
  try {
    expect(kIsWeb, isFalse, reason: 'Use an actual Android phone, not Chrome.');
    expect(defaultTargetPlatform, TargetPlatform.android);
    // No clear(), auth restore, login, preference backup/restore, or disk writes.
    SharedPreferences.setMockInitialValues({});
    await AppSettings.init();
    await GameAudio.init();
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
    await _frames(tester, 350);
    final view = tester.view;
    _note(result, 'rendered', {
      'physicalWidth': view.physicalSize.width,
      'physicalHeight': view.physicalSize.height,
      'devicePixelRatio': view.devicePixelRatio,
      'logicalWidth': view.physicalSize.width / view.devicePixelRatio,
      'logicalHeight': view.physicalSize.height / view.devicePixelRatio,
    });
    _noExceptions(tester, '$id initial render');
    await body(result);
    _noExceptions(tester, '$id body');
    result['status'] = 'passed';
  } catch (error) {
    result['status'] = 'failed';
    result['error'] = error.toString();
    rethrow;
  } finally {
    try {
      // Dispose the whole Navigator, including any popup or pushed menu route.
      // Do not use Back/Quit or rematch as generic game input.
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester, 400);
      _noExceptions(tester, '$id disposal');
      _note(result, 'disposed');
    } catch (error) {
      result['status'] = 'failed';
      result['disposalError'] = error.toString();
      rethrow;
    } finally {
      debugPrint('DEVICE_SMOKE_RESULT ${jsonEncode(result)}');
    }
  }
}

bool get _atResult => find.byType(ResultScreen).evaluate().isNotEmpty;

Future<void> _minimumPlayers(WidgetTester tester, LocalGameInfo game) async {
  // Some fixed-count games have no stepper; inspect the actual intro as well.
  for (var attempt = 0; attempt < 8; attempt++) {
    final intro = tester.widget<GameIntro>(find.byType(GameIntro));
    if (intro.players.length == game.minPlayers) return;
    await _tap(
      tester,
      find.byKey(
        ValueKey(
          intro.players.length > game.minPlayers ? 'players-' : 'players+',
        ),
      ),
    );
  }
  fail('Could not select ${game.minPlayers} players for ${game.id}');
}

final _navigationLabel = RegExp(
  r'\b(back|exit|leave|quit|home|menu|restart|rematch|play again|settings|help|rules|pause)\b',
  caseSensitive: false,
);

// Protect whole navigation controls, not only the text glyphs. This includes
// ancestor gesture detectors for custom game buttons. A safe tap is only input
// delivery smoke: it need not be a legal move, start a solo timer, or score.
Future<void> _safeInput(
  WidgetTester tester,
  Map<String, Object?> result,
) async {
  if (_atResult) {
    _note(result, 'input-not-exercised', 'Game already reached its result');
    return;
  }
  final play = find.byType(GamePause);
  expect(play, findsOneWidget);
  final blocked = <Rect>[];
  final controls = find.descendant(
    of: play,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is RoundButton ||
          widget is PauseButton ||
          widget is HelpButton ||
          widget is EditableText ||
          widget is TextField ||
          widget is GoldButton && _navigationLabel.hasMatch(widget.label) ||
          widget is KitButton && _navigationLabel.hasMatch(widget.label),
    ),
  );
  void block(Finder finder) {
    for (final element in finder.evaluate()) {
      final box = element.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        blocked.add((box.localToGlobal(Offset.zero) & box.size).inflate(12));
      }
    }
  }

  block(controls);
  final labels = find.descendant(
    of: play,
    matching: find.textContaining(_navigationLabel, findRichText: true),
  );
  block(labels);
  for (final label in labels.evaluate()) {
    label.visitAncestorElements((ancestor) {
      if (ancestor.widget is GamePause) return false;
      final widget = ancestor.widget;
      if (widget is GestureDetector ||
          widget is InkResponse ||
          widget is ButtonStyleButton ||
          widget is GoldButton ||
          widget is KitButton) {
        block(find.byWidget(widget));
      }
      return true;
    });
  }
  final area = tester.getRect(play);
  for (final y in [0.65, 0.5, 0.8, 0.35]) {
    for (final x in [0.5, 0.3, 0.7]) {
      final point = Offset(
        area.left + area.width * x,
        area.top + area.height * y,
      );
      if (blocked.any((rect) => rect.contains(point))) continue;
      await tester.tapAt(point);
      await _frames(tester, 100);
      _note(result, 'safe-input-delivered', {'x': point.dx, 'y': point.dy});
      _noExceptions(tester, '${result['id']} safe input');
      expect(
        find.byType(LocalGameShell),
        findsOneWidget,
        reason: 'Safe input must not leave the shell',
      );
      return;
    }
  }
  _note(result, 'input-not-exercised', 'No point clear of navigation controls');
}

Future<void> _pauseResume(
  WidgetTester tester,
  Map<String, Object?> result,
) async {
  if (_atResult) {
    _note(result, 'pause-not-exercised', 'Game already reached its result');
    return;
  }
  final pause = find.byType(PauseButton).hitTestable();
  if (pause.evaluate().isEmpty) {
    _note(
      result,
      'pause-not-exercised',
      'No visible PauseButton on this screen',
    );
    return;
  }
  await _tap(tester, pause.first);
  await _frames(tester, 350);
  // A game can finish while the pause dialog is opening; the shell closes it.
  if (_atResult) {
    _note(result, 'pause-not-exercised', 'Result arrived while opening pause');
    return;
  }
  expect(find.byType(PauseSheet), findsOneWidget);
  final notifier = tester.widget<GamePause>(find.byType(GamePause)).notifier!;
  expect(notifier.value, isTrue);
  _noExceptions(tester, '${result['id']} pause');
  _note(result, 'paused');
  await _frames(tester, 250);
  expect(notifier.value, isTrue);
  await _tap(
    tester,
    find.descendant(of: find.byType(PauseSheet), matching: find.text('Resume')),
  );
  await _frames(tester, 350);
  expect(find.byType(PauseSheet), findsNothing);
  if (!_atResult) expect(notifier.value, isFalse);
  _noExceptions(tester, '${result['id']} resume');
  _note(result, 'resumed');
}

void main() {
  _binding.reportData = <String, dynamic>{
    'scope': 'native render/start/input/pause/resume/dispose smoke, not rules',
    'preferences': 'in-memory; existing device preferences untouched',
    'visibleShellCount': _visible.length,
    'scheduledNonNitroShellCount': _visible
        .where((game) => game.id != 'nitro_knockout')
        .length,
    'gallery': _visible.map(_metadata).toList(),
    'specialMenus': ['guess_person', 'raja_mantri'],
    'excludedRemoteOnly': [
      for (final game in localGames.where((game) => game.remoteOnly)) game.id,
    ],
    'nitro': _includeNitro
        ? 'opt-in shell smoke only'
        : 'parent-owned; skipped',
    'cases': _cases,
  };

  testWidgets('device_smoke gallery metadata and native hub render', (
    tester,
  ) async {
    await _case(tester, 'gallery', const LocalGamesHubScreen(), (result) async {
      expect(_visible.map((game) => game.id).toSet().length, _visible.length);
      expect(totalGameCount, _visible.length + 2);
      expect(find.byType(LocalGamesHubScreen), findsOneWidget);
      _note(result, 'gallery-metadata', _binding.reportData!['gallery']);
      _note(
        result,
        'remote-only-excluded',
        _binding.reportData!['excludedRemoteOnly'],
      );
    });
  }, tags: ['device_smoke', 'gallery']);

  for (final game in _visible) {
    final nitro = game.id == 'nitro_knockout';
    testWidgets(
      'device_smoke shell ${game.id} (${game.title})',
      (tester) async {
        await _case(tester, game.id, LocalGameShell(game: game), (
          result,
        ) async {
          _note(result, 'metadata', _metadata(game));
          await _minimumPlayers(tester, game);
          _note(result, 'minimum-players-selected', game.minPlayers);
          if (tester.widget<GameIntro>(find.byType(GameIntro)).turns != null) {
            // Exercise the actual game renderer, not only the hand-off card.
            await _tap(tester, find.text('Split screen'));
            _note(result, 'play-mode-selected', 'Split screen');
          }
          await _tap(tester, find.text('Tap to start'));
          _note(result, 'start-tapped');
          final countdown = find.byType(CountdownOverlay).evaluate().isNotEmpty;
          // Covers 3-2-1 + GO and the shell's transition. Solo/take-turn titles
          // intentionally bypass the countdown and may still show title controls.
          await _frames(tester, countdown ? 3200 : 350);
          expect(find.byType(CountdownOverlay), findsNothing);
          expect(find.byType(GameIntro), findsNothing);
          expect(
            _atResult || find.byType(GamePause).evaluate().isNotEmpty,
            isTrue,
          );
          _noExceptions(tester, '${game.id} start/countdown');
          _note(
            result,
            countdown ? 'countdown-completed' : 'countdown-bypassed',
          );
          await _safeInput(tester, result);
          await _pauseResume(tester, result);
          await _frames(tester, 500);
          _note(
            result,
            _atResult ? 'result-observed' : 'play-or-title-observed',
          );
        });
      },
      tags: ['device_smoke', 'shell', if (nitro) 'nitro' else 'local_shell'],
      skip: nitro && !_includeNitro,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }

  testWidgets('device_smoke special guess_person menu and choosing screen', (
    tester,
  ) async {
    await _case(tester, 'guess_person', const GuessPersonMenuScreen(), (
      result,
    ) async {
      expect(find.text('PLAY'), findsOneWidget);
      expect(find.text('HOW TO PLAY'), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
      _note(result, 'menu-controls-rendered');
      await _tap(tester, find.text('PLAY'));
      await _frames(tester, 500);
      expect(find.byType(GuessPersonGameScreen), findsOneWidget);
      await _tap(tester, find.text('START CHOOSING'));
      await _frames(tester, 500);
      expect(find.text('Choose your\ncharacter!'), findsOneWidget);
      await _tap(tester, find.text('RANDOM'));
      await _frames(tester, 150);
      expect(find.textContaining('Selected: '), findsOneWidget);
      _note(result, 'choosing-and-random-selection-smoked');
      _note(
        result,
        'pause-not-exercised',
        'Special flow; not a LocalGameShell',
      );
    });
  }, tags: ['device_smoke', 'special_menu']);

  testWidgets('device_smoke special raja_mantri menu and initial deal', (
    tester,
  ) async {
    await _case(tester, 'raja_mantri', const RmcsMenuScreen(), (result) async {
      expect(find.byType(TextField), findsNWidgets(4));
      _note(result, 'menu-controls-rendered', 'Four local player fields');
      await _tap(tester, find.text('Deal the cards'));
      await _frames(tester, 1400);
      expect(find.byType(RmcsGameScreen), findsOneWidget);
      expect(
        tester
            .widget<RmcsGameScreen>(find.byType(RmcsGameScreen))
            .game
            .players
            .length,
        4,
      );
      _note(result, 'initial-deal-smoked');
      _note(
        result,
        'pause-not-exercised',
        'Special flow; not a LocalGameShell',
      );
    });
  }, tags: ['device_smoke', 'special_menu']);
}
