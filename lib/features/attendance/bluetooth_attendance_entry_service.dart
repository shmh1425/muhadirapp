import 'attendance_entry_point.dart';
import 'attendance_source.dart';
import 'attendance_submission_result.dart';
import 'attendance_pipeline_logger.dart';

/// Bluetooth signal forwarding — no Firestore/queue access.
abstract final class BluetoothAttendanceEntryService {
  static Future<AttendanceSubmissionResult> submitFromSignal({
    required String sessionId,
    required String courseId,
    required String studentId,
    String? requestId,
    String? bluetoothSessionToken,
    String? sessionIdHash,
    String? tokenFragment,
    int? tokenVersion,
    int? detectedSignalStrength,
    String? detectedSignalId,
    String? rawPayload,
  }) async {
    AttendancePipelineLogger.log(
      AttendancePipelineLogger.bt,
      'forward to entry point',
      requestId: requestId,
      sessionId: sessionId,
    );
    return AttendanceEntryPoint.submit(
      source: AttendanceSource.bluetooth,
      sessionId: sessionId,
      studentId: studentId,
      courseId: courseId,
      requestId: requestId,
      attendanceStatus: 'present',
      metadata: <String, dynamic>{
        'sessionId': sessionId,
        if (bluetoothSessionToken != null)
          'bluetoothSessionToken': bluetoothSessionToken,
        if (sessionIdHash != null) 'sessionIdHash': sessionIdHash,
        if (tokenFragment != null) 'tokenFragment': tokenFragment,
        if (tokenVersion != null) 'tokenVersion': tokenVersion,
        if (detectedSignalStrength != null)
          'detectedSignalStrength': detectedSignalStrength,
        if (detectedSignalId != null) 'detectedSignalId': detectedSignalId,
        if (rawPayload != null) 'rawPayload': rawPayload,
      },
    );
  }
}
