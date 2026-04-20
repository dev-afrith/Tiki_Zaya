import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ThemeController appThemeController = ThemeController();

class ThemeController extends ChangeNotifier {
  static const _storageKey = 'theme_preference';
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, mode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }
}
