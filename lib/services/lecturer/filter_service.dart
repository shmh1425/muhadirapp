import '../../models/lecturer/lecture_item.dart';
import '../../screens/lecturer/lecturer_language.dart';

/// Service لإدارة منطق الفلترة
class FilterService {
  /// الحصول على التاريخ المطلوب حسب الفلتر
  static DateTime getSelectedDate(String filter, {DateTime? baseDate}) {
    final now = baseDate ?? DateTime.now();
    switch (filter) {
      case 'غدًا':
        return now.add(const Duration(days: 1));
      case 'الكل':
        return now; // للعرض فقط، لكن سنعرض كل المحاضرات
      default: // 'اليوم'
        return now;
    }
  }

  /// فلترة المحاضرات حسب الفلتر المختار
  static List<LectureItem> filterLectures(
    List<LectureItem> allLectures,
    String selectedFilter, {
    DateTime? baseDate,
  }) {
    if (selectedFilter == 'الكل') {
      return allLectures;
    }

    final targetWeekday = getSelectedDate(
      selectedFilter,
      baseDate: baseDate,
    ).weekday;
    return allLectures
        .where((lecture) => lecture.dayOfWeek == targetWeekday)
        .toList();
  }

  /// الحصول على عنوان القسم حسب الفلتر
  static String getSectionTitle(String filter) {
    switch (filter) {
      case 'غدًا':
        return LecturerLanguageController.tr(
          'محاضرات الغد',
          "Tomorrow's Lectures",
        );
      case 'الكل':
        return LecturerLanguageController.tr('جميع المحاضرات', 'All Lectures');
      default: // 'اليوم'
        return LecturerLanguageController.tr(
          'محاضرات اليوم',
          "Today's Lectures",
        );
    }
  }
}
