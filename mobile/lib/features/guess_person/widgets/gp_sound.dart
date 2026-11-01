import '../../../core/audio/game_audio.dart';
import '../../../core/ui/components.dart' show haptic, HapticWeight;
import '../logic/guess_person_controller.dart';

/// Guess the Person's sounds go through the app's audio (so the sound switch applies) and
/// its haptics through the vibration setting. Fire-and-forget.
void playGpSfx(GpSfx s) {
  switch (s) {
    case GpSfx.select:
    case GpSfx.question:
      GameAudio.sfx('tap');
    case GpSfx.eliminate:
      haptic(HapticWeight.selection);
    case GpSfx.timerWarning:
      haptic(HapticWeight.light);
    case GpSfx.correct:
      GameAudio.sfx('coin');
      haptic(HapticWeight.medium);
    case GpSfx.gameOver:
      GameAudio.sfx('win');
      haptic(HapticWeight.medium);
    case GpSfx.wrong:
      GameAudio.sfx('lose');
      haptic(HapticWeight.heavy);
  }
}
