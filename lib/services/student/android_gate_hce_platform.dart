import 'package:flutter/services.dart';

/// Android-only helpers for gate HCE (preferred service + NFC settings).
class AndroidGateHcePlatform {
  AndroidGateHcePlatform._();

  static const MethodChannel _channel =
      MethodChannel('com.example.muhadirapp/gate_hce');

  static Future<bool> setPreferredGateService() async {
    try {
      final ok = await _channel.invokeMethod<bool>('setPreferredGateHce');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> unsetPreferredGateService() async {
    try {
      final ok = await _channel.invokeMethod<bool>('unsetPreferredGateHce');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openNfcPaymentSettings() async {
    try {
      final ok = await _channel.invokeMethod<bool>('openNfcPaymentSettings');
      return ok == true;
    } catch (_) {
      return false;
    }
  }
}
