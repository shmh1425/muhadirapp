import 'dart:async';

import '../../models/attendance/manual_attendance_record.dart';
import '../../services/attendance/bluetooth_attendance_service.dart';
import '../../services/attendance/manual_attendance_offline_service.dart';
import '../../services/attendance/nfc_attendance_service.dart';
import '../../services/attendance/qr_attendance_service.dart';
import '../../services/offline/offline_sync_engine.dart';
import 'attendance_connectivity.dart';
import 'attendance_session_snapshot.dart';
import 'attendance_offline_bridge.dart';
import 'attendance_payload.dart';
import 'attendance_pipeline_logger.dart';
import 'attendance_source.dart';
import 'attendance_submission_result.dart';
import 'delegates/attendance_bluetooth_delegate.dart';
import 'delegates/attendance_nfc_delegate.dart';
import 'delegates/attendance_qr_online_delegate.dart';

/// Single decision point: offline engine path vs QR online-only path.
class AttendanceUnifiedService {
  AttendanceUnifiedService._();
  static final AttendanceUnifiedService instance = AttendanceUnifiedService._();

  final AttendanceOfflineBridge _offlineBridge = AttendanceOfflineBridge.instance;
  final AttendanceNfcDelegate _nfc = AttendanceNfcDelegate.instance;
  final AttendanceBluetoothDelegate _bluetooth =
      AttendanceBluetoothDelegate.instance;
  final AttendanceQrOnlineDelegate _qr = AttendanceQrOnlineDelegate.instance;
  final ManualAttendanceOfflineService _manualOffline =
      ManualAttendanceOfflineService.instance;

  Future<AttendanceSubmissionResult> submit(AttendancePayload payload) async {
    if (payload.source.isOnlineOnly) {
      return _submitQrOnline(payload);
    }
    return _submitOfflineCapable(payload);
  }

  /// Lecturer manual batch — offline engine via [ManualAttendanceOfflineService].
  Future<AttendanceSubmissionResult> submitManualBatch({
    required String sessionId,
    required String courseId,
    required Map<int, ManualAttendanceStatus> updates,
    String? requestId,
  }) async {
    AttendancePipelineLogger.log(
      AttendancePipelineLogger.manual,
      'manual batch submit',
      requestId: requestId,
      sessionId: sessionId,
      detail: 'count=${updates.length}',
    );
    final result = await _manualOffline.submitAttendance(
      sessionId: sessionId,
      courseId: courseId,
      updates: updates,
    );
    if (result.usedQueue) {
      return AttendanceSubmissionResult(
        success: true,
        outcome: AttendanceSubmissionOutcome.queuedOffline,
        source: AttendanceSource.manual,
        message: 'Manual attendance queued for sync.',
        requestId: requestId,
        queuedCount: result.queuedCount,
      );
    }
    return AttendanceSubmissionResult(
      success: true,
      outcome: AttendanceSubmissionOutcome.appliedOnline,
      source: AttendanceSource.manual,
      message: 'Manual attendance saved.',
      requestId: requestId,
    );
  }

  Future<AttendanceSubmissionResult> _submitQrOnline(
    AttendancePayload payload,
  ) async {
    if (!await AttendanceConnectivity.isOnlineForAttendance()) {
      AttendancePipelineLogger.log(
        AttendancePipelineLogger.qr,
        'rejected offline',
        requestId: payload.requestId,
      );
      return AttendanceSubmissionResult.rejectedOffline(AttendanceSource.qr);
    }
    final qrResult = await _qr.submit(payload);
    if (!qrResult.success) {
      throw QrAttendanceException(
        code: QrAttendanceErrorCode.unknown,
        message: qrResult.message,
      );
    }
    return AttendanceSubmissionResult(
      success: true,
      outcome: AttendanceSubmissionOutcome.appliedOnline,
      source: AttendanceSource.qr,
      message: qrResult.message,
      requestId: payload.requestId,
      recordId: qrResult.recordId,
      sessionSnapshot: qrResult.sessionSnapshot,
    );
  }

  Future<AttendanceSubmissionResult> _submitOfflineCapable(
    AttendancePayload payload,
  ) async {
    if (!await AttendanceConnectivity.isOnlineForAttendance()) {
      AttendancePipelineLogger.log(
        AttendancePipelineLogger.offline,
        'no connectivity — enqueue immediately',
        requestId: payload.requestId,
        detail: 'source=${payload.source.wireValue}',
      );
      return _enqueueOfflineSubmission(payload);
    }

    try {
      final onlineResult = await _applyOnlineFirst(payload);
      return AttendanceSubmissionResult(
        success: true,
        outcome: AttendanceSubmissionOutcome.appliedOnline,
        source: payload.source,
        message: onlineResult.message,
        requestId: payload.requestId,
        recordId: onlineResult.recordId,
        sessionSnapshot: onlineResult.sessionSnapshot,
      );
    } on NfcAttendanceException {
      rethrow;
    } on BluetoothAttendanceException catch (e) {
      if (e.code == BluetoothAttendanceErrorCode.alreadyMarked) {
        return AttendanceSubmissionResult.duplicate(AttendanceSource.bluetooth);
      }
      if (e.code == BluetoothAttendanceErrorCode.unknown) {
        AttendancePipelineLogger.log(
          AttendancePipelineLogger.offline,
          'bluetooth online failed — enqueue',
          requestId: payload.requestId,
          detail: e.message,
        );
        return _enqueueOfflineSubmission(payload);
      }
      rethrow;
    } on QrAttendanceException {
      rethrow;
    } catch (e) {
      AttendancePipelineLogger.log(
        AttendancePipelineLogger.offline,
        'online path failed — enqueue',
        requestId: payload.requestId,
        detail: '$e',
      );
      return _enqueueOfflineSubmission(payload);
    }
  }

  Future<AttendanceSubmissionResult> _enqueueOfflineSubmission(
    AttendancePayload payload,
  ) async {
    await _offlineBridge.enqueue(payload);
    unawaited(OfflineSyncEngine.instance.runStartupSyncSequence());
    return AttendanceSubmissionResult(
      success: true,
      outcome: AttendanceSubmissionOutcome.queuedOffline,
      source: payload.source,
      message: 'Attendance queued for sync.',
      requestId: payload.requestId,
      queuedCount: 1,
    );
  }

  Future<
      ({
        String? message,
        String? recordId,
        AttendanceSessionSnapshot? sessionSnapshot,
      })> _applyOnlineFirst(
    AttendancePayload payload,
  ) async {
    switch (payload.source) {
      case AttendanceSource.nfc:
        final r = await _nfc.submitOnline(payload);
        return (
          message: r.message,
          recordId: r.recordId,
          sessionSnapshot: r.sessionSnapshot,
        );
      case AttendanceSource.bluetooth:
        final r = await _bluetooth.submitOnline(payload);
        return (
          message: r.message,
          recordId: r.recordId,
          sessionSnapshot: r.sessionSnapshot,
        );
      case AttendanceSource.manual:
        throw UnsupportedError('Use submitManualBatch for manual UI saves.');
      case AttendanceSource.qr:
        throw UnsupportedError('QR must not use offline-capable path.');
    }
  }
}
