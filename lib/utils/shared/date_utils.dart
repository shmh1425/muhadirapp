/// أدوات مساعدة للتعامل مع التواريخ
class AppDateUtils {
  /// تحويل رقم إلى أرقام عربية
  static String toArabicNumber(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((digit) => arabicDigits[int.parse(digit)]).join();
  }

  /// الحصول على اسم اليوم بالعربية
  static String getArabicDayName(DateTime date) {
    const days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return days[date.weekday - 1]; // weekday: 1=الاثنين, 7=الأحد
  }

  /// الحصول على اسم الشهر بالعربية
  static String getArabicMonthName(DateTime date) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return months[date.month - 1];
  }

  /// الحصول على معلومات التاريخ (اسم اليوم، رقم اليوم، اسم الشهر)
  static Map<String, String> getDateInfo(DateTime date) {
    return {
      'dayName': AppDateUtils.getArabicDayName(date),
      'dayNumber': AppDateUtils.toArabicNumber(date.day),
      'monthName': AppDateUtils.getArabicMonthName(date),
    };
  }

  /// الحصول على التحية حسب الوقت
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير';
    } else {
      return 'مساء الخير';
    }
  }
}

