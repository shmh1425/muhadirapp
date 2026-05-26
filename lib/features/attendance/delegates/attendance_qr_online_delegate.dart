import '../../../services/attendance/qr_attendance_service.dart';
import '../attendance_payload.dart';
import '../attendance_pipeline_logger.dart';
import '../attendance_session_snapshot.dart';

class AttendanceQrOnlineDelegateResult {
  const AttendanceQrOnlineDelegateResult({
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

/// QR online-only delegate — Firestore via existing QR service.
class AttendanceQrOnlineDelegate {
  AttendanceQrOnlineDelegate._();
  static final AttendanceQrOnlineDelegate instance =
      AttendanceQrOnlineDelegate._();

  Future<AttendanceQrOnlineDelegateResult> submit(AttendancePayload payload) async {
    final meta = payload.metadata ?? <String, dynamic>{};
    AttendancePipelineLogger.log(
      AttendancePipelineLogger.qr,
      'online-only submit',
      requestId: payload.requestId,
      sessionId: payload.sessionId,
    );
    if (meta.containsKey('sessionId') &&
        meta.containsKey('sectionId') &&
        meta.containsKey('tokenId')) {
      final result = await QrAttendanceService.instance.submitAttendanceFromQrPayload(
        Map<String, dynamic>.from(meta),
        currentTime: payload.timestamp.toLocal(),
      );
      return AttendanceQrOnlineDelegateResult(
        success: result.success,
        message: result.message,
        recordId: result.recordId,
        sessionSnapshot: AttendanceSessionSnapshot.fromQr(result.session),
      );
    }
    final numericCode = (meta['numericCode'] ?? '').toString().trim();
    if (numericCode.isNotEmpty) {
      final result =
          await QrAttendanceService.instance.submitAttendanceFromNumericCode(
        numericCode,
        currentTime: payload.timestamp.toLocal(),
      );
      return AttendanceQrOnlineDelegateResult(
        success: result.success,
        message: result.message,
        recordId: result.recordId,
        sessionSnapshot: AttendanceSessionSnapshot.fromQr(result.session),
      );
    }
    throw ArgumentError('QR metadata must include QR payload or numericCode.');
  }
}
