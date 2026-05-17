import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_nfc_hce/flutter_nfc_hce.dart';

import 'android_gate_hce_platform.dart';
import 'student_gate_payload.dart';

/// Android NFC Host Card Emulation so the security gate reader can read the
/// student phone like an NDEF tag (AID fixed by [flutter_nfc_hce] plugin).
///
/// Payload matches [StudentGatePayload] / [NfcTagIdentifier] `student_gate_card`.
class StudentGateHceService {
  StudentGateHceService._();
  static final StudentGateHceService instance = StudentGateHceService._();

  final FlutterNfcHce _plugin = FlutterNfcHce();

  bool get isPlatformSupported => !kIsWeb && Platform.isAndroid;

  /// NDEF text payload (JSON) for gate readers.
  static String buildGatePayload(
    int studentId, {
    int gateCardRev = 0,
    DateTime? at,
  }) =>
      StudentGatePayload.buildJsonString(
        studentId,
        gateCardRev: gateCardRev,
        at: at,
      );

  Future<bool> isHceSupported() async {
    if (!isPlatformSupported) return false;
    try {
      return await _plugin.isNfcHceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> isNfcAdapterEnabled() async {
    if (!isPlatformSupported) return false;
    try {
      return await _plugin.isNfcEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Starts broadcasting gate payload. Call [stop] when leaving the card screen.
  ///
  /// [persistMessage] is false to avoid storing student id in internal storage
  /// across reboots (privacy).
  Future<String?> start({
    required int studentId,
    int gateCardRev = 0,
    DateTime? at,
  }) async {
    if (!isPlatformSupported || studentId <= 0) return null;
    final content = StudentGatePayload.buildJsonString(
      studentId,
      gateCardRev: gateCardRev,
      at: at,
    );
    await AndroidGateHcePlatform.setPreferredGateService();
    return _plugin.startNfcHce(
      content,
      mimeType: 'text/plain',
      persistMessage: false,
    );
  }

  Future<void> stop() async {
    if (!isPlatformSupported) return;
    try {
      await _plugin.stopNfcHce();
    } catch (_) {
      // no-op
    }
    await AndroidGateHcePlatform.unsetPreferredGateService();
  }
}
