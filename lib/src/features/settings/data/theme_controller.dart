
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider for the SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

// ThemeController using Notifier (modern Riverpod)
class ThemeController extends Notifier<ThemeMode> {
  static const _themeKey = 'themeMode';

  @override
  ThemeMode build() {
    // Load initial state
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedTheme = prefs.getString(_themeKey);
    
    if (savedTheme == 'w') {
      return ThemeMode.light;
    } else if (savedTheme == 'b') {
      return ThemeMode.dark;
    } else {
      return ThemeMode.light; // Default to white
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    String value;
    if (mode == ThemeMode.light) {
      value = 'w'; // white
    } else if (mode == ThemeMode.dark) {
      value = 'b'; // black (dark)
    } else {
      value = 'w';
    }
    await prefs.setString(_themeKey, value);
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);
