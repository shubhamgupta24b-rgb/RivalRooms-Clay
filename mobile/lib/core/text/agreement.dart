/// Verb agreement for the player name "You".
///
/// A seat named You is the person holding the phone, so the verb is second person
/// ("You win", "You have"). Every other name takes the third person
/// ("Mina wins", "Mina has").
bool isYou(String name) => name.trim().toLowerCase() == 'you';

/// [youForm] when [name] is You, otherwise [otherForm].
String verbFor(String name, String youForm, String otherForm) =>
    isYou(name) ? youForm : otherForm;

String winsWord(String name) => verbFor(name, 'win', 'wins');

String hasWord(String name) => verbFor(name, 'have', 'has');

/// "You win!" or "Mina wins!".
String winsBang(String name) => '$name ${winsWord(name)}!';

/// "You win" or "Mina wins", without the exclamation.
String winsPhrase(String name) => '$name ${winsWord(name)}';
