import 'dart:math';
import '../shell/local_game_logic.dart';

enum ClashColor { red, yellow, green, blue, wild }

enum ClashKind { number, skip, reverse, drawTwo, wild, wildFour }

class ClashCard {
  final int id;
  final ClashColor color;
  final ClashKind kind;
  final int number; // 0-9 for number cards, -1 otherwise
  const ClashCard(this.id, this.color, this.kind, [this.number = -1]);

  bool get isWild => color == ClashColor.wild;
  String get label => switch (kind) {
        ClashKind.number => '$number',
        ClashKind.skip => '⊘',
        ClashKind.reverse => '⇄',
        ClashKind.drawTwo => '+2',
        ClashKind.wild => '★',
        ClashKind.wildFour => '+4',
      };
  @override
  String toString() => '${color.name}:$label';
}

enum ClashPhase { handoff, play, chooseColor, finished }

/// UNO-style shedding game for 2-6 players on one phone. Match the top card's colour,
/// number or symbol; wilds change the colour. Skip, Reverse, +2 and Wild +4 behave as usual
/// (no stacking). Down to one card? Call ONE! before playing it, or draw 2 as a penalty.
/// First to empty their hand wins. Between turns the phone is passed with the hand hidden.
class ColourClashLogic extends LocalGameLogic {
  static const handSize = 7;
  final int players;
  final Random _random;
  final List<List<ClashCard>> hands;
  final List<ClashCard> drawPile = [];
  final List<ClashCard> discard = [];
  late ClashColor color;
  int turn = 0;
  int direction = 1;
  ClashPhase phase = ClashPhase.handoff;
  bool drewThisTurn = false;
  ClashCard? drawnCard;
  bool calledOne = false;
  ClashCard? _pendingWild;
  int? winner;
  String message = '';

  ColourClashLogic({this.players = 2, Random? random, List<ClashCard>? deck})
      : _random = random ?? Random(),
        hands = List.generate(players, (_) => <ClashCard>[]) {
    drawPile.addAll(deck ?? (fullDeck()..shuffle(_random)));
    for (var r = 0; r < handSize; r++) {
      for (final h in hands) {
        h.add(_take());
      }
    }
    // Start on a number card so the first turn is plain.
    var first = _take();
    while (first.kind != ClashKind.number) {
      drawPile.insert(0, first);
      first = _take();
    }
    discard.add(first);
    color = first.color;
    message = 'Match ${_colorName(color)} or ${first.label}';
  }

  /// The standard 108-card deck.
  static List<ClashCard> fullDeck() {
    final cards = <ClashCard>[];
    var id = 0;
    for (final c in ClashColor.values.where((c) => c != ClashColor.wild)) {
      cards.add(ClashCard(id++, c, ClashKind.number, 0));
      for (var n = 1; n <= 9; n++) {
        cards.add(ClashCard(id++, c, ClashKind.number, n));
        cards.add(ClashCard(id++, c, ClashKind.number, n));
      }
      for (final k in [ClashKind.skip, ClashKind.reverse, ClashKind.drawTwo]) {
        cards.add(ClashCard(id++, c, k));
        cards.add(ClashCard(id++, c, k));
      }
    }
    for (var i = 0; i < 4; i++) {
      cards.add(ClashCard(id++, ClashColor.wild, ClashKind.wild));
      cards.add(ClashCard(id++, ClashColor.wild, ClashKind.wildFour));
    }
    return cards;
  }

  static String _colorName(ClashColor c) => c.name.toUpperCase();

  ClashCard get top => discard.last;
  List<ClashCard> get hand => hands[turn];
  int nextPlayer([int steps = 1]) =>
      ((turn + direction * steps) % players + players) % players;

  @override
  bool get finished => phase == ClashPhase.finished;
  @override
  List<int> get scores =>
      [for (var i = 0; i < players; i++) winner == i ? 1 : 0];
  @override
  void update(int elapsedMs) {}

  ClashCard _take() {
    if (drawPile.isEmpty) {
      // Reshuffle everything under the top card.
      final keep = discard.removeLast();
      drawPile.addAll(discard..shuffle(_random));
      discard
        ..clear()
        ..add(keep);
    }
    return drawPile.removeLast();
  }

  void _give(int player, int n) {
    for (var i = 0; i < n && (drawPile.isNotEmpty || discard.length > 1); i++) {
      hands[player].add(_take());
    }
  }

  bool canPlay(ClashCard c) {
    if (c.isWild || c.color == color) return true;
    if (c.kind != top.kind) return false;
    return c.kind != ClashKind.number || c.number == top.number;
  }

  /// Cards in the current hand that may be played now.
  Iterable<ClashCard> get playable => drewThisTurn
      ? [if (drawnCard != null && canPlay(drawnCard!)) drawnCard!]
      : hand.where(canPlay);

  /// The next player picks up the phone.
  void reveal() {
    if (forward('reveal', const [])) return;
    if (phase != ClashPhase.handoff) return;
    phase = ClashPhase.play;
    notifyListeners();
  }

  /// Plays [cardId] from the current hand. Wilds need [chosen] (or a later [chooseColor]).
  /// Returns false if the move isn't allowed.
  bool play(int cardId, {ClashColor? chosen}) {
    if (forward('play', [cardId, chosen?.index])) return false;
    if (phase != ClashPhase.play) return false;
    final i = hand.indexWhere((c) => c.id == cardId);
    if (i < 0) return false;
    final card = hand[i];
    if (!canPlay(card) || (drewThisTurn && card.id != drawnCard?.id))
      return false;
    hand.removeAt(i);
    discard.add(card);
    if (card.isWild) {
      _pendingWild = card;
      phase = ClashPhase.chooseColor;
      if (chosen != null) return chooseColor(chosen);
      notifyListeners();
      return true;
    }
    color = card.color;
    _finishPlay(card);
    return true;
  }

  bool chooseColor(ClashColor c) {
    if (forward('color', [c.index])) return false;
    if (phase != ClashPhase.chooseColor || c == ClashColor.wild) return false;
    color = c;
    final card = _pendingWild!;
    _pendingWild = null;
    phase = ClashPhase.play;
    _finishPlay(card);
    return true;
  }

  void _finishPlay(ClashCard card) {
    final me = turn;
    if (hand.length == 1 && !calledOne) {
      _give(me, 2);
      message = "Forgot to call ONE! +2 cards";
    } else {
      message = '';
    }
    if (hand.isEmpty) {
      winner = me;
      phase = ClashPhase.finished;
      notifyListeners();
      return;
    }
    var skip = 1;
    switch (card.kind) {
      case ClashKind.skip:
        skip = 2;
      case ClashKind.reverse:
        if (players == 2) {
          skip = 2;
        } else {
          direction = -direction;
        }
      case ClashKind.drawTwo:
        _give(nextPlayer(), 2);
        skip = 2;
      case ClashKind.wildFour:
        _give(nextPlayer(), 4);
        skip = 2;
      case ClashKind.number:
      case ClashKind.wild:
        break;
    }
    final effect = switch (card.kind) {
      ClashKind.skip => 'Next player skipped',
      ClashKind.reverse =>
        players == 2 ? 'Reverse: same player again' : 'Direction reversed',
      ClashKind.drawTwo => 'Next player draws 2 and is skipped',
      ClashKind.wildFour =>
        'Next player draws 4 and is skipped. Colour: ${_colorName(color)}',
      ClashKind.wild => 'Colour is now ${_colorName(color)}',
      ClashKind.number => '',
    };
    message = [message, effect].where((m) => m.isNotEmpty).join(' · ');
    _endTurn(skip);
  }

  /// Draws one card. If it can be played the player may play it or [pass]; otherwise the turn ends.
  ClashCard? draw() {
    if (forward('draw', const [])) return null;
    if (phase != ClashPhase.play || drewThisTurn) return null;
    final card = _take();
    hand.add(card);
    drewThisTurn = true;
    drawnCard = card;
    if (!canPlay(card)) {
      message = 'Drew a card and passed';
      _endTurn(1);
    } else {
      notifyListeners();
    }
    return card;
  }

  bool pass() {
    if (forward('pass', const [])) return false;
    if (phase != ClashPhase.play || !drewThisTurn) return false;
    message = 'Drew a card and passed';
    _endTurn(1);
    return true;
  }

  /// Call before playing your second-last card.
  bool callOne() {
    if (forward('one', const [])) return false;
    if (phase != ClashPhase.play || hand.length != 2) return false;
    calledOne = true;
    notifyListeners();
    return true;
  }

  void _endTurn(int steps) {
    turn = nextPlayer(steps);
    drewThisTurn = false;
    drawnCard = null;
    calledOne = false;
    phase = ClashPhase.handoff;
    notifyListeners();
  }
}
