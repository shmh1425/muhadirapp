import '../../../services/attendance/nfc_attendance_service.dart';
import '../attendance_payload.dart';
import '../attendance_pipeline_logger.dart';
import '../attendance_session_snapshot.dart';

class AttendanceNfcDelegateResult {
  const AttendanceNfcDelegateResult({
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

/// Online Firestore path for NFC (invoked only from unified service).
class AttendanceNfcDelegate {
  AttendanceNfcDelegate._();
  static final AttendanceNfcDelegate instance = AttendanceNfcDelegate._();

  Future<AttendanceNfcDelegateResult> submitOnline(AttendancePayload payload) async {
    final meta = payload.metadata ?? <String, dynamic>{};
    final lecturerCardId =
        (meta['lecturerCardId'] ?? '').toString().trim();
    final studentId = payload.studentIdInt;
    if (lecturerCardId.isEmpty || studentId == null || studentId <= 0) {
      throw ArgumentError('NFC payload requires lecturerCardId and studentId.');
    }
    AttendancePipelineLogger.log(
      AttendancePipelineLogger.nfc,
      'online submit',
      requestId: payload.requestId,
      studentId: payload.studentId,
    );
    final result = await NfcAttendanceService.instance.submitAttendanceFromCard(
      lecturerCardId: lecturerCardId,
      studentId: studentId,
      currentTime: payload.timestamp.toLocal(),
      location: meta['location'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(meta['location'] as Map)
          : null,
    );
    return AttendanceNfcDelegateResult(
      success: result.success,
      message: result.message,
      recordId: result.recordId,
      sessionSnapshot: result.session == null
          ? null
          : AttendanceSessionSnapshot.fromNfc(result.session!),
    );
  }
}
