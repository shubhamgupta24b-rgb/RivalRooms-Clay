import 'package:flutter/material.dart';
import '../models/person.dart';
import 'gp_theme.dart';
import 'person_portrait.dart';

enum CardMark { none, selected, eliminated, correct, wrong }

/// White character card with the name on a dark strip, like a board-game tile.
class PersonCard extends StatelessWidget {
  final Person person;
  final CardMark mark;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? badge; // e.g. "SELECTED" shown on the card, never colour-only
  const PersonCard(
      {super.key,
      required this.person,
      this.mark = CardMark.none,
      this.onTap,
      this.onLongPress,
      this.badge});

  static const _grey = ColorFilter.matrix(<double>[
    0.33, 0.33, 0.33, 0, 0, //
    0.33, 0.33, 0.33, 0, 0, //
    0.33, 0.33, 0.33, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final out = mark == CardMark.eliminated;
    final border = switch (mark) {
      CardMark.selected => GpColors.accent,
      CardMark.correct => GpColors.yes,
      CardMark.wrong => GpColors.no,
      _ => Colors.white,
    };
    final state = switch (mark) {
      CardMark.eliminated => ', eliminated',
      CardMark.selected => ', selected',
      _ => '',
    };

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        // Paper, like the other card games.
        gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDF6), Color(0xFFF5E9D2)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: border, width: mark == CardMark.none || out ? 2 : 4),
        boxShadow: [
          if (mark == CardMark.selected)
            BoxShadow(
                color: GpColors.accent.withValues(alpha: 0.7), blurRadius: 14),
          const BoxShadow(
              color: Color(0x40000000), offset: Offset(0, 3), blurRadius: 2),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 4, 3, 0),
                child: out
                    ? ColorFiltered(
                        colorFilter: _grey, child: PersonPortrait(person))
                    : PersonPortrait(person),
              ),
              if (out) const CustomPaint(painter: _CrossPainter()),
            ]),
          ),
          Container(
            color: GpCoral.nameStrip,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(person.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    decoration: out ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white,
                  )),
            ),
          ),
        ]),
      ),
    );

    card = AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: out ? 0.55 : 1,
        child: card);
    if (badge != null) {
      card = Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: card),
        Positioned(
          top: -7,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: border == Colors.white ? GpColors.accent : border,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(badge!,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: GpColors.ink)),
            ),
          ),
        ),
      ]);
    }

    return Semantics(
      button: onTap != null,
      label: 'Person ${person.number} ${person.name}$state',
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: mark == CardMark.selected ? 1.06 : 1.0,
        child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            behavior: HitTestBehavior.opaque,
            child: card),
      ),
    );
  }
}

/// Plain-language list of a person's visible traits, e.g. "Blue eyes · Brown hair · Glasses".
String describePerson(Person p) {
  String cap(String s) => s[0].toUpperCase() + s.substring(1);
  return [
    p.gender == Gender.female ? 'Female' : 'Male',
    '${cap(p.eyeColor)} eyes',
    p.isBald
        ? 'Bald'
        : '${cap(p.hairColor)} ${p.hairStyle == 'short' ? 'short' : p.hairStyle} hair',
    '${cap(p.skinTone)} skin',
    if (p.hasGlasses) 'Glasses',
    if (p.hasHat) cap(p.hat),
    if (p.hasBeard) 'Beard' else if (p.hasMustache) 'Mustache',
    if (p.hasAccessory) cap(p.accessory == 'bowtie' ? 'bow tie' : p.accessory),
  ].join(' · ');
}

/// Big view of one person, opened by pressing and holding a card.
Future<void> showPersonZoom(BuildContext context, Person p) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.pop(ctx),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AspectRatio(aspectRatio: 0.8, child: PersonCard(person: p)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: GpCoral.panel, borderRadius: BorderRadius.circular(18)),
            child: Text(describePerson(p),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.4)),
          ),
          const SizedBox(height: 8),
          const Text('Tap anywhere to close',
              style: TextStyle(color: Colors.white70)),
        ]),
      ),
    ),
  );
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.shortestSide * 0.18;
    final p = Paint()
      ..color = GpColors.no
      ..strokeWidth = size.shortestSide * 0.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(pad, pad), Offset(size.width - pad, size.height - pad), p);
    canvas.drawLine(
        Offset(size.width - pad, pad), Offset(pad, size.height - pad), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
