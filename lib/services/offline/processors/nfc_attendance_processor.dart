import 'package:flutter/foundation.dart';

import '../../../features/attendance/attendance_payload.dart';
import '../../../services/attendance/nfc_attendance_service.dart';
import '../offline_operation.dart';
import '../offline_operation_types.dart';
import 'offline_operation_processor.dart';

/// Replays queued NFC taps through the existing NFC attendance service.
class NfcAttendanceProcessor implements OfflineOperationProcessor {
  @override
  String get type => OfflineOperationTypes.nfcAttendance;

  @override
  Future<void> process(OfflineOperation operation) async {
    final payload = AttendancePayload.fromQueueMap(operation.payload);
    final meta = payload.metadata ?? payload.toQueuePayload();
    final lecturerCardId = (meta['lecturerCardId'] ?? '').toString().trim();
    final studentId = payload.studentIdInt;
    if (lecturerCardId.isEmpty || studentId == null || studentId <= 0) {
      throw ArgumentError('Invalid NFC queue payload.');
    }
    await NfcAttendanceService.instance.submitAttendanceFromCard(
      lecturerCardId: lecturerCardId,
      studentId: studentId,
      currentTime: payload.timestamp.toLocal(),
      location: meta['location'] is Map
          ? Map<String, dynamic>.from(meta['location'] as Map)
          : null,
    );
    if (kDebugMode) {
      debugPrint(
        '[ATTENDANCE_SYNC] nfc replay success operationId=${operation.id}',
      );
    }
  }
}
