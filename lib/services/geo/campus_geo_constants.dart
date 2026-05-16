/// Geographic point for campus boundary math (latitude, longitude in WGS84).
class CampusLatLng {
  const CampusLatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Buffered boundary polygon for **فرع الزاهر (Al-Zaher)**.
///
/// Registered in [CampusGeoRegistry]. Attendance uses today's schedule `location`;
/// the girls gate uses [CampusGeoCheckMode.girlsSecurityGate] (not the timetable).
///
/// The polygon is intentionally **slightly expanded** relative to a strict campus
/// outline to act as a **buffer**: consumer GPS (especially near buildings) can
/// drift tens of meters, so a tight boundary would cause false rejections.
/// Adjust vertices only with campus GIS data and stakeholder sign-off.
///
/// Vertices are ordered along the perimeter (polygon is **closed**: the last
/// vertex connects back to the first). Ray-casting assumes this order.
const List<CampusLatLng> alZaherCampusPolygon = <CampusLatLng>[
  CampusLatLng(21.440300, 39.811200),
  CampusLatLng(21.441700, 39.810900),
  CampusLatLng(21.441100, 39.807000),
  CampusLatLng(21.439000, 39.807200),
];

/// Tight boundary for **فرع العابدية** (attendance via schedule location).
const List<CampusLatLng> alAbdiyaCampusPolygon = <CampusLatLng>[
  CampusLatLng(21.3560743, 39.9293730),
  CampusLatLng(21.3535619, 39.9259599),
  CampusLatLng(21.3404679, 39.9251754),
  CampusLatLng(21.3186124, 39.9342942),
  CampusLatLng(21.3118496, 39.9470377),
  CampusLatLng(21.3271242, 39.9633328),
];

/// Gate-only outline: [alAbdiyaCampusPolygon] + modest west bulge for شطر الطالبات.
const List<CampusLatLng> alAbdiyaGateEnvelopePolygon = <CampusLatLng>[
  CampusLatLng(21.3560743, 39.9293730),
  CampusLatLng(21.3535619, 39.9259599),
  CampusLatLng(21.3542, 39.9185),
  CampusLatLng(21.3385, 39.9140),
  CampusLatLng(21.3185, 39.9165),
  CampusLatLng(21.3404679, 39.9251754),
  CampusLatLng(21.3186124, 39.9342942),
  CampusLatLng(21.3118496, 39.9470377),
  CampusLatLng(21.3271242, 39.9633328),
];

/// Alias kept for geo-fence math ([GeoFenceService]) — default polygon is Al-Zaher.
const List<CampusLatLng> campusPolygon = alZaherCampusPolygon;
