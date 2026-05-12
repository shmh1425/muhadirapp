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

  /// معرّف المحاضر الحالي من [LecturerAuthService]. null إذا لم يكن محاضراً مسجلاً.
  String? get currentLecturerId {
    final lecturer = LecturerAuthService.instance.currentLecturer;
    return lecturer?.lecturerId;
  }

  /// جلب جميع محاضرات المحاضر الحالي من الـ sections المرتبطة به.
  Future<List<LectureItem>> getLecturesForCurrentLecturer() async {
    final lecturerId = currentLecturerId;
    if (lecturerId == null || lecturerId.isEmpty) return [];

    final catalog = await _repo.getCatalogForLecturer(lecturerId);
    return catalog.toLectureItems(isArabic: LecturerLanguageController.isArabic);
  }
}
