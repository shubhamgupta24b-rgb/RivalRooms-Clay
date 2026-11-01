import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart';
import '../../guess_person/models/gp_player.dart';
import '../../../core/ui/materials/materials.dart';
import '../party/party_widgets.dart' show PromptCard;
import '../shell/local_game_shell.dart' show ResultScope;
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/ticking_play.dart';

enum TodPhase { spin, spinning, choose, prompt, finished }

/// Spin the bottle, then Truth or Dare. Doing it scores a point; skipping scores nothing.
/// Each player gets [spinsEach] spins on average; most points wins.
class TruthDareLogic extends LocalGameLogic {
  static const truths = [
    'What is the most embarrassing thing in your phone gallery?',
    'Who in this room would you call at 3 a.m. in an emergency?',
    'What is a habit you hide from everyone?',
    'What was your most awkward moment in class?',
    'What is the last lie you told?',
    'Which app do you spend the most time on, honestly?',
    'What is your most irrational fear?',
    'Who was your first crush?',
    'What is the weirdest food combo you secretly love?',
    'What is something you pretend to understand but don’t?',
    'If you could swap lives with someone here for a day, who and why?',
    'What is the silliest reason you have cried?',
    'What is the worst gift you ever received?',
    'What is your guilty-pleasure song?',
    'Have you ever blamed someone else for something you did?',
    'What is the most childish thing you still do?',
    'What is one thing you would change about yourself?',
    'Which teacher did you like the most, and why?',
    'What is the longest you have gone without a shower?',
    'What is the funniest nickname you have had?',
    'What is a secret talent nobody here knows about?',
    'What was your most cringe social media post?',
    'Who here do you think would survive a zombie apocalypse?',
    'What is the most money you have wasted on something useless?',
    'What is a rumour you once believed?',
  ];
  static const dares = [
    'Do your best impression of someone in this room.',
    'Talk in an accent for the next two rounds.',
    'Do 15 jumping jacks right now.',
    'Sing the chorus of the last song you listened to.',
    'Let the group choose a funny pose for you to hold for 20 seconds.',
    'Speak without closing your mouth for 30 seconds.',
    'Do a dramatic movie-trailer voice describing your day.',
    'Show the last photo you took (only if it’s OK to share!).',
    'Dance for 20 seconds with no music.',
    'Balance a spoon (or pen) on your nose for 10 seconds.',
    'Say the alphabet backwards as fast as you can.',
    'Act like a cat until your next turn.',
    'Compliment every player in a different way.',
    'Try to lick your elbow.',
    'Do your best robot dance.',
    'Tell a joke. If nobody laughs, do 5 push-ups.',
    'Make up a 4-line rap about the person on your left.',
    'Walk like a model across the room.',
    'Hold a plank for 30 seconds.',
    'Say "I love Party Games" in three different voices.',
    'Let someone draw a tiny smiley on your hand.',
    'Pretend to be a news reporter for 30 seconds.',
    'Speak only in questions until your next turn.',
    'Do your best evil laugh.',
    'Imitate a famous celebrity until someone guesses who.',
  ];

  final int players;
  final int totalSpins;
  final Random _random;
  final List<int> points;
  late final List<String> _truthDeck = [...truths]..shuffle(_random);
  late final List<String> _dareDeck = [...dares]..shuffle(_random);
  TodPhase phase = TodPhase.spin;
  int spins = 0;
  int? chosen;
  bool truth = true;
  String prompt = '';

  TruthDareLogic({this.players = 2, int spinsEach = 3, Random? random})
      : totalSpins = players * spinsEach,
        _random = random ?? Random(),
        points = List.filled(players, 0);

  @override
  bool get finished => phase == TodPhase.finished;
  @override
  List<int> get scores => points;
  @override
  void update(int elapsedMs) {}

  /// Starts a spin; returns the player it will land on (or [target], for tests).
  int? spin([int? target]) {
    if (forward('spin', const [])) return null;
    if (phase != TodPhase.spin) return null;
    chosen = target ?? _random.nextInt(players);
    phase = TodPhase.spinning;
    notifyListeners();
    return chosen;
  }

  /// The bottle has stopped.
  void landed() {
    if (forward('landed', const [])) return;
    if (phase != TodPhase.spinning) return;
    phase = TodPhase.choose;
    notifyListeners();
  }

  void choose({required bool truth}) {
    if (forward('choose', [truth])) return;
    if (phase != TodPhase.choose) return;
    this.truth = truth;
    final deck = truth ? _truthDeck : _dareDeck;
    prompt = deck.removeLast();
    deck.insert(0, prompt); // recycle at the bottom
    phase = TodPhase.prompt;
    notifyListeners();
  }

  void complete({required bool done}) {
    if (forward('complete', [done])) return;
    if (phase != TodPhase.prompt) return;
    if (done) points[chosen!]++;
    spins++;
    phase = spins >= totalSpins ? TodPhase.finished : TodPhase.spin;
    notifyListeners();
  }
}

final truthDareInfo = LocalGameInfo(
  id: 'truth_dare',
  title: 'Truth or Dare',
  emoji: '🍾',
  color: const Color(0xFFFF4FA3),
  tagline: 'Spin the bottle. No chickening out!',
  rules: const [
    'Sit in a circle around the phone and tap SPIN.',
    'Whoever the bottle points to picks TRUTH or DARE.',
    'Do it for +1 point, or skip for nothing. Most points after everyone has had 3 spins wins!',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  maxPlayers: 6,
  online: RelaySpec<TruthDareLogic>(
    create: (n) => TruthDareLogic(players: n),
    save: (g) => {
      'phase': g.phase.index,
      'spins': g.spins,
      'chosen': g.chosen,
      'truth': g.truth,
      'prompt': g.prompt,
      'points': g.points
    },
    load: (g, s, me) {
      g.phase = TodPhase.values[asInt(s['phase'])];
      g.spins = asInt(s['spins']);
      g.chosen = nInt(s['chosen']);
      g.truth = s['truth'] == true;
      g.prompt = s['prompt'] as String;
      g.points.setAll(0, ints(s['points']));
    },
    apply: (g, from, name, a) {
      switch (name) {
        case 'spin':
          g.spin(); // anyone can spin
        case 'landed':
          g.landed();
        case 'choose' when from == g.chosen:
          g.choose(truth: a[0] == true);
        case 'complete' when from == g.chosen:
          g.complete(done: a[0] == true);
      }
    },
    view: (context, g, players, me) => _TodTable(players: players, g: g),
  ),
  play: (players, onFinished) => TickingPlay<TruthDareLogic>(
    create: () => TruthDareLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _TodTable(players: players, g: g),
  ),
);

// Palette: truth blue, dare red, party pink, and a round wooden table with a felt top.
// Truth is blue, Dare orange (spec 5.2 #22).
const _truthBlue = Color(0xFF2E8BFF);
const _dareRed = Color(0xFFFF8A1F);

class _TodTable extends StatefulWidget {
  final List<GpPlayer> players;
  final TruthDareLogic g;
  const _TodTable({required this.players, required this.g});
  @override
  State<_TodTable> createState() => _TodTableState();
}

class _TodTableState extends State<_TodTable> {
  double _angle = 0; // bottle angle where it rests now

  double _angleFor(int i) => -pi / 2 + i * 2 * pi / widget.players.length;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final players = widget.players;
    final target = g.chosen == null ? _angle : _angleFor(g.chosen!) + pi / 2;
    // Always spin forwards several full turns to the target.
    var end = target;
    if (g.phase == TodPhase.spinning) {
      end = target + 2 * pi * 4;
      while (end - _angle < 2 * pi * 4) {
        end += 2 * pi;
      }
    }
    ResultScope.of(context)?.subtitle = '${g.totalSpins} spins of the bottle';
    return MomentWatcher<TodPhase>(
      value: g.phase,
      onChange: (fx, before, now) {
        if (now == TodPhase.choose && g.chosen != null)
          fx?.announce(players[g.chosen!].name, sub: 'Truth or dare?');
        if (before == TodPhase.prompt &&
            now != TodPhase.prompt &&
            g.points.fold(0, (a, b) => a + b) > _lastTotal) {
          fx?.pop('+1');
          GameAudio.sfx('coin');
        }
        _lastTotal = g.points.fold(0, (a, b) => a + b);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.l),
        child: Column(children: [
          ScoreHud(
            title: 'Truth or Dare',
            state: 'Spin ${min(g.spins + 1, g.totalSpins)} of ${g.totalSpins}',
            players: players,
            turn: g.phase == TodPhase.spin || g.phase == TodPhase.spinning
                ? null
                : g.chosen,
            score: (i) => '${g.points[i]}',
            tag: (i) => g.chosen == i &&
                    g.phase != TodPhase.spinning &&
                    g.phase != TodPhase.spin
                ? (g.phase == TodPhase.prompt
                    ? (g.truth ? 'TRUTH' : 'DARE')
                    : 'PICKED')
                : null,
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final r = min(c.maxWidth, c.maxHeight) / 2 - 40;
              final centre = Offset(c.maxWidth / 2, c.maxHeight / 2);
              return Stack(children: [
                // The table: a wooden ring around a felt top.
                Positioned(
                  left: centre.dx - r - 20,
                  top: centre.dy - r - 20,
                  width: 2 * r + 40,
                  height: 2 * r + 40,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x80000000),
                              offset: Offset(0, 12),
                              blurRadius: 20)
                        ]),
                    child: ClipOval(
                      child: CustomPaint(
                        painter: const WoodPainter(radius: 0),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: ClipOval(
                              child: const CustomPaint(
                                  painter: FeltPainter(rim: false, radius: 0),
                                  size: Size.infinite)),
                        ),
                      ),
                    ),
                  ),
                ),
                for (var i = 0; i < players.length; i++)
                  Positioned(
                    left: centre.dx + cos(_angleFor(i)) * r - 58,
                    top: centre.dy + sin(_angleFor(i)) * r - 22,
                    width: 116,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 300),
                      scale: g.chosen == i &&
                              g.phase != TodPhase.spinning &&
                              g.phase != TodPhase.spin
                          ? 1.15
                          : 1,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(5, 5, 10, 5),
                        decoration: BoxDecoration(
                          color: NeonPalette.sheet,
                          borderRadius: Radii.rChip,
                          border: Border.all(
                              color:
                                  g.chosen == i ? Brand.gold : players[i].color,
                              width: g.chosen == i ? 2.5 : 1.5),
                          boxShadow: [
                            if (g.chosen == i && g.phase != TodPhase.spinning)
                              BoxShadow(
                                  color: Brand.gold.withValues(alpha: 0.6),
                                  blurRadius: 16,
                                  spreadRadius: 1)
                          ],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          PlayerBadge(
                              index:
                                  PlayerPalette.indexOf(players[i].color) ?? i,
                              size: 22,
                              color: players[i].color,
                              initial: players[i].name),
                          const SizedBox(width: 6),
                          Flexible(
                              child: Text(players[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontFamily: Fonts.body,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12))),
                        ]),
                      ),
                    ),
                  ),
                Positioned(
                  left: centre.dx - r * 0.55,
                  top: centre.dy - r * 0.55,
                  width: r * 1.1,
                  height: r * 1.1,
                  child: Semantics(
                    button: g.phase == TodPhase.spin,
                    label: 'Spin the bottle',
                    child: GestureDetector(
                      onTap: g.phase == TodPhase.spin
                          ? () {
                              haptic(HapticWeight.medium);
                              g.spin();
                            }
                          : null,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: _angle, end: end),
                        duration: g.phase == TodPhase.spinning
                            ? const Duration(milliseconds: 2600)
                            : Duration.zero,
                        curve: Curves.easeOutCubic,
                        onEnd: () {
                          if (g.phase == TodPhase.spinning) {
                            _angle = target % (2 * pi);
                            haptic(HapticWeight.heavy);
                            GameAudio.sfx('pop');
                            g.landed();
                          }
                        },
                        builder: (_, a, __) => Transform.rotate(
                            angle: a,
                            child:
                                const CustomPaint(painter: _BottlePainter())),
                      ),
                    ),
                  ),
                ),
              ]);
            }),
          ),
          _bottom(g, players),
        ]),
      ),
    );
  }

  int _lastTotal = 0;

  Widget _bottom(TruthDareLogic g, List<GpPlayer> players) {
    switch (g.phase) {
      case TodPhase.spin:
        return GoldButton('Spin the bottle', icon: GameIcons.rotate, height: 58,
            onPressed: () {
          haptic(HapticWeight.medium);
          GameAudio.sfx('throw');
          g.spin();
        });
      case TodPhase.spinning:
        return SizedBox(
            height: 58,
            child: Center(
                child: Text('Spinning…',
                    style: context.tk.styles.h3
                        .copyWith(color: context.tk.onBgMuted))));
      case TodPhase.choose:
        final p = players[g.chosen!];
        return Column(mainAxisSize: MainAxisSize.min, children: [
          TurnBanner(
              text: '${p.name}, pick one!', color: p.color, compact: true),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _PickCard(
                    label: 'TRUTH',
                    icon: GameIcons.speech,
                    color: _truthBlue,
                    onTap: () => g.choose(truth: true))),
            const SizedBox(width: 12),
            Expanded(
                child: _PickCard(
                    label: 'DARE',
                    icon: GameIcons.bolt,
                    color: _dareRed,
                    onTap: () => g.choose(truth: false))),
          ]),
        ]);
      case TodPhase.prompt:
        final color = g.truth ? _truthBlue : _dareRed;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          PromptCard(
              key: ValueKey(g.prompt),
              header: g.truth ? 'Truth' : 'Dare',
              text: g.prompt,
              icon: g.truth ? GameIcons.speech : GameIcons.bolt,
              color: color),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: KitButton('Skip',
                    icon: GameIcons.skip,
                    style: KitButtonStyle.soft,
                    height: 56,
                    onPressed: () => g.complete(done: false))),
            const SizedBox(width: 10),
            Expanded(
                child: GoldButton('Did it +1',
                    icon: GameIcons.check,
                    onPressed: () => g.complete(done: true))),
          ]),
        ]);
      case TodPhase.finished:
        return const SizedBox(height: 58);
    }
  }
}

/// A big Truth / Dare card to pick.
class _PickCard extends StatelessWidget {
  final String label;
  final GameIcons icon;
  final Color color;
  final VoidCallback onTap;
  const _PickCard(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () {
            haptic(HapticWeight.selection);
            onTap();
          },
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(color, Colors.white, 0.1)!,
                    Color.lerp(color, Colors.black, 0.25)!
                  ]),
              borderRadius: Radii.rButton,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6), width: 2),
              boxShadow: Shadows.edge(Color.lerp(color, Colors.black, 0.5)!),
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              GameIcon(icon, size: 34),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 28,
                      letterSpacing: 2,
                      color: Colors.white)),
            ]),
          ),
        ),
      );
}

/// A glass bottle seen from above, neck pointing up: see-through green glass with a
/// highlight, a paper label and a cork.
class _BottlePainter extends CustomPainter {
  const _BottlePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final bodyW = w * 0.3, neckW = w * 0.11;
    final path = Path()
      ..moveTo(cx - neckW / 2, h * 0.06)
      ..lineTo(cx + neckW / 2, h * 0.06)
      ..lineTo(cx + neckW / 2, h * 0.3)
      ..quadraticBezierTo(cx + bodyW / 2, h * 0.36, cx + bodyW / 2, h * 0.48)
      ..lineTo(cx + bodyW / 2, h * 0.9)
      ..quadraticBezierTo(
          cx + bodyW / 2, h * 0.95, cx + bodyW / 2 - 6, h * 0.95)
      ..lineTo(cx - bodyW / 2 + 6, h * 0.95)
      ..quadraticBezierTo(cx - bodyW / 2, h * 0.95, cx - bodyW / 2, h * 0.9)
      ..lineTo(cx - bodyW / 2, h * 0.48)
      ..quadraticBezierTo(cx - bodyW / 2, h * 0.36, cx - neckW / 2, h * 0.3)
      ..close();
    final body = Rect.fromLTWH(cx - bodyW / 2, 0, bodyW, h);
    canvas.drawPath(
        path.shift(const Offset(4, 7)),
        Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(colors: [
            Color(0xCC0F5C2A),
            Color(0xCC3FB86A),
            Color(0xCC1E7A3E),
            Color(0xCC0B4420)
          ], stops: [
            0,
            0.35,
            0.7,
            1
          ]).createShader(body));
    // Paper label with a gold band.
    final label = Rect.fromLTWH(cx - bodyW / 2, h * 0.56, bodyW, h * 0.2);
    canvas.drawRect(
        label,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFDF6), Color(0xFFF0E1C2)])
              .createShader(label));
    canvas.drawRect(
        Rect.fromLTWH(label.left, label.top + label.height * 0.42, label.width,
            label.height * 0.16),
        Paint()..color = Brand.gold);
    // Cork.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - neckW / 2 - 1, h * 0.02, neckW + 2, h * 0.07),
            const Radius.circular(3)),
        Paint()..color = const Color(0xFFC8925A));
    // Glass highlights.
    final shine = Paint()
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawLine(Offset(cx - bodyW * 0.3, h * 0.5),
        Offset(cx - bodyW * 0.3, h * 0.88), shine..strokeWidth = bodyW * 0.09);
    canvas.drawLine(Offset(cx - neckW * 0.2, h * 0.12),
        Offset(cx - neckW * 0.2, h * 0.28), shine..strokeWidth = neckW * 0.18);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF0D3D1C));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
