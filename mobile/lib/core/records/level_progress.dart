import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Unlocked level (1-based) for a campaign key, stored with the app's other local data.
class LevelProgress {
  static String _key(String id) => 'level_$id';

  static Future<int> unlocked(String id) async {
    final p = await SharedPreferences.getInstance();
    return max(1, p.getInt(_key(id)) ?? 1);
  }

  /// Records that [level] is now available. Never locks a level that was already open.
  static Future<int> unlock(String id, int level) async {
    final p = await SharedPreferences.getInstance();
    final next = max(p.getInt(_key(id)) ?? 1, level);
    await p.setInt(_key(id), next);
    return next;
  }
}
