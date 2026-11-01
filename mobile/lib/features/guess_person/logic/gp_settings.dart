import '../../../core/ui/app_flavor.dart';

class GpSettings {
  static const roundOptions = [3, 5, 10];
  static const timerOptions = [0, 15, 30, 60];
  static const peopleOptions = [20, 30];
  static const playerOptions = [2, 3, 4, 5, 6];

  final int rounds;
  final int timerSeconds; // 0 = no timer
  bool get hasTimer => timerSeconds > 0;
  final int peopleCount; // capped at the dataset size
  final bool autoEliminate;
  final bool sound;
  final int playerCount; // 2-6; roles rotate around the group each round

  const GpSettings({
    this.rounds = 5,
    this.timerSeconds = 0,
    this.peopleCount = 30,
    this.autoEliminate =
        flatStyle, // the flat app folds down non-matching faces by itself
    this.sound = true,
    this.playerCount = 2,
  });

  // A future "Quick Mode" is just another preset, e.g.
  // const GpSettings(rounds: 3, timerSeconds: 15, peopleCount: 12).

  GpSettings copyWith(
          {int? rounds,
          int? timerSeconds,
          int? peopleCount,
          bool? autoEliminate,
          bool? sound,
          int? playerCount}) =>
      GpSettings(
        rounds: rounds ?? this.rounds,
        timerSeconds: timerSeconds ?? this.timerSeconds,
        peopleCount: peopleCount ?? this.peopleCount,
        autoEliminate: autoEliminate ?? this.autoEliminate,
        sound: sound ?? this.sound,
        playerCount: playerCount ?? this.playerCount,
      );
}
