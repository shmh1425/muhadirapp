import 'package:flutter/foundation.dart';

/// Shared preferences for female security module (e.g. selected gate).
final ValueNotifier<int> selectedGate = ValueNotifier<int>(3);

/// Label for gate in header: "بوابة رقم 1", "بوابة رقم 2", etc.
String gateLabel(int gate) => 'بوابة رقم $gate';

/// Full gate label for card preview: "بوابة 1 - الزاهر", etc.
String gateLabelWithLocation(int gate) => 'بوابة $gate - الزاهر';
