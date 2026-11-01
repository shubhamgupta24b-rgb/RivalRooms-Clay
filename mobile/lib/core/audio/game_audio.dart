import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/components.dart';

/// Background music and sound effects. There is no audio package: the tunes are
/// chiptunes synthesised here (melody, bass and drums rendered to WAV off the UI thread)
/// and played by a small channel in MainActivity (MediaPlayer for music, SoundPool for
/// effects). Everything is fire-and-forget; without the channel (tests, desktop) it's silent.
class GameAudio {
  GameAudio._();
  static const _ch = MethodChannel('party/audio');

  /// Music on, sound effects on, music volume (0..1). Widgets listen to this.
  static final settings = ValueNotifier<AudioSettings>(const AudioSettings());

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static String? _wanted, _playing;
  static int _musicRequest = 0;

  /// Holds synthesis at a deterministic boundary in audio regression tests.
  @visibleForTesting
  static Future<Uint8List> Function(Chiptune)? renderTrackForTesting;
  static final _sentMusic = <String>{}, _sentSfx = <String>{};

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      final volume = p.getDouble('audio_volume') ?? 0.6;
      settings.value = AudioSettings(
          music: p.getBool('audio_music') ?? true,
          sfx: p.getBool('audio_sfx') ?? true,
          volume: volume.isFinite ? volume.clamp(0.0, 1.0).toDouble() : 0.6);
    } catch (_) {}
  }

  static Future<void> update(AudioSettings s) async {
    final old = settings.value;
    settings.value = s;
    if (!s.music) {
      _stop();
    } else if (!old.music && _wanted != null) {
      final w = _wanted!;
      _wanted = null;
      music(w);
    } else {
      // Slider previews already updated the notifier before this commit.
      _call('volume', {'volume': s.volume});
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('audio_music', s.music);
      await p.setBool('audio_sfx', s.sfx);
      await p.setDouble('audio_volume', s.volume);
    } catch (_) {}
  }

  /// The tune a game plays, if it has one.
  static String? musicFor(String gameId) => gameMusic[gameId];

  /// Starts [track] looping (if music is on), replacing whatever was playing.
  static Future<void> music(String? track) async {
    if (track == null) return stopMusic();
    if (_wanted == track) return;
    _wanted = track;
    final request = ++_musicRequest;
    if (!_supported || !settings.value.music || _playing == track) return;
    Uint8List? bytes;
    if (!_sentMusic.contains(track)) {
      final spec = chiptunes[track];
      if (spec == null) return;
      bytes = await (renderTrackForTesting?.call(spec) ??
          Isolate.run(() => renderTrack(spec)));
    }
    if (request != _musicRequest || _wanted != track || !settings.value.music) {
      return;
    }
    // The native command is sent now; a late reply must not resurrect playback.
    _playing = track;
    await _call('music',
        {'name': track, 'bytes': bytes, 'volume': settings.value.volume});
    _sentMusic.add(track);
  }

  static void stopMusic() {
    _wanted = null;
    _stop();
  }

  static void _stop() {
    ++_musicRequest;
    if (_playing == null) return;
    _playing = null;
    _call('stopMusic', null);
  }

  /// Plays a short effect: tap, shoot, hit, pop, coin, jump, throw, boom, win, lose.
  static void sfx(String name) {
    if (!_supported || !settings.value.sfx) return;
    final first = !_sentSfx.contains(name);
    if (first) {
      final spec = soundEffects[name];
      if (spec == null) return;
      _sentSfx.add(name);
      _call('sfx', {'name': name, 'bytes': _wav(spec()), 'volume': 1.0});
    } else {
      _call('sfx', {'name': name, 'volume': 1.0});
    }
  }

  static Future<void> _call(String method, Object? args) async {
    try {
      await _ch.invokeMethod(method, args);
    } catch (_) {
      // No audio on this platform.
    }
  }
}

@immutable
class AudioSettings {
  final bool music, sfx;
  final double volume;
  const AudioSettings({this.music = true, this.sfx = true, this.volume = 0.6});
  AudioSettings copyWith({bool? music, bool? sfx, double? volume}) =>
      AudioSettings(
          music: music ?? this.music,
          sfx: sfx ?? this.sfx,
          volume: volume ?? this.volume);
}

/// Which games have music, and which tune.
const gameMusic = {
  'air_hockey': 'race',
  'paint_fight': 'race',
  'ping_pong': 'arcade',
  'brick_breaker': 'arcade',
  'flappy_jump': 'arcade',
  'dino_run': 'arcade',
  'sky_jumper': 'arcade',
  'stack_tower': 'arcade',
  'fruit_cut': 'arcade',
  'chicken_jump': 'arcade',
  'bike_race': 'race',
  'candy_crush': 'chill',
  'carrom': 'chill',
  'eight_ball': 'chill',
  'slingshot': 'arcade',
  'space_shooter': 'space',
  'color_switch': 'space',
  'block_drop': 'space',
  'bubble_shooter': 'chill',
  'fruit_merge': 'chill',
  'fruit_merge_battle': 'chill',
  'game_2048': 'chill',
  'ball_sort': 'chill',
  'ring_sort': 'chill',
  'sliding_puzzle': 'chill',
  'sudoku': 'chill',
  'minesweeper': 'chill',
  'mini_golf': 'chill',
  'bottle_smash': 'fair',
  'shooting_gallery': 'fair',
  'archery': 'fair',
  'whack_mole': 'fair',
  'basketball_hoops': 'fair',
};

/// A looping tune: 8 steps (eighth notes) a bar; [chords] are bass roots, one per bar;
/// [melody] is MIDI notes, 0 = rest, -1 = hold the previous note.
class Chiptune {
  final int bpm;
  final List<int> chords, melody;
  final double duty; // melody pulse width; 0 = a soft triangle instead
  final bool lightDrums;
  const Chiptune(this.bpm, this.chords, this.melody,
      {this.duty = 0.25, this.lightDrums = false});
}

const chiptunes = {
  'arcade': Chiptune(140, [
    48,
    45,
    41,
    43
  ], [
    72, 76, 79, 76, 81, 79, 76, 72, 69, 72, 76, 81, 79, 76, 72, 69, //
    77, 81, 84, 81, 79, 77, 76, 74, 74, 79, 83, 79, 86, -1, 83, -1,
    84, -1, 83, 79, 76, -1, 79, 81, 81, -1, 79, 76, 72, -1, 76, 79,
    77, -1, 76, 77, 81, 79, 77, 76, 74, -1, 76, 74, 71, -1, 72, -1,
  ]),
  'race': Chiptune(
      168,
      [45, 41, 43, 40],
      [
        69, 0, 69, 72, 76, 0, 74, 72, 77, 0, 77, 76, 74, 0, 72, 74, //
        79, 0, 79, 77, 76, 0, 74, 72, 76, -1, 75, 76, 71, -1, 68, -1,
        81, -1, 79, 76, 81, -1, 79, 76, 77, -1, 76, 72, 77, -1, 76, 72,
        79, -1, 77, 74, 79, -1, 77, 74, 76, 74, 72, 71, 69, -1, -1, 0,
      ],
      duty: 0.5),
  'fair': Chiptune(
      152,
      [48, 43, 48, 43, 41, 48, 43, 48],
      [
        79, 78, 79, 0, 76, 0, 72, 0, 74, 73, 74, 0, 71, 0, 67, 0, //
        76, 75, 76, 0, 79, 0, 84, 0, 83, -1, 81, 79, 77, -1, 74, 0,
        77, 76, 77, 0, 81, 0, 84, 0, 84, -1, 79, 0, 76, 0, 72, 0,
        74, 76, 77, 79, 81, 79, 77, 74, 72, -1, -1, 0, 79, 0, 72, 0,
      ],
      duty: 0.125),
  'chill': Chiptune(
      100,
      [48, 45, 41, 43],
      [
        76, -1, -1, 79, 76, -1, 72, -1, 72, -1, -1, 76, 74, -1, 72, -1, //
        69, -1, 72, -1, 77, -1, 76, -1, 74, -1, -1, -1, 0, 0, 71, 74,
        76, -1, 79, -1, 84, -1, 83, 79, 81, -1, -1, 79, 76, -1, 72, -1,
        77, -1, 76, -1, 74, -1, 72, -1, 71, -1, 72, -1, 74, -1, -1, -1,
      ],
      duty: 0,
      lightDrums: true),
  'space': Chiptune(
      128,
      [45, 45, 41, 43],
      [
        69, 72, 76, 81, 76, 72, 69, 72, 69, 72, 76, 81, 84, 81, 76, 72, //
        65, 69, 72, 77, 72, 69, 65, 69, 67, 71, 74, 79, 83, 79, 74, 71,
        81, -1, 0, 81, 79, -1, 76, -1, 81, -1, 0, 84, 83, -1, 79, -1,
        77, -1, 0, 77, 76, -1, 72, -1, 74, -1, 76, -1, 79, -1, 83, -1,
      ],
      duty: 0.125),
};

const _rate = 22050;
double _freq(int midi) => 440 * pow(2, (midi - 69) / 12).toDouble();
double _square(double phase, double duty) => phase % 1 < duty ? 1 : -1;
double _triangle(double phase) => 4 * ((phase % 1) - 0.5).abs() - 1;

/// Renders a whole tune to a WAV file (runs in a background isolate).
Uint8List renderTrack(Chiptune t) {
  final step = 60 / t.bpm / 2;
  final stepN = (step * _rate).round();
  final out = Float64List(stepN * t.melody.length);
  final noise = Random(7);
  void add(int at, int n, double Function(double t) f) {
    for (var i = 0; i < n && at + i < out.length; i++) {
      out[at + i] += f(i / _rate);
    }
  }

  for (var s = 0; s < t.melody.length; s++) {
    final at = s * stepN;
    // Melody: hold through the -1s that follow.
    final m = t.melody[s];
    if (m > 0) {
      var len = 1;
      while (s + len < t.melody.length && t.melody[s + len] == -1) {
        len++;
      }
      final f = _freq(m), dur = len * step;
      add(at, (dur * _rate).round(), (x) {
        final env = min(1.0, x / 0.005) *
            exp(-x * (t.duty == 0 ? 1.6 : 2.6)) *
            min(1.0, (dur - x) / 0.02);
        final wave = t.duty == 0
            ? _triangle(x * f) * 0.9 + _triangle(x * f * 2) * 0.15
            : _square(x * f, t.duty) * 0.6;
        return wave * env * 0.22;
      });
    }
    // Bass: root, octave, fifth, octave across each beat.
    final root = t.chords[(s ~/ 8) % t.chords.length];
    final b = _freq(root + const [0, 12, 7, 12][s % 4]);
    add(at, (step * 0.9 * _rate).round(),
        (x) => _triangle(x * b) * min(1.0, x / 0.004) * exp(-x * 3) * 0.3);
    // Drums: kick on the beat, snare on 2 and 4, hats on the off-beats.
    if (s % 4 == 0) {
      add(
          at,
          (0.14 * _rate).round(),
          (x) =>
              sin(2 * pi * (55 * x + 400 * (1 - exp(-x * 30)) / 30)) *
              exp(-x * 22) *
              (t.lightDrums ? 0.3 : 0.55));
    }
    if (!t.lightDrums && s % 8 == 4) {
      add(at, (0.15 * _rate).round(),
          (x) => (noise.nextDouble() * 2 - 1) * exp(-x * 25) * 0.22);
    }
    if (s.isOdd) {
      var last = 0.0;
      add(at, (0.03 * _rate).round(), (x) {
        final n = noise.nextDouble() * 2 - 1, hp = n - last;
        last = n;
        return hp * exp(-x * 120) * (t.lightDrums ? 0.04 : 0.07);
      });
    }
  }
  return _wav(out);
}

/// Short effects, made on first use.
final soundEffects = <String, Float64List Function()>{
  'tap': () => _fx(0.05, (x, _) => _square(x * 880, 0.5) * exp(-x * 60) * 0.3),
  'shoot': () => _fx(
      0.16,
      (x, n) =>
          (_square(x * (900 - 4000 * x), 0.5) * 0.3 + n * 0.4) * exp(-x * 22)),
  'hit': () => _fx(
      0.14, (x, n) => (n * 0.6 + sin(2 * pi * 90 * x) * 0.5) * exp(-x * 30)),
  'pop': () => _fx(0.08,
      (x, _) => sin(2 * pi * (600 * x + 4000 * x * x)) * exp(-x * 40) * 0.5),
  'coin': () => _fx(0.25,
      (x, _) => _square(x * (x < 0.07 ? 988 : 1319), 0.5) * exp(-x * 9) * 0.25),
  'jump': () => _fx(0.14,
      (x, _) => _square(x * (300 + 3000 * x), 0.25) * exp(-x * 14) * 0.25),
  'throw': () => _fx(0.22, (x, n) => n * sin(pi * x / 0.22) * 0.3),
  'boom': () =>
      _fx(0.45, (x, n) => (n * 0.7 + sin(2 * pi * 50 * x) * 0.5) * exp(-x * 8)),
  'win': () => _fx(0.7, (x, _) {
        final i = min(3, (x / 0.1).floor());
        return _square(x * _freq(const [72, 76, 79, 84][i]), 0.25) *
            exp(-(x - i * 0.1) * (i == 3 ? 4 : 12)) *
            0.3;
      }),
  'lose': () => _fx(0.6, (x, _) {
        final i = min(2, (x / 0.15).floor());
        return _triangle(x * _freq(const [67, 64, 60][i])) *
            exp(-(x - i * 0.15) * (i == 2 ? 4 : 10)) *
            0.4;
      }),
};

/// [f] gets the time and smoothed noise.
Float64List _fx(double seconds, double Function(double x, double noise) f) {
  final rng = Random(3);
  final out = Float64List((seconds * _rate).round());
  var lp = 0.0;
  for (var i = 0; i < out.length; i++) {
    lp += 0.35 * ((rng.nextDouble() * 2 - 1) - lp);
    out[i] = f(i / _rate, lp * 2);
  }
  return out;
}

/// 16-bit mono WAV, softly limited so stacked notes never crackle.
Uint8List _wav(Float64List samples) {
  final data = ByteData(44 + samples.length * 2);
  void str(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, _rate, Endian.little)
    ..setUint32(28, _rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final x = samples[i];
    final limited = x / (1 + x.abs() * 0.6) * 1.2;
    data.setInt16(
        44 + i * 2, (limited.clamp(-1.0, 1.0) * 32000).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Music and sound switches plus a volume slider, for the pause menu and game intros.
class SoundControls extends StatelessWidget {
  final Color color;
  const SoundControls({super.key, this.color = const Color(0xFF7C4DFF)});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AudioSettings>(
      valueListenable: GameAudio.settings,
      builder: (context, s, _) {
        final muted = context.tk.textMuted;
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingSwitch(
                  emoji: '🎵',
                  label: 'Music',
                  value: s.music,
                  color: color,
                  onChanged: (v) => GameAudio.update(s.copyWith(music: v))),
              if (s.music)
                Row(children: [
                  SizedBox(
                      width: 34,
                      child: Icon(Icons.volume_down_rounded,
                          color: muted, size: 20)),
                  Expanded(
                    child: Slider(
                      value: s.volume,
                      activeColor: fillFor(color),
                      semanticFormatterCallback: (v) =>
                          'Music volume ${(v * 100).round()}%',
                      onChanged: (v) =>
                          GameAudio.settings.value = s.copyWith(volume: v),
                      onChangeEnd: (v) =>
                          GameAudio.update(s.copyWith(volume: v)),
                    ),
                  ),
                  Icon(Icons.volume_up_rounded, color: muted, size: 20),
                ]),
              SettingSwitch(
                emoji: '🔊',
                label: 'Sound effects',
                value: s.sfx,
                color: color,
                onChanged: (v) {
                  GameAudio.update(s.copyWith(sfx: v));
                  if (v) GameAudio.sfx('tap');
                },
              ),
            ]);
      },
    );
  }
}
