import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/lecturer/lecture_item.dart';
import '../../screens/lecturer/lecturer_language.dart';
import '../lecturer_auth_service.dart';

/// مصدر موحد لمحاضرات المحاضر: يجلب الـ sections المرتبطة بالمحاضر الحالي
/// ويحوّلها إلى قائمة [LectureItem] لاستخدامها في الصفحة الرئيسية، إدارة المحاضرات، والجدول.
class LecturerSectionsService {
  LecturerSectionsService._();
  static final LecturerSectionsService instance = LecturerSectionsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<LectureItem> _cachedLectures = <LectureItem>[];
  static const String _sectionsCollection = 'sections';
  static const String _coursesCollection = 'courses';

  /// معرّف المحاضر الحالي من [LecturerAuthService]. null إذا لم يكن محاضراً مسجلاً.
  String? get currentLecturerId {
    final lecturer = LecturerAuthService.instance.currentLecturer;
    return lecturer?.lecturerId;
  }

  /// آخر قائمة محاضرات ناجحة تم جلبها لنفس المحاضر ضمن الجلسة الحالية.
  List<LectureItem> get cachedLectures =>
      List<LectureItem>.unmodifiable(_cachedLectures);

  /// جلب جميع محاضرات المحاضر الحالي من الـ sections المرتبطة به.
  /// اسم المقرر يُجلب من مجموعة [courses] حسب اللغة الحالية (عربي/إنجليزي).
  Future<List<LectureItem>> getLecturesForCurrentLecturer() async {
    final lecturerId = currentLecturerId;
    if (lecturerId == null || lecturerId.isEmpty) {
      debugPrint(
        '[LecturerSectionsService] empty lecturerId; returning cached lectures '
        'count=${_cachedLectures.length}',
      );
      return List<LectureItem>.from(_cachedLectures);
    }

    final snapshot = await _firestore
        .collection(_sectionsCollection)
        .where('lecturerId', isEqualTo: lecturerId)
        .get();

    final courseCodes = <String>{};
    for (final doc in snapshot.docs) {
      final code = (doc.data()['courseCode'] ?? '').toString().trim();
      if (code.isNotEmpty) courseCodes.add(code);
    }

    final courseCodeToName = await _fetchCourseDisplayNames(courseCodes);

    final list = <LectureItem>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final isActive = data['isActive'];
      if (isActive == false) continue;

      final courseCode = (data['courseCode'] ?? '').toString().trim();
      final displayName = courseCodeToName[courseCode];

      list.addAll(_sectionToLectureItems(doc.id, data, displayName));
    }

    if (list.isNotEmpty) {
      _cachedLectures = List<LectureItem>.from(list);
    } else if (_cachedLectures.isNotEmpty) {
      debugPrint(
        '[LecturerSectionsService] fetched empty list for lecturer=$lecturerId; '
        'using cached count=${_cachedLectures.length}',
      );
      return List<LectureItem>.from(_cachedLectures);
    }

    debugPrint(
      '[LecturerSectionsService] lecturer=$lecturerId fetched lectures='
      '${list.length} cached=${_cachedLectures.length}',
    );
    return list;
  }

  /// جلب أسماء المقررات للعرض حسب اللغة الحالية من مجموعة courses.
  /// يدعم: courseNameAr، courseNameEn، والاحتياطي courseName.
  Future<Map<String, String>> _fetchCourseDisplayNames(
    Set<String> courseCodes,
  ) async {
    final result = <String, String>{};
    if (courseCodes.isEmpty) return result;

    final isArabic = LecturerLanguageController.isArabic;
    for (final code in courseCodes) {
      final doc = await _firestore
          .collection(_coursesCollection)
          .doc(code)
          .get();
      if (!doc.exists || doc.data() == null) continue;
      final d = doc.data()!;
      // Firestore: courseName_Ar للعربي، courseName للإنجليزي
      final nameAr =
          (d['courseName_Ar'] ?? d['courseNameAr'] ?? d['nameAr'] ?? '')
              .toString()
              .trim();
      final nameEn = (d['courseName'] ?? d['courseNameEn'] ?? d['nameEn'] ?? '')
          .toString()
          .trim();
      final fallback = nameAr.isNotEmpty ? nameAr : nameEn;
      final display = isArabic
          ? (nameAr.isNotEmpty
                ? nameAr
                : (nameEn.isNotEmpty ? nameEn : fallback))
          : (nameEn.isNotEmpty
                ? nameEn
                : (nameAr.isNotEmpty ? nameAr : fallback));
      if (display.isNotEmpty) result[code] = display;
    }
    return result;
  }

  /// تحويل وثيقة section واحدة (مع جدولها) إلى قائمة [LectureItem].
  /// [courseDisplayName] اسم المقرر للعرض (من مجموعة courses حسب اللغة)، أو null فيُستخدم courseName من السكشن.
  List<LectureItem> _sectionToLectureItems(
    String sectionDocId,
    Map<String, dynamic> data, [
    String? courseDisplayName,
  ]) {
    final schedule = data['schedule'] as List<dynamic>?;
    if (schedule == null || schedule.isEmpty) return [];

    final courseCode = (data['courseCode'] ?? '').toString().trim();
    final courseName =
        (courseDisplayName != null && courseDisplayName.isNotEmpty)
        ? courseDisplayName
        : (data['courseName'] ?? '').toString().trim();
    final crn = courseCode.isNotEmpty ? courseCode : sectionDocId;
    final sectionNum = sectionDocId.contains('-')
        ? sectionDocId.split('-').last
        : '1';

    final items = <LectureItem>[];
    for (final e in schedule) {
      final m = Map<String, dynamic>.from(
        e is Map ? e as Map<String, dynamic> : <String, dynamic>{},
      );
      final dayOfWeek = _parseInt(m['dayOfWeek'], 1);
      if (dayOfWeek < 1 || dayOfWeek > 7) continue;

      String startTime = (m['startTime'] ?? '08:00').toString().trim();
      String endTime = (m['endTime'] ?? '10:00').toString().trim();
      startTime = _normalizeTime(startTime);
      endTime = _normalizeTime(endTime);

      final hall = (m['hall'] ?? '').toString().trim();
      final activity = (m['activity'] ?? 'نظري').toString().trim();
      final location = (m['location'] ?? m['مقر'] ?? '').toString().trim();

      final durationMinutes = _durationMinutes(startTime, endTime);
      final isDouble = durationMinutes >= 90;

      items.add(
        LectureItem(
          courseName: courseName.isNotEmpty ? courseName : courseCode,
          crn: crn,
          hall: hall.isNotEmpty ? hall : '—',
          section: sectionNum,
          activity: activity.isNotEmpty ? activity : 'نظري',
          startTime: startTime,
          isDouble: isDouble,
          dayOfWeek: dayOfWeek,
          sectionId: sectionDocId,
          location: location.isNotEmpty ? location : null,
          scheduleEndTime: endTime,
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

  /// صيغة وقت "HH:mm" (مثلاً 8:00 -> 08:00)
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
