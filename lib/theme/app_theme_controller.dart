import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Global theme mode for the app. Listen to this to rebuild MaterialApp.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(
  ThemeMode.system,
);

const String _themeBoxName = 'app_theme_preferences';
const String _themeModeKey = 'theme_mode';

ThemeMode themeModeFromString(String? value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

String themeModeToString(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => 'system',
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
  };
}

/// Loads the persisted app theme mode. Call after Hive is initialized.
Future<void> loadSavedThemeMode() async {
  final box = await Hive.openBox<dynamic>(_themeBoxName);
  final saved = box.get(_themeModeKey) as String?;
  appThemeMode.value = themeModeFromString(saved);
}

/// Sets the app theme mode and notifies listeners.
void setAppThemeMode(ThemeMode mode) {
  if (appThemeMode.value == mode) return;
  appThemeMode.value = mode;
  _saveThemeMode(mode);
}

void setThemeMode(ThemeMode mode) => setAppThemeMode(mode);

Future<void> _saveThemeMode(ThemeMode mode) async {
  final box = await Hive.openBox<dynamic>(_themeBoxName);
  await box.put(_themeModeKey, themeModeToString(mode));
}
