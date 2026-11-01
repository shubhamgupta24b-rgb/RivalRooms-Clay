import 'package:flutter/material.dart';
import '../../../core/ui/components.dart';
import 'package:provider/provider.dart';
import '../logic/gp_settings.dart';
import '../logic/guess_person_controller.dart';
import '../models/gp_player.dart';
import '../models/gp_question.dart';
import '../widgets/game_header.dart';
import '../widgets/gp_sound.dart';
import '../widgets/gp_theme.dart';
import '../widgets/pass_device_view.dart';
import '../widgets/person_card.dart';
import '../widgets/person_grid.dart';
import '../widgets/question_panel.dart';
import '../widgets/result_view.dart' show ResultView;
import '../../local_games/shell/local_game_info.dart';
import '../../local_games/shell/result_screen.dart';

/// Hosts one match. The controller is created here and disposed with the screen,
/// which also cancels its timer.
class GuessPersonGameScreen extends StatelessWidget {
  final GpSettings settings;
  const GuessPersonGameScreen({super.key, this.settings = const GpSettings()});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GuessPersonController(
          settings: settings,
          players: defaultPlayers(settings.playerCount),
          onSfx: playGpSfx)
        ..startGame(),
      child: const _GameView(),
    );
  }
}

class _GameView extends StatelessWidget {
  const _GameView();

  Future<void> _confirmLeave(BuildContext context) async {
    final leave = await confirmAction(context,
        title: 'Leave game?',
        message: 'Scores for this match will be lost.',
        confirm: 'Leave',
        cancel: 'Stay',
        emoji: null);
    if (leave && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuessPersonController>();
    // guessing <-> finalGuess share one view so the board doesn't flash.
    final viewKey =
        '${c.round}-${c.phase == GpPhase.finalGuess ? GpPhase.guessing : c.phase}';
    void leave() => _confirmLeave(context);

    Widget body;
    if (!c.hasEnoughPeople) {
      body = _ErrorView(onBack: () => Navigator.pop(context));
    } else {
      body = switch (c.phase) {
        GpPhase.roundSetup => PassDeviceView(
            title: 'ROUND ${c.round}',
            to: c.chooser,
            icon: Icons.visibility_off_rounded,
            message:
                "${c.chooser.name}'s turn to choose. Choose one person secretly.",
            buttonLabel: 'START CHOOSING',
            onReady: c.beginSelection,
          ),
        GpPhase.selectingPerson => _SelectView(c: c, onClose: leave),
        GpPhase.confirmSelection => _ConfirmView(c: c),
        GpPhase.passDevice => PassDeviceView(
            title: 'PERSON SELECTED',
            to: c.guesser,
            onReady: c.switchToGuessing),
        GpPhase.guessing ||
        GpPhase.finalGuess =>
          _GuessView(c: c, onClose: leave),
        GpPhase.result => ResultView(
            result: c.result!,
            players: c.players,
            lastRound: c.isLastRound,
            onNext: c.nextRound),
        GpPhase.gameOver => _GameOverView(c: c),
      };
    }

    return PopScope(
      canPop: c.phase == GpPhase.gameOver || !c.hasEnoughPeople,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        body: CoralBackground(
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(key: ValueKey(viewKey), child: body),
            ),
          ),
        ),
      ),
    );
  }
}

/// ✕ on the left, who's playing on the right.
class _TopBar extends StatelessWidget {
  final GuessPersonController c;
  final VoidCallback onClose;
  final bool guessing;
  const _TopBar(
      {required this.c, required this.onClose, required this.guessing});

  @override
  Widget build(BuildContext context) {
    final p = guessing ? c.guesser : c.chooser;
    return Row(children: [
      CircleCloseButton(onPressed: onClose),
      const SizedBox(width: 10),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _Pill('ROUND ${c.round}/${c.totalRounds}'),
              const SizedBox(width: 6),
              if (guessing) ...[
                _Pill('${c.peopleLeft} LEFT'),
                const SizedBox(width: 6)
              ],
              PlayerTag(name: p.name, color: p.color),
              if (guessing && c.settings.hasTimer) ...[
                const SizedBox(width: 6),
                TimerBadge(c.secondsLeft)
              ],
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: NeonPalette.overlay,
            borderRadius: Radii.rChip,
            border: Border.all(color: Colors.white.withValues(alpha: 0.14))),
        child: Text(text,
            style: const TextStyle(
                fontFamily: Fonts.display, color: Colors.white, fontSize: 15)),
      );
}

class _SelectView extends StatelessWidget {
  final GuessPersonController c;
  final VoidCallback onClose;
  const _SelectView({required this.c, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _TopBar(c: c, onClose: onClose, guessing: false),
        const SizedBox(height: 10),
        Expanded(
          child: PersonGrid(
            people: c.people,
            markFor: (p) =>
                p.id == c.selectedId ? CardMark.selected : CardMark.none,
            badgeFor: (p) => p.id == c.selectedId ? 'SELECTED' : null,
            onTap: (p) => c.selectSecretPerson(p.id),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Choose your\ncharacter!',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: Fonts.display,
                color: Colors.white,
                fontSize: 30,
                height: 1.05)),
        // The picked card may be scrolled out of view (e.g. after RANDOM): name it here too.
        if (c.selectedPerson != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Selected: ${c.selectedPerson!.name}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: Fonts.body,
                    color: Brand.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 15)),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: GpButton('RANDOM',
                  icon: Icons.casino_rounded,
                  color: Colors.white,
                  onPressed: c.selectRandomPerson)),
          const SizedBox(width: 12),
          Expanded(
              child: GpButton('CONFIRM',
                  icon: Icons.check_rounded,
                  onPressed: c.selectedId == null ? null : c.requestConfirm)),
        ]),
      ]),
    );
  }
}

class _ConfirmView extends StatelessWidget {
  final GuessPersonController c;
  const _ConfirmView({required this.c});

  @override
  Widget build(BuildContext context) {
    final p = c.selectedPerson;
    if (p == null) return const SizedBox.shrink();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DarkPanel(
            padding: const EdgeInsets.all(22),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                      child: SizedBox(
                          width: 160,
                          height: 200,
                          child:
                              PersonCard(person: p, mark: CardMark.selected))),
                  const SizedBox(height: 22),
                  const Text('Are you sure?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: Fonts.display,
                          color: Colors.white,
                          fontSize: 30)),
                  const SizedBox(height: 6),
                  Text('${c.guesser.name} will try to find ${p.name}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 24),
                  GpButton('CONFIRM PERSON',
                      icon: Icons.lock_rounded,
                      onPressed: c.confirmSecretPerson),
                  const SizedBox(height: 12),
                  GpButton('CHANGE',
                      icon: Icons.undo_rounded,
                      outlined: true,
                      onPressed: c.changeSelection),
                ]),
          ),
        ),
      ),
    );
  }
}

class _GuessView extends StatelessWidget {
  final GuessPersonController c;
  final VoidCallback onClose;
  const _GuessView({required this.c, required this.onClose});

  void _tap(BuildContext context, int id) {
    if (c.phase == GpPhase.guessing) {
      c.eliminatePerson(id);
      return;
    }
    if (c.chooseGuess(id) == GuessPick.eliminated) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('This person has been eliminated.'),
            duration: Duration(milliseconds: 1400)));
    }
  }

  bool? _answerFor(GpQuestion q) {
    for (final h in c.history) {
      if (h.question.id == q.id) return h.answer;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final controls = _controls();
      // Short screens: cap the controls and let them scroll so the board keeps its space.
      final bottom = box.maxHeight < 700
          ? ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.42),
              child: SingleChildScrollView(child: controls))
          : controls;
      return _layout(context, bottom);
    });
  }

  Widget _controls() {
    final finalMode = c.phase == GpPhase.finalGuess;
    final pending = c.pendingGuess;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!finalMode) ...[
            AnswerBanner(
                answer: c.lastAnswer,
                emptyHint:
                    'Pick a category, ask a question, then tap people to rule them out.'),
            const SizedBox(height: 10),
            CategoryPanel(
                questions: c.questions,
                answerFor: _answerFor,
                onAsk: c.askQuestion),
            const SizedBox(height: 10),
            GpButton('MAKE FINAL GUESS',
                icon: Icons.ads_click_rounded, onPressed: c.startFinalGuess),
          ] else if (pending == null)
            GpButton('CANCEL',
                icon: Icons.close_rounded,
                color: Colors.white,
                onPressed: c.cancelFinalGuess)
          else
            DarkPanel(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                SizedBox(
                    width: 74, height: 94, child: PersonCard(person: pending)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Is ${pending.name} your final guess?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16)),
                        const SizedBox(height: 8),
                        GpButton('YES, FINAL GUESS',
                            color: GpColors.yes,
                            textColor: Colors.white,
                            onPressed: c.makeFinalGuess),
                        const SizedBox(height: 8),
                        GpButton('CANCEL',
                            outlined: true, onPressed: c.cancelFinalGuess),
                      ]),
                ),
              ]),
            ),
        ]);
  }

  Widget _layout(BuildContext context, Widget bottom) {
    final finalMode = c.phase == GpPhase.finalGuess;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _TopBar(c: c, onClose: onClose, guessing: true),
        const SizedBox(height: 8),
        if (finalMode)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: TurnBanner(
                text: 'Who is the person?',
                sub: 'Tap your final guess',
                color: Brand.gold,
                kind: TurnBannerKind.success,
                icon: GameIcons.target,
                compact: true),
          ),
        Expanded(
          child: PersonGrid(
            people: c.people,
            markFor: (p) => c.eliminated.contains(p.id)
                ? CardMark.eliminated
                : (p.id == c.pendingGuessId
                    ? CardMark.selected
                    : CardMark.none),
            badgeFor: (p) => p.id == c.pendingGuessId ? 'GUESS' : null,
            onTap: (p) => _tap(context, p.id),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Tip: press and hold a face to see it up close',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const SizedBox(height: 10),
        bottom,
      ]),
    );
  }
}

/// The shared result screen (spec 2.10) with Guess the Person's final scores.
class _GameOverView extends StatelessWidget {
  final GuessPersonController c;
  const _GameOverView({required this.c});

  static final _info = LocalGameInfo(
    id: 'guess_person',
    title: 'Guess the Person',
    emoji: '',
    color: const Color(0xFFFFC93C),
    tagline: '',
    rules: const [],
    scoreUnit: 'points',
    splitScreen: false,
    maxPlayers: 6,
    play: (_, __) => const SizedBox.shrink(),
  );

  @override
  Widget build(BuildContext context) {
    final players = [
      for (final p in c.players)
        GpPlayer(name: p.name, color: p.color, score: p.score)
    ];
    return ResultScreen(
      game: _info,
      players: players,
      extras: ResultExtras()
        ..subtitle = '${c.totalRounds} rounds · ${c.players.length} players',
      onRematch: c.resetGame,
      onChangePlayers: () => Navigator.pop(context),
      onExit: () => Navigator.pop(context),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onBack;
  const _ErrorView({required this.onBack});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Not enough characters to play.',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 16),
            GpButton('BACK', onPressed: onBack),
          ]),
        ),
      );
}
