/// Geographic point for campus boundary math (latitude, longitude in WGS84).
class CampusLatLng {
  const CampusLatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Expanded campus boundary for Security Gate geo-fencing (buffered polygon).
///
/// The polygon is intentionally **slightly expanded** relative to a strict campus
/// outline to act as a **buffer**: consumer GPS (especially near buildings) can
/// drift tens of meters, so a tight boundary would cause false rejections.
/// Adjust vertices only with campus GIS data and stakeholder sign-off.
///
/// Vertices are ordered along the perimeter (polygon is **closed**: the last
/// vertex connects back to the first). Ray-casting assumes this order.
const List<CampusLatLng> campusPolygon = <CampusLatLng>[
  CampusLatLng(21.440300, 39.811200),
  CampusLatLng(21.441700, 39.810900),
  CampusLatLng(21.441100, 39.807000),
  CampusLatLng(21.439000, 39.807200),
];
