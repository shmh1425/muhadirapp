/// Centralized operation identity for queue dedup and sync (Phase 3.6).
///
/// All operation-key string building must go through this file.
abstract final class AttendanceOperationIdentity {
  static const String payloadField = 'operationKey';

  /// Dedup key: `sessionId_studentId_source_status`.
  static String buildOperationKey({
    required String sessionId,
    required int studentId,
    required String attendanceStatus,
    String source = 'manual',
  }) {
    final session = sessionId.trim();
    final status = attendanceStatus.trim().toLowerCase();
    final channel = source.trim().toLowerCase();
    return '${session}_${studentId}_${channel}_$status';
  }

  /// Stable sync tracking id (operation id + optional dedup key).
  static String buildSyncIdentity({
    required String operationId,
    String? operationKey,
  }) {
    final id = operationId.trim();
    final key = operationKey?.trim();
    if (key != null && key.isNotEmpty) return '$id::$key';
    return id;
  }

  /// Parses and normalizes payload identity (session/student/source/status).
  static NormalizedAttendanceIdentity? normalizeAttendanceIdentity(
    Map<String, dynamic> payload,
  ) {
    final map = Map<String, dynamic>.from(payload);
    var sessionId = (map['sessionId'] ?? '').toString().trim();
    final studentId = _parseStudentId(map['studentId']);
    final status =
        (map['attendanceStatus'] ?? '').toString().trim().toLowerCase();
    final source = (map['source'] ?? 'manual').toString().trim();

    if (sessionId.isEmpty) {
      final card = (map['lecturerCardId'] ?? '').toString().trim();
      if (card.isNotEmpty && source == 'nfc') {
        sessionId = 'nfc_$card';
      } else if (source == 'bluetooth') {
        sessionId = (map['sessionIdHash'] ?? 'bt_pending').toString().trim();
      }
    }

    if (sessionId.isEmpty || studentId <= 0 || status.isEmpty) {
      return null;
    }

    final operationKey = buildOperationKey(
      sessionId: sessionId,
      studentId: studentId,
      attendanceStatus: status,
      source: source.isEmpty ? 'manual' : source,
    );

    return NormalizedAttendanceIdentity(
      sessionId: sessionId,
      studentId: studentId,
      attendanceStatus: status,
      source: source.isEmpty ? 'manual' : source,
      operationKey: operationKey,
    );
  }

  static String? operationKeyFromPayload(Map<String, dynamic> payload) {
    final embedded = payload[payloadField]?.toString().trim();
    if (embedded != null && embedded.isNotEmpty) return embedded;
    return normalizeAttendanceIdentity(payload)?.operationKey;
  }

  static Map<String, dynamic> embedInPayload(Map<String, dynamic> payload) {
    final map = Map<String, dynamic>.from(payload);
    final key = operationKeyFromPayload(map);
    if (key != null) {
      map[payloadField] = key;
    }
    return map;
  }

  /// Firestore manual record document id (schema unchanged).
  static String recordDocId({
    required String sessionId,
    required int studentId,
  }) =>
      '${sessionId.trim()}_$studentId';

  static int _parseStudentId(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString()) ?? 0;
  }
}

class NormalizedAttendanceIdentity {
  const NormalizedAttendanceIdentity({
    required this.sessionId,
    required this.studentId,
    required this.attendanceStatus,
    required this.source,
    required this.operationKey,
  });

  final String sessionId;
  final int studentId;
  final String attendanceStatus;
  final String source;
  final String operationKey;
}
