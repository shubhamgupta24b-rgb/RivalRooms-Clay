import 'dart:async';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/audio/game_audio.dart';
import 'package:multiplayer_game/core/records/records.dart';
import 'package:multiplayer_game/core/ui/components.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_info.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_logic.dart';
import 'package:multiplayer_game/features/local_games/shell/local_game_shell.dart';
import 'package:multiplayer_game/features/local_games/shell/result_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/ticking_play.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Test-only storage gate; no production injection hook is needed.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'shell_helpers.dart';

class _Clock extends TimedDuel {
  _Clock() : super(60000);
  @override
  List<int> get scores => [0];
}

class _Game {
  final finishes = <void Function(List<int>)>[];
  final clocks = <_Clock>[];

  LocalGameInfo info({bool solo = true}) => LocalGameInfo(
    id: 'shell_lifecycle',
    title: 'Shell lifecycle',
    emoji: '',
    color: Colors.blue,
    tagline: 'Test match',
    rules: const ['Finish the match.'],
    scoreUnit: 'points',
    splitScreen: false,
    minPlayers: solo ? 1 : 2,
    maxPlayers: solo ? 1 : 2,
    bot: (_, __, ___) {},
    play: (_, finish) {
      finishes.add(finish);
      return TickingPlay(
        create: () {
          final clock = _Clock();
          clocks.add(clock);
          return clock;
        },
        onFinished: finish,
        builder: (_, clock) => Column(
          children: [
            const PauseButton(),
            const HelpButton(),
            Text('elapsed ${clock.elapsedMs}'),
          ],
        ),
      );
    },
  );
}

class _DelayedStore extends InMemorySharedPreferencesStore {
  _DelayedStore() : super.empty();
  final firstWrite = Completer<void>();
  int writes = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final result = await super.setValue(valueType, key, value);
    if (key == 'flutter.records' && ++writes == 1) {
      await firstWrite.future;
    }
    return result;
  }
}

Future<void> _open(
  WidgetTester tester,
  _Game game, {
  bool solo = true,
  bool computer = false,
}) async {
  tester.view.physicalSize = const Size(411, 914);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: LocalGameShell(game: game.info(solo: solo)),
    ),
  );
  if (computer) await toggleComputer(tester, 1);
  await tapStart(tester);
  await tester.pump(CountdownOverlay.total);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

ResultScreen _result(WidgetTester tester) =>
    tester.widget<ResultScreen>(find.byType(ResultScreen));

Future<void> _background(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump(const Duration(seconds: 20));
}

Future<void> _resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // These tests exercise shell timing, not Android sound synthesis.
    GameAudio.settings.value = const AudioSettings(music: false, sfx: false);
  });

  tearDown(() {
    GameAudio.settings.value = const AudioSettings();
  });

  testWidgets('duplicate finishes change scores, wins and records only once', (
    tester,
  ) async {
    final game = _Game();
    await _open(tester, game, solo: false);
    final finish = game.finishes.last;
    finish([8, 2]);
    finish([1, 20]);
    await tester.pump();
    expect(_result(tester).players.map((p) => p.score), [8, 2]);
    expect(_result(tester).wins, [1, 0]);
    expect((await Records.all())['shell_lifecycle']!.played, 1);
    finish([0, 30]);
    await tester.pump();
    expect(_result(tester).wins, [1, 0]);
    expect((await Records.all())['shell_lifecycle']!.played, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'malformed score lengths are ignored without consuming the result',
    (tester) async {
      final game = _Game();
      await _open(tester, game, solo: false);
      final finish = game.finishes.last;
      for (final scores in <List<int>>[
        [],
        [1],
        [1, 2, 3],
      ]) {
        finish(scores);
        await tester.pump();
        expect(find.byType(ResultScreen), findsNothing);
        expect(await Records.all(), isEmpty);
      }
      finish([3, 4]);
      await tester.pump();
      expect(_result(tester).wins, [0, 1]);
      expect((await Records.all())['shell_lifecycle']!.played, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('old match cannot finish the rematch countdown or new game', (
    tester,
  ) async {
    final game = _Game();
    await _open(tester, game, solo: false);
    final oldFinish = game.finishes.last;
    oldFinish([9, 1]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    _result(tester).onRematch();
    oldFinish([0, 100]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CountdownOverlay), findsOneWidget);
    expect(find.byType(ResultScreen), findsNothing);
    await tester.pump(CountdownOverlay.total);
    await tester.pump(const Duration(milliseconds: 400));
    expect(game.clocks, hasLength(2));
    oldFinish([0, 100]);
    await tester.pump();
    expect(find.byType(ResultScreen), findsNothing);
    game.finishes.last([7, 2]);
    await tester.pump();
    expect(_result(tester).wins, [2, 0]);
    expect((await Records.all())['shell_lifecycle']!.played, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background stops the game clock without an elapsed-time jump', (
    tester,
  ) async {
    final game = _Game();
    await _open(tester, game);
    final clock = game.clocks.single;
    await tester.pump(const Duration(milliseconds: 500));
    final before = clock.elapsedMs;
    await _background(tester);
    expect(clock.elapsedMs, before);
    await _resume(tester);
    expect(clock.elapsedMs, before);
    await tester.pump(const Duration(milliseconds: 250));
    expect(clock.elapsedMs, before + 250);
    await tester.pumpWidget(const SizedBox());
  });

  for (final help in [false, true]) {
    testWidgets(
      'foreground keeps ${help ? 'help' : 'menu'} paused until dismissed',
      (tester) async {
        final game = _Game();
        await _open(tester, game);
        final clock = game.clocks.single;
        await tester.tap(find.byType(help ? HelpButton : PauseButton));
        await tester.pump();
        final before = clock.elapsedMs;
        await _background(tester);
        await _resume(tester);
        await tester.pump(const Duration(seconds: 3));
        expect(clock.elapsedMs, before);
        final context = tester.element(
          find.byType(LocalGameShell, skipOffstage: false),
        );
        Navigator.of(context).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final resumed = clock.elapsedMs;
        await tester.pump(const Duration(milliseconds: 250));
        expect(clock.elapsedMs, resumed + 250);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('dismissing help in background does not resume the clock', (
    tester,
  ) async {
    final game = _Game();
    await _open(tester, game);
    final clock = game.clocks.single;
    await tester.tap(find.byType(HelpButton));
    await tester.pump();
    await _background(tester);
    final before = clock.elapsedMs;
    Navigator.of(
      tester.element(find.byType(LocalGameShell, skipOffstage: false)),
    ).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(clock.elapsedMs, before);
    await _resume(tester);
    // The returning route first unmutes TickerMode, then establishes a tick epoch.
    await tester.pump(const Duration(milliseconds: 1));
    final resumed = clock.elapsedMs;
    expect(resumed, inInclusiveRange(before, before + 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(clock.elapsedMs, resumed + 250);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'countdown pauses for menu and background, then resumes remaining time',
    (tester) async {
      final game = _Game();
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: LocalGameShell(game: game.info(solo: false))),
      );
      await tapStart(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.binding.handlePopRoute();
      await tester.pump();
      await _background(tester);
      await _resume(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(game.clocks, isEmpty);
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(game.clocks, isEmpty);
      expect(find.text('2'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1851));
      await tester.pump();
      expect(game.clocks, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final help in [false, true]) {
    testWidgets('countdown stops for ${help ? 'help' : 'background'} alone', (
      tester,
    ) async {
      final game = _Game();
      await tester.pumpWidget(
        MaterialApp(home: LocalGameShell(game: game.info(solo: false))),
      );
      await tapStart(tester);
      await tester.pump(const Duration(milliseconds: 300));
      final countdown = tester.widget<CountdownOverlay>(
        find.byType(CountdownOverlay),
      );
      if (help) {
        LeaveGameScope.helpOf(tester.element(find.byType(CountdownOverlay)))!();
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
      } else {
        await _background(tester);
      }
      expect(countdown.paused!.value, isTrue);
      expect(game.clocks, isEmpty);
      if (help) {
        Navigator.of(
          tester.element(find.byType(LocalGameShell, skipOffstage: false)),
        ).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      } else {
        await _resume(tester);
      }
      expect(countdown.paused!.value, isFalse);
      await tester.pump(CountdownOverlay.total);
      await tester.pump();
      expect(game.clocks, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('old countdown completion cannot start a later rematch early', (
    tester,
  ) async {
    final game = _Game();
    await tester.pumpWidget(
      MaterialApp(home: LocalGameShell(game: game.info(solo: false))),
    );
    await tapStart(tester);
    final oldDone = tester
        .widget<CountdownOverlay>(find.byType(CountdownOverlay))
        .onDone;
    await tester.pump(CountdownOverlay.total);
    await tester.pump(const Duration(milliseconds: 400));
    game.finishes.last([1, 0]);
    await tester.pump();
    _result(tester).onRematch();
    await tester.pump();
    oldDone();
    await tester.pump();
    expect(game.clocks, hasLength(1));
    await tester.pump(CountdownOverlay.total + const Duration(milliseconds: 1));
    await tester.pump();
    expect(game.clocks, hasLength(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'restart replaces the clock and rejects the abandoned match finish',
    (tester) async {
      final game = _Game();
      await _open(tester, game);
      final oldFinish = game.finishes.last;
      await tester.tap(find.byType(PauseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restart').last);
      await tester.pump();
      await tester.pump(CountdownOverlay.total);
      await tester.pump(const Duration(milliseconds: 400));
      expect(game.clocks, hasLength(2));
      expect(game.clocks.last.elapsedMs, lessThan(1000));
      oldFinish([100]);
      await tester.pump();
      expect(find.byType(ResultScreen), findsNothing);
      expect(await Records.all(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final won in [false, true]) {
    testWidgets('human versus computer plays ${won ? 'win' : 'lose'} sound', (
      tester,
    ) async {
      GameAudio.settings.value = const AudioSettings(music: false);
      final sounds = <String>[];
      const channel = MethodChannel('party/audio');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'sfx')
          sounds.add((call.arguments as Map)['name'] as String);
        return null;
      });
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      });
      final game = _Game();
      await _open(tester, game, solo: false, computer: true);
      sounds.clear();
      game.finishes.last(won ? [5, 1] : [1, 5]);
      await tester.pump();
      expect(sounds, [won ? 'win' : 'lose']);
      expect((await Records.all())['shell_lifecycle']!.wins, won ? 1 : 0);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets(
    'delayed solo best persists but cannot overwrite a rematch result',
    (tester) async {
      final originalStore = SharedPreferencesStorePlatform.instance;
      final store = _DelayedStore();
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(() {
        SharedPreferences.setMockInitialValues({});
        SharedPreferencesStorePlatform.instance = originalStore;
      });
      final game = _Game();
      await _open(tester, game);
      game.finishes.last([50]);
      await tester.pump();
      expect(store.writes, 1);
      expect(_result(tester).best, isNull);
      _result(tester).onRematch();
      await tester.pump();
      await tester.pump(CountdownOverlay.total);
      await tester.pump(const Duration(milliseconds: 400));
      game.finishes.last([10]);
      await tester.pump();
      expect(_result(tester).best, 50);
      expect(_result(tester).newBest, isFalse);
      store.firstWrite.complete();
      await tester.pump();
      expect(_result(tester).players.single.score, 10);
      expect(_result(tester).best, 50);
      expect(_result(tester).newBest, isFalse);
      expect((await Records.all())['shell_lifecycle']!.played, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'countdown supports initially paused and replacement listenables',
    (tester) async {
      final paused = ValueNotifier(true);
      final replacement = ValueNotifier(true);
      var completions = 0;
      Widget app(ValueNotifier<bool>? pause) => MaterialApp(
        home: CountdownOverlay(
          paused: pause,
          onDone: () => completions++,
          color: Colors.blue,
        ),
      );
      await tester.pumpWidget(app(paused));
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('3'), findsOneWidget);
      paused.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(app(replacement));
      paused.value = true;
      paused.value = false;
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('3'), findsOneWidget);
      expect(completions, 0);
      // Removing the pause source resumes from the same progress.
      await tester.pumpWidget(app(null));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('2'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1851));
      expect(completions, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(completions, 1);
      await tester.pumpWidget(const SizedBox());
      paused.dispose();
      replacement.dispose();
    },
  );
}
