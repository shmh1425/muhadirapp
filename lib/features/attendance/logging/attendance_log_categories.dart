import 'package:flutter/foundation.dart';

/// Unified attendance log categories (Phase 3.6).
abstract final class AttendanceLogCategories {
  static const offlineEngine = '[OFFLINE_ENGINE]';
  static const queue = '[QUEUE]';
  static const sync = '[SYNC]';
  static const attendance = '[ATTENDANCE]';
  static const state = '[STATE]';
  static const ui = '[UI]';
  static const error = '[ERROR]';

  // Pipeline channels
  static const entry = '[ATTENDANCE_ENTRY]';
  static const router = '[ATTENDANCE_ROUTER]';
  static const nfc = '[ATTENDANCE_NFC]';
  static const bluetooth = '[ATTENDANCE_BT]';
  static const qr = '[ATTENDANCE_QR]';
  static const manual = '[ATTENDANCE_MANUAL]';
  static const offlineBridge = '[ATTENDANCE_OFFLINE]';

  static void log(
    String category,
    String message, {
    String? requestId,
    String? sessionId,
    String? studentId,
    String? operationId,
    String? operationKey,
    String? traceId,
    String? correlationId,
    String? detail,
  }) {
    if (!kDebugMode) return;
    final parts = <String>[
      category,
      message,
      if (traceId != null) 'traceId=$traceId',
      if (correlationId != null) 'correlationId=$correlationId',
      if (requestId != null) 'requestId=$requestId',
      if (sessionId != null) 'sessionId=$sessionId',
      if (studentId != null) 'studentId=$studentId',
      if (operationId != null) 'operationId=$operationId',
      if (operationKey != null) 'operationKey=$operationKey',
      if (detail != null) 'detail=$detail',
    ];
    debugPrint(parts.join(' '));
  }

  static void logError(
    String message, {
    String? traceId,
    String? correlationId,
    String? detail,
  }) {
    log(error, message, traceId: traceId, correlationId: correlationId, detail: detail);
  }
}
