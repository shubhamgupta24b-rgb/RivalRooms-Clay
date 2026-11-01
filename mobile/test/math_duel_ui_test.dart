import 'dart:math';
import 'dart:ui' show SemanticsAction, Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/audio/game_audio.dart';
import 'package:multiplayer_game/core/settings/app_settings.dart';
import 'package:multiplayer_game/core/ui/tokens.dart';
import 'package:multiplayer_game/features/guess_person/models/gp_player.dart';
import 'package:multiplayer_game/features/local_games/math_duel/math_duel_game.dart';
import 'package:multiplayer_game/features/local_games/shell/ticking_play.dart';

Future<void> mountMath(
  WidgetTester tester,
  MathDuelLogic g, {
  bool relay = true,
  int me = 0,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool systemReduced = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final players = defaultPlayers(g.score.length);
  players[0] = GpPlayer(
    name: 'Alex with a very long classroom name',
    color: players[0].color,
  );
  final play = mathDuelInfo.play(players, (_) {}) as TickingPlay<MathDuelLogic>;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: systemReduced,
        ),
        child: Scaffold(
          body: ListenableBuilder(
            listenable: g,
            builder: (context, _) => relay
                ? mathDuelInfo.online!.view(context, g, players, me)
                : play.builder(context, g),
          ),
        ),
      ),
    ),
  );
}

Finder answerTile(MathDuelLogic g, int seat, int value) => find.byKey(
  ValueKey('math-answer-$seat-${g.question.options.indexOf(value)}'),
);

void main() {
  final haptics = <MethodCall>[];
  late bool oldHaptics, oldMotion;
  late AudioSettings oldAudio;

  setUp(() {
    oldHaptics = AppSettings.haptics.value;
    oldMotion = Motion.reduceSetting.value;
    oldAudio = GameAudio.settings.value;
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        });
  });
  tearDown(() {
    AppSettings.haptics.value = oldHaptics;
    Motion.reduceSetting.value = oldMotion;
    GameAudio.settings.value = oldAudio;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'chalkboard reveals the correct equation and disables answer tiles',
    (tester) async {
      addTearDown(tester.view.reset);
      final g = MathDuelLogic(random: Random(3));
      addTearDown(g.dispose);
      await mountMath(tester, g);
      expect(find.text('${g.question.text} = ?'), findsOneWidget);
      expect(find.text('QUICK MATHS / SUM 1'), findsOneWidget);
      await tester.tap(answerTile(g, 0, g.question.answer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Correct! +1'), findsOneWidget);
      expect(
        find.text('${g.question.text} = ${g.question.answer}'),
        findsOneWidget,
      );
      expect(g.scores, [1, 0]);
      expect(haptics.single.arguments, 'HapticFeedbackType.lightImpact');
      await tester.tap(answerTile(g, 0, g.question.answer));
      expect(g.scores, [1, 0]);
      expect(haptics, hasLength(1));
    },
  );

  testWidgets(
    'wrong answer locks only that player, then resets on the next sum',
    (tester) async {
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        final g = MathDuelLogic(random: Random(4));
        addTearDown(g.dispose);
        await mountMath(tester, g, relay: false);
        final wrong = g.question.options.firstWhere(
          (v) => v != g.question.answer,
        );
        await tester.tap(answerTile(g, 0, wrong));
        await tester.pump();
        expect(find.text('Wrong • locked until the next sum'), findsOneWidget);
        expect(g.lockedOut, {0});
        expect(g.betweenQuestions, isFalse);
        expect(
          find.text('${g.question.text} = ?'),
          findsNWidgets(2),
          reason: 'a wrong answer must not reveal the solution to opponents',
        );
        expect(haptics.single.arguments, 'HapticFeedbackType.heavyImpact');
        final disabled = tester.getSemantics(
          find
              .descendant(
                of: answerTile(g, 0, wrong),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(
          disabled.getSemanticsData().flagsCollection.isEnabled,
          Tristate.isFalse,
        );
        await tester.tap(answerTile(g, 0, g.question.answer));
        expect(g.scores, [0, 0]);
        await tester.tap(answerTile(g, 1, g.question.answer));
        await tester.pump();
        expect(g.scores, [0, 1]);
        expect(find.text('Correct! +1'), findsOneWidget);
        expect(haptics, hasLength(2));
        g.update(g.pauseMs);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(g.lockedOut, isEmpty);
        expect(
          find.text('Choose the answer • first correct scores'),
          findsNWidgets(2),
        );
        expect(find.text('${g.question.text} = ?'), findsNWidgets(2));
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('all wrong reveals answer even when nobody scored', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final g = MathDuelLogic(random: Random(7));
    addTearDown(g.dispose);
    await mountMath(tester, g, relay: false);
    final wrong = g.question.options.firstWhere((v) => v != g.question.answer);
    await tester.tap(answerTile(g, 0, wrong));
    await tester.pump();
    await tester.tap(answerTile(g, 1, wrong));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('No correct answers • next sum soon'), findsNWidgets(2));
    expect(
      find.text('${g.question.text} = ${g.question.answer}'),
      findsNWidgets(2),
    );
    expect(find.text('✓'), findsNWidgets(2));
    expect(g.scores, [0, 0]);
  });

  testWidgets(
    'answer tiles expose enabled accessible actions for a relay seat',
    (tester) async {
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        final g = MathDuelLogic(random: Random(2));
        addTearDown(g.dispose);
        await mountMath(tester, g, me: 1);
        final tile = answerTile(g, 1, g.question.answer);
        final node = tester.getSemantics(
          find.descendant(of: tile, matching: find.byType(Semantics)).first,
        );
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        expect(node.label, contains('${g.question.answer}'));
        tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
          node.id,
          SemanticsAction.tap,
        );
        await tester.pump();
        expect(g.scores, [0, 1]);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('relay sends the same answer action and waits for host state', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final host = MathDuelLogic(random: Random(3));
    final guest = MathDuelLogic(random: Random(9));
    addTearDown(host.dispose);
    addTearDown(guest.dispose);
    final relay = mathDuelInfo.online!;
    relay.load(guest, relay.save(host), 1);
    final sent = <(String, List<Object?>)>[];
    guest.sendToHost = (name, args) => sent.add((name, args));
    await mountMath(tester, guest, me: 1);
    await tester.tap(answerTile(guest, 1, guest.question.answer));
    expect(sent, hasLength(1));
    expect(sent.single.$1, 'answer');
    expect(sent.single.$2, [1, host.question.answer]);
    expect(guest.scores, [0, 0]);
    expect(haptics, isEmpty);
    relay.apply(host, 1, sent.single.$1, sent.single.$2);
    relay.load(guest, relay.save(host), 1);
    guest.changed();
    await tester.pump();
    expect(find.text('Correct! +1'), findsOneWidget);
    expect(guest.scores, [0, 1]);
    expect(haptics, hasLength(1));
    guest.changed();
    await tester.pump();
    expect(
      haptics,
      hasLength(1),
      reason: 'repeat snapshots cannot replay feedback',
    );
  });

  for (final system in [false, true]) {
    testWidgets('muted feedback and reduced motion (system: $system)', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      AppSettings.haptics.value = false;
      GameAudio.settings.value = const AudioSettings(music: false, sfx: false);
      Motion.reduceSetting.value = !system;
      final g = MathDuelLogic(random: Random(1));
      addTearDown(g.dispose);
      await mountMath(tester, g, systemReduced: system);
      await tester.tap(answerTile(g, 0, g.question.answer));
      await tester.pump();
      expect(haptics, isEmpty);
      for (final widget in tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      )) {
        expect(widget.duration, Duration.zero);
      }
      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero,
      );
      expect(find.text('Correct! +1'), findsOneWidget);
    });
  }

  testWidgets('narrow portrait uses 2×2 tiles; short wide seats use one row', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final g = MathDuelLogic(random: Random(1));
    addTearDown(g.dispose);
    await mountMath(tester, g, size: const Size(320, 568));
    final a = tester.getRect(answerTile(g, 0, g.question.options[0]));
    final b = tester.getRect(answerTile(g, 0, g.question.options[1]));
    final c = tester.getRect(answerTile(g, 0, g.question.options[2]));
    expect(a.top, b.top);
    expect(c.top, greaterThan(a.bottom));
    expect(a.width, greaterThanOrEqualTo(48));
    expect(a.height, greaterThanOrEqualTo(48));
    await mountMath(tester, g, relay: false, size: const Size(568, 320));
    for (final value in g.question.options) {
      final rect = tester.getRect(answerTile(g, 0, value));
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(rect.width, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(800, 1280),
  ]) {
    for (var count = 2; count <= 4; count++) {
      testWidgets(
        '$count desks fit $size with large text and answer feedback',
        (tester) async {
          addTearDown(tester.view.reset);
          final g = MathDuelLogic(players: count, random: Random(1));
          addTearDown(g.dispose);
          await mountMath(tester, g, relay: false, size: size, textScale: 1.6);
          expect(find.text('${g.question.text} = ?'), findsNWidgets(count));
          expect(tester.takeException(), isNull);
          for (var seat = 0; seat < count; seat++) {
            for (final value in g.question.options) {
              final rect = tester.getRect(answerTile(g, seat, value));
              expect(rect.width, greaterThanOrEqualTo(48 - 1e-6));
              expect(rect.height, greaterThanOrEqualTo(48 - 1e-6));
            }
          }
          await tester.tap(answerTile(g, count - 1, g.question.answer));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));
          expect(find.text('Correct! +1'), findsOneWidget);
          expect(
            find.text('${g.question.text} = ${g.question.answer}'),
            findsNWidgets(count),
          );
          expect(g.score.last, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
