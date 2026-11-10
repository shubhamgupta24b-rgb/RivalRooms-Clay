import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/game_hud.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton, ResultScope;
import '../shell/start_gate.dart';
import '../shell/ticking_play.dart';
import '../solo/solo_common.dart';

class _Block {
  final double at;
  final double lane;
  const _Block(this.at, this.lane);
}

/// Side-view race. Steer, accelerate, brake. Hit a block and you slow down. First to the line wins.
class BikeLogic extends SoloLogic {
  final int track;
  final Random rng;
  double progress = 0;
  double speed = 0;
  double lane = 0; // -1 left .. 1 right
  double steer = 0;
  bool gas = false;
  bool brake = false;
  bool crashed = false;
  final List<_Block> blocks = [];
  int _last = 0;
  final Set<int> _hit = {};

  BikeLogic({this.track = 1, Random? random})
      : rng = random ?? Random(track * 99) {
    final n = 6 + track * 4;
    for (var i = 0; i < n; i++) {
      blocks.add(_Block(0.08 + i * (0.8 / n) + rng.nextDouble() * 0.02,
          rng.nextDouble() * 2 - 1));
    }
  }

  void setSteer(double v) => steer = v.clamp(-1.0, 1.0);
  void setGas(bool v) => gas = v;
  void setBrake(bool v) => brake = v;

  @override
  void step(int now) {
    if (crashed) return;
    final dt = ((now - _last) / 1000).clamp(0.0, 0.05);
    _last = now;
    final accel = (gas ? 0.9 : -0.25) + (brake ? -1.4 : 0);
    speed = (speed + accel * dt).clamp(0.0, 0.55 + track * 0.05);
    lane = (lane + steer * 1.4 * dt).clamp(-1.0, 1.0);
    progress += speed * dt * 0.35;
    for (var i = 0; i < blocks.length; i++) {
      if (_hit.contains(i)) continue;
      final b = blocks[i];
      if ((progress - b.at).abs() < 0.02 && (lane - b.lane).abs() < 0.28) {
        _hit.add(i);
        speed *= 0.25;
      }
    }
    score = (progress * 100).floor().clamp(0, 100);
    if (progress >= 1) gameOver(600);
    notifyListeners();
  }
}

class BikeRace extends LocalGameLogic {
  final int track;
  final List<BikeLogic> bikes;
  int elapsed = 0;
  int? winner;
  BikeRace({this.track = 1, int players = 2})
      : bikes = [
          for (var i = 0; i < players; i++)
            BikeLogic(track: track, random: Random(track * 99))
        ];

  @override
  bool get finished => winner != null || elapsed > 120000;
  @override
  /// 0–100, the percent of the track each bike has covered. The finisher is 100.
  List<int> get scores => [
        for (var i = 0; i < bikes.length; i++)
          winner == i ? 100 : bikes[i].score.clamp(0, 99)
      ];

  void input(int player, double steer, bool gas, bool brake) {
    if (forward('input', [player, steer, gas, brake])) return;
    if (finished || elapsed < 3000 || player < 0 || player >= bikes.length)
      return;
    final b = bikes[player];
    b.setSteer(steer);
    b.setGas(gas);
    b.setBrake(brake);
  }

  @override
  void update(int ms) {
    elapsed = ms;
    if (ms >= 3000 && winner == null) {
      for (var i = 0; i < bikes.length; i++) {
        bikes[i].update(ms);
        if (bikes[i].progress >= 1 && winner == null) winner = i;
      }
    }
    notifyListeners();
  }

  Map<String, dynamic> save() => {
        't': elapsed,
        'w': winner,
        'p': [for (final b in bikes) b.progress],
        'lane': [for (final b in bikes) b.lane],
        'speed': [for (final b in bikes) b.speed],
      };

  void load(Map<String, dynamic> s) {
    elapsed = asInt(s['t']);
    winner = nInt(s['w']);
    final p = doubles(s['p']);
    final lane = doubles(s['lane']);
    final speed = doubles(s['speed']);
    for (var i = 0; i < bikes.length; i++) {
      bikes[i].progress = p[i];
      bikes[i].lane = lane[i];
      bikes[i].speed = speed[i];
    }
  }
}

final bikeRaceInfo = LocalGameInfo(
  id: 'bike_race',
  title: 'Bike Racing',
  emoji: '🏍️',
  color: const Color(0xFF3DDC97),
  tagline: 'Steer, throttle, beat the blocks!',
  rules: const [
    'Hold the gas, steer left and right, tap brake to scrub speed.',
    'Three tracks. Later tracks are faster and have more blocks.',
    'Online, both bikes share the track. The first across the line wins.',
  ],
  scoreUnit: 'percent of the track',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 2,
  online: RelaySpec<BikeRace>(
    create: (n) => BikeRace(players: n),
    save: (g) => g.save(),
    load: (g, s, me) => g.load(s),
    continuous: {'input'},
    apply: (g, from, name, a) {
      if (name == 'input' && asInt(a[0]) == from)
        g.input(from, asDouble(a[1]), a[2] == true, a[3] == true);
    },
    view: (context, g, players, me) =>
        _BikeView(race: g, me: me, players: players),
  ),
  play: (players, onFinished) => players.length < 2
      ? _BikeMenu(onFinished: onFinished)
      : TickingPlay<BikeRace>(
          create: () => BikeRace(players: 2),
          onFinished: onFinished,
          builder: (context, g) => _BikeView(race: g, me: 0, players: players)),
);

class _BikeMenu extends StatefulWidget {
  final void Function(List<int>) onFinished;
  const _BikeMenu({required this.onFinished});
  @override
  State<_BikeMenu> createState() => _BikeMenuState();
}

class _BikeMenuState extends State<_BikeMenu> {
  int? track;
  @override
  Widget build(BuildContext context) {
    if (track == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Align(alignment: Alignment.centerLeft, child: PauseButton()),
          const SizedBox(height: 12),
          for (var i = 1; i <= 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GoldButton('Track $i',
                  height: 56, onPressed: () => setState(() => track = i)),
            ),
        ]),
      );
    }
    return StartGate(
      color: const Color(0xFF3D7A4A),
      child: (context) => TickingPlay<BikeLogic>(
      create: () => BikeLogic(track: track!),
      onFinished: widget.onFinished,
      builder: (context, g) {
        ResultScope.of(context)?.subtitle =
            'Track progress · ${g.score}% of the lap';
        return SoloFrame(
          title: 'Track ${g.track}',
          score: g.score,
          extra: g.progress >= 1 ? 'Finish' : '${g.score}% of the track',
          child: _Pad(
              onSteer: g.setSteer,
              onGas: g.setGas,
              onBrake: g.setBrake,
              child: CustomPaint(
                  painter: _TrackPainter(
                      progress: g.progress, lane: g.lane, blocks: g.blocks),
                  child: const SizedBox.expand())));
      }));
  }
}

class _BikeView extends StatelessWidget {
  final BikeRace race;
  final int me;
  final List<GpPlayer> players;
  const _BikeView(
      {required this.race, required this.me, required this.players});
  @override
  Widget build(BuildContext context) {
    final b = race.bikes[me];
    ResultScope.of(context)?.subtitle = 'Percent of the track';
    return Column(children: [
      GameHud(
          players: players,
          scores: race.scores,
          extra: (_) => '%',
          trailing: Text(
              race.elapsed < 3000
                  ? '${(3 - race.elapsed / 1000).ceil()}'
                  : '${(b.speed * 200).floor()} km/h',
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white,
                  fontSize: 18))),
      Expanded(
          child: _Pad(
              onSteer: (v) => race.input(me, v, b.gas, b.brake),
              onGas: (v) => race.input(me, b.steer, v, b.brake),
              onBrake: (v) => race.input(me, b.steer, b.gas, v),
              child: CustomPaint(
                  painter: _TrackPainter(
                      progress: b.progress, lane: b.lane, blocks: b.blocks),
                  child: const SizedBox.expand()))),
    ]);
  }
}

class _Pad extends StatelessWidget {
  final Widget child;
  final void Function(double) onSteer;
  final void Function(bool) onGas;
  final void Function(bool) onBrake;
  const _Pad(
      {required this.child,
      required this.onSteer,
      required this.onGas,
      required this.onBrake});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(child: child),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(children: [
          _hold('◀', (d) => onSteer(d ? -1 : 0)),
          const Spacer(),
          _hold('BRAKE', onBrake),
          const SizedBox(width: 8),
          _hold('GAS', onGas),
          const Spacer(),
          _hold('▶', (d) => onSteer(d ? 1 : 0)),
        ]),
      ),
    ]);
  }

  Widget _hold(String label, void Function(bool) down) => GestureDetector(
        onTapDown: (_) => down(true),
        onTapUp: (_) => down(false),
        onTapCancel: () => down(false),
        child: Container(
          width: 56,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: const Color(0xFF2A2448),
              borderRadius: BorderRadius.circular(14)),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900)),
        ),
      );
}

class _TrackPainter extends CustomPainter {
  final double progress, lane;
  final List<_Block> blocks;
  _TrackPainter(
      {required this.progress, required this.lane, required this.blocks});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF243044));
    final road =
        Rect.fromLTWH(size.width * 0.2, 0, size.width * 0.6, size.height);
    canvas.drawRect(road, Paint()..color = const Color(0xFF3A4258));
    for (final b in blocks) {
      final dy = (b.at - progress) * size.height * 1.4 + size.height * 0.72;
      if (dy < -20 || dy > size.height + 20) continue;
      final x = road.left + (b.lane + 1) / 2 * road.width;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, dy), width: 28, height: 18),
              const Radius.circular(4)),
          Paint()..color = const Color(0xFFFF5A36));
    }
    final bikeX = road.left + (lane + 1) / 2 * road.width;
    canvas.drawCircle(Offset(bikeX, size.height * 0.72), 16,
        Paint()..color = const Color(0xFF3DDC97));
    canvas.drawRect(Rect.fromLTWH(0, size.height - 8, size.width * progress, 8),
        Paint()..color = const Color(0xFFFFC21A));
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) => true;
}
