import 'dart:async';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/audio/game_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('party/audio');
  final calls = <MethodCall>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    GameAudio.stopMusic();
    await GameAudio.init();
    GameAudio.renderTrackForTesting = (_) async => Uint8List.fromList([1, 2]);
    calls.clear();
  });

  tearDown(() {
    GameAudio.stopMusic();
    GameAudio.renderTrackForTesting = null;

    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('muting during generation cancels playback and can resume', (
    tester,
  ) async {
    final renders = <Completer<Uint8List>>[];
    GameAudio.renderTrackForTesting = (_) {
      final render = Completer<Uint8List>();
      renders.add(render);
      return render.future;
    };

    final pending = GameAudio.music('arcade');
    expect(renders, hasLength(1));
    await GameAudio.update(GameAudio.settings.value.copyWith(music: false));
    renders.first.complete(Uint8List.fromList([1]));
    await pending;
    expect(calls.where((c) => c.method == 'music'), isEmpty);

    await GameAudio.update(GameAudio.settings.value.copyWith(music: true));
    expect(renders, hasLength(2));
    renders.last.complete(Uint8List.fromList([2]));
    await tester.pump();
    final music = calls.where((c) => c.method == 'music').single;
    expect(music.arguments['name'], 'arcade');
    expect(music.arguments['bytes'], Uint8List.fromList([2]));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('returning to the same track rejects an older generation', (
    tester,
  ) async {
    final renders = <Completer<Uint8List>>[];
    GameAudio.renderTrackForTesting = (_) {
      final render = Completer<Uint8List>();
      renders.add(render);
      return render.future;
    };

    final first = GameAudio.music('race');
    await GameAudio.music('race');
    expect(renders, hasLength(1), reason: 'Deduplicate a pending track');
    final other = GameAudio.music('fair');
    final latest = GameAudio.music('race');
    expect(renders, hasLength(3));
    renders.last.complete(Uint8List.fromList([3]));
    await latest;
    renders.first.complete(Uint8List.fromList([1]));
    renders[1].complete(Uint8List.fromList([2]));
    await Future.wait([first, other]);

    final music = calls.where((c) => c.method == 'music').single;
    expect(music.arguments['name'], 'race');
    expect(music.arguments['bytes'], Uint8List.fromList([3]));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a late native reply cannot restore stopped playback', (
    tester,
  ) async {
    final reply = Completer<void>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'music' && !reply.isCompleted) await reply.future;
      return null;
    });

    final pending = GameAudio.music('chill');
    await tester.pump();
    expect(calls.where((c) => c.method == 'music'), hasLength(1));
    GameAudio.stopMusic();
    await tester.pump();
    expect(calls.where((c) => c.method == 'stopMusic'), hasLength(1));
    reply.complete();
    await pending;

    await GameAudio.music('chill');
    expect(calls.where((c) => c.method == 'music'), hasLength(2));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('slider release sends and persists the previewed volume', (
    tester,
  ) async {
    await GameAudio.music('space');
    calls.clear();
    final previews = <double>[];
    void listen() => previews.add(GameAudio.settings.value.volume);
    GameAudio.settings.addListener(listen);
    addTearDown(() => GameAudio.settings.removeListener(listen));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SoundControls())),
    );
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0.25);
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0.25);
    expect(previews, [0.25], reason: 'Nitro listens to live settings previews');
    expect(calls.where((c) => c.method == 'volume'), isEmpty);

    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(0.25);
    await tester.pumpAndSettle();
    final volume = calls.where((c) => c.method == 'volume').single;
    expect(volume.arguments['volume'], 0.25);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble('audio_volume'), 0.25);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('muting takes effect before preferences finish writing', (
    tester,
  ) async {
    await GameAudio.music('fair');
    calls.clear();
    final update = GameAudio.update(
      GameAudio.settings.value.copyWith(music: false),
    );
    // The command is issued synchronously, before update's first await.
    expect(calls.where((c) => c.method == 'stopMusic'), hasLength(1));
    await update;
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final (stored, expected) in <(double, double)>[
    (-0.5, 0.0),
    (1.5, 1.0),
    (double.nan, 0.6),
    (double.infinity, 0.6),
    (double.negativeInfinity, 0.6),
    (0.35, 0.35),
  ]) {
    testWidgets('loaded volume $stored is safe for the slider', (tester) async {
      SharedPreferences.setMockInitialValues({
        'audio_music': true,
        'audio_sfx': false,
        'audio_volume': stored,
      });
      await GameAudio.init();
      expect(GameAudio.settings.value.volume, expected);
      expect(GameAudio.settings.value.music, isTrue);
      expect(GameAudio.settings.value.sfx, isFalse);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SoundControls())),
      );
      expect(tester.widget<Slider>(find.byType(Slider)).value, expected);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
