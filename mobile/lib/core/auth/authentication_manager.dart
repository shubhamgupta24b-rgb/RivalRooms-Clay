import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dev-mode guest auth. The token format matches the server's AUTH_MODE=dev.
/// When Firebase is set up, replace the body of these methods with
/// FirebaseAuth (anonymous + Google) and return `await user.getIdToken()` from [token].
class AuthenticationManager extends ChangeNotifier {
  String? _id;
  String? _name;

  bool get signedIn => _id != null;
  String get displayName => _name ?? '';
  String get token => 'dev:$_id:$_name';

  Future<bool> restore() async {
    final p = await SharedPreferences.getInstance();
    _id = p.getString('uid');
    _name = p.getString('name');
    notifyListeners();
    return signedIn;
  }

  Future<void> signInAsGuest(String name) async {
    final p = await SharedPreferences.getInstance();
    final rnd = Random.secure();
    _id = p.getString('uid') ??
        List.generate(12, (_) => rnd.nextInt(36).toRadixString(36)).join();
    final clean = name.trim().replaceAll(':', '');
    _name = clean.length > 20 ? clean.substring(0, 20) : clean;
    await p.setString('uid', _id!);
    await p.setString('name', _name!);
    notifyListeners();
  }

  Future<void> signOut() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('uid');
    await p.remove('name');
    _id = null;
    _name = null;
    notifyListeners();
  }
}
