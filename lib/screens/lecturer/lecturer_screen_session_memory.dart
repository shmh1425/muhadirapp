import '../../models/lecturer/lecture_item.dart';

/// In-memory snapshot for lecturer screens (per app session). Cleared on logout.
class LecturerManageScreenSessionMemory {
  LecturerManageScreenSessionMemory._();

  static String? _lecturerId;
  static List<LectureItem>? _lectures;
  static int? _selectedWeekNumber;
  static DateTime? _selectedDate;
  static String? _selectedCourseCode;
  static Set<String>? _selectedLectureKeys;

  static bool canRestore(String lecturerId) {
    final id = lecturerId.trim();
    if (id.isEmpty) return false;
    final list = _lectures;
    if (list == null || list.isEmpty) return false;
    if (_lecturerId != id) return false;
    return true;
  }

  static LecturerManageScreenRestore? takeRestore(String lecturerId) {
    if (!canRestore(lecturerId)) return null;
    return LecturerManageScreenRestore(
      lectures: List<LectureItem>.from(_lectures!),
      selectedWeekNumber: _selectedWeekNumber,
      selectedDate: _selectedDate,
      selectedCourseCode: _selectedCourseCode,
      selectedLectureKeys: _selectedLectureKeys == null
          ? <String>{}
          : Set<String>.from(_selectedLectureKeys!),
    );
  }

  static void save({
    required String lecturerId,
    required List<LectureItem> lectures,
    int? selectedWeekNumber,
    DateTime? selectedDate,
    String? selectedCourseCode,
    required Set<String> selectedLectureKeys,
  }) {
    final id = lecturerId.trim();
    if (id.isEmpty || lectures.isEmpty) return;
    _lecturerId = id;
    _lectures = List<LectureItem>.from(lectures);
    _selectedWeekNumber = selectedWeekNumber;
    _selectedDate = selectedDate;
    _selectedCourseCode = selectedCourseCode;
    _selectedLectureKeys = Set<String>.from(selectedLectureKeys);
  }

  static void clear() {
    _lecturerId = null;
    _lectures = null;
    _selectedWeekNumber = null;
    _selectedDate = null;
    _selectedCourseCode = null;
    _selectedLectureKeys = null;
  }
}

class LecturerManageScreenRestore {
  const LecturerManageScreenRestore({
    required this.lectures,
    required this.selectedWeekNumber,
    required this.selectedDate,
    required this.selectedCourseCode,
    required this.selectedLectureKeys,
  });

  final List<LectureItem> lectures;
  final int? selectedWeekNumber;
  final DateTime? selectedDate;
  final String? selectedCourseCode;
  final Set<String> selectedLectureKeys;
}
