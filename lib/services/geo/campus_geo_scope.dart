import 'campus_geo_registry.dart';

/// Back-compat helpers around [CampusGeoRegistry].
class CampusGeoScope {
  CampusGeoScope._();

  static const String alZaherCampusId = CampusGeoRegistry.alZaherCampusId;

  @Deprecated('Use schedule / gate campus resolution via StudentCampusGeoGuard.')
  static bool studentRequiresAlZaherGeoFence(Map<String, dynamic>? data) {
    final id = CampusGeoRegistry.campusIdFromStudentFields(data);
    return id == alZaherCampusId;
  }
}
