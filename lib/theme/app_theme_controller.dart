import 'package:flutter/material.dart';

/// Global theme mode for the app. Listen to this to rebuild MaterialApp.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

/// Sets the app theme mode and notifies listeners.
void setAppThemeMode(ThemeMode mode) {
  appThemeMode.value = mode;
}
