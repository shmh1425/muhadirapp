import 'dart:io';

import 'package:flutter/foundation.dart';

/// Platform capabilities for campus gate NFC / QR on the student card.
class StudentGatePlatform {
  StudentGatePlatform._();

  static bool get showNfcModeChip =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Phone acts as NFC card via HCE (Android only).
  static bool get supportsPhoneHce => !kIsWeb && Platform.isAndroid;

  /// Program an NTAG sticker/card with the same gate JSON (iOS + Android).
  static bool get supportsNfcTagProgramming =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
