import 'package:flutter/material.dart';
import '../party/word_turns.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';

/// Dumb Charades with Bollywood (and a few Hollywood) movies.
const charadesMovies = [
  'Sholay', 'Dilwale Dulhania Le Jayenge', '3 Idiots', 'Lagaan', 'Dangal', 'PK',
  'Kabhi Khushi Kabhie Gham', 'Kuch Kuch Hota Hai', //
  'Zindagi Na Milegi Dobara', 'Yeh Jawaani Hai Deewani', 'Chak De! India',
  'Taare Zameen Par', 'Munna Bhai MBBS', 'Hera Pheri', 'Golmaal', //
  'Bahubali', 'RRR', 'KGF', 'Pushpa', 'Jawan', 'Pathaan', 'Gully Boy', 'Queen',
  'Barfi!', 'Andhadhun', 'Drishyam', 'Kahaani', //
  'Bajrangi Bhaijaan', 'Sultan', 'Dhoom', 'Krrish', 'Koi Mil Gaya',
  'Om Shanti Om', 'Jab We Met', 'Rang De Basanti', 'Swades', //
  'Jodhaa Akbar', 'Padmaavat', 'Bajirao Mastani', 'Tanhaji', 'Uri', 'Shershaah',
  'Animal', 'Stree', 'Bhool Bhulaiyaa', 'Welcome', //
  'Housefull', 'Dil Chahta Hai', 'Rockstar', 'Kal Ho Naa Ho', 'Devdas',
  'Mother India', 'Don', 'Agneepath', 'Singham', 'Wanted', //
  'Titanic', 'Avengers', 'Spider-Man', 'The Lion King', 'Frozen',
  'Harry Potter', 'Jurassic Park', 'Finding Nemo', 'Toy Story',
];

final charadesInfo = LocalGameInfo(
  id: 'charades',
  title: 'Dumb Charades',
  emoji: '🎬',
  color: const Color(0xFFFF7043),
  tagline: 'Act out the movie. No talking!',
  rules: const [
    'On your turn, only you see the movie name. Act it out with no words and no lip-reading tricks!',
    'Everyone else shouts guesses. Tap GOT IT when someone gets it right, or SKIP a tough one.',
    '60 seconds per turn, 2 turns each. The best actor wins! 2 to 6 players.',
  ],
  scoreUnit: 'movies',
  splitScreen: false,
  maxPlayers: 6,
  online: wordTurnsRelay(
      create: (n) => WordTurnsLogic(players: n, words: charadesMovies),
      view: _view,
      actorOnly: true),
  play: (players, onFinished) => TickingPlay<WordTurnsLogic>(
    create: () =>
        WordTurnsLogic(players: players.length, words: charadesMovies),
    onFinished: onFinished,
    builder: (context, g) => _view(context, g, players, null),
  ),
);

Widget _view(BuildContext context, WordTurnsLogic g, List players, int? me) =>
    WordTurnsView(
      players: players.cast(),
      g: g,
      me: me,
      title: 'Dumb Charades',
      readyText: "You're acting! Hold the phone so only you can see.",
      watchText: 'Watch the actor and shout the movie name!',
      performerSeesWord: true,
      color: const Color(0xFFFF7043),
    );
