import '../models/gp_question.dart';
import '../models/person.dart';

enum RoundOutcome { correct, wrong, timeUp }

/// Scoring is kept out of the UI and controller so it can change in one place.
int pointsFor(RoundOutcome o) => o == RoundOutcome.correct ? 1 : 0;

/// Question groups, in the order their tiles appear on the guessing screen.
const gpCategories = [
  GpCategory('gender', 'GENDER', '🚻'),
  GpCategory('eyes', 'EYE COLOR', '👁️'),
  GpCategory('hair', 'HAIR', '💇'),
  GpCategory('hair_color', 'HAIR COLOR', '🎨'),
  GpCategory('skin', 'SKIN TONE', '✋'),
  GpCategory('accessories', 'ACCESSORIES', '👓'),
  GpCategory('facial_hair', 'FACIAL HAIR', '🧔'),
];

const _eyeOrder = ['brown', 'blue', 'green'];
const _hairOrder = ['black', 'brown', 'blonde', 'red', 'gray'];
const _skinOrder = ['light', 'tan', 'brown', 'dark'];

List<String> _distinct(Iterable<String> values, List<String> order) {
  final list = values.toSet().toList();
  int rank(String v) => order.contains(v) ? order.indexOf(v) : order.length;
  list.sort((a, b) => rank(a).compareTo(rank(b)));
  return list;
}

/// Builds the question list from the people actually on the board. Questions that
/// cannot split the board (everyone yes, or everyone no) are dropped.
List<GpQuestion> buildQuestions(List<Person> people) {
  final all = <GpQuestion>[
    GpQuestion(
        'male', 'MALE', 'Is the person male?', (p) => p.gender == Gender.male,
        category: 'gender'),
    GpQuestion('female', 'FEMALE', 'Is the person female?',
        (p) => p.gender == Gender.female,
        category: 'gender'),
    for (final c in _distinct(people.map((p) => p.eyeColor), _eyeOrder))
      GpQuestion('eyes_$c', c.toUpperCase(), 'Does the person have $c eyes?',
          (p) => p.eyeColor == c,
          category: 'eyes'),
    GpQuestion('long_hair', 'LONG', 'Does the person have long hair?',
        (p) => p.hasLongHair,
        category: 'hair'),
    GpQuestion('short_hair', 'SHORT', 'Does the person have short hair?',
        (p) => p.hasShortHair,
        category: 'hair'),
    GpQuestion('curly', 'CURLY', 'Does the person have curly hair?',
        (p) => p.hairStyle == 'curly',
        category: 'hair'),
    GpQuestion('bun', 'BUN', 'Is the person\'s hair in a bun?',
        (p) => p.hairStyle == 'bun',
        category: 'hair'),
    GpQuestion('spiky', 'SPIKY', 'Does the person have spiky hair?',
        (p) => p.hairStyle == 'spiky',
        category: 'hair'),
    GpQuestion('bald', 'BALD', 'Is the person bald?', (p) => p.isBald,
        category: 'hair'),
    // Bald people have no hair colour to ask about.
    for (final c in _distinct(
        people.where((p) => !p.isBald).map((p) => p.hairColor), _hairOrder))
      GpQuestion('hair_$c', c.toUpperCase(), 'Does the person have $c hair?',
          (p) => !p.isBald && p.hairColor == c,
          category: 'hair_color'),
    for (final c in _distinct(people.map((p) => p.skinTone), _skinOrder))
      GpQuestion('skin_$c', c.toUpperCase(), 'Does the person have $c skin?',
          (p) => p.skinTone == c,
          category: 'skin'),
    GpQuestion('glasses', 'GLASSES', 'Does the person wear glasses?',
        (p) => p.hasGlasses,
        category: 'accessories'),
    GpQuestion(
        'hat', 'HAT', 'Is the person wearing a hat or cap?', (p) => p.hasHat,
        category: 'accessories'),
    GpQuestion('acc_earrings', 'EARRINGS', 'Is the person wearing earrings?',
        (p) => p.accessory == 'earrings',
        category: 'accessories'),
    GpQuestion('acc_necklace', 'NECKLACE', 'Is the person wearing a necklace?',
        (p) => p.accessory == 'necklace',
        category: 'accessories'),
    GpQuestion('acc_bowtie', 'BOW TIE', 'Is the person wearing a bow tie?',
        (p) => p.accessory == 'bowtie',
        category: 'accessories'),
    GpQuestion(
        'beard', 'BEARD', 'Does the person have a beard?', (p) => p.hasBeard,
        category: 'facial_hair'),
    GpQuestion('mustache', 'MUSTACHE', 'Does the person have a mustache?',
        (p) => p.hasMustache,
        category: 'facial_hair'),
  ];
  return all.where((q) {
    final yes = people.where(q.test).length;
    return yes > 0 && yes < people.length;
  }).toList();
}
