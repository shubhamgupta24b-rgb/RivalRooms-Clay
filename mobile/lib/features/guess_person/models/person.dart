enum Gender { male, female }

/// One character on the board. Pure data: per-round state such as "eliminated"
/// lives in the controller so the same Person can be reused across rounds.
class Person {
  final int id;
  final String name;
  final Gender gender;
  final String skinTone; // light | tan | brown | dark
  final String eyeColor; // brown | blue | green
  final String hairColor; // black | brown | blonde | red | gray
  final String hairStyle; // short | long | bald | bun | curly | spiky
  final String hat; // none | cap | beanie | fedora | beret
  final bool hasGlasses;
  final String facialHair; // none | beard | mustache
  final String shirtColor; // red | blue | green | yellow
  final String accessory; // none | earrings | necklace | bowtie

  /// Optional image asset. When null (or missing on disk) the portrait is drawn in code.
  final String? image;

  const Person({
    required this.id,
    required this.name,
    required this.gender,
    required this.skinTone,
    this.eyeColor = 'brown',
    required this.hairColor,
    required this.hairStyle,
    required this.shirtColor,
    this.hat = 'none',
    this.hasGlasses = false,
    this.facialHair = 'none',
    this.accessory = 'none',
    this.image,
  });

  bool get hasHat => hat != 'none';
  bool get hasBeard => facialHair == 'beard';

  /// Beards are drawn with a mustache, so they count too.
  bool get hasMustache => facialHair != 'none';
  bool get isBald => hairStyle == 'bald';
  bool get hasLongHair => hairStyle == 'long';
  bool get hasShortHair => hairStyle == 'short' || hairStyle == 'spiky';
  bool get hasAccessory => accessory != 'none';
  String get number => id.toString().padLeft(2, '0');

  /// Never print attributes: this keeps the secret person out of debug logs.
  @override
  String toString() => 'Person#$number';
}
