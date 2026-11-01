import 'person.dart';

class GpQuestion {
  final String id;
  final String label; // short button text, e.g. "GLASSES"
  final String prompt; // full question, e.g. "Does the person have glasses?"
  final bool Function(Person) test;
  final String category; // a GpCategory id
  const GpQuestion(this.id, this.label, this.prompt, this.test,
      {this.category = 'other'});
}

/// A group of questions shown as one tile on the guessing screen.
class GpCategory {
  final String id;
  final String label;
  final String emoji;
  const GpCategory(this.id, this.label, this.emoji);
}

class AskedQuestion {
  final GpQuestion question;
  final bool answer;
  const AskedQuestion(this.question, this.answer);
}
