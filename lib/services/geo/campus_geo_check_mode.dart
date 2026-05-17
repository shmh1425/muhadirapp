/// How campus geo-fencing is chosen before a location check.
enum CampusGeoCheckMode {
  /// Attendance QR: campuses from **today's** schedule `location` / مقر (NFC/BT exempt).
  todaySchedule,

  /// Attendance fallback: every enrolled weekly slot location.
  allSchedule,

  /// Girls security gate card — **not** tied to schedule or student profile.
  /// Valid inside any campus in [CampusGeoRegistry.gateGeoFenceCampusIds].
  girlsSecurityGate,
}
