import 'package:flutter/material.dart';
import '../party/party_widgets.dart' show GameTopBar;
import '../shell/local_game_logic.dart';
import '../../../core/records/records.dart';
import '../../../core/ui/components.dart';
import '../shell/local_game_shell.dart' show ScorePill, GameTheme;

/// Base for one-player games: a clock, a score, and a short pause after "game over" so
/// you can see what happened before the score screen.
abstract class SoloLogic extends LocalGameLogic {
  int now = 0;
  int score = 0;
  int? _endAt;
  bool get over => _endAt != null;

  @override
  bool get finished => _endAt != null && now >= _endAt!;
  @override
  List<int> get scores => [score];

  @override
  void update(int elapsedMs) {
    now = elapsedMs;
    if (!over) step(elapsedMs);
  }

  /// Per-frame game step while the game is running.
  @protected
  void step(int now) {}

  /// Ends the game; the score screen follows after [pauseMs].
  @protected
  void gameOver([int pauseMs = 1200]) {
    if (over) return;
    _endAt = now + pauseMs;
    notifyListeners();
  }
}

/// Top bar for solo games: pause, title, the live score, and your best on this phone
/// (with a "NEW BEST" badge the moment you beat it).
class SoloFrame extends StatefulWidget {
  final String title;
  final int score;
  final String? extra; // e.g. "42s"
  final int? lives; // hearts left, drawn as icons next to the score
  final int maxLives;
  final Widget child;
  const SoloFrame(
      {super.key,
      required this.title,
      required this.score,
      this.extra,
      this.lives,
      this.maxLives = 3,
      required this.child});

  @override
  State<SoloFrame> createState() => _SoloFrameState();
}

class _SoloFrameState extends State<SoloFrame> {
  int? _best; // best score before this game

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_best != null) return;
    final id = GameTheme.idOf(context);
    if (id == null) return;
    Records.all().then((r) {
      if (mounted) setState(() => _best = r[id]?.best ?? 0);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final best = _best;
    final beaten = best != null && best > 0 && widget.score > best;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.m),
      child: Column(children: [
        GameTopBar(
          title: widget.title,
          subtitle: widget.extra,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.lives != null)
              Padding(
                padding: const EdgeInsets.only(right: Space.s),
                child: Semantics(
                  label: '${widget.lives} of ${widget.maxLives} lives',
                  excludeSemantics: true,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var h = 0; h < widget.maxLives; h++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: GameIcon(
                            h < widget.lives!
                                ? GameIcons.heart
                                : GameIcons.heartEmpty,
                            size: 16,
                            color: const Color(0xFFFF5B6E)),
                      ),
                  ]),
                ),
              ),
            if (best != null && best > 0)
              Padding(
                padding: const EdgeInsets.only(right: Space.s),
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.normal),
                  child: beaten
                      ? Container(
                          key: const ValueKey('new'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: Space.s, vertical: 4),
                          decoration: BoxDecoration(
                              color: Brand.gold, borderRadius: Radii.rMd),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GameIcon(GameIcons.trophy,
                                    size: 14, color: Brand.ink),
                                SizedBox(width: 4),
                                Text('NEW BEST',
                                    style: TextStyle(
                                        fontFamily: Fonts.display,
                                        color: Brand.ink,
                                        fontSize: 13)),
                              ]),
                        )
                      : Column(
                          key: const ValueKey('best'),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                              Text('BEST',
                                  style: t.styles.label.copyWith(
                                      fontSize: 10,
                                      color:
                                          t.flat ? t.textMuted : t.onBgMuted)),
                              Text('$best',
                                  style: t.styles.score.copyWith(
                                      fontSize: 14,
                                      color: t.flat ? t.text : t.onBg)),
                            ]),
                ),
              ),
            Semantics(
              label: 'Score ${widget.score}',
              excludeSemantics: true,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(widget.score),
                tween: Tween(begin: Motion.reduced(context) ? 1 : 1.25, end: 1),
                duration: Motion.of(context, Motion.normal),
                builder: (_, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: ScorePill('${widget.score}'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: Space.s),
        Expanded(child: RepaintBoundary(child: widget.child)),
      ]),
    );
  }
}

/// Swipe direction from a fling: 0 up, 1 right, 2 down, 3 left (or null if too small).
int? swipeDir(Offset v, {double minSpeed = 120}) {
  if (v.distance < minSpeed) return null;
  return v.dx.abs() > v.dy.abs() ? (v.dx > 0 ? 1 : 3) : (v.dy > 0 ? 2 : 0);
}
