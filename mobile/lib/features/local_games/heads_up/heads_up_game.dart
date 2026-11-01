import 'package:flutter/material.dart';
import '../party/word_turns.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';

const headsUpWords = [
  // Animals
  'Elephant', 'Penguin', 'Kangaroo', 'Giraffe', 'Monkey', 'Crocodile',
  'Peacock', 'Octopus', 'Camel', 'Panda',
  // Food
  'Biryani', 'Pani Puri', 'Dosa', 'Pizza', 'Jalebi', 'Momos', 'Maggi',
  'Chocolate', 'Ice Cream', 'Vada Pav',
  // Famous people
  'Virat Kohli',
  'MS Dhoni',
  'Shah Rukh Khan',
  'Amitabh Bachchan',
  'Sachin Tendulkar',
  'Taylor Swift',
  'Cristiano Ronaldo',
  'Lionel Messi',
  'Elon Musk',
  'Narendra Modi',
  // Things
  'Umbrella', 'Toothbrush', 'Laptop', 'Pressure Cooker', 'Auto Rickshaw',
  'Ceiling Fan', 'Mirror', 'Headphones', 'Selfie Stick', 'Mosquito',
  // Places
  'Taj Mahal', 'Goa', 'Mumbai Local', 'Eiffel Tower', 'Himalayas',
  'Hostel Room', 'Exam Hall', 'Wedding Hall', 'Moon', 'Bollywood',
  // Actions & jobs
  'Dancing', 'Sleeping in class', 'Taking a selfie', 'Cricket umpire', 'Chef',
  'Pilot', 'Magician', 'Doctor', 'Superhero', 'YouTuber',
  // Pop culture
  'Spider-Man', 'Harry Potter', 'Doraemon', 'Chhota Bheem', 'Shinchan',
  'Pikachu', 'Batman', 'Minecraft', 'PUBG', 'Instagram Reel',
];

final headsUpInfo = LocalGameInfo(
  id: 'heads_up',
  title: 'Heads Up',
  emoji: '🙆',
  color: const Color(0xFF00B8D9),
  tagline: 'Phone on your forehead. Guess fast!',
  rules: const [
    'On your turn, hold the phone on your forehead with the screen facing your friends. Don\'t peek!',
    'Friends give clues (talk, act, sing) without saying the word. You guess.',
    'GOT IT if you guess right, SKIP to pass. 60 seconds, 2 turns each. 2 to 6 players.',
  ],
  scoreUnit: 'words',
  splitScreen: false,
  maxPlayers: 6,
  online: wordTurnsRelay(
      create: (n) => WordTurnsLogic(players: n, words: headsUpWords),
      view: _view,
      hideFromActor: true),
  play: (players, onFinished) => TickingPlay<WordTurnsLogic>(
    create: () => WordTurnsLogic(players: players.length, words: headsUpWords),
    onFinished: onFinished,
    builder: (context, g) => _view(context, g, players, null),
  ),
);

Widget _view(BuildContext context, WordTurnsLogic g, List players, int? me) =>
    WordTurnsView(
      players: players.cast(),
      g: g,
      me: me,
      title: 'Heads Up',
      readyText:
          "You're guessing! Hold the phone on your forehead, screen facing out.",
      watchText: 'Give clues, but never say the word!',
      performerSeesWord: false,
      color: const Color(0xFF00B8D9),
    );
