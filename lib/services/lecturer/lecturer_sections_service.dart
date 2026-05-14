import 'package:flutter/foundation.dart';

import '../../models/lecturer/lecture_item.dart';
import '../../repositories/lecturer_catalog_repository.dart';
import '../../screens/lecturer/lecturer_language.dart';
import '../lecturer_auth_service.dart';

/// Back-compat facade: delegates to [LecturerCatalogRepository] (Hive + parallel course reads).
///
/// Prefer [lecturerUnifiedCatalogProvider] in UI for a single in-flight load via Riverpod.
class LecturerSectionsService {
  LecturerSectionsService._();
  static final LecturerSectionsService instance = LecturerSectionsService._();

  final LecturerCatalogRepository _repo = LecturerCatalogRepository.instance;
  List<LectureItem> _cachedLectures = <LectureItem>[];

  /// معرّف المحاضر الحالي من [LecturerAuthService]. null إذا لم يكن محاضراً مسجلاً.
  String? get currentLecturerId {
    final lecturer = LecturerAuthService.instance.currentLecturer;
    return lecturer?.lecturerId;
  }

  /// آخر قائمة محاضرات ناجحة تم جلبها لنفس المحاضر ضمن الجلسة الحالية.
  List<LectureItem> get cachedLectures =>
      List<LectureItem>.unmodifiable(_cachedLectures);

  /// جلب جميع محاضرات المحاضر الحالي من الـ sections المرتبطة به.
  Future<List<LectureItem>> getLecturesForCurrentLecturer() async {
    final lecturerId = currentLecturerId;
    if (lecturerId == null || lecturerId.isEmpty) {
      debugPrint(
        '[LecturerSectionsService] empty lecturerId; returning cached lectures '
        'count=${_cachedLectures.length}',
      );
      return List<LectureItem>.from(_cachedLectures);
    }

    try {
      final catalog = await _repo.getCatalogForLecturer(lecturerId);
      final list = catalog.toLectureItems(
        isArabic: LecturerLanguageController.isArabic,
      );
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
    } catch (e, st) {
      debugPrint('[LecturerSectionsService] getCatalog failed: $e\n$st');
      if (_cachedLectures.isNotEmpty) {
        return List<LectureItem>.from(_cachedLectures);
      }
      rethrow;
    }
  }
}
