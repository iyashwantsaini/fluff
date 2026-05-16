import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent user preferences.
///
/// Loaded once at app startup via [Prefs.init]. Mutations write through
/// to [SharedPreferences] immediately and notify listeners so UI can
/// rebuild. **Pure-local, no telemetry, no sync.**
class Prefs extends ChangeNotifier {
  Prefs._(this._sp);

  static Prefs? _instance;
  static Prefs get instance {
    final p = _instance;
    if (p == null) {
      throw StateError('Prefs.init() must be awaited before use.');
    }
    return p;
  }

  static Future<Prefs> init() async {
    final sp = await SharedPreferences.getInstance();
    final p = Prefs._(sp);
    _instance = p;
    return p;
  }

  final SharedPreferences _sp;

  // ---- theme ----------------------------------------------------------

  static const _kThemeMode = 'fluff.themeMode';

  ThemeMode get themeMode {
    final raw = _sp.getString(_kThemeMode);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode m) async {
    await _sp.setString(_kThemeMode, m.name);
    notifyListeners();
  }

  // ---- accessibility --------------------------------------------------

  static const _kLargeText = 'fluff.a11y.largeText';
  static const _kReduceMotion = 'fluff.a11y.reduceMotion';
  static const _kHighContrast = 'fluff.a11y.highContrast';
  static const _kHapticOnLongPress = 'fluff.a11y.hapticOnLongPress';

  bool get largeText => _sp.getBool(_kLargeText) ?? false;
  bool get reduceMotion => _sp.getBool(_kReduceMotion) ?? false;
  bool get highContrast => _sp.getBool(_kHighContrast) ?? false;
  bool get hapticOnLongPress => _sp.getBool(_kHapticOnLongPress) ?? true;

  Future<void> setLargeText(bool v) async {
    await _sp.setBool(_kLargeText, v);
    notifyListeners();
  }

  Future<void> setReduceMotion(bool v) async {
    await _sp.setBool(_kReduceMotion, v);
    notifyListeners();
  }

  Future<void> setHighContrast(bool v) async {
    await _sp.setBool(_kHighContrast, v);
    notifyListeners();
  }

  Future<void> setHapticOnLongPress(bool v) async {
    await _sp.setBool(_kHapticOnLongPress, v);
    notifyListeners();
  }

  // ---- onboarding -----------------------------------------------------

  static const _kFirstRunComplete = 'fluff.firstRunComplete';

  bool get firstRunComplete => _sp.getBool(_kFirstRunComplete) ?? false;

  Future<void> setFirstRunComplete(bool v) async {
    await _sp.setBool(_kFirstRunComplete, v);
    notifyListeners();
  }
}
