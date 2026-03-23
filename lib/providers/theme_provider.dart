import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePreference { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_pref';
  ThemePreference _pref = ThemePreference.system;

  ThemeProvider() {
    _load();
  }

  ThemePreference get pref => _pref;

  ThemeMode get themeMode => switch (_pref) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light  => ThemeMode.light,
    ThemePreference.dark   => ThemeMode.dark,
  };

  void set(ThemePreference p) {
    _pref = p;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, _pref.index);
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(_key);
      if (index != null && index >= 0 && index < ThemePreference.values.length) {
        _pref = ThemePreference.values[index];
        notifyListeners();
      }
    } catch (_) {
      // Corrupt data — use default
    }
  }
}
