import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/tokens.dart';

/// Player preferences kept on this phone: vibration, reduce motion, and the name and colour
/// used for "you" in one-device games. (Sound lives in GameAudio.)
abstract final class AppSettings {
  static const _device = MethodChannel('party/device');

  static final haptics = ValueNotifier<bool>(true);
  static final playerName = ValueNotifier<String>('');
  static final playerColor = ValueNotifier<int>(0);

  /// 0 easy, 1 medium, 2 hard. Shared by every computer opponent.
  static const cpuLabels = ['Easy', 'Medium', 'Hard'];
  static final cpuLevel = ValueNotifier<int>(1);

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      haptics.value = p.getBool('set_haptics') ?? true;
      Motion.reduceSetting.value = p.getBool('set_reduce_motion') ?? false;
      playerName.value = p.getString('set_player_name') ?? '';
      playerColor.value = (p.getInt('set_player_color') ?? 0)
          .clamp(0, PlayerPalette.colors.length - 1);
      cpuLevel.value = (p.getInt('set_cpu_level') ?? 1).clamp(0, 2);
    } catch (_) {}
    _applyHaptics();
  }

  static Future<void> setHaptics(bool on) async {
    haptics.value = on;
    _applyHaptics();
    if (on) HapticFeedback.selectionClick().ignore();
    await _save((p) => p.setBool('set_haptics', on));
  }

  static Future<void> setReduceMotion(bool on) async {
    Motion.reduceSetting.value = on;
    await _save((p) => p.setBool('set_reduce_motion', on));
  }

  static Future<void> setPlayerName(String name) async {
    playerName.value = name.trim();
    await _save((p) => p.setString('set_player_name', name.trim()));
  }

  static Future<void> setCpuLevel(int level) async {
    cpuLevel.value = level.clamp(0, 2);
    await _save((p) => p.setInt('set_cpu_level', cpuLevel.value));
  }

  static Future<void> setPlayerColor(int seat) async {
    playerColor.value = seat;
    await _save((p) => p.setInt('set_player_color', seat));
  }

  static Future<void> _save(
      Future<bool> Function(SharedPreferences p) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  /// Games buzz from many places (HapticFeedback.*); Android's view setting silences them all.
  static void _applyHaptics() {
    if (kIsWeb || !Platform.isAndroid) return;
    _device
        .invokeMethod('haptics', {'on': haptics.value}).catchError((_) => null);
  }
}
