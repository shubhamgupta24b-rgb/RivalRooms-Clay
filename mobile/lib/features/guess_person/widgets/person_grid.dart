import 'package:flutter/material.dart';
import '../models/person.dart';
import '../../../core/ui/app_flavor.dart';
import '../../../core/ui/materials/materials.dart';
import 'gp_theme.dart';
import 'person_card.dart';

/// The board: a rounded brown panel of cards. 5 columns on phones (30 people = 6 rows),
/// more on tablets. Card height comes from the space available so the whole board fits
/// without scrolling when possible.
class PersonGrid extends StatelessWidget {
  final List<Person> people;
  final CardMark Function(Person) markFor;
  final void Function(Person)? onTap;
  final String? Function(Person)? badgeFor;
  const PersonGrid(
      {super.key,
      required this.people,
      required this.markFor,
      this.onTap,
      this.badgeFor});

  static int columnsFor(int count, double width) {
    if (width >= 900) return count >= 30 ? 10 : 8;
    if (width >= 600) return 6;
    return count <= 16 ? 4 : 5;
  }

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return const Center(
          child: Text('No characters available',
              style: TextStyle(color: Colors.white)));
    }
    // A felt board under the cards (the flat app: its dark-blue board).
    return CustomPaint(
      painter: flatStyle ? null : const FeltPainter(radius: 26),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: flatStyle
            ? BoxDecoration(
                color: GpCoral.board, borderRadius: BorderRadius.circular(26))
            : null,
        child: LayoutBuilder(builder: (context, c) {
          const gap = 7.0;
          final cols = columnsFor(people.length, c.maxWidth);
          final rows = (people.length / cols).ceil();
          final cellW = (c.maxWidth - gap * (cols - 1)) / cols;
          final cellH = c.maxHeight.isFinite
              ? (c.maxHeight - gap * (rows - 1)) / rows
              : cellW * 1.3;
          // Too short a cell makes portraits unreadable: clamp, and let the grid scroll instead.
          final ratio = (cellW / cellH).clamp(0.6, 1.0);
          return GridView.builder(
            padding: const EdgeInsets.only(top: 2),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
                childAspectRatio: ratio),
            itemCount: people.length,
            itemBuilder: (_, i) {
              final p = people[i];
              return PersonCard(
                key: ValueKey(p.id),
                person: p,
                mark: markFor(p),
                badge: badgeFor?.call(p),
                onTap: onTap == null ? null : () => onTap!(p),
                onLongPress: () => showPersonZoom(
                    context, p), // press and hold to see the face up close
              );
            },
          );
        }),
      ),
    );
  }
}
