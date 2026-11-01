import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../party/prompt_vote.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';

const wouldRatherPrompts = [
  'Never use social media again|Never watch movies again',
  'Eat only biryani forever|Eat only pizza forever', //
  'Be able to fly|Be invisible', 'Live without music|Live without movies',
  'Always be 10 minutes late|Always be 20 minutes early', //
  'Have unlimited data|Have unlimited money for food',
  'Talk to animals|Speak every language',
  'Go to the mountains|Go to the beach', //
  'Be a famous singer|Be a famous cricketer', 'Never feel cold|Never feel hot',
  'Read minds|See the future', //
  'Give up chai|Give up coffee', 'Have no exams ever|Have no homework ever',
  'Live in a big city|Live in a quiet village', //
  'Be the funniest person in the room|Be the smartest person in the room',
  'Travel to the past|Travel to the future', //
  'Have a pet dragon|Have a pet unicorn', 'Win the lottery|Live twice as long',
  'Only whisper|Only shout', //
  'Lose your phone|Lose your wallet', 'Be a superhero|Be a wizard',
  'Eat spicy food forever|Eat sweet food forever', //
  'Watch only cartoons|Watch only news',
  'Have a rewind button|Have a pause button for life',
  'Sleep 4 hours and feel great|Sleep 12 hours always',
];

final wouldRatherInfo = LocalGameInfo(
  id: 'would_rather',
  title: 'Would You Rather',
  emoji: '🤔',
  color: const Color(0xFF00B894),
  tagline: 'A or B? Side with the crowd!',
  rules: const [
    'Two choices appear. Everyone secretly picks A or B.',
    'Then the votes are revealed. Everyone on the bigger side scores a point.',
    'Argue about it as much as you like! 8 questions. 2 to 6 players.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  maxPlayers: 6,
  online: promptVoteRelay(_create, _view),
  play: (players, onFinished) => TickingPlay<PromptVoteLogic>(
    create: () => _create(players.length),
    onFinished: onFinished,
    builder: (context, g) => _view(context, g, players, null),
  ),
);

PromptVoteLogic _create(int n) => PromptVoteLogic(
    mode: VoteMode.wouldRather, players: n, prompts: wouldRatherPrompts);
Widget _view(BuildContext context, PromptVoteLogic g, List<GpPlayer> players,
        int? me) =>
    PromptVoteView(
        players: players,
        g: g,
        me: me,
        title: 'Would You Rather',
        color: const Color(0xFF00B894));
