/// Attendance channel identifiers for the unified pipeline.
enum AttendanceSource {
  nfc,
  bluetooth,
  manual,
  /// Online-only — never uses the offline queue.
  qr,
}

extension AttendanceSourceX on AttendanceSource {
  bool get supportsOfflineQueue =>
      this == AttendanceSource.nfc ||
      this == AttendanceSource.bluetooth ||
      this == AttendanceSource.manual;

  bool get isOnlineOnly => this == AttendanceSource.qr;

  String get wireValue => name;
}
