import 'campus_geo_constants.dart';

/// One campus branch with a geo-fence polygon and schedule-location aliases.
class CampusGeoDefinition {
  const CampusGeoDefinition({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.polygon,
    this.scheduleLocationAliases = const <String>[],
  });

  final String id;
  final String nameAr;
  final String nameEn;

  /// Empty ⇒ geo-fence not enforced until coordinates are configured.
  final List<CampusLatLng> polygon;

  /// Values from `sections.schedule[].location` / `مقر` that map to [id].
  final List<String> scheduleLocationAliases;

  bool get hasPolygon => polygon.length >= 3;
}

/// Registered campus branches (add polygons here when GIS is ready).
class CampusGeoRegistry {
  CampusGeoRegistry._();

  static const String alZaherCampusId = 'zaher';

  static const String alAbdiyaCampusId = 'abdiya';

  static final CampusGeoDefinition alZaher = CampusGeoDefinition(
    id: alZaherCampusId,
    nameAr: 'الزاهر',
    nameEn: 'Al-Zaher',
    polygon: alZaherCampusPolygon,
    scheduleLocationAliases: <String>[
      'الزاهر',
      'زاهر',
      'al-zaher',
      'al zaher',
      'zaher',
    ],
  );

  static final CampusGeoDefinition alAbdiya = CampusGeoDefinition(
    id: alAbdiyaCampusId,
    nameAr: 'العابدية',
    nameEn: 'Al-Abdiya',
    polygon: alAbdiyaCampusPolygon,
    scheduleLocationAliases: <String>[
      'العابدية',
      'العبيدية',
      'عابدية',
      'عبيدية',
      'al-abdiya',
      'al abdiya',
      'al-abidiyah',
      'abdiya',
      'abdia',
      'abidiyah',
    ],
  );

  static final List<CampusGeoDefinition> all = <CampusGeoDefinition>[
    alZaher,
    alAbdiya,
  ];

  /// Gate card: الزاهر polygon + العابدية gate outline (incl. شطر الطالبات west bulge).
  static final CampusGeoDefinition alAbdiyaGate = CampusGeoDefinition(
    id: alAbdiyaCampusId,
    nameAr: 'العابدية',
    nameEn: 'Al-Abdiya',
    polygon: alAbdiyaGateEnvelopePolygon,
    scheduleLocationAliases: alAbdiya.scheduleLocationAliases,
  );

  /// Girls security gate only — not derived from timetable.
  static List<CampusGeoDefinition> get gateGeoFenceCampuses => <CampusGeoDefinition>[
    alZaher,
    alAbdiyaGate,
  ];

  static Set<String> get gateGeoFenceCampusIds =>
      gateGeoFenceCampuses.map((c) => c.id).toSet();

  static CampusGeoDefinition? byId(String? campusId) {
    final id = normalizeCampusId(campusId);
    if (id.isEmpty) return null;
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  static String normalizeCampusId(String? raw) {
    return (raw ?? '').trim().toLowerCase().replaceAll(' ', '_');
  }

  static String _normalizeLocationLabel(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Maps a schedule `location` / `مقر` label to a registered [CampusGeoDefinition.id].
  static String? campusIdForScheduleLocation(String? location) {
    final label = _normalizeLocationLabel(location ?? '');
    if (label.isEmpty) return null;

    for (final campus in all) {
      for (final alias in campus.scheduleLocationAliases) {
        final a = _normalizeLocationLabel(alias);
        if (a.isEmpty) continue;
        if (label == a || label.contains(a)) {
          return campus.id;
        }
      }
    }

    if (label.contains('زاهر') || label.contains('zaher')) {
      return alZaherCampusId;
    }
    if (label.contains('عابد') ||
        label.contains('عبيد') ||
        label.contains('abdiya') ||
        label.contains('abdia') ||
        label.contains('abidiyah')) {
      return alAbdiyaCampusId;
    }

    return null;
  }

  /// Reads `campusId` / `campusName` / gate fields on `external_students`.
  static String? campusIdFromStudentFields(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return null;

    String first(List<String> keys) {
      for (final key in keys) {
        final v = data[key]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    final explicitId = normalizeCampusId(
      first(const [
        'gateCampusId',
        'gate_campus_id',
        'campusId',
        'campus_id',
        'branchId',
        'branch_id',
      ]),
    );
    if (explicitId.isNotEmpty) {
      if (byId(explicitId) != null) return explicitId;
      if (explicitId == 'alzaher' ||
          explicitId == 'al_zaher' ||
          explicitId == 'al-zaher') {
        return alZaherCampusId;
      }
      if (explicitId == 'alabdiya' ||
          explicitId == 'al_abdiya' ||
          explicitId == 'al-abdiya' ||
          explicitId == 'alabdia' ||
          explicitId == 'alabidiyah' ||
          explicitId == 'abidiyah') {
        return alAbdiyaCampusId;
      }
    }

    final name = first(const [
      'gateCampusName',
      'gate_campus_name',
      'campusName',
      'campus_name',
      'campus',
      'branch',
      'branchName',
      'branch_name',
      'فرع',
      'الفرع',
    ]);
    return campusIdForScheduleLocation(name);
  }

  static List<CampusGeoDefinition> definitionsForCampusIds(
    Iterable<String> campusIds,
  ) {
    final out = <CampusGeoDefinition>[];
    final seen = <String>{};
    for (final raw in campusIds) {
      final def = byId(raw);
      if (def == null || !seen.add(def.id)) continue;
      out.add(def);
    }
    return out;
  }
}
