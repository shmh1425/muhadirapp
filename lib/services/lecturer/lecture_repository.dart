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
  /// تقويم "الكل": تقريباً كل الأيام فيها محاضرات (عدا الإجازات)، توزيع متنوع، يوم بدون محاضرات (أربعاء)
  List<LectureItem> getAllLectures() {
    final now = DateTime.now();
    return [
      // الأحد (7): 5 محاضرات — توزيع متنوع
      LectureItem(courseName: 'هندسة البرمجيات', crn: 'SE3310', hall: 'DEN01', section: '1', activity: 'نظري', startTime: '8:00', isDouble: true, dayOfWeek: 7),
      LectureItem(courseName: 'قواعد البيانات', crn: 'CS3320', hall: 'DEN02', section: '2', activity: 'نظري', startTime: '10:00', isDouble: true, dayOfWeek: 7),
      LectureItem(courseName: 'الذكاء الاصطناعي', crn: 'CS3330', hall: 'DEN03', section: '1', activity: 'نظري', startTime: '12:00', isDouble: false, dayOfWeek: 7),
      LectureItem(courseName: 'أمن المعلومات', crn: 'CS3340', hall: 'DEN04', section: '3', activity: 'نظري', startTime: '2:00', isDouble: true, dayOfWeek: 7),
      LectureItem(courseName: 'الشبكات الحاسوبية', crn: 'CS3350', hall: 'DEN05', section: '2', activity: 'نظري', startTime: '4:00', isDouble: false, dayOfWeek: 7),
      // الاثنين (1): 2 محاضرات
      LectureItem(courseName: 'تطوير التطبيقات', crn: 'SE3360', hall: 'DEN06', section: '1', activity: 'نظري', startTime: '8:00', isDouble: true, dayOfWeek: 1),
      LectureItem(courseName: 'الخوارزميات المتقدمة', crn: 'CS3370', hall: 'DEN07', section: '2', activity: 'نظري', startTime: '10:00', isDouble: false, dayOfWeek: 1),
      // الثلاثاء (2): 4 محاضرات (لاختبار 4 نقاط +)
      LectureItem(courseName: 'أنظمة التشغيل', crn: 'CS3380', hall: 'DEN08', section: '3', activity: 'نظري', startTime: '8:00', isDouble: true, dayOfWeek: 2),
      LectureItem(courseName: 'البرمجة المتقدمة', crn: 'CS3390', hall: 'DEN09', section: '1', activity: 'نظري', startTime: '10:00', isDouble: false, dayOfWeek: 2),
      LectureItem(courseName: 'مشروع التخرج', crn: 'CS3400', hall: 'DEN10', section: '1', activity: 'عملي', startTime: '12:00', isDouble: true, dayOfWeek: 2),
      LectureItem(courseName: 'تحليل النظم', crn: 'SE3410', hall: 'DEN11', section: '2', activity: 'نظري', startTime: '2:00', isDouble: false, dayOfWeek: 2),
      // الأربعاء (3): لا محاضرات — لاختبار "لا توجد محاضرات"
      // الخميس (4): 3 محاضرات
      LectureItem(courseName: 'قواعد البيانات المتقدمة', crn: 'CS3420', hall: 'DEN12', section: '1', activity: 'نظري', startTime: '8:00', isDouble: true, dayOfWeek: 4),
      LectureItem(courseName: 'هندسة المتطلبات', crn: 'SE3430', hall: 'DEN01', section: '2', activity: 'نظري', startTime: '10:00', isDouble: false, dayOfWeek: 4),
      LectureItem(courseName: 'الذكاء الاصطناعي التطبيقي', crn: 'CS3440', hall: 'DEN02', section: '1', activity: 'نظري', startTime: '12:00', isDouble: true, dayOfWeek: 4),
      // الجمعة (5) والسبت (6): عطلة — لا محاضرات
      // لتبويب اليوم/غداً
      LectureItem(courseName: 'محاضرة اليوم', crn: 'TODAY1', hall: 'DEN01', section: '1', activity: 'نظري', startTime: '9:00', isDouble: false, dayOfWeek: now.weekday),
      LectureItem(courseName: 'محاضرة الغد', crn: 'TOMORROW1', hall: 'DEN02', section: '1', activity: 'نظري', startTime: '11:00', isDouble: true, dayOfWeek: now.add(const Duration(days: 1)).weekday),
    ];
  }

  /// جلب المحاضرات ليوم معين
  List<LectureItem> getLecturesForDay(int dayOfWeek, {List<LectureItem>? allLectures}) {
    final lectures = allLectures ?? getAllLectures();
    return lectures.where((lecture) => lecture.dayOfWeek == dayOfWeek).toList();
  }
}

