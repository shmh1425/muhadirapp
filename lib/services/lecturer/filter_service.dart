import '../../models/lecturer/lecture_item.dart';

/// Service لإدارة منطق الفلترة
class FilterService {
  /// الحصول على التاريخ المطلوب حسب الفلتر
  static DateTime getSelectedDate(String filter) {
    final now = DateTime.now();
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
    String selectedFilter,
  ) {
    if (selectedFilter == 'الكل') {
      return allLectures;
    }

    final targetWeekday = getSelectedDate(selectedFilter).weekday;
    return allLectures
        .where((lecture) => lecture.dayOfWeek == targetWeekday)
        .toList();
  }

  /// الحصول على عنوان القسم حسب الفلتر
  static String getSectionTitle(String filter) {
    switch (filter) {
      case 'غدًا':
        return 'محاضرات الغد';
      case 'الكل':
        return 'جميع المحاضرات';
      default: // 'اليوم'
        return 'محاضرات اليوم';
    }
  }
}

