import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'svg_path.dart';

export 'svg_path.dart' show svgPath;

/// Drawn icons (UI_SPEC 2.13) that replace every emoji in the game UI, plus the fruit
/// illustrations (Memory, Fruit Duel, Fruit Merge). The fruit paths are ported from
/// docs/ui-redesign/mockups/memory/Main.dc.html (`<g id="f-…">`); orange, pear and melon
/// are drawn in the same style. Icons with a stroke-only design draw in [GameIcon.color].
enum GameIcons {
  // App and HUD
  back,
  forward,
  close,
  pause,
  play,
  help,
  restart,
  sound,
  vibration,
  clock,
  globe,
  wifi,
  trophy,
  copy,
  share,
  search,
  settings,
  plus,
  minus,
  people,
  check,
  cross,
  undo,
  skip,
  eye,
  lock,
  lightbulb,
  flag,
  star,
  heart,
  heartEmpty,
  shield,
  crown,
  crownKing,
  coin,
  target,
  wind,
  arrow,
  bow,
  home,
  chevronDown,
  // Weapons, projectiles, and power-ups for action games.
  rocket,
  tripleRocket,
  mine,
  bolt,
  gun,
  mysteryBox,
  bomb,
  // Dice
  dice1,
  dice2,
  dice3,
  dice4,
  dice5,
  dice6,
  // Characters and game things
  duck,
  rabbit,
  mole,
  goldenMole,
  alien,
  ufo,
  tank,
  cactus,
  bird,
  pig,
  ladder,
  snake,
  rock,
  paper,
  scissors,
  bat,
  ball,
  cricketBall,
  puck,
  mallet,
  football,
  glove,
  bottle,
  woodBlock,
  stoneBlock,
  paintBrush,
  pencil,
  magnifier,
  mask,
  scroll,
  moon,
  sun,
  medical,
  clapper,
  speech,
  hammer,
  arrowLeft,
  arrowRight,
  arrowUp,
  arrowDown,
  rotate,
  drop,
  // Fruit
  apple,
  banana,
  grapes,
  watermelon,
  strawberry,
  kiwi,
  cherry,
  mango,
  peach,
  pineapple,
  coconut,
  lemon,
  orange,
  pear,
  melon,
}

/// The fruit drawings, in the order games use them.
const fruitIcons = [
  GameIcons.apple,
  GameIcons.banana,
  GameIcons.grapes,
  GameIcons.watermelon,
  GameIcons.strawberry,
  GameIcons.kiwi,
  GameIcons.cherry,
  GameIcons.mango,
  GameIcons.peach,
  GameIcons.pineapple,
  GameIcons.coconut,
  GameIcons.lemon,
  GameIcons.orange,
  GameIcons.pear,
  GameIcons.melon,
];

/// A drawn icon. [color] is used by stroke-style icons and "current colour" parts.
class GameIcon extends StatelessWidget {
  final GameIcons icon;
  final double size;
  final Color color;
  final String? semanticLabel;
  const GameIcon(this.icon,
      {super.key,
      this.size = 24,
      this.color = Colors.white,
      this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final art = CustomPaint(
        size: Size.square(size), painter: GameIconPainter(icon, color));
    if (semanticLabel == null) return ExcludeSemantics(child: art);
    return Semantics(label: semanticLabel, image: true, child: art);
  }
}

/// Paints one [GameIcons] icon scaled to the canvas size. Usable directly in game painters
/// through [paintIcon].
class GameIconPainter extends CustomPainter {
  final GameIcons icon;
  final Color color;
  const GameIconPainter(this.icon, this.color);

  @override
  void paint(Canvas canvas, Size size) =>
      paintIcon(canvas, icon, Offset.zero & size, color: color);

  @override
  bool shouldRepaint(GameIconPainter old) =>
      old.icon != icon || old.color != color;
}

/// Draws [icon] into [rect] on [canvas] (for game scenes that draw icons themselves).
void paintIcon(Canvas canvas, GameIcons icon, Rect rect,
    {Color color = Colors.white}) {
  final art = _Art.of(icon);
  final s = (rect.width < rect.height ? rect.width : rect.height) / art.box;
  canvas.save();
  canvas.translate(
      rect.center.dx - art.box * s / 2, rect.center.dy - art.box * s / 2);
  canvas.scale(s);
  for (final ink in art.inks) {
    ink.paint(canvas, color);
  }
  canvas.restore();
}

class _Art {
  final double box; // viewBox size
  final List<IconInk> inks;
  const _Art(this.box, this.inks);

  static final _cache = <GameIcons, _Art>{};
  static _Art of(GameIcons i) => _cache.putIfAbsent(i, () => _build(i));
}

// Small builders. `cs` = stroke in the icon colour, `cf` = fill in the icon colour.
IconInk _f(String d, Color c, {double o = 1}) =>
    IconInk(svgPath(d), fill: c, opacity: o);
IconInk _fp(Path p, Color c, {double o = 1}) => IconInk(p, fill: c, opacity: o);
IconInk _s(String d, Color c, double w, {double o = 1}) =>
    IconInk(svgPath(d), stroke: c, style: InkStroke(w), opacity: o);
IconInk _sp(Path p, Color c, double w, {double o = 1}) =>
    IconInk(p, stroke: c, style: InkStroke(w), opacity: o);
IconInk _cs(String d, [double w = 2]) =>
    IconInk(svgPath(d), strokeCurrent: true, style: InkStroke(w));
IconInk _csp(Path p, [double w = 2]) =>
    IconInk(p, strokeCurrent: true, style: InkStroke(w));
IconInk _cf(String d) => IconInk(svgPath(d), fillCurrent: true);
IconInk _cfp(Path p) => IconInk(p, fillCurrent: true);
IconInk _fs(Path p, Color fill, Color stroke, double w) =>
    IconInk(p, fill: fill, stroke: stroke, style: InkStroke(w));

const _ink = Color(0xFF1A1440);
const _white = Color(0xFFFFFFFF);
const _gold = Color(0xFFFFC93C);
const _goldDeep = Color(0xFFA87A12);
const _red = Color(0xFFE53935);
const _leaf = Color(0xFF43A047);
const _stem = Color(0xFF6D4C41);
const _wood = Color(0xFFD7A15A);
const _woodDark = Color(0xFF8A5A2B);
const _skin = Color(0xFFF2C29B);
const _skinEdge = Color(0xFFB9825A);

List<IconInk> _dice(List<(double, double)> pips) => [
      _fs(svgRect(2, 2, 20, 20, 4.5), _white, const Color(0xFFD9DEE6), 1),
      for (final (x, y) in pips) _fp(svgCircle(x, y, 2.1), _ink),
    ];

/// Shifts every ink by ([dx], [dy]) and scales by [k] (for icons made of smaller copies).
List<IconInk> _place(List<IconInk> inks, double dx, double dy, double k) {
  final m =
      Float64List.fromList([k, 0, 0, 0, 0, k, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1]);
  return [
    for (final i in inks)
      IconInk(i.path.transform(m),
          fill: i.fill,
          fillCurrent: i.fillCurrent,
          stroke: i.stroke,
          strokeCurrent: i.strokeCurrent,
          style: i.style == null ? null : InkStroke(i.style!.width * k),
          opacity: i.opacity),
  ];
}

List<IconInk> _rocket() => [
      _f('M12 2c4 3 5 8 4 13H8C7 10 8 5 12 2z', const Color(0xFFECEFF1)),
      _f('M8 13l-3.5 4.5H9zM16 13l3.5 4.5H15z', _red),
      _fp(svgCircle(12, 9, 2), const Color(0xFF2E8BFF)),
      _f('M10 15.5h4l-2 6z', const Color(0xFFFF9800)),
    ];

List<IconInk> _mole(Color fur, Color dark) => [
      _f('M4 22c0-9 3.5-15 8-15s8 6 8 15z', fur),
      _fp(svgEllipse(12, 15, 3.4, 2.5), const Color(0xFFF8BBD0)),
      _fp(svgCircle(12, 13.6, 1.2), dark),
      _fp(svgCircle(9.2, 11, 1.1), _ink),
      _fp(svgCircle(14.8, 11, 1.1), _ink),
      _f('M11 17h2v2h-2z', _white),
    ];

_Art _build(GameIcons i) {
  switch (i) {
    // ---------------------------------------------------------------- app and HUD
    case GameIcons.back:
      return _Art(24, [_cs('M15 5L8 12l7 7', 2.6)]);
    case GameIcons.forward:
      return _Art(24, [_cs('M9 5l7 7-7 7', 2.6)]);
    case GameIcons.chevronDown:
      return _Art(24, [_cs('M6 9l6 6 6-6', 2.6)]);
    case GameIcons.close:
    case GameIcons.cross:
      return _Art(24, [_cs('M6 6l12 12M18 6L6 18', 2.8)]);
    case GameIcons.pause:
      return _Art(24, [
        _cfp(svgRect(6, 4, 4.4, 16, 1.6)),
        _cfp(svgRect(13.6, 4, 4.4, 16, 1.6))
      ]);
    case GameIcons.play:
      return _Art(24, [_cf('M7 4l13 8-13 8z')]);
    case GameIcons.help:
      return _Art(24, [
        _csp(svgCircle(12, 12, 9.4)),
        _cs('M9.3 9.3a2.9 2.9 0 1 1 4 2.7c-.7.3-1.3 1-1.3 1.8v.5'),
        _cfp(svgCircle(12, 17.4, 0.9))
      ]);
    case GameIcons.restart:
      return _Art(22, [
        _cs('M3 11a8 8 0 0 1 14-5.3M19 3v4h-4', 2.4),
        _cs('M19 11a8 8 0 0 1-14 5.3M3 19v-4h4', 2.4)
      ]);
    case GameIcons.sound:
      return _Art(20, [
        _cs('M3 8h3l4-3v10l-4-3H3z', 1.8),
        _cs('M13 7a4 4 0 0 1 0 6M15.5 4.5a8 8 0 0 1 0 11', 1.8)
      ]);
    case GameIcons.vibration:
      return _Art(
          20, [_csp(svgRect(6, 2, 8, 16, 2), 1.8), _cs('M2 7v6M18 7v6', 1.8)]);
    case GameIcons.clock:
      return _Art(
          20, [_csp(svgCircle(10, 10, 7), 1.8), _cs('M10 6v4l3 2', 1.8)]);
    case GameIcons.globe:
      return _Art(24, [
        _csp(svgCircle(12, 12, 9)),
        _cs('M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18')
      ]);
    case GameIcons.wifi:
      return _Art(24, [
        _cs('M2 9a15 15 0 0 1 20 0M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0'),
        _cfp(svgCircle(12, 19.5, 1.3))
      ]);
    case GameIcons.trophy:
      return _Art(24, [
        _f('M7 4h10v5a5 5 0 0 1-10 0z', _gold),
        _s('M7 6H4a3 3 0 0 0 3 4M17 6h3a3 3 0 0 1-3 4', _gold, 2),
        _f('M11 13.6h2v4h-2z', _goldDeep),
        _fp(svgRect(7.5, 18, 9, 3.4, 1.2), _goldDeep),
        _f('M9 5.5h2v3.5a2 2 0 0 1-2-2z', _white, o: 0.45),
      ]);
    case GameIcons.copy:
      return _Art(16, [
        _csp(svgRect(5, 5, 9, 9, 2), 1.8),
        _cs('M11 5V3a1 1 0 0 0-1-1H3a1 1 0 0 0-1 1v7a1 1 0 0 0 1 1h2', 1.8)
      ]);
    case GameIcons.share:
      return _Art(16, [
        _csp(svgCircle(12, 3.5, 2), 1.8),
        _csp(svgCircle(4, 8, 2), 1.8),
        _csp(svgCircle(12, 12.5, 2), 1.8),
        _cs('M6 7l4-2.5M6 9l4 2.5', 1.8)
      ]);
    case GameIcons.search:
      return _Art(18, [_csp(svgCircle(8, 8, 5.5)), _cs('M12.5 12.5L16 16')]);
    case GameIcons.settings:
      return _Art(24, [
        _cs('M4 7h9M19 7h1M4 17h3M13 17h7'),
        _csp(svgCircle(16, 7, 2.4)),
        _csp(svgCircle(10, 17, 2.4))
      ]);
    case GameIcons.plus:
      return _Art(24, [_cs('M12 5v14M5 12h14', 2.8)]);
    case GameIcons.minus:
      return _Art(24, [_cs('M5 12h14', 2.8)]);
    case GameIcons.people:
      return _Art(24, [
        _csp(svgCircle(9, 8, 3.5)),
        _cs('M3 20a6 6 0 0 1 12 0'),
        _csp(svgCircle(17, 9, 2.5)),
        _cs('M15.5 14.4A5 5 0 0 1 21 19')
      ]);
    case GameIcons.check:
      return _Art(24, [_cs('M5 12.5l4.5 4.5L19 7', 3)]);
    case GameIcons.undo:
      return _Art(24,
          [_cs('M9 14L4 9l5-5', 2.4), _cs('M4 9h10a6 6 0 0 1 0 12h-3', 2.4)]);
    case GameIcons.skip:
      return _Art(24, [_cf('M5 5l9 7-9 7z'), _cfp(svgRect(16, 5, 3, 14, 1))]);
    case GameIcons.eye:
      return _Art(24, [
        _cs('M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z'),
        _cfp(svgCircle(12, 12, 3.2))
      ]);
    case GameIcons.lock:
      return _Art(24, [
        _cs('M8 11V8a4 4 0 0 1 8 0v3', 2.4),
        _cfp(svgRect(5, 11, 14, 10, 2.4))
      ]);
    case GameIcons.lightbulb:
      return _Art(24, [
        _f('M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2V16h5v-.1c0-.8.4-1.5 1-2A6 6 0 0 0 12 3z',
            _gold),
        _s('M9.5 18.5h5M10.5 21h3', const Color(0xFFB0BEC5), 2)
      ]);
    case GameIcons.flag:
      return _Art(
          24, [_s('M6 21V3.5', _stem, 2.2), _f('M6 4h12l-3 4 3 4H6z', _red)]);
    case GameIcons.star:
      return _Art(24, [
        _f('M12 2l3 6.5 7 .8-5.2 4.8 1.5 7L12 17.6 5.7 21l1.5-7L2 9.3l7-.8z',
            _gold),
        _f('M12 5.5l1.6 3.6 1.6.2-2.8.9z', _white, o: 0.5)
      ]);
    case GameIcons.heart:
      return _Art(24, [
        _f('M12 21s-8.5-5.4-8.5-11.3A4.6 4.6 0 0 1 12 7a4.6 4.6 0 0 1 8.5 2.7C20.5 15.6 12 21 12 21z',
            const Color(0xFFFF5E5B)),
        _fp(svgEllipse(8, 9.6, 1.6, 2.4), _white, o: 0.45)
      ]);
    case GameIcons.heartEmpty:
      return _Art(24, [
        _cs('M12 20s-7.7-5-7.7-10.4A4.3 4.3 0 0 1 12 7.2a4.3 4.3 0 0 1 7.7 2.4C19.7 15 12 20 12 20z',
            2.2)
      ]);
    case GameIcons.shield:
      return _Art(24, [
        _f('M12 2l8 3v6c0 5-3.5 9-8 11-4.5-2-8-6-8-11V5z',
            const Color(0xFF2E8BFF)),
        _s('M12 5l5 1.9V11c0 3.4-2.2 6.2-5 7.6', _white, 1.6, o: 0.7)
      ]);
    case GameIcons.crown:
      return _Art(18, [
        _f('M1 13L3 4l4 4 2-6 2 6 4-4 2 9z', _gold),
        _fp(svgRect(1.4, 13, 15.2, 2.6, 1), _goldDeep)
      ]);
    case GameIcons.crownKing:
      return _Art(24, [
        _f('M3 17L5 7l4.5 4.5L12 5l2.5 6.5L19 7l2 10z', _gold),
        _fp(svgRect(3.5, 17, 17, 3, 1.2), _goldDeep),
        _fp(svgCircle(5, 6.4, 1.5), _gold),
        _fp(svgCircle(12, 4.4, 1.5), _gold),
        _fp(svgCircle(19, 6.4, 1.5), _gold),
        _fp(svgCircle(12, 14, 1.7), _red),
      ]);
    case GameIcons.coin:
      return _Art(24, [
        _fp(svgCircle(12, 12, 9.5), _gold),
        _sp(svgCircle(12, 12, 6.6), _goldDeep, 1.6),
        _f('M12 7.8l1.3 2.8 3 .3-2.3 2 .7 3L12 14.4 9.3 16l.7-3-2.3-2 3-.3z',
            _goldDeep)
      ]);
    case GameIcons.target:
      return _Art(20, [
        _fp(svgCircle(10, 10, 9), const Color(0xFFF4F2EC)),
        _fp(svgCircle(10, 10, 7.2), const Color(0xFF222222)),
        _fp(svgCircle(10, 10, 5.5), const Color(0xFF1F7BD0)),
        _fp(svgCircle(10, 10, 3.8), const Color(0xFFE12A2F)),
        _fp(svgCircle(10, 10, 2), const Color(0xFFF7C51E)),
      ]);
    case GameIcons.wind:
      return _Art(20, [
        _cs('M2 7h10a2.5 2.5 0 1 0-2.5-2.5', 1.8),
        _cs('M2 11h13a2.5 2.5 0 1 1-2.5 2.5', 1.8),
        _cs('M2 15h6', 1.8)
      ]);
    case GameIcons.arrow:
      return _Art(24, [_cs('M20 4L8 16M8 16l-1 5-3-3 5-1z'), _cs('M14 4h6v6')]);
    case GameIcons.bow:
      return _Art(24, [
        _s('M7 2.5c8.5 4 8.5 15 0 19', const Color(0xFF7A5230), 2.6),
        _s('M7 2.5v19', const Color(0xFFEDE7DA), 1),
        _s('M3 12h15', const Color(0xFF3E2723), 1.6),
        _f('M21 12l-4-2.4v4.8z', const Color(0xFF90A4AE)),
        _f('M3 12l-1.5-2h2.5l1.5 2-1.5 2H1.5z', _red),
      ]);
    case GameIcons.home:
      return _Art(24, [
        _cs('M3 11l9-7 9 7'),
        _cs('M5.5 9.5V20h13V9.5'),
        _cs('M10 20v-5h4v5')
      ]);

    // ---------------------------------------------------------------- weapons and power-ups
    case GameIcons.rocket:
      return _Art(24, _rocket());
    case GameIcons.tripleRocket:
      return _Art(24, [
        ..._place(_rocket(), -3.5, 4, 0.62),
        ..._place(_rocket(), 16.5, 4, 0.62),
        ..._place(_rocket(), 6.5, -1, 0.62)
      ]);
    case GameIcons.mine:
      return _Art(24, [
        _s('M12 3.5v4M12 18.5v2.5M3.5 13h3M17.5 13h3M5.8 6.8l2.6 2.6M18.2 6.8l-2.6 2.6M5.8 19.2l2.6-2.6M18.2 19.2l-2.6-2.6',
            const Color(0xFF37474F), 2.2),
        _fp(svgCircle(12, 13, 6.4), const Color(0xFF37474F)),
        _fp(svgCircle(12, 13, 2.3), const Color(0xFFFF5E5B)),
        _fp(svgCircle(10, 11, 1.2), _white, o: 0.4),
      ]);
    case GameIcons.bolt:
      return _Art(24, [
        _f('M13.5 2L4 14h7l-1.5 8L20 10h-7z', _gold),
        _f('M12.4 4.5L7 11.6h3', _white, o: 0.4)
      ]);
    case GameIcons.gun:
      return _Art(24, [
        _f('M2.5 8.5h16l1.5-1.5h1.5v5h-6.5l-1 2.2h-3l-1 5.3H6l1.2-5.3H2.5z',
            const Color(0xFF455A64)),
        _f('M3.5 9.6h14v1.2h-14z', _white, o: 0.3)
      ]);
    case GameIcons.mysteryBox:
      return _Art(24, [
        _fs(svgRect(3, 4, 18, 17, 3.2), const Color(0xFFFFB300), _goldDeep,
            1.4),
        _s('M9.4 10.2a2.6 2.6 0 1 1 3.7 2.3c-.7.4-1.1 1-1.1 1.7v.7', _white,
            2.4),
        _fp(svgCircle(12, 17.6, 1.2), _white),
      ]);
    case GameIcons.bomb:
      return _Art(24, [
        _fp(svgCircle(11, 14, 7), const Color(0xFF263238)),
        _fp(svgEllipse(8.5, 11.5, 1.6, 2.4), _white, o: 0.35),
        _f('M14.6 7.3l2-2 2 2-2 2z', const Color(0xFF455A64)),
        _s('M17.5 6Q19 2.5 21.5 3.5', const Color(0xFF8D6E63), 1.6),
        _f('M21.5 1l.8 1.7 1.7.8-1.7.8-.8 1.7-.8-1.7-1.7-.8 1.7-.8z', _gold),
      ]);

    // ---------------------------------------------------------------- dice
    case GameIcons.dice1:
      return _Art(24, _dice([(12, 12)]));
    case GameIcons.dice2:
      return _Art(24, _dice([(7.5, 7.5), (16.5, 16.5)]));
    case GameIcons.dice3:
      return _Art(24, _dice([(7.5, 7.5), (12, 12), (16.5, 16.5)]));
    case GameIcons.dice4:
      return _Art(
          24, _dice([(7.5, 7.5), (16.5, 7.5), (7.5, 16.5), (16.5, 16.5)]));
    case GameIcons.dice5:
      return _Art(
          24,
          _dice(
              [(7.5, 7.5), (16.5, 7.5), (12, 12), (7.5, 16.5), (16.5, 16.5)]));
    case GameIcons.dice6:
      return _Art(
          24,
          _dice([
            (7.5, 7),
            (16.5, 7),
            (7.5, 12),
            (16.5, 12),
            (7.5, 17),
            (16.5, 17)
          ]));

    // ---------------------------------------------------------------- characters and things
    case GameIcons.duck:
      return _Art(24, [
        _f('M3 15c0-3 3-4.5 7-4.5h4c1.5-1 1.5-4.5 4.5-4.5s3.5 3 2 5c2 4-1 9-8.5 9C6 20 3 18 3 15z',
            const Color(0xFFFFD54F)),
        _f('M20.5 8.2l3 .8-3 1.2z', const Color(0xFFFF9800)),
        _fp(svgCircle(18.4, 8, 0.9), _ink),
        _f('M7 14q3 3 7 0', _white, o: 0.5),
      ]);
    case GameIcons.rabbit:
      return _Art(24, [
        _fp(svgEllipse(8.8, 6, 2, 5.2), const Color(0xFFE0E0E0)),
        _fp(svgEllipse(15.2, 6, 2, 5.2), const Color(0xFFE0E0E0)),
        _fp(svgEllipse(8.8, 6.4, 0.9, 3.6), const Color(0xFFF8BBD0)),
        _fp(svgEllipse(15.2, 6.4, 0.9, 3.6), const Color(0xFFF8BBD0)),
        _fp(svgCircle(12, 15, 7), const Color(0xFFF5F5F5)),
        _fp(svgCircle(9.4, 14, 1.1), _ink),
        _fp(svgCircle(14.6, 14, 1.1), _ink),
        _fp(svgEllipse(12, 16.6, 1.3, 1), const Color(0xFFF48FB1)),
      ]);
    case GameIcons.mole:
      return _Art(24, _mole(const Color(0xFF8D6E63), const Color(0xFF4E342E)));
    case GameIcons.goldenMole:
      return _Art(24, [
        ..._mole(_gold, _goldDeep),
        _f('M20 2l.8 1.8 1.8.8-1.8.8L20 7.2l-.8-1.8-1.8-.8 1.8-.8z', _white)
      ]);
    case GameIcons.alien:
      return _Art(24, [
        _f('M5 9a7 7 0 0 1 14 0v5H5z', const Color(0xFF66BB6A)),
        _s('M7 14l-2 5M10 14l-1 5M14 14l1 5M17 14l2 5', const Color(0xFF388E3C),
            2),
        _s('M8 3.5L9.5 6M16 3.5L14.5 6', const Color(0xFF388E3C), 1.6),
        _fp(svgEllipse(9.3, 9.5, 1.6, 2.1), _ink),
        _fp(svgEllipse(14.7, 9.5, 1.6, 2.1), _ink),
      ]);
    case GameIcons.ufo:
      return _Art(24, [
        _fp(svgEllipse(12, 10, 5, 4.4), const Color(0xFF90CAF9)),
        _fp(svgEllipse(12, 14, 10, 3.6), const Color(0xFFB0BEC5)),
        _fp(svgEllipse(12, 13, 10, 2), const Color(0xFFCFD8DC)),
        for (final x in [6.0, 12.0, 18.0]) _fp(svgCircle(x, 14.4, 1), _gold),
        _fp(svgEllipse(10.4, 8.6, 1.2, 1.6), _white, o: 0.6),
      ]);
    case GameIcons.tank:
      return _Art(24, [
        _fp(svgRect(2, 15, 20, 5, 2.5), const Color(0xFF37474F)),
        for (final x in [5.0, 9.5, 14.5, 19.0])
          _fp(svgCircle(x, 17.5, 1.3), const Color(0xFF90A4AE)),
        _fp(svgRect(4, 11, 16, 4.5, 1.5), const Color(0xFF6D8B3A)),
        _fp(svgRect(8, 7.5, 8, 4.5, 2), const Color(0xFF7FA046)),
        _fp(svgRect(15, 8.6, 8, 2, 1), const Color(0xFF55702C)),
      ]);
    case GameIcons.cactus:
      return _Art(24, [
        _f('M10 22V5a2 2 0 0 1 4 0v17z', _leaf),
        _f('M10 14H7a2 2 0 0 1-2-2V8.5a1.5 1.5 0 0 1 3 0V11h2zM14 12h3V7.5a1.5 1.5 0 0 1 3 0V12a3 3 0 0 1-3 3h-3z',
            _leaf),
        _s('M12 5v16', const Color(0xFF2E7D32), 1),
        _fp(svgRect(6, 21, 12, 2, 1), const Color(0xFFD7B57A)),
      ]);
    case GameIcons.bird:
      return _Art(24, [
        IconInk(svgCircle(12, 13, 8.5), fillCurrent: true),
        _fp(svgEllipse(12, 17, 5, 3.6), const Color(0xFFFFE0B2)),
        _fp(svgCircle(9.4, 11.4, 2.1), _white),
        _fp(svgCircle(14.6, 11.4, 2.1), _white),
        _fp(svgCircle(9.9, 11.7, 1), _ink),
        _fp(svgCircle(15.1, 11.7, 1), _ink),
        _s('M6.8 8.3l4 1.8M17.2 8.3l-4 1.8', _ink, 1.4),
        _f('M10.6 13.4h2.8L12 15.8z', const Color(0xFFFFA000)),
      ]);
    case GameIcons.pig:
      return _Art(24, [
        _fp(svgCircle(6.5, 6.5, 2.4), const Color(0xFF7CB342)),
        _fp(svgCircle(17.5, 6.5, 2.4), const Color(0xFF7CB342)),
        _fp(svgCircle(12, 13, 9), const Color(0xFF8BC34A)),
        _fp(svgEllipse(12, 15, 3.6, 2.6), const Color(0xFFAED581)),
        _fp(svgCircle(10.6, 15, 0.9), const Color(0xFF33691E)),
        _fp(svgCircle(13.4, 15, 0.9), const Color(0xFF33691E)),
        _fp(svgCircle(8.4, 10.5, 1.5), _white),
        _fp(svgCircle(15.6, 10.5, 1.5), _white),
        _fp(svgCircle(8.6, 10.7, 0.7), _ink),
        _fp(svgCircle(15.4, 10.7, 0.7), _ink),
      ]);
    case GameIcons.ladder:
      return _Art(24, [
        _s('M7 2v20M17 2v20', _woodDark, 2.4),
        _s('M7 6h10M7 10.5h10M7 15h10M7 19.5h10', _wood, 2)
      ]);
    case GameIcons.snake:
      return _Art(24, [
        _s('M4 20c4 0 4-5 8-5s4 5 8 5M12 15c-4 0-6-3-4-6s6-2 8-5',
            const Color(0xFF43A047), 3.4),
        _fp(svgEllipse(16.8, 3.8, 2.6, 2), const Color(0xFF2E7D32)),
        _fp(svgCircle(17.6, 3.3, 0.6), _white),
        _s('M19.3 4.4l2 .8', _red, 1),
      ]);
    case GameIcons.rock:
      return _Art(24, [
        _fs(
            svgPath(
                'M5 11a3 3 0 0 1 3-3h8a4 4 0 0 1 4 4v3a6 6 0 0 1-6 6h-3a6 6 0 0 1-6-6z'),
            _skin,
            _skinEdge,
            1.4),
        _s('M9 8v3.5M12.5 8v3.5M16 8.3v3.5', _skinEdge, 1.2),
        _f('M5 13.5a2.5 2.5 0 0 1 5 0v1H5z', _skin),
      ]);
    case GameIcons.paper:
      return _Art(24, [
        _fs(
            svgPath(
                'M6 22V10a1.5 1.5 0 0 1 3 0V4a1.5 1.5 0 0 1 3 0v-1a1.5 1.5 0 0 1 3 0v1.5a1.5 1.5 0 0 1 3 0V13l1.6-2.2a1.5 1.5 0 0 1 2.4 1.8L18 19a6 6 0 0 1-5 3z'),
            _skin,
            _skinEdge,
            1.3),
        _s('M9 10v5M12 4v10M15 3.5V14M18 6v8', _skinEdge, 1),
      ]);
    case GameIcons.scissors:
      return _Art(24, [
        _fs(
            svgPath(
                'M8 22l-1-8V4.5a1.5 1.5 0 0 1 3 0V12l2.5-8.5a1.5 1.5 0 0 1 2.9.9L13 13l3.5-.5a2.5 2.5 0 0 1 2.5 2.5v1a6 6 0 0 1-6 6z'),
            _skin,
            _skinEdge,
            1.3),
      ]);
    case GameIcons.bat:
      return _Art(24, [
        _fp(svgRotate(svgRect(10, 2, 4.4, 14, 1.6), 35, 12, 12),
            const Color(0xFFE6C08A)),
        _sp(svgRotate(svgLine(12.2, 15, 12.2, 22), 35, 12, 12),
            const Color(0xFF5D4037), 2.6)
      ]);
    case GameIcons.ball:
      return _Art(24, [
        _fp(svgCircle(12, 12, 9), const Color(0xFFFF8F00)),
        _s('M3.4 10.5Q12 13 20.6 10.5M12 3c-3 4-3 14 0 18',
            const Color(0xFF5D2E00), 1.3)
      ]);
    case GameIcons.cricketBall:
      return _Art(24, [
        _fp(svgCircle(12, 12, 9), const Color(0xFFC62828)),
        _s('M6 6.5q6 5.5 12 11', _white, 1.2),
        _s('M7.4 5.6q6 5.5 11.6 10.4', _white, 0.6, o: 0.8),
        _fp(svgEllipse(9, 8.6, 1.6, 2.3), _white, o: 0.3)
      ]);
    case GameIcons.puck:
      return _Art(24, [
        _fp(svgEllipse(12, 14, 9, 4), const Color(0xFF15181F)),
        _fp(svgEllipse(12, 12, 9, 4), const Color(0xFF3A3F4B)),
        _sp(svgEllipse(12, 12, 6, 2.4), _white, 1, o: 0.3)
      ]);
    case GameIcons.mallet:
      return _Art(24, [
        IconInk(svgCircle(12, 14, 9), fillCurrent: true),
        _fp(svgCircle(12, 14, 9), _ink, o: 0.2),
        IconInk(svgCircle(12, 11.5, 4.6), fillCurrent: true),
        _fp(svgCircle(10.8, 10, 1.8), _white, o: 0.5)
      ]);
    case GameIcons.football:
      return _Art(24, [
        _fs(svgCircle(12, 12, 9.4), _white, const Color(0xFF263238), 1.2),
        _fp(svgPolygon([12, 8.2, 15.4, 10.6, 14.1, 14.6, 9.9, 14.6, 8.6, 10.6]),
            const Color(0xFF263238)),
        _s('M12 8.2V3M15.4 10.6l4.6-1.7M14.1 14.6l3 4M9.9 14.6l-3 4M8.6 10.6L4 8.9',
            const Color(0xFF263238), 1.2),
      ]);
    case GameIcons.glove:
      return _Art(24, [
        _fs(
            svgPath(
                'M7 22v-4L4.6 13a1.6 1.6 0 0 1 2.8-1.5L9 14V5a1.5 1.5 0 0 1 3 0V3.8a1.5 1.5 0 0 1 3 0V5a1.5 1.5 0 0 1 3 0v1a1.5 1.5 0 0 1 3 0v8a8 8 0 0 1-4 7v1z'),
            const Color(0xFF26A69A),
            const Color(0xFF00695C),
            1.3),
        _fp(svgRect(6.5, 19.5, 11, 3, 1), const Color(0xFF00695C)),
      ]);
    case GameIcons.bottle:
      return _Art(24, [
        _f('M10 2h4v4l2.4 3.4V21a1.5 1.5 0 0 1-1.5 1.5H9.1A1.5 1.5 0 0 1 7.6 21V9.4L10 6z',
            const Color(0xFF2E9E47)),
        _fp(svgRect(7.6, 12.5, 8.8, 5, 0.6), const Color(0xFFF5E9D2)),
        _fp(svgRect(9.6, 1.5, 4.8, 2, 0.8), _gold),
        _f('M9 10.5h1.2v9H9z', _white, o: 0.4),
      ]);
    case GameIcons.woodBlock:
      return _Art(24, [
        _fs(svgRect(2.5, 4, 19, 16, 2), _wood, _woodDark, 1.4),
        _s('M5 9h14M5 14.5h9M15.5 14.5H19', _woodDark, 1, o: 0.6)
      ]);
    case GameIcons.stoneBlock:
      return _Art(24, [
        _fs(svgRect(2.5, 4, 19, 16, 2), const Color(0xFF9E9E9E),
            const Color(0xFF616161), 1.4),
        _s('M9 4l2 5-3 4 2 7M15 13l4 2', const Color(0xFF616161), 1.2)
      ]);
    case GameIcons.paintBrush:
      return _Art(24, [
        _s('M15 4l5 5', const Color(0xFF8D6E63), 3),
        _f('M13.5 5.5l5 5-6 6-5-5z', const Color(0xFFB0BEC5)),
        IconInk(svgPath('M7.5 11.5l5 5c-1.5 3-4 5-8.5 5 .4-4.4 2-7.6 3.5-10z'),
            fillCurrent: true)
      ]);
    case GameIcons.pencil:
      return _Art(24, [
        _f('M4 20l1.2-5L16 4.2 19.8 8 9 18.8z', _gold),
        _f('M4 20l1.2-5 3.8 3.8z', const Color(0xFFF2D49B)),
        _f('M3.6 21.2l.8-3 2.2 2.2z', _ink),
        _f('M16 4.2l1.6-1.6a1.4 1.4 0 0 1 2 0l1.8 1.8a1.4 1.4 0 0 1 0 2L19.8 8z',
            const Color(0xFFF48FB1))
      ]);
    case GameIcons.magnifier:
      return _Art(24, [
        _fs(svgCircle(10, 10, 6.4), const Color(0x339CC9FF),
            const Color(0xFF90A4AE), 2.6),
        _s('M14.8 14.8L21 21', const Color(0xFF5D4037), 3.2)
      ]);
    case GameIcons.mask:
      return _Art(24, [
        _f('M2 9c3-2 7-2 10 0 3-2 7-2 10 0 0 5-3 8-6 8-2 0-3-2-4-2s-2 2-4 2c-3 0-6-3-6-8z',
            const Color(0xFF263238)),
        _fp(svgEllipse(7.4, 11.6, 2.2, 1.4), _white),
        _fp(svgEllipse(16.6, 11.6, 2.2, 1.4), _white)
      ]);
    case GameIcons.scroll:
      return _Art(24, [
        _fs(svgRect(5, 4, 14, 16, 2), const Color(0xFFF5E9D2),
            const Color(0xFFB08A50), 1.3),
        _fp(svgRect(3, 3, 18, 3, 1.5), const Color(0xFFD8B169)),
        _fp(svgRect(3, 18, 18, 3, 1.5), const Color(0xFFD8B169)),
        _s('M8 9.5h8M8 12.5h8M8 15.5h5', const Color(0xFF8A6A3A), 1.2)
      ]);
    case GameIcons.moon:
      return _Art(24, [
        _f('M15 3a9 9 0 1 0 6 15.5A8 8 0 0 1 15 3z', const Color(0xFFFFF3C4))
      ]);
    case GameIcons.sun:
      return _Art(24, [
        _fp(svgCircle(12, 12, 5), _gold),
        _s('M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9L7 7M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1',
            _gold, 2)
      ]);
    case GameIcons.medical:
      return _Art(24, [
        _fp(svgRect(2.5, 2.5, 19, 19, 5), _white),
        _f('M10 6h4v4h4v4h-4v4h-4v-4H6v-4h4z', _red)
      ]);
    case GameIcons.clapper:
      return _Art(24, [
        _fp(svgRect(3, 9, 18, 12, 1.6), const Color(0xFF263238)),
        _f('M3 5.5l17-3 .8 4-17 3z', const Color(0xFF263238)),
        _s('M6.5 4.8l1.6 3.6M11 4l1.6 3.6M15.5 3.2l1.6 3.6', _white, 1.6),
        _s('M6 13h12M6 16.5h8', _white, 1.4, o: 0.6)
      ]);
    case GameIcons.speech:
      return _Art(24, [_cs('M4 5h16v11H11l-5 4v-4H4z', 2.2)]);
    case GameIcons.hammer:
      return _Art(24, [
        _s('M14 10l7 7', const Color(0xFF8D6E63), 3),
        _fp(svgRotate(svgRect(3, 4, 12, 7, 1.6), 45, 9, 7.5),
            const Color(0xFF78909C))
      ]);
    case GameIcons.arrowLeft:
      return _Art(24, [_cf('M16 4L6 12l10 8z')]);
    case GameIcons.arrowRight:
      return _Art(24, [_cf('M8 4l10 8-10 8z')]);
    case GameIcons.arrowUp:
      return _Art(24, [_cf('M4 16l8-10 8 10z')]);
    case GameIcons.arrowDown:
      return _Art(24, [_cf('M4 8l8 10 8-10z')]);
    case GameIcons.rotate:
      return _Art(
          24, [_cs('M20 12a8 8 0 1 1-2.6-5.9', 2.6), _cf('M20.5 3v6.5H14z')]);
    case GameIcons.drop:
      return _Art(24, [
        _cs('M12 3v12', 2.6),
        _cf('M6 12h12l-6 7z'),
        _cfp(svgRect(5, 20, 14, 2, 1))
      ]);

    // ---------------------------------------------------------------- fruit (40-unit, from the Memory mockup)
    case GameIcons.apple:
      return _Art(40, [
        _f('M20 12 C14 8 6 11 7 21 C8 31 14 36 20 33 C26 36 32 31 33 21 C34 11 26 8 20 12Z',
            const Color(0xFFE53935)),
        _fp(svgEllipse(13, 18, 3, 5), _white, o: 0.35),
        _s('M20 12 Q21 7 23 5', _stem, 2),
        _f('M22 8 Q28 4 31 8 Q26 11 22 8Z', _leaf),
      ]);
    case GameIcons.banana:
      return _Art(40, [
        IconInk(
            svgPath('M8 12 Q10 30 30 32 Q34 31 33 28 Q16 26 13 10 Q11 8 8 12Z'),
            fill: const Color(0xFFFFD54F),
            stroke: const Color(0xFFC99A00),
            style: const InkStroke(1.2)),
        _s('M11 13 Q14 26 28 29', const Color(0xFFFFF3B0), 1.5),
        _s('M8 12 L6 9', _stem, 2.5),
        _fp(svgCircle(32, 30, 1.5), _stem),
      ]);
    case GameIcons.grapes:
      return _Art(40, [
        _s('M20 12 L20 6', _stem, 2),
        _f('M20 9 Q27 4 30 9 Q25 12 20 9Z', const Color(0xFF66BB6A)),
        for (final (x, y) in const [
          (15.5, 16.0),
          (24.5, 16.0),
          (11.5, 22.0),
          (20.0, 22.0),
          (28.5, 22.0),
          (15.5, 28.0),
          (24.5, 28.0),
          (20.0, 34.0)
        ])
          _fp(svgCircle(x, y, 4.6), const Color(0xFF7E57C2)),
        for (final (x, y) in const [
          (14.0, 14.5),
          (18.5, 20.5),
          (23.0, 26.5),
          (27.0, 20.5)
        ])
          _fp(svgCircle(x, y, 1.3), _white, o: 0.45),
      ]);
    case GameIcons.watermelon:
      return _Art(40, [
        _f('M5 16 A15 15 0 0 0 35 16 Z', const Color(0xFF43A047)),
        _f('M7.5 16 A12.5 12.5 0 0 0 32.5 16 Z', const Color(0xFFF1F8E9)),
        _f('M9 16 A11 11 0 0 0 31 16 Z', const Color(0xFFEF5350)),
        for (final (x, y) in const [
          (14.0, 20.0),
          (20.0, 23.0),
          (26.0, 20.0),
          (17.0, 26.0),
          (23.0, 26.0)
        ])
          _fp(svgEllipse(x, y, 1, 1.8), const Color(0xFF263238)),
      ]);
    case GameIcons.strawberry:
      return _Art(40, [
        _f('M20 35 C10 28 7 20 10 15 C13 11 27 11 30 15 C33 20 30 28 20 35Z',
            const Color(0xFFE53935)),
        for (final (x, y) in const [
          (15.0, 19.0),
          (20.0, 18.0),
          (25.0, 19.0),
          (17.0, 24.0),
          (23.0, 24.0),
          (20.0, 29.0)
        ])
          _fp(svgEllipse(x, y, 0.8, 1.3), const Color(0xFFFFE082)),
        _f('M12 14 L15 8 L18 12 L20 7 L22 12 L25 8 L28 14 Q20 17 12 14Z',
            _leaf),
      ]);
    case GameIcons.kiwi:
      return _Art(40, [
        _fp(svgCircle(20, 20, 14), const Color(0xFF8D6E63)),
        _fp(svgCircle(20, 20, 12), const Color(0xFF8BC34A)),
        _fp(svgCircle(20, 20, 8), const Color(0xFFAED581)),
        _fp(svgEllipse(20, 20, 4, 3), const Color(0xFFF1F8E9)),
        for (final (x, y) in const [
          (20.0, 13.5),
          (24.6, 15.4),
          (26.5, 20.0),
          (24.6, 24.6),
          (20.0, 26.5),
          (15.4, 24.6),
          (13.5, 20.0),
          (15.4, 15.4)
        ])
          _fp(svgCircle(x, y, 0.9), const Color(0xFF212121)),
      ]);
    case GameIcons.cherry:
      return _Art(40, [
        _s('M13 27 Q17 14 26 7 M27 27 Q27 15 26 7', _stem, 2),
        _f('M26 7 Q32 3 34 8 Q29 10 26 7Z', _leaf),
        _fp(svgCircle(13, 29, 6), const Color(0xFFC62828)),
        _fp(svgCircle(27, 29, 6), const Color(0xFFD32F2F)),
        _fp(svgCircle(11, 27, 1.6), _white, o: 0.5),
        _fp(svgCircle(25, 27, 1.6), _white, o: 0.5),
      ]);
    case GameIcons.mango:
      return _Art(40, [
        _f('M12 30 C6 22 10 10 20 8 C30 7 34 16 30 26 C27 33 17 35 12 30Z',
            const Color(0xFFFFB300)),
        _fp(svgEllipse(25, 15, 6, 5), const Color(0xFFFB8C00), o: 0.6),
        _fp(svgEllipse(14, 22, 2.5, 5), _white, o: 0.3),
        _f('M20 8 Q24 3 30 5 Q26 9 20 8Z', _leaf),
      ]);
    case GameIcons.peach:
      return _Art(40, [
        _fp(svgCircle(20, 22, 12), const Color(0xFFFFAB91)),
        _fp(svgCircle(24, 25, 8), const Color(0xFFFF7043), o: 0.5),
        _s('M20 11 Q15 21 20 34', const Color(0xFFE64A19), 1.2, o: 0.45),
        _f('M20 10 Q26 4 31 8 Q26 12 20 10Z', _leaf),
      ]);
    case GameIcons.pineapple:
      final body = svgEllipse(20, 25, 9, 12);
      return _Art(40, [
        _f('M20 14 L14 4 L18 9 L20 2 L22 9 L26 4 Z', _leaf),
        _fp(body, const Color(0xFFFFC107)),
        IconInk(
            svgPath(
                'M8 14L32 38M8 22L24 38M16 13L32 29M32 14L8 38M32 22L16 38M24 13L8 29'),
            stroke: const Color(0xFFD68A00),
            style: const InkStroke(1.1),
            clip: body),
      ]);
    case GameIcons.coconut:
      return _Art(40, [
        _fp(svgCircle(20, 20, 14), const Color(0xFF6D4C41)),
        _fp(svgCircle(20, 20, 11), const Color(0xFFFAFAFA)),
        _fp(svgCircle(20, 20, 7), const Color(0xFFECEFF1)),
        _s('M9 14 Q11 10 14 9', const Color(0xFF8D6E63), 1.2),
      ]);
    case GameIcons.lemon:
      return _Art(40, [
        IconInk(
            svgPath('M6 20 Q8 10 20 10 Q32 10 34 20 Q32 30 20 30 Q8 30 6 20Z'),
            fill: const Color(0xFFFFEB3B),
            stroke: const Color(0xFFF9A825),
            style: const InkStroke(1.2)),
        _fp(svgEllipse(14, 16, 4, 2), _white, o: 0.5),
        _f('M20 10 Q24 5 29 7 Q25 11 20 10Z', _leaf),
      ]);
    case GameIcons.orange:
      return _Art(40, [
        _fp(svgCircle(20, 22, 13), const Color(0xFFFB8C00)),
        _fp(svgCircle(24, 25, 8), const Color(0xFFEF6C00), o: 0.45),
        for (final (x, y) in const [
          (14.0, 20.0),
          (18.0, 27.0),
          (25.0, 18.0),
          (27.0, 28.0)
        ])
          _fp(svgCircle(x, y, 0.7), const Color(0xFFE65100), o: 0.6),
        _fp(svgEllipse(14, 17, 3, 4.5), _white, o: 0.35),
        _s('M20 9.5 Q20.5 7.5 21 6.5', _stem, 2),
        _f('M21 8 Q27 4 30 8 Q25 11 21 8Z', _leaf),
      ]);
    case GameIcons.pear:
      return _Art(40, [
        _f('M20 9 C16 9 15 13 15 16 C15 19 9 22 9 28 C9 34 14 37 20 37 C26 37 31 34 31 28 C31 22 25 19 25 16 C25 13 24 9 20 9Z',
            const Color(0xFFC0CA33)),
        _fp(svgEllipse(25, 29, 5, 6), const Color(0xFF9E9D24), o: 0.4),
        _fp(svgEllipse(14.5, 26, 2.5, 5), _white, o: 0.3),
        _s('M20 9 Q20.5 6 22 4', _stem, 2),
        _f('M21.5 6 Q27 2 30 6 Q25 9 21.5 6Z', _leaf),
      ]);
    case GameIcons.melon:
      return _Art(40, [
        _fp(svgEllipse(20, 22, 15, 12), const Color(0xFF9CCC65)),
        _s('M8 17 Q20 22 32 17M7 24 Q20 29 33 24M10 30 Q20 34 30 30',
            const Color(0xFFF1F8E9), 1.3,
            o: 0.8),
        _s('M14 11 Q12 22 14 33M26 11 Q28 22 26 33', const Color(0xFFF1F8E9),
            1.1,
            o: 0.6),
        _fp(svgEllipse(13, 17, 3, 2), _white, o: 0.4),
        _s('M20 10 Q20.5 7 22 5.5', _stem, 2),
      ]);
  }
}

/// Paints [icon] to an image-free picture once and reuses it (for icons drawn every frame).
ui.Picture iconPicture(GameIcons icon, double size,
    {Color color = Colors.white}) {
  final rec = ui.PictureRecorder();
  paintIcon(Canvas(rec), icon, Rect.fromLTWH(0, 0, size, size), color: color);
  return rec.endRecording();
}
