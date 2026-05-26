/// Display-only attendance sync state (UI layer).
enum AttendanceUIState {
  idle,
  pending,
  syncing,
  synced,
  failed,
}

/// Per student/session UI model (in-memory only).
class AttendanceOperationUIModel {
  const AttendanceOperationUIModel({
    required this.sessionId,
    required this.studentId,
    required this.state,
    required this.lastUpdated,
    this.message,
    this.operationId,
  });

  final String sessionId;
  final String studentId;
  final AttendanceUIState state;
  final DateTime lastUpdated;
  final String? message;
  final String? operationId;

  static String cacheKey(String sessionId, String studentId) =>
      '${sessionId.trim()}_${studentId.trim()}';

  AttendanceOperationUIModel copyWith({
    AttendanceUIState? state,
    DateTime? lastUpdated,
    String? message,
    String? operationId,
  }) {
    return AttendanceOperationUIModel(
      sessionId: sessionId,
      studentId: studentId,
      state: state ?? this.state,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      message: message ?? this.message,
      operationId: operationId ?? this.operationId,
    );
  }

  bool get isActiveSync =>
      state == AttendanceUIState.pending ||
      state == AttendanceUIState.syncing ||
      state == AttendanceUIState.failed;
}
