import 'package:flutter/material.dart';

/// Leading back chevron for student headers: always `<` ([Icons.arrow_back_ios_new]).
/// English and Arabic UIs use the same glyph; [Row] / [Directionality] handle placement.
class StudentBackChevronIcon extends StatelessWidget {
  /// Not `const` so hot reload can update this widget when fields change
  /// (avoids "Const class cannot remove fields" during development).
  // ignore: prefer_const_constructors_in_immutables
  StudentBackChevronIcon({
    super.key,
    required this.color,
    this.size = 18,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.arrow_back_ios_new, color: color, size: size);
  }
}
