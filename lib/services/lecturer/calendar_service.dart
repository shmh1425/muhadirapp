import '../../models/calendar_day.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../utils/hijri_converter.dart';

/// Service لإدارة منطق التقويم وحالة الأيام
class CalendarService {
  final LectureRepository _repository;
  
  // ─── عدد أيام نافذة التعديل ───
  // الأيام الماضية ضمن هذه الفترة = قابلة للتعديل (أخضر)
  // الأيام الماضية الأقدم = عرض فقط (أزرق)
  // القيمة: 14 يوم (أسبوعين قبل اليوم الحالي)
  static const int editableWindowDays = 14;

  CalendarService(this._repository);

  /// بناء بيانات التقويم من المحاضرات
  List<CalendarDay> buildCalendarDays(
    DateTime currentMonth,
    List<LectureItem> allLectures,
  ) {
    final List<CalendarDay> calendarDays = [];
    final now = DateTime.now();
    // مقارنة بالتاريخ فقط بدون الوقت
    final today = DateTime(now.year, now.month, now.day);

    // الحصول على آخر يوم في الشهر الحالي
    final lastDay = DateTime(
      currentMonth.year,
      currentMonth.month + 1,
      0,
    );

    // إنشاء بيانات لكل يوم في الشهر
    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(
        currentMonth.year,
        currentMonth.month,
        day,
      );
      final hijriInfo = HijriConverter.gregorianToHijri(date);

      // حساب عدد المحاضرات في هذا اليوم
      final dayOfWeek = date.weekday;
      final lecturesForDay = allLectures
          .where((lecture) => lecture.dayOfWeek == dayOfWeek)
          .toList();
      final lecturesCount = lecturesForDay.length;

      // تحديد الحالة حسب الأولوية
      final status = _determineDayStatus(
        date: date,
        today: today,
        lecturesCount: lecturesCount,
      );

      calendarDays.add(CalendarDay(
        date: date,
        hijriDay: hijriInfo['day'] as int,
        hijriMonthName: hijriInfo['monthName'] as String,
        hijriYear: hijriInfo['year'] as int,
        lecturesCount: lecturesCount,
        status: status,
      ));
    }

    return calendarDays;
  }

  /// تحديد حالة اليوم حسب الأولوية
  /// 1) اليوم الحالي (أخضر غامق) → أعلى أولوية
  /// 2) عطلة رسمية (رمادي)
  /// 3) مستقبل (أحمر مقفل) → كل تاريخ بعد اليوم مقفل
  /// 4) ماضي فيه محاضرات → editable (أخضر) أو viewOnly (أزرق)
  /// 5) افتراضي (بدون تلوين)
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
    } else if (isHoliday) {
      // عطلة رسمية → ثاني أولوية
      return DayStatus.holiday;
    } else if (isFuture) {
      // أي تاريخ مستقبلي = أحمر مقفل (سواء فيه محاضرات أو لا)
      return DayStatus.futureLocked;
    } else if (isPast && lecturesCount > 0) {
      // ماضي فيه محاضرات → تحديد editable أو viewOnly
      final daysDiff = today.difference(date).inDays;
      if (daysDiff <= editableWindowDays) {
        // آخر 14 يوم (أسبوعين) → قابل للتعديل (أخضر)
        return DayStatus.editable;
      } else {
        // أقدم من 14 يوم → عرض فقط (أزرق)
        return DayStatus.viewOnly;
      }
    } else {
      // ماضي بدون محاضرات أو حالة افتراضية
      return DayStatus.none;
    }
  }
}

