import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/lecturer/unified_lecturer_catalog.dart';

/// Cache-first lecturer sections + course metadata (not attendance / NFC).
class LecturerCatalogRepository {
  LecturerCatalogRepository({
    FirebaseFirestore? firestore,
    Box<dynamic>? catalogBox,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _catalogBox = catalogBox;

  static final LecturerCatalogRepository instance = LecturerCatalogRepository._();
  LecturerCatalogRepository._()
      : _firestore = FirebaseFirestore.instance,
        _catalogBox = null;

  final FirebaseFirestore _firestore;
  final Box<dynamic>? _catalogBox;

  static const String boxName = 'lecturerCatalogBox';
  static const String _sectionsCollection = 'sections';
  static const String _coursesCollection = 'courses';

  Box<dynamic> get _box {
    final b = _catalogBox ?? Hive.box<dynamic>(boxName);
    return b;
  }

  UnifiedLecturerCatalog? getCachedCatalog(String lecturerId) {
    final key = lecturerId.trim();
    if (key.isEmpty || !_box.isOpen) return null;
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      if (raw is Map) {
        return UnifiedLecturerCatalog.fromHiveMap(
          Map<String, dynamic>.from(raw),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCatalog(String lecturerId, UnifiedLecturerCatalog catalog) async {
    final key = lecturerId.trim();
    if (key.isEmpty) return;
    await _box.put(key, catalog.toHiveMap());
  }

  /// Hive-first: return cache immediately when present and refresh in background.
  Future<UnifiedLecturerCatalog> getCatalogForLecturer(String lecturerId) async {
    final id = lecturerId.trim();
    if (id.isEmpty) return UnifiedLecturerCatalog.empty();

    final cached = getCachedCatalog(id);
    if (cached != null && !cached.isEmpty) {
      unawaited(_refreshFromFirestoreAndCache(id));
      return cached;
    }

    final fresh = await _fetchFromFirestore(id);
    await saveCatalog(id, fresh);
    return fresh;
  }

  Future<void> _refreshFromFirestoreAndCache(String lecturerId) async {
    try {
      final fresh = await _fetchFromFirestore(lecturerId);
      await saveCatalog(lecturerId, fresh);
    } catch (_) {}
  }

  Future<UnifiedLecturerCatalog> _fetchFromFirestore(String lecturerId) async {
    final snapshot = await _firestore
        .collection(_sectionsCollection)
        .where('lecturerId', isEqualTo: lecturerId)
        .get();

    final courseCodes = <String>{};
    for (final doc in snapshot.docs) {
      final code = (doc.data()['courseCode'] ?? '').toString().trim();
      if (code.isNotEmpty) courseCodes.add(code);
    }

    final courseMaps = await _fetchCourseMapsParallel(courseCodes);

    final rows = <LecturerCatalogRow>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['isActive'] == false) continue;

      final courseCode = (data['courseCode'] ?? '').toString().trim();
      final courseDoc = courseCode.isEmpty ? null : courseMaps[courseCode];
      final names = _namesFromSectionAndCourse(data, courseDoc);

      rows.addAll(
        _sectionDocToRows(
          doc.id,
          data,
          courseNameAr: names.$1,
          courseNameEn: names.$2,
        ),
      );
    }

    return UnifiedLecturerCatalog(rows: rows);
  }

  /// Parallel document reads (no sequential N+1 loop).
  Future<Map<String, Map<String, dynamic>>> _fetchCourseMapsParallel(
    Set<String> courseCodes,
  ) async {
    if (courseCodes.isEmpty) return {};
    final snaps = await Future.wait(
      courseCodes.map(
        (c) => _firestore.collection(_coursesCollection).doc(c).get(),
      ),
    );
    final out = <String, Map<String, dynamic>>{};
    for (final s in snaps) {
      if (!s.exists) continue;
      final d = s.data();
      if (d == null) continue;
      out[s.id] = Map<String, dynamic>.from(d);
    }
    return out;
  }

  (String, String) _namesFromSectionAndCourse(
    Map<String, dynamic> section,
    Map<String, dynamic>? course,
  ) {
    final sectionAr =
        (section['courseName_Ar'] ?? section['courseNameAr'] ?? '')
            .toString()
            .trim();
    final sectionEn =
        (section['courseName'] ?? section['courseNameEn'] ?? '')
            .toString()
            .trim();

    final courseAr = course == null
        ? ''
        : (course['courseName_Ar'] ??
                course['courseNameAr'] ??
                course['nameAr'] ??
                '')
            .toString()
            .trim();
    final courseEn = course == null
        ? ''
        : (course['courseName'] ??
                course['courseNameEn'] ??
                course['nameEn'] ??
                '')
            .toString()
            .trim();

    final nameAr =
        sectionAr.isNotEmpty ? sectionAr : (courseAr.isNotEmpty ? courseAr : '');
    final nameEn =
        sectionEn.isNotEmpty ? sectionEn : (courseEn.isNotEmpty ? courseEn : '');
    return (nameAr, nameEn);
  }

  List<LecturerCatalogRow> _sectionDocToRows(
    String sectionDocId,
    Map<String, dynamic> data, {
    required String courseNameAr,
    required String courseNameEn,
  }) {
    final schedule = data['schedule'] as List<dynamic>?;
    if (schedule == null || schedule.isEmpty) return [];

    final courseCode = (data['courseCode'] ?? '').toString().trim();
    final sectionNum = sectionDocId.contains('-')
        ? sectionDocId.split('-').last
        : '1';

    final items = <LecturerCatalogRow>[];
    for (final e in schedule) {
      final m = Map<String, dynamic>.from(
        e is Map ? e as Map<String, dynamic> : <String, dynamic>{},
      );
      final dayOfWeek = _parseInt(m['dayOfWeek'], 1);
      if (dayOfWeek < 1 || dayOfWeek > 7) continue;

      var startTime = (m['startTime'] ?? '08:00').toString().trim();
      var endTime = (m['endTime'] ?? '10:00').toString().trim();
      startTime = _normalizeTime(startTime);
      endTime = _normalizeTime(endTime);

      final hall = (m['hall'] ?? '').toString().trim();
      final activity = (m['activity'] ?? 'نظري').toString().trim();
      final locationRaw = (m['location'] ?? m['مقر'] ?? '').toString().trim();

      final durationMinutes = _durationMinutes(startTime, endTime);
      final isDouble = durationMinutes >= 90;

      items.add(
        LecturerCatalogRow(
          sectionId: sectionDocId,
          courseCode: courseCode,
          courseNameAr: courseNameAr,
          courseNameEn: courseNameEn,
          sectionNum: sectionNum,
          dayOfWeek: dayOfWeek,
          startTime: startTime,
          scheduleEndTime: endTime,
          hall: hall,
          activity: activity,
          location: locationRaw.isNotEmpty ? locationRaw : null,
          isDouble: isDouble,
        ),
      );
    }
    return items;
  }

  int _parseInt(dynamic v, int fallback) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  String _normalizeTime(String time) {
    final parts = time.split(':');
    if (parts.isEmpty) return '08:00';
    final hour = int.tryParse(parts[0].trim()) ?? 8;
    final minute = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  int _durationMinutes(String start, String end) {
    final (sh, sm) = _parseTime(start);
    final (eh, em) = _parseTime(end);
    return (eh * 60 + em) - (sh * 60 + sm);
  }

  (int, int) _parseTime(String time) {
    final parts = time.split(':');
    final h = parts.isNotEmpty ? (int.tryParse(parts[0].trim()) ?? 0) : 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
    return (h, m);
  }
}
