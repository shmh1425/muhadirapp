import '../../models/calendar_day.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../utils/hijri_converter.dart';

/// Service لإدارة منطق التقويم وحالة الأيام
class CalendarService {
  final LectureRepository _repository;

  CalendarService(this._repository);

  /// بناء بيانات التقويم من المحاضرات
  List<CalendarDay> buildCalendarDays(
    DateTime currentMonth,
    List<LectureItem> allLectures,
  ) {
    final List<CalendarDay> calendarDays = [];
    final now = _repository.currentDateTime;
    // مقارنة بالتاريخ فقط بدون الوقت
    final today = DateTime(now.year, now.month, now.day);

    // الحصول على آخر يوم في الشهر الحالي
    final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0);

    // إنشاء بيانات لكل يوم في الشهر
    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      final hijriInfo = HijriConverter.gregorianToHijri(date);

      // العطلة: لا محاضرات ولا نقاط (جمعة/سبت + عطلات رسمية)
      final isHoliday = _repository.isHoliday(date);
      final holidayType = isHoliday
          ? _repository.holidayTypeForDate(date)
          : null;
      final dayOfWeek = date.weekday;
      final lecturesForDay = isHoliday
          ? <LectureItem>[]
          : allLectures
                .where((lecture) => lecture.dayOfWeek == dayOfWeek)
                .toList();
      final lecturesCount = lecturesForDay.length;

      // تحديد الحالة حسب الأولوية
      final status = _determineDayStatus(
        date: date,
        today: today,
        lecturesCount: lecturesCount,
      );

      calendarDays.add(
        CalendarDay(
          date: date,
          hijriDay: hijriInfo['day'] as int,
          hijriMonthName: hijriInfo['monthName'] as String,
          hijriYear: hijriInfo['year'] as int,
          lecturesCount: lecturesCount,
          status: status,
          holidayType: holidayType,
        ),
      );
    }

    return calendarDays;
  }

  /// تحديد حالة اليوم حسب الأولوية
  /// 1) اليوم الحالي (أخضر غامق) → أعلى أولوية
  /// 2) عطلة رسمية من Firebase
  /// 3) أي يوم فيه محاضرات وليس عطلة:
  ///    - ماضي: قابل للتعديل
  ///    - مستقبل: مقفل حتى يحين يومه
  /// 4) افتراضي (بدون تلوين)
  DayStatus _determineDayStatus({
    required DateTime date,
    required DateTime today,
    required int lecturesCount,
  }) {
    final bool isToday = date.isAtSameMomentAs(today);
    final bool isHoliday = _repository.isHoliday(date);
    final bool isFuture = date.isAfter(today);
    final bool isPast = date.isBefore(today);

    if (isToday) {
      // اليوم الحالي → أعلى أولوية
      return DayStatus.today;
    }

    if (isHoliday) {
      // عطلة رسمية → ثاني أولوية
      return DayStatus.holiday;
    }

    if (lecturesCount > 0 && isFuture) {
      // مستقبل مع محاضرات: مغلق حتى يحين يومه.
      return DayStatus.futureLocked;
    }

    if (isPast && lecturesCount > 0) {
      // أي يوم ماضي وفيه محاضرات (وليس عطلة): قابل للتعديل.
      return DayStatus.editable;
    }

    // يوم طبيعي بدون محاضرات
    return DayStatus.none;
  }
}
