import 'dart:math';
import 'dart:ui' show SemanticsAction, Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/audio/game_audio.dart';
import 'package:multiplayer_game/core/settings/app_settings.dart';
import 'package:multiplayer_game/core/ui/tokens.dart';
import 'package:multiplayer_game/features/guess_person/models/gp_player.dart';
import 'package:multiplayer_game/features/local_games/reaction_tap/reaction_tap_game.dart';
import 'package:multiplayer_game/features/local_games/shell/split_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/ticking_play.dart';

Future<void> mountReaction(
  WidgetTester tester,
  ReactionTapLogic g, {
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
    name: 'Alex with a very long racing name',
    color: players[0].color,
  );
  final play =
      reactionTapInfo.play(players, (_) {}) as TickingPlay<ReactionTapLogic>;
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
                ? reactionTapInfo.online!.view(context, g, players, me)
                : play.builder(context, g),
          ),
        ),
      ),
    ),
  );
}

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

  testWidgets('starting tree shows WAIT, instant GO, and pointer-down timing', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final g = ReactionTapLogic(random: Random(11));
    addTearDown(g.dispose);
    await mountReaction(tester, g);
    expect(find.byKey(const ValueKey('starting-tree')), findsOneWidget);
    expect(find.text('WAIT'), findsOneWidget);
    expect(find.text('HOLD • WAIT FOR GREEN'), findsOneWidget);

    g.update(g.goAt + 237);
    await tester.pump();
    expect(find.text('GO!'), findsOneWidget);
    expect(find.text('TAP NOW'), findsOneWidget);
    final pad = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(
      pad.duration,
      Duration.zero,
      reason: 'the start signal must not wait for a fade',
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('reaction-lane-0'))),
    );
    expect(g.scores, [1, 0], reason: 'scores before the finger is released');
    await gesture.up();
    await tester.pump();
    expect(find.text('FIRST!'), findsOneWidget);
    expect(find.text('+1 point • 237 ms'), findsOneWidget);
    expect(haptics.single.arguments, 'HapticFeedbackType.mediumImpact');
    await tester.tap(find.byKey(const ValueKey('reaction-lane-0')));
    expect(g.scores, [1, 0]);
    expect(haptics, hasLength(1), reason: 'result taps have no feedback');
  });

  testWidgets(
    'false starts explain the penalty and reset without losing identity',
    (tester) async {
      addTearDown(tester.view.reset);
      final g = ReactionTapLogic(random: Random(2))..score[0] = 1;
      addTearDown(g.dispose);
      await mountReaction(tester, g, relay: false);
      await tester.tap(find.byKey(const ValueKey('reaction-lane-0')));
      await tester.pump();
      expect(g.scores, [0, 0]);
      expect(find.text('FALSE START'), findsOneWidget);
      expect(find.text('HOLD STEADY'), findsOneWidget);
      expect(find.text('−1 point • score never below 0'), findsOneWidget);
      expect(haptics.single.arguments, 'HapticFeedbackType.heavyImpact');
      g.update(g.resultMs);
      await tester.pump();
      expect(find.text('WAIT'), findsNWidgets(2));
      final split = tester.widget<SplitScreen>(find.byType(SplitScreen));
      expect(split.colors, hasLength(2));
      expect(
        find.byWidgetPredicate((w) => w is RotatedBox && w.quarterTurns == 2),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'accessible lane activation works and result lanes are disabled',
    (tester) async {
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        final g = ReactionTapLogic(random: Random(7));
        addTearDown(g.dispose);
        await mountReaction(tester, g, me: 1);
        final lane = find.byKey(const ValueKey('reaction-lane-1'));
        final node = tester.getSemantics(lane);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        g.update(g.goAt + 100);
        await tester.pump();
        tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
          node.id,
          SemanticsAction.tap,
        );
        await tester.pump();
        expect(g.scores, [0, 1]);
        final data = tester.getSemantics(lane).getSemanticsData();
        expect(data.flagsCollection.isEnabled, Tristate.isFalse);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('relay sends the same tap action and waits for host state', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final host = ReactionTapLogic(random: Random(3));
    final guest = ReactionTapLogic(random: Random(9));
    addTearDown(host.dispose);
    addTearDown(guest.dispose);
    final relay = reactionTapInfo.online!;
    host.update(host.goAt + 210);
    relay.load(guest, relay.save(host), 1);
    final sent = <(String, List<Object?>)>[];
    guest.sendToHost = (name, args) => sent.add((name, args));
    await mountReaction(tester, guest, me: 1);
    await tester.tap(find.byKey(const ValueKey('reaction-lane-1')));
    expect(sent, hasLength(1));
    expect(sent.single.$1, 'tap');
    expect(sent.single.$2, [1]);
    expect(guest.scores, [0, 0]);
    expect(haptics, isEmpty);
    relay.apply(host, 1, sent.single.$1, sent.single.$2);
    relay.load(guest, relay.save(host), 1);
    guest.changed();
    await tester.pump();
    expect(find.text('+1 point • 210 ms'), findsOneWidget);
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
      final g = ReactionTapLogic(random: Random(1));
      addTearDown(g.dispose);
      await mountReaction(tester, g, systemReduced: system);
      await tester.tap(find.byKey(const ValueKey('reaction-lane-0')));
      await tester.pump();
      expect(haptics, isEmpty);
      expect(
        tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .duration,
        Duration.zero,
      );
      expect(find.text('FALSE START'), findsOneWidget);
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(800, 1280),
  ]) {
    for (var count = 2; count <= 6; count++) {
      testWidgets('$count lanes fit $size with large text in every phase', (
        tester,
      ) async {
        addTearDown(tester.view.reset);
        final g = ReactionTapLogic(players: count, random: Random(1));
        addTearDown(g.dispose);
        await mountReaction(
          tester,
          g,
          relay: false,
          size: size,
          textScale: 1.6,
        );
        expect(
          find.byKey(const ValueKey('starting-tree')),
          findsNWidgets(count),
        );
        expect(tester.takeException(), isNull);
        g.update(g.goAt + 180);
        await tester.pump();
        expect(find.text('GO!'), findsNWidgets(count));
        final lane = tester.getRect(
          find.byKey(ValueKey('reaction-lane-${count - 1}')),
        );
        // Stay near the outer edge, clear of the shared pause/target chip.
        await tester.tapAt(Offset(lane.right - 20, lane.bottom - 20));
        await tester.pump();
        expect(find.text('FIRST!'), findsOneWidget);
        expect(find.text('BEATEN'), findsNWidgets(count - 1));
        expect(g.score.last, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
