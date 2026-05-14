/// Machine-readable result of a campus geo-fence check (no user-facing copy).
enum GeoFenceOutcome {
  /// Current coordinates lie inside the configured campus polygon.
  inside,

  /// GPS fix obtained but point is outside the allowed polygon.
  outsideCampus,

  /// Location permission not granted (includes denied forever).
  permissionDenied,

  /// OS location services (GPS) are turned off.
  locationServiceDisabled,

  /// Could not obtain a fix: timeout, error, unsupported platform, etc.
  locationUnavailable,
}
