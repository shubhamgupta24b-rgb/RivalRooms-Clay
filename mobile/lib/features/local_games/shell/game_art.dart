import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import '../../../core/ui/materials/materials.dart';

/// Each game's drawn icon (no emoji in game UI). Used by the intro header, How to play,
/// results, the hub tiles, rooms and records.
const gameIcons = <String, GameIcons>{
  'air_hockey': GameIcons.puck,
  'archery': GameIcons.target,
  'ball_sort': GameIcons.bottle,
  'basketball_hoops': GameIcons.ball,
  'battleship': GameIcons.bomb,
  'bingo': GameIcons.star,
  'block_drop': GameIcons.stoneBlock,
  'bottle_smash': GameIcons.bottle,
  'brick_breaker': GameIcons.woodBlock,
  'bubble_shooter': GameIcons.drop,
  'charades': GameIcons.clapper,
  'checkers': GameIcons.crownKing,
  'classic_snake': GameIcons.snake,
  'color_switch': GameIcons.paintBrush,
  'colour_clash': GameIcons.mysteryBox,
  'connect_four': GameIcons.coin,
  'crush_it': GameIcons.hammer,
  'dino_run': GameIcons.cactus,
  'dots_boxes': GameIcons.pencil,
  'draw_guess': GameIcons.paintBrush,
  'find_spy': GameIcons.eye,
  'flappy_jump': GameIcons.bird,
  'fruit_duel': GameIcons.watermelon,
  'fruit_merge': GameIcons.pineapple,
  'fruit_merge_battle': GameIcons.strawberry,
  'game_2048': GameIcons.stoneBlock,
  'guess_person': GameIcons.magnifier,
  'guess_who': GameIcons.magnifier,
  'hand_cricket': GameIcons.bat,
  'hangman': GameIcons.pencil,
  'heads_up': GameIcons.speech,
  'ludo': GameIcons.dice5,
  'mafia': GameIcons.moon,
  'math_duel': GameIcons.plus,
  'memory': GameIcons.cherry,
  'minesweeper': GameIcons.mine,
  'mini_golf': GameIcons.flag,
  'most_likely': GameIcons.people,
  'paint_fight': GameIcons.paintBrush,
  'penalty': GameIcons.football,
  'piano_tiles': GameIcons.sound,
  'ping_pong': GameIcons.mallet,
  'quiz_battle': GameIcons.lightbulb,
  'raja_mantri': GameIcons.crown,
  'reaction_tap': GameIcons.bolt,
  'rock_paper_scissors': GameIcons.rock,
  'shooting_gallery': GameIcons.duck,
  'simon_says': GameIcons.sound,
  'sky_jumper': GameIcons.arrowUp,
  'sliding_puzzle': GameIcons.woodBlock,
  'slingshot': GameIcons.pig,
  'smash_karts': GameIcons.rocket,
  'snake_duel': GameIcons.snake,
  'snakes_ladders': GameIcons.ladder,
  'space_shooter': GameIcons.ufo,
  'stack_tower': GameIcons.woodBlock,
  'sudoku': GameIcons.pencil,
  'tic_tac_toe': GameIcons.cross,
  'truth_dare': GameIcons.bottle,
  'undercover': GameIcons.mask,
  'whack_mole': GameIcons.mole,
  'word_scramble': GameIcons.scroll,
  'would_rather': GameIcons.help,
};

/// The icon for a game id (team versions use their base game's icon).
GameIcons gameIconFor(String id) {
  if (gameIcons[id] case final i?) return i;
  for (final e in gameIcons.entries) {
    if (id.startsWith(e.key)) return e.value;
  }
  return GameIcons.star;
}

/// The surface a game is played on, used as its art background.
enum ArtGround { felt, wood, paper, day, sunset, night, grass, court, ice, water, track }

const _grounds = <String, ArtGround>{
  'colour_clash': ArtGround.felt,
  'memory': ArtGround.felt,
  'bingo': ArtGround.felt,
  'raja_mantri': ArtGround.felt,
  'guess_person': ArtGround.felt,
  'guess_who': ArtGround.felt,
  'fruit_duel': ArtGround.felt,
  'fruit_merge': ArtGround.wood,
  'fruit_merge_battle': ArtGround.wood,
  'ludo': ArtGround.wood,
  'snakes_ladders': ArtGround.wood,
  'checkers': ArtGround.wood,
  'connect_four': ArtGround.wood,
  'dots_boxes': ArtGround.paper,
  'tic_tac_toe': ArtGround.paper,
  'sudoku': ArtGround.paper,
  'sliding_puzzle': ArtGround.wood,
  'game_2048': ArtGround.wood,
  'hangman': ArtGround.paper,
  'word_scramble': ArtGround.paper,
  'ball_sort': ArtGround.wood,
  'charades': ArtGround.paper,
  'draw_guess': ArtGround.paper,
  'heads_up': ArtGround.paper,
  'quiz_battle': ArtGround.paper,
  'most_likely': ArtGround.paper,
  'would_rather': ArtGround.paper,
  'truth_dare': ArtGround.felt,
  'math_duel': ArtGround.paper,
  'rock_paper_scissors': ArtGround.paper,
  'find_spy': ArtGround.night,
  'undercover': ArtGround.night,
  'mafia': ArtGround.night,
  'archery': ArtGround.day,
  'slingshot': ArtGround.day,
  'flappy_jump': ArtGround.day,
  'sky_jumper': ArtGround.day,
  'bottle_smash': ArtGround.sunset,
  'shooting_gallery': ArtGround.sunset,
  'dino_run': ArtGround.day,
  'stack_tower': ArtGround.day,
  'smash_karts': ArtGround.track,
  'space_shooter': ArtGround.night,
  'simon_says': ArtGround.night,
  'piano_tiles': ArtGround.night,
  'reaction_tap': ArtGround.night,
  'color_switch': ArtGround.night,
  'bubble_shooter': ArtGround.night,
  'brick_breaker': ArtGround.night,
  'block_drop': ArtGround.night,
  'classic_snake': ArtGround.grass,
  'snake_duel': ArtGround.grass,
  'penalty': ArtGround.grass,
  'mini_golf': ArtGround.grass,
  'hand_cricket': ArtGround.grass,
  'whack_mole': ArtGround.grass,
  'minesweeper': ArtGround.grass,
  'crush_it': ArtGround.court,
  'ping_pong': ArtGround.court,
  'basketball_hoops': ArtGround.court,
  'paint_fight': ArtGround.court,
  'air_hockey': ArtGround.ice,
  'battleship': ArtGround.water,
};

ArtGround groundFor(String id) {
  if (_grounds[id] case final g?) return g;
  for (final e in _grounds.entries) {
    if (id.startsWith(e.key)) return e.value;
  }
  return ArtGround.night;
}

/// A painted scene for a game's header. Games register theirs in [gameScenes] as they are
/// redesigned; the rest get [GameArtPainter]: their ground, a glow in the game colour and
/// their icon.
typedef ScenePainterBuilder = CustomPainter Function(Color color);
final gameScenes = <String, ScenePainterBuilder>{};

/// A game's small picture (hub tiles, rooms, records, intro): the surface it's played on,
/// a soft glow in the game colour and its drawn icon, simple but different per game.
class GameArtPainter extends CustomPainter {
  final String id;
  final Color color;
  final double iconScale;
  const GameArtPainter(this.id, this.color, {this.iconScale = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.save();
    canvas.clipRect(r);
    final ground = groundFor(id);
    switch (ground) {
      case ArtGround.felt:
        const FeltPainter(rim: false, radius: 0).paint(canvas, size);
      case ArtGround.wood:
        const WoodPainter(radius: 0).paint(canvas, size);
      case ArtGround.paper:
        const FeltPainter(rim: false, radius: 0).paint(canvas, size);
      case ArtGround.day:
        SkyPainter(hills: true, horizon: 0.74, sun: id != 'stack_tower').paint(canvas, size);
      case ArtGround.sunset:
        const SkyPainter(time: SkyTime.sunset, hills: true, horizon: 0.74).paint(canvas, size);
      case ArtGround.night:
        _night(canvas, size);
      case ArtGround.grass:
        const GrassPainter(stripes: 6).paint(canvas, size);
      case ArtGround.court:
        const CourtPainter(planks: 7).paint(canvas, size);
      case ArtGround.ice:
        _ice(canvas, size);
      case ArtGround.water:
        const WaterPainter(radius: 0).paint(canvas, size);
      case ArtGround.track:
        const SkyPainter(time: SkyTime.sunset, horizon: 0.55, clouds: false).paint(canvas, size);
        canvas.save();
        canvas.clipPath(Path()
          ..moveTo(size.width * 0.2, size.height * 0.6)
          ..lineTo(size.width * 0.8, size.height * 0.6)
          ..lineTo(size.width * 1.15, size.height)
          ..lineTo(-size.width * 0.15, size.height)
          ..close());
        const AsphaltPainter().paint(canvas, size);
        canvas.restore();
    }
    // A glow in the game colour behind the icon.
    final c = Offset(size.width / 2, size.height * 0.5);
    final glow = size.shortestSide * 0.62;
    canvas.drawCircle(c, glow, Paint()..shader = RadialGradient(colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: glow)));

    final s = size.shortestSide * iconScale;
    if (ground == ArtGround.paper) {
      // A paper card, slightly turned, with the icon on it.
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.12);
      final card = Rect.fromCenter(center: Offset.zero, width: s * 1.25, height: s * 1.6);
      canvas.translate(card.left, card.top); // the paper painter draws at the origin
      PaperCardPainter(radius: s * 0.14, tint: color).paint(canvas, card.size);
      canvas.restore();
      paintIcon(canvas, gameIconFor(id), Rect.fromCenter(center: c, width: s * 0.85, height: s * 0.85), color: fillFor(color));
    } else if (id.startsWith('colour_clash')) {
      _cardFan(canvas, c, s);
    } else {
      // Soft shadow, then the icon.
      canvas.drawOval(
          Rect.fromCenter(center: c + Offset(0, s * 0.52), width: s * 0.9, height: s * 0.16),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      paintIcon(canvas, gameIconFor(id), Rect.fromCenter(center: c, width: s, height: s), color: Colors.white);
    }
    canvas.restore();
  }

  /// Colour Clash: two of its cards fanned out (blue behind, red in front), like a hand.
  void _cardFan(Canvas canvas, Offset c, double s) {
    final w = s * 0.74, h = s * 1.08;
    void card(Offset at, double turn, Color fill) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(turn);
      final outer = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), Radius.circular(w * 0.14));
      canvas.drawRRect(outer.shift(Offset(0, s * 0.04)), Paint()..color = Colors.black.withValues(alpha: 0.3));
      canvas.drawRRect(outer, Paint()..color = Colors.white);
      canvas.drawRRect(outer.deflate(w * 0.08), Paint()..color = fill);
      canvas.save();
      canvas.rotate(-0.55);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 0.62, height: h * 0.62), Paint()..color = Colors.white);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 0.34, height: h * 0.36), Paint()..color = fill);
      canvas.restore();
      canvas.restore();
    }

    card(c + Offset(-w * 0.32, s * 0.02), -0.28, const Color(0xFF1E7BE0));
    card(c + Offset(w * 0.30, s * 0.04), 0.2, const Color(0xFFE53935));
  }

  void _night(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
        r, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, NeonPalette.bgBottom, 0.55)!, NeonPalette.bgBottom]).createShader(r));
    SkyPainter.drawStars(canvas, size);
  }

  void _ice(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE9F4FB), Color(0xFFBFDDEE)]).createShader(r));
    final line = Paint()
      ..color = const Color(0x66E5383B)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), line);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.shortestSide * 0.3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x552E8BFF));
  }

  @override
  bool shouldRepaint(GameArtPainter old) => old.id != id || old.color != color || old.iconScale != iconScale;
}

/// A game's art: its registered scene, or [GameArtPainter], fading into the night
/// background at the bottom when [fade] is on. Used by the intro header and How to play.
class GameArt extends StatelessWidget {
  final String id;
  final Color color;
  final bool fade;
  const GameArt({super.key, required this.id, required this.color, this.fade = true});

  @override
  Widget build(BuildContext context) {
    final scene = gameScenes[id];
    return ExcludeSemantics(
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: scene?.call(color) ?? GameArtPainter(id, color, iconScale: 0.46)),
        if (fade)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.5, 1], colors: [Color(0x000B0E2E), NeonPalette.bg]),
            ),
          ),
      ]),
    );
  }
}

/// "2–4 players", "2 players" or SOLO.
String playersLabel(int min, int max) => max <= 1 ? 'SOLO' : (max > min ? '$min–$max players' : '$max players');

/// A game in a grid (spec 4.4, Hub mockup): drawn art, name in Lilita, a player-count chip
/// and an optional star. Pressing sinks it; long-press also stars it.
class GameTile extends StatefulWidget {
  final String id, title;
  final Color color;
  final int minPlayers, maxPlayers;
  final bool? favourite; // null: no star button
  final VoidCallback onTap;
  final VoidCallback? onStar;
  final bool selected;
  const GameTile(
      {super.key,
      required this.id,
      required this.title,
      required this.color,
      required this.minPlayers,
      required this.maxPlayers,
      required this.onTap,
      this.favourite,
      this.onStar,
      this.selected = false});

  @override
  State<GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<GameTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final solo = w.maxPlayers <= 1;
    final flat = context.tk.flat;
    final tile = Semantics(
      button: true,
      selected: w.selected,
      label: '${w.title}, ${solo ? 'solo' : playersLabel(w.minPlayers, w.maxPlayers)}${w.favourite == true ? ', favourite' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          haptic(HapticWeight.selection);
          w.onTap();
        },
        onLongPress: w.onStar,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
          decoration: BoxDecoration(
            color: flat ? Colors.white : const Color(0xFF151A45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: w.selected ? (flat ? FlatPalette.ink : Brand.gold) : (flat ? FlatPalette.stroke : Colors.white.withValues(alpha: 0.12)), width: w.selected ? 2.5 : 1),
            boxShadow: _down ? null : [flat ? const BoxShadow(color: Color(0x38000000), offset: Offset(0, 4)) : const BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                CustomPaint(painter: GameArtPainter(w.id, w.color)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                ShrinkText(w.title, style: TextStyle(fontFamily: Fonts.display, fontSize: 17, height: 1.15, color: flat ? FlatPalette.ink : Colors.white)),
                const SizedBox(height: 4),
                PlayersChip(min: w.minPlayers, max: w.maxPlayers),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (w.favourite == null) return tile;
    return Stack(children: [
      Positioned.fill(child: tile),
      Positioned(
        top: 0,
        right: 0,
        child: Semantics(
          button: true,
          label: w.favourite! ? 'Unstar ${w.title}' : 'Star ${w.title}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: w.onStar,
            child: SizedBox(
              width: kTouchTarget,
              height: kTouchTarget,
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0x990A0E28), shape: BoxShape.circle),
                  child: w.favourite!
                      ? const GameIcon(GameIcons.star, size: 16, color: Brand.gold)
                      // Not a favourite: the same star, greyed out.
                      : ColorFiltered(colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: 0.45), BlendMode.srcIn), child: const GameIcon(GameIcons.star, size: 16)),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// One line of text that steps its font down (to [minSize]) to fit before it ellipsizes,
/// so long game names on narrow tiles ("Snakes & Ladders" at 320 px) stay readable.
class ShrinkText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double minSize;
  const ShrinkText(this.text, {super.key, required this.style, this.minSize = 13});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final scaler = MediaQuery.textScalerOf(context);
        var size = style.fontSize!;
        while (size > minSize) {
          final tp = TextPainter(text: TextSpan(text: text, style: style.copyWith(fontSize: size)), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)..layout();
          final fits = tp.width <= box.maxWidth;
          tp.dispose();
          if (fits) break;
          size -= 1;
        }
        return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style.copyWith(fontSize: size));
      });
}

/// The small "2–4 players" / SOLO chip on tiles.
class PlayersChip extends StatelessWidget {
  final int min, max;
  const PlayersChip({super.key, required this.min, required this.max});

  @override
  Widget build(BuildContext context) {
    final solo = max <= 1;
    final flat = context.tk.flat;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration:
          BoxDecoration(color: solo ? Brand.gold.withValues(alpha: flat ? 0.45 : 0.22) : (flat ? FlatPalette.option : Colors.white.withValues(alpha: 0.12)), borderRadius: BorderRadius.circular(8)),
      child: Text(playersLabel(min, max),
          style: TextStyle(fontFamily: Fonts.body, fontSize: 11, fontWeight: FontWeight.w900, color: flat ? FlatPalette.ink : (solo ? const Color(0xFFFFE08A) : Colors.white))),
    );
  }
}

/// A square of a game's art, e.g. for list rows and the lobby's next-game card.
class GameThumb extends StatelessWidget {
  final String id;
  final Color color;
  final double size;
  final double radius;
  const GameThumb({super.key, required this.id, required this.color, this.size = 52, this.radius = 14});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(width: size, height: size, child: CustomPaint(painter: GameArtPainter(id, color, iconScale: 0.62))),
        ),
      );
}
