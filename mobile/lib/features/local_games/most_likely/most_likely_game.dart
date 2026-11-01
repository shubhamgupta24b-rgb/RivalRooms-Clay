import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../party/prompt_vote.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';

const mostLikelyPrompts = [
  'become famous', 'fall asleep in class', 'forget their own birthday',
  'become a millionaire', 'cry during a movie', //
  'survive a zombie apocalypse', 'eat the last samosa without asking',
  'get lost in their own city', 'become a YouTuber', //
  'reply "ok" to a long message', 'be late to their own wedding',
  'win a dance competition', 'talk to animals', //
  'become the Prime Minister', 'binge-watch a whole series in one night',
  'lose their phone today', 'adopt ten cats', //
  'laugh at the wrong moment', 'start a business', 'go viral on Instagram',
  'spend all their money on food', //
  'win a cricket match single-handed', 'become a teacher',
  'fight a mosquito at 3 a.m.', 'know all the gossip', //
  'travel the whole world', 'cheat at Ludo', 'sing in the bathroom',
  'cook the best biryani', 'become a superhero',
];

final mostLikelyInfo = LocalGameInfo(
  id: 'most_likely',
  title: 'Most Likely To',
  emoji: '👉',
  color: const Color(0xFFFF9F43),
  tagline: 'Who in your group would…?',
  rules: const [
    'A question appears: "Who is most likely to…?"',
    'Everyone secretly votes for a player (yes, you can vote for yourself).',
    'The most-voted player gets a crown point. 8 questions. 3 to 6 players.',
  ],
  scoreUnit: 'crowns',
  splitScreen: false,
  minPlayers: 3,
  maxPlayers: 6,
  online: promptVoteRelay(_create, _view),
  play: (players, onFinished) => TickingPlay<PromptVoteLogic>(
    create: () => _create(players.length),
    onFinished: onFinished,
    builder: (context, g) => _view(context, g, players, null),
  ),
);

PromptVoteLogic _create(int n) => PromptVoteLogic(
    mode: VoteMode.mostLikely, players: n, prompts: mostLikelyPrompts);
Widget _view(BuildContext context, PromptVoteLogic g, List<GpPlayer> players,
        int? me) =>
    PromptVoteView(
        players: players,
        g: g,
        me: me,
        title: 'Most Likely To',
        color: const Color(0xFFFF9F43));
