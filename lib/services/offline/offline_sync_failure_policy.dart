import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../attendance/bluetooth_attendance_service.dart';

/// Classifies sync failures for retry vs terminal handling in [OfflineSyncEngine].
abstract final class OfflineSyncFailurePolicy {
  static const int defaultMaxRetries = 3;

  /// Attendance already on server — replay should complete the queue op.
  static bool isSuccessfulIdempotentFailure(Object error) {
    if (error is BluetoothAttendanceException) {
      return error.code == BluetoothAttendanceErrorCode.alreadyMarked;
    }
    return false;
  }

  /// Terminal errors (permission, invalid payload) — mark failed immediately.
  static bool isPermanentFailure(Object error) {
    if (isSuccessfulIdempotentFailure(error)) return false;
    if (error.toString().contains('Manual attendance sync exceeded max retries')) {
      return true;
    }
    if (error is FirebaseException) {
      return _isPermanentFirebaseCode(error.code);
    }
    if (error is ArgumentError || error is StateError) {
      return true;
    }
    return false;
  }

  /// True when the failure is likely transient (network / unavailable service).
  static bool isTransientFailure(Object error) {
    if (isPermanentFailure(error)) return false;
    if (error is FirebaseException) {
      return _isTransientFirebaseCode(error.code);
    }
    final message = error.toString().toLowerCase();
    return message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('unavailable') ||
        message.contains('unable to resolve host') ||
        message.contains('unknownhost') ||
        message.contains('eai_nodata') ||
        message.contains('firestore.googleapis.com');
  }

  static bool _isPermanentFirebaseCode(String code) {
    switch (code.toLowerCase()) {
      case 'permission-denied':
      case 'unauthenticated':
      case 'invalid-argument':
      case 'failed-precondition':
      case 'not-found':
      case 'already-exists':
        return true;
      default:
        return false;
    }
  }

  static bool _isTransientFirebaseCode(String code) {
    switch (code.toLowerCase()) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'aborted':
      case 'resource-exhausted':
      case 'internal':
        return true;
      default:
        return false;
    }
  }

  static void logClassification({
    required String operationId,
    required Object error,
    required bool willRequeue,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ATTENDANCE_SYNC] syncFailureClassification id=$operationId '
      'transient=${isTransientFailure(error)} permanent=${isPermanentFailure(error)} '
      'willRequeue=$willRequeue error=$error',
    );
  }
}
