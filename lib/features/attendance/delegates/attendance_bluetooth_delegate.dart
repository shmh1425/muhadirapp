import '../../../services/attendance/bluetooth_attendance_service.dart';
import '../attendance_payload.dart';
import '../attendance_pipeline_logger.dart';
import '../attendance_session_snapshot.dart';

class AttendanceBluetoothDelegateResult {
  const AttendanceBluetoothDelegateResult({
    required this.success,
    required this.message,
    this.recordId,
    this.sessionSnapshot,
  });

  final bool success;
  final String message;
  final String? recordId;
  final AttendanceSessionSnapshot? sessionSnapshot;
}

/// Online Firestore path for Bluetooth (invoked only from unified service).
class AttendanceBluetoothDelegate {
  AttendanceBluetoothDelegate._();
  static final AttendanceBluetoothDelegate instance =
      AttendanceBluetoothDelegate._();

  Future<AttendanceBluetoothDelegateResult> submitOnline(
    AttendancePayload payload,
  ) async {
    final meta = payload.metadata ?? <String, dynamic>{};
    AttendancePipelineLogger.log(
      AttendancePipelineLogger.bt,
      'online submit',
      requestId: payload.requestId,
      sessionId: payload.sessionId,
    );
    final result = await BluetoothAttendanceService.instance
        .submitAttendanceFromBluetoothSignal(
      sessionId: (meta['sessionId'] ?? payload.sessionId).toString(),
      bluetoothSessionToken: meta['bluetoothSessionToken']?.toString(),
      sessionIdHash: meta['sessionIdHash']?.toString(),
      tokenFragment: meta['tokenFragment']?.toString(),
      tokenVersion: _safeInt(meta['tokenVersion']),
      detectedSignalStrength: _safeInt(meta['detectedSignalStrength']),
      detectedSignalId: meta['detectedSignalId']?.toString(),
      rawPayload: meta['rawPayload']?.toString(),
      currentTime: payload.timestamp.toLocal(),
    );
    return AttendanceBluetoothDelegateResult(
      success: result.success,
      message: result.message,
      recordId: result.recordId,
      sessionSnapshot: AttendanceSessionSnapshot.fromBluetooth(result.session),
    );
  }

  static int? _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString());
  }
}
