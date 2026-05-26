import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../features/attendance/logging/attendance_log_categories.dart';

/// Structured debug logs for offline infrastructure.
abstract final class OfflineEngineLog {
  static const engine = AttendanceLogCategories.offlineEngine;
  static const queue = AttendanceLogCategories.queue;
  static const sync = AttendanceLogCategories.sync;
  static const attendance = AttendanceLogCategories.attendance;
  static const error = AttendanceLogCategories.error;

  // Legacy aliases
  static const attendanceSync = sync;
  static const attendanceQueue = queue;

  static final Uuid _uuid = const Uuid();

  static String newTraceId() => _uuid.v4().substring(0, 8);
  static String newCorrelationId() => _uuid.v4();

  static void log(
    String prefix,
    String message, {
    String? operationId,
    String? operationKey,
    String? correlationId,
    String? traceId,
    String? detail,
  }) {
    if (!kDebugMode) return;
    final parts = <String>[
      prefix,
      message,
      if (traceId != null) 'traceId=$traceId',
      if (correlationId != null) 'correlationId=$correlationId',
      if (operationId != null) 'id=$operationId',
      if (operationKey != null) 'operationKey=$operationKey',
      if (detail != null) 'detail=$detail',
    ];
    debugPrint(parts.join(' '));
  }

  static void logError(
    String message, {
    String? correlationId,
    String? traceId,
    String? detail,
  }) {
    log(error, message, correlationId: correlationId, traceId: traceId, detail: detail);
  }
}
