/// أداة تحويل التاريخ الميلادي إلى هجري
/// تستخدم خوارزمية الكويت (Kuwaiti Algorithm) المعتمدة عالمياً
/// الدقة: ±1 يوم مقارنة بتقويم أم القرى (مقبول للعرض)
class HijriConverter {
  /// أسماء الأشهر الهجرية
  static const List<String> hijriMonths = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الثاني',
    'جمادى الأولى',
    'جمادى الثانية',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  /// تحويل التاريخ الميلادي إلى هجري باستخدام خوارزمية الكويت
  static Map<String, dynamic> gregorianToHijri(DateTime gregorianDate) {
    // الخطوة 1: تحويل الميلادي إلى رقم اليوم اليولياني (Julian Day Number)
    final jd = _gregorianToJulianDay(
      gregorianDate.year,
      gregorianDate.month,
      gregorianDate.day,
    );

    // الخطوة 2: تحويل رقم اليوم اليولياني إلى تاريخ هجري
    return _julianDayToHijri(jd);
  }

  /// تحويل تاريخ ميلادي إلى رقم اليوم اليولياني (Jean Meeus algorithm)
  static int _gregorianToJulianDay(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final int a = year ~/ 100;
    final int b = 2 - a + (a ~/ 4);
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524;
  }

  /// تحويل رقم اليوم اليولياني إلى تاريخ هجري (خوارزمية الكويت)
  static Map<String, dynamic> _julianDayToHijri(int jd) {
    int l = jd - 1948440 + 10632;
    final int n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final int j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        ((l ~/ 5670)) * ((43 * l) ~/ 15238);
    l = l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        ((j ~/ 16)) * ((15238 * j) ~/ 43) +
        29;
    final int m = (24 * l) ~/ 709;
    final int d = l - (709 * m) ~/ 24;
    final int y = 30 * n + j - 30;

    // التأكد من أن القيم في النطاق الصحيح
    final int safeMonth = m.clamp(1, 12);
    final int safeDay = d.clamp(1, 30);

    return {
      'year': y,
      'month': safeMonth,
      'day': safeDay,
      'monthName': hijriMonths[safeMonth - 1],
    };
  }

  /// الحصول على اسم الشهر الهجري من رقمه (1-12)
  static String getMonthName(int month) {
    final safeMonth = month.clamp(1, 12);
    return hijriMonths[safeMonth - 1];
  }

  /// تحويل رقم إلى أرقام عربية
  static String toArabicNumber(int number) {
    const arabicDigits = [
      '٠',
      '١',
      '٢',
      '٣',
      '٤',
      '٥',
      '٦',
      '٧',
      '٨',
      '٩',
    ];
    return number.toString().split('').map((digit) {
      if (digit == '-') return '-';
      return arabicDigits[int.parse(digit)];
    }).join();
  }
}
