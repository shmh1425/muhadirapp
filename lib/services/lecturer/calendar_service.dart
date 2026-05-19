import '../../models/calendar_day.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../utils/hijri_converter.dart';

/// Service لإدارة منطق التقويم وحالة الأيام
class CalendarService {
  final LectureRepository _repository;
  static const int _editableWindowDays = 14;

  CalendarService(this._repository);

  /// بناء بيانات التقويم من المحاضرات
  ///
  /// When [applyActiveTermBounds] is true, days outside the active term show no
  /// lecture counts (used by Lecturer Home).
  List<CalendarDay> buildCalendarDays(
    DateTime currentMonth,
    List<LectureItem> allLectures, {
    bool applyActiveTermBounds = false,
  }) {
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

      final outsideTerm = applyActiveTermBounds &&
          !_repository.isWithinActiveTerm(date);
      final schedulingExcluded = applyActiveTermBounds
          ? _repository.isScheduledLecturesExcluded(date)
          : _repository.isHoliday(date);
      final holidayType = schedulingExcluded
          ? (_repository.holidayTypeForDate(date) ??
              (applyActiveTermBounds &&
                      _repository.isNonAttendanceWeekDate(date)
                  ? 'break'
                  : null))
          : null;
      final dayOfWeek = date.weekday;
      final showScheduledLectures = !outsideTerm && !schedulingExcluded;
      final lecturesForDay = showScheduledLectures
          ? allLectures
                .where((lecture) => lecture.dayOfWeek == dayOfWeek)
                .toList()
          : <LectureItem>[];
      final lecturesCount = lecturesForDay.length;

      // تحديد الحالة حسب الأولوية
      final status = _determineDayStatus(
        date: date,
        today: today,
        lecturesCount: lecturesCount,
        outsideTerm: outsideTerm,
        schedulingExcluded: schedulingExcluded,
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
  /// 3) يوم بدون محاضرات: none
  /// 4) أي يوم فيه محاضرات وليس عطلة:
  ///    - ماضي خارج آخر أسبوعين: عرض فقط
  ///    - ماضي داخل آخر أسبوعين: قابل للتعديل
  ///    - مستقبل: مقفل حتى يحين يومه
  /// 5) افتراضي (بدون تلوين)
  DayStatus _determineDayStatus({
    required DateTime date,
    required DateTime today,
    required int lecturesCount,
    bool outsideTerm = false,
    bool schedulingExcluded = false,
  }) {
    final bool isToday = date.isAtSameMomentAs(today);
    final bool isFuture = date.isAfter(today);
    final bool isPast = date.isBefore(today);
    final cutoff = today.subtract(const Duration(days: _editableWindowDays));

    if (outsideTerm) {
      return DayStatus.none;
    }

    if (isToday) {
      // اليوم الحالي → أعلى أولوية
      return DayStatus.today;
    }

    if (schedulingExcluded) {
      // عطلة / أسبوع غير محسوب للحضور
      return DayStatus.holiday;
    }

    if (lecturesCount == 0) {
      // يوم بدون محاضرات: لا نقاط ولا فتح سجلات.
      return DayStatus.none;
    }

    if (lecturesCount > 0 && isFuture) {
      // مستقبل مع محاضرات: مغلق حتى يحين يومه.
      return DayStatus.futureLocked;
    }

    if (isPast && lecturesCount > 0) {
      if (date.isBefore(cutoff)) {
        // تاريخ قديم خارج نافذة التعديل.
        return DayStatus.viewOnly;
      }
      // تاريخ ماضٍ داخل نافذة آخر أسبوعين.
      return DayStatus.editable;
    }

    // يوم طبيعي بدون محاضرات
    return DayStatus.none;
  }
}
