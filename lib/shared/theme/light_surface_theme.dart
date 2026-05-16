import 'package:flutter/material.dart';

/// Wraps light-background screens so [TextField] typed text stays dark when the app uses dark mode.
ThemeData themeForLightSurface() {
  return ThemeData(
    brightness: Brightness.light,
    useMaterial3: false,
    fontFamily: 'Cairo',
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF006571),
      onPrimary: Colors.white,
      onSurface: Color(0xFF1A1A1A),
      surface: Colors.white,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Color(0xFF006571),
      selectionColor: Color(0x4027A2A9),
    ),
  );
}

/// Standard dark text style for inputs on white / light-grey panels.
const TextStyle lightSurfaceFieldTextStyle = TextStyle(
  fontSize: 15,
  color: Color(0xFF1A1A1A),
  fontFamily: 'Cairo',
);

const Color lightSurfaceFieldHintColor = Color(0xFF9E9E9E);
