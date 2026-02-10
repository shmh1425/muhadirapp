import '../../models/lecturer/lecture_item.dart';

/// Repository لإدارة بيانات المحاضرات والعطلات
/// يمكن استبدالها لاحقاً بـ API calls
class LectureRepository {
  // ─── العطلات الرسمية ───
  // الجمعة والسبت تُعتبر عطلة تلقائياً.
  // أضف هنا أي عطلات رسمية إضافية (أعياد، إجازات جامعية، إلخ).
  // لاحقاً يمكن جلبها من API بدلاً من قائمة ثابتة.
  final Set<DateTime> _officialHolidays = {
    // مثال: DateTime(2026, 3, 29), // عيد الفطر (تعديل حسب الإعلان الرسمي)
  };

  /// هل التاريخ عطلة رسمية؟ (عطلة نهاية الأسبوع + العطل الرسمية)
  bool isHoliday(DateTime date) {
    // عطلة نهاية الأسبوع: الجمعة (5) والسبت (6)
    if (date.weekday == 5 || date.weekday == 6) return true;
    // عطلات رسمية إضافية
    final dateOnly = DateTime(date.year, date.month, date.day);
    return _officialHolidays.contains(dateOnly);
  }

  /// جلب جميع المحاضرات (Mock data)
  /// dayOfWeek: 1=الاثنين, 2=الثلاثاء, 3=الأربعاء, 4=الخميس, 5=الجمعة, 6=السبت, 7=الأحد
  List<LectureItem> getAllLectures() {
    final now = DateTime.now();
    return [
      LectureItem(
        courseName: 'هندسة البرمجيات',
        crn: 'SE3310',
        hall: 'DEN01',
        section: '1',
        activity: 'نظري',
        startTime: '8:00',
        isDouble: true, // محاضرة زوجية: 8:00-8:50 و 9:00-9:50
        dayOfWeek: now.weekday, // اليوم
      ),
      LectureItem(
        courseName: 'قواعد البيانات',
        crn: 'CS3320',
        hall: 'DEN02',
        section: '2',
        activity: 'نظري',
        startTime: '10:00',
        isDouble: true, // محاضرة زوجية: 10:00-10:50 و 11:00-11:50
        dayOfWeek: now.weekday, // اليوم
      ),
      LectureItem(
        courseName: 'الذكاء الاصطناعي',
        crn: 'CS3330',
        hall: 'DEN03',
        section: '1',
        activity: 'نظري',
        startTime: '12:00',
        isDouble: false, // محاضرة فردية: 12:00-12:50
        dayOfWeek: now.weekday, // اليوم
      ),
      LectureItem(
        courseName: 'أمن المعلومات',
        crn: 'CS3340',
        hall: 'DEN04',
        section: '3',
        activity: 'نظري',
        startTime: '2:00',
        isDouble: true, // محاضرة زوجية: 2:00-2:50 و 3:00-3:50
        dayOfWeek: now.weekday, // اليوم
      ),
      LectureItem(
        courseName: 'الشبكات الحاسوبية',
        crn: 'CS3350',
        hall: 'DEN05',
        section: '2',
        activity: 'نظري',
        startTime: '4:00',
        isDouble: false, // محاضرة فردية: 4:00-4:50
        dayOfWeek: now.weekday, // اليوم
      ),
      LectureItem(
        courseName: 'تطوير التطبيقات',
        crn: 'SE3360',
        hall: 'DEN06',
        section: '1',
        activity: 'نظري',
        startTime: '6:00',
        isDouble: true, // محاضرة زوجية: 6:00-6:50 و 7:00-7:50
        dayOfWeek: now.weekday, // اليوم
      ),
      // محاضرات الغد
      LectureItem(
        courseName: 'الخوارزميات المتقدمة',
        crn: 'CS3370',
        hall: 'DEN07',
        section: '2',
        activity: 'نظري',
        startTime: '8:00',
        isDouble: false, // محاضرة فردية: 8:00-8:50
        dayOfWeek: now.add(const Duration(days: 1)).weekday, // الغد
      ),
      LectureItem(
        courseName: 'أنظمة التشغيل',
        crn: 'CS3380',
        hall: 'DEN08',
        section: '3',
        activity: 'نظري',
        startTime: '10:00',
        isDouble: true, // محاضرة زوجية: 10:00-10:50 و 11:00-11:50
        dayOfWeek: now.add(const Duration(days: 1)).weekday, // الغد
      ),
      LectureItem(
        courseName: 'البرمجة المتقدمة',
        crn: 'CS3390',
        hall: 'DEN09',
        section: '1',
        activity: 'نظري',
        startTime: '12:00',
        isDouble: false, // محاضرة فردية: 12:00-12:50
        dayOfWeek: now.add(const Duration(days: 1)).weekday, // الغد
      ),
      LectureItem(
        courseName: 'مشروع التخرج',
        crn: 'CS3400',
        hall: 'DEN10',
        section: '1',
        activity: 'عملي',
        startTime: '2:00',
        isDouble: true, // محاضرة زوجية: 2:00-2:50 و 3:00-3:50
        dayOfWeek: now.add(const Duration(days: 1)).weekday, // الغد
      ),
    ];
  }

  /// جلب المحاضرات ليوم معين
  List<LectureItem> getLecturesForDay(int dayOfWeek, {List<LectureItem>? allLectures}) {
    final lectures = allLectures ?? getAllLectures();
    return lectures.where((lecture) => lecture.dayOfWeek == dayOfWeek).toList();
  }
}

