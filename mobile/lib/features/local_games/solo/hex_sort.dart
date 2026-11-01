import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/records/level_progress.dart';
import '../../../core/ui/components.dart';
import '../ring_sort/ring_sort_logic.dart';
import '../shell/local_game_shell.dart' show PauseButton;

const _ballColors = [
  Color(0xFFFF4D6D),
  Color(0xFF3A86FF),
  Color(0xFF2EC4B6),
  Color(0xFFFFBE0B),
  Color(0xFF9B5DE5),
  Color(0xFFFF8C42),
  Color(0xFF00BBF9),
  Color(0xFFF15BB5),
  Color(0xFF8D6346),
  Color(0xFF80ED99),
];

/// 50 hand-scaled puzzles per difficulty. Each one is scrambled from a solved board by
/// legal pours, so it is solvable, and the scramble gets longer as the level number rises.
const hexLevelsEach = 50;

class HexPuzzle {
  final int colors;
  final List<List<int>> tubes;
  const HexPuzzle(this.colors, this.tubes);
  bool get solved => tubes.every(
      (t) => t.isEmpty || (t.length == 4 && t.every((b) => b == t.first)));
}

int hexPourCount(List<List<int>> tubes, int from, int to) {
  if (from == to) return 0;
  final a = tubes[from], b = tubes[to];
  if (a.isEmpty || b.length >= 4) return 0;
  if (b.isNotEmpty && b.last != a.last) return 0;
  var run = 1;
  while (run < a.length && a[a.length - 1 - run] == a.last) {
    run++;
  }
  return min(run, 4 - b.length);
}

/// [difficulty] 0 easy, 1 medium, 2 hard. [level] is 1–50.
HexPuzzle hexPuzzle(int difficulty, int level) {
  final lv = level.clamp(1, hexLevelsEach);
  final rng = Random(difficulty * 10007 + lv * 97);
  final colors = switch (difficulty) {
    0 => 3 + (lv - 1) ~/ 17,
    1 => 4 + (lv - 1) ~/ 13,
    _ => min(9, 5 + (lv - 1) ~/ 10),
  };
  final empties = difficulty == 2 && lv > 30 ? 1 : 2;
  final scramble = switch (difficulty) {
    0 => 4 + lv,
    1 => 14 + lv * 2,
    _ => 28 + lv * 3,
  };
  final tubes = <List<int>>[
    for (var c = 0; c < colors; c++) [c, c, c, c],
    for (var i = 0; i < empties; i++) <int>[],
  ];
  bool solved() => tubes.every(
      (t) => t.isEmpty || (t.length == 4 && t.every((b) => b == t.first)));
  void pour(int from, int to) {
    final n = hexPourCount(tubes, from, to);
    if (n == 0) return;
    final k = 1 + rng.nextInt(n);
    for (var i = 0; i < k; i++) {
      tubes[to].add(tubes[from].removeLast());
    }
  }

  var guard = 0;
  do {
    for (var s = 0; s < scramble; s++) {
      final moves = <(int, int)>[];
      for (var a = 0; a < tubes.length; a++) {
        for (var b = 0; b < tubes.length; b++) {
          if (hexPourCount(tubes, a, b) > 0) moves.add((a, b));
        }
      }
      if (moves.isEmpty) break;
      final m = moves[rng.nextInt(moves.length)];
      pour(m.$1, m.$2);
    }
  } while (solved() && ++guard < 8);
  if (solved()) {
    final src = tubes.indexWhere((t) => t.isNotEmpty);
    final dst = tubes.indexWhere((t) => t.isEmpty);
    if (src >= 0 && dst >= 0) tubes[dst].add(tubes[src].removeLast());
  }
  return HexPuzzle(colors, [for (final t in tubes) List<int>.of(t)]);
}

class HexSortScreen extends StatefulWidget {
  final void Function(List<int> scores) onFinished;
  const HexSortScreen({super.key, required this.onFinished});
  @override
  State<HexSortScreen> createState() => _HexSortScreenState();
}

class _HexSortScreenState extends State<HexSortScreen> {
  static const _names = ['Easy', 'Medium', 'Hard'];
  int difficulty = 0;
  int? level;
  int unlocked = 1;
  HexPuzzle? puzzle;
  int? selected;
  int moves = 0;
  final List<List<List<int>>> _history = [];
  String? hint;

  String get _key => 'ball_sort_${_names[difficulty].toLowerCase()}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = await LevelProgress.unlocked(_key);
    if (mounted) setState(() => unlocked = n.clamp(1, hexLevelsEach));
  }

  void _open(int lv) {
    if (lv > unlocked) return;
    setState(() {
      level = lv;
      puzzle = hexPuzzle(difficulty, lv);
      selected = null;
      moves = 0;
      hint = null;
      _history.clear();
    });
  }

  void _tap(int tube) {
    final p = puzzle;
    if (p == null || p.solved) return;
    final s = selected;
    if (s == null) {
      if (p.tubes[tube].isNotEmpty) setState(() => selected = tube);
      return;
    }
    if (s == tube) {
      setState(() => selected = null);
      return;
    }
    final n = hexPourCount(p.tubes, s, tube);
    if (n == 0) {
      setState(() => selected = p.tubes[tube].isNotEmpty ? tube : null);
      HapticFeedback.heavyImpact().ignore();
      return;
    }
    setState(() {
      _history.add([for (final t in p.tubes) List<int>.of(t)]);
      for (var i = 0; i < n; i++) {
        p.tubes[tube].add(p.tubes[s].removeLast());
      }
      moves++;
      selected = null;
      hint = null;
    });
    HapticFeedback.selectionClick().ignore();
    if (p.solved) {
      LevelProgress.unlock(_key, min(hexLevelsEach, (level ?? 1) + 1))
          .then((n) {
        if (mounted) setState(() => unlocked = n);
      });
    }
  }

  void _undo() {
    if (_history.isEmpty || puzzle == null) return;
    setState(() {
      puzzle = HexPuzzle(puzzle!.colors, _history.removeLast());
      moves = max(0, moves - 1);
      selected = null;
    });
  }

  void _restart() {
    if (level == null) return;
    setState(() {
      puzzle = hexPuzzle(difficulty, level!);
      _history.clear();
      moves = 0;
      selected = null;
      hint = null;
    });
  }

  void _hint() {
    final p = puzzle;
    if (p == null || p.solved) return;
    final plan =
        solveRings([for (final t in p.tubes) List<int>.of(t)], limit: 8000);
    setState(() => hint = plan == null || plan.isEmpty
        ? 'No short hint for this one'
        : 'Try tube ${plan.first.$1 + 1} → ${plan.first.$2 + 1}');
  }

  @override
  Widget build(BuildContext context) {
    final p = puzzle;
    if (p == null || level == null) return _picker();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(children: [
        Row(children: [
          const PauseButton(),
          const SizedBox(width: 8),
          Expanded(
              child: Text('${_names[difficulty]}  $level / $hexLevelsEach',
                  style: const TextStyle(
                      fontFamily: Fonts.display,
                      color: Colors.white,
                      fontSize: 22))),
          Text('$moves',
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  color: Colors.white,
                  fontSize: 22,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        if (hint != null)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(hint!,
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w800))),
        const SizedBox(height: 8),
        Expanded(
            child: _HexBoard(tubes: p.tubes, selected: selected, onTap: _tap)),
        const SizedBox(height: 8),
        if (p.solved)
          Row(children: [
            Expanded(
                child: KitButton('Levels',
                    style: KitButtonStyle.soft,
                    onPressed: () => setState(() => puzzle = null))),
            const SizedBox(width: 8),
            Expanded(
                child: KitButton('Retry',
                    style: KitButtonStyle.soft, onPressed: _restart)),
            const SizedBox(width: 8),
            Expanded(
              child: GoldButton('Next',
                  height: 52,
                  onPressed:
                      level! >= hexLevelsEach ? null : () => _open(level! + 1)),
            ),
          ])
        else
          Row(children: [
            Expanded(
                child: KitButton('Undo',
                    icon: GameIcons.undo,
                    style: KitButtonStyle.soft,
                    onPressed: _undo)),
            const SizedBox(width: 8),
            Expanded(
                child: KitButton('Restart',
                    icon: GameIcons.restart,
                    style: KitButtonStyle.soft,
                    onPressed: _restart)),
            const SizedBox(width: 8),
            Expanded(
                child: KitButton('Hint',
                    icon: GameIcons.help,
                    style: KitButtonStyle.soft,
                    onPressed: _hint)),
          ]),
      ]),
    );
  }

  Widget _picker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Align(alignment: Alignment.centerLeft, child: PauseButton()),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: KitButton(_names[i],
                    style: difficulty == i
                        ? KitButtonStyle.soft
                        : KitButtonStyle.outline, onPressed: () {
                  setState(() => difficulty = i);
                  _load();
                }),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Text('Unlocked $unlocked of $hexLevelsEach',
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: hexLevelsEach,
            itemBuilder: (_, i) {
              final lv = i + 1;
              final open = lv <= unlocked;
              return Material(
                color: open ? const Color(0xFF7B4DFF) : const Color(0xFF2A2440),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: open ? () => _open(lv) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                      child: Text(open ? '$lv' : '•',
                          style: const TextStyle(
                              fontFamily: Fonts.display,
                              color: Colors.white,
                              fontSize: 18))),
                ),
              );
            },
          ),
        ),
        GoldButton('Exit',
            height: 52,
            onPressed: () => widget.onFinished([max(0, unlocked - 1)])),
      ]),
    );
  }
}

class _HexBoard extends StatelessWidget {
  final List<List<int>> tubes;
  final int? selected;
  final void Function(int) onTap;
  const _HexBoard(
      {required this.tubes, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final n = tubes.length;
      final per = n <= 5 ? n : (n / 2).ceil();
      final w = min((c.maxWidth - 8 * per) / per, 86.0);
      return Center(
        child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 12,
            children: [
              for (var i = 0; i < n; i++)
                GestureDetector(
                  onTap: () => onTap(i),
                  child: CustomPaint(
                    painter: _HexPainter(
                        tubes[i],
                        selected == i,
                        tubes[i].length == 4 &&
                            tubes[i].isNotEmpty &&
                            tubes[i].every((b) => b == tubes[i].first)),
                    size: Size(w, w * 1.15),
                  ),
                ),
            ]),
      );
    });
  }
}

class _HexPainter extends CustomPainter {
  final List<int> balls;
  final bool picked, done;
  _HexPainter(this.balls, this.picked, this.done);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.46;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = -pi / 2 + i * pi / 3;
      final p = c + Offset(cos(a), sin(a)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0x33FFFFFF));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = picked || done ? 3.5 : 2
          ..color = done
              ? const Color(0xFF2ECC71)
              : (picked ? const Color(0xFFFFC21A) : Colors.white70));
    final d = size.width * 0.22;
    for (var i = 0; i < balls.length; i++) {
      final y = size.height - 10 - d * 0.5 - i * (d * 0.92);
      final at = Offset(size.width / 2, y);
      final col = _ballColors[balls[i] % _ballColors.length];
      canvas.drawCircle(at, d / 2, Paint()..color = col);
      canvas.drawCircle(at + Offset(-d * 0.12, -d * 0.12), d * 0.12,
          Paint()..color = Colors.white.withValues(alpha: 0.7));
    }
  }

  @override
  bool shouldRepaint(_HexPainter old) =>
      old.balls != balls || old.picked != picked || old.done != done;
}
