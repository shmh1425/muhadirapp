import '../../services/attendance/attendance_state_versioning.dart';
import 'identity/attendance_operation_identity.dart';
import '../../services/offline/offline_operation_types.dart';
import '../../services/offline/offline_queue_service.dart';
import 'attendance_payload.dart';
import 'attendance_pipeline_logger.dart';
import 'attendance_source.dart';

/// Enqueues attendance operations into Phase 2B offline engine.
class AttendanceOfflineBridge {
  AttendanceOfflineBridge._();
  static final AttendanceOfflineBridge instance = AttendanceOfflineBridge._();

  final OfflineQueueService _queue = OfflineQueueService.instance;

  String operationTypeFor(AttendanceSource source) {
    switch (source) {
      case AttendanceSource.nfc:
        return OfflineOperationTypes.nfcAttendance;
      case AttendanceSource.bluetooth:
        return OfflineOperationTypes.bluetoothAttendance;
      case AttendanceSource.manual:
        return OfflineOperationTypes.manualAttendance;
      case AttendanceSource.qr:
        throw StateError('QR must never be enqueued.');
    }
  }

  Future<bool> enqueue(AttendancePayload payload) async {
    if (payload.source.isOnlineOnly) {
      throw StateError('QR cannot be enqueued.');
    }
    final queuePayload = AttendanceOperationIdentity.embedInPayload(
      AttendanceStateVersioning.enrichPayload(
        payload.toQueuePayload(),
        clientMutationId: payload.requestId,
      ),
    );
    await _queue.enqueueOrCoalesceByOperationKey(
      type: operationTypeFor(payload.source),
      payload: queuePayload,
    );
    AttendancePipelineLogger.log(
      AttendancePipelineLogger.offline,
      'enqueued',
      requestId: payload.requestId,
      sessionId: payload.sessionId,
      studentId: payload.studentId,
      detail: 'type=${operationTypeFor(payload.source)}',
    );
    return true;
  }
}
