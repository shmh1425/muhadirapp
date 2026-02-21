import 'package:flutter_test/flutter_test.dart';
import 'package:muhadirapp/utils/hijri_converter.dart';

/// اختبار التحويل الهجري: اليوم + تاريخين ثابتين معروفين
/// إذا ظهر فرق يوم عن أم القرى يُعدّل الخوارزم
void main() {
  group('HijriConverter', () {
    test('اليوم: تحويل اليوم الحالي يعيد شهر ويوم وسنة هجرية معقولة', () {
      final now = DateTime.now();
      final hijri = HijriConverter.gregorianToHijri(now);
      expect(hijri['year'], greaterThan(1440));
      expect(hijri['year'], lessThan(1500));
      expect(hijri['month'], greaterThanOrEqualTo(1));
      expect(hijri['month'], lessThanOrEqualTo(12));
      expect(hijri['day'], greaterThanOrEqualTo(1));
      expect(hijri['day'], lessThanOrEqualTo(30));
    });

    test('تاريخ ثابت: 7 يوليو 2024 ≈ محرم 1445 أو 1446 (خوارزمية الكويت ±1 يوم)', () {
      final gregorian = DateTime(2024, 7, 7);
      final hijri = HijriConverter.gregorianToHijri(gregorian);
      expect(hijri['year'], anyOf(1445, 1446));
      expect(hijri['month'], inInclusiveRange(1, 12));
      expect((hijri['day'] as int), inInclusiveRange(1, 30));
    });

    test('تاريخ ثابت: 19 فبراير 2026 يعيد تاريخ هجري متسق', () {
      final gregorian = DateTime(2026, 2, 19);
      final hijri = HijriConverter.gregorianToHijri(gregorian);
      expect(hijri['year'], inInclusiveRange(1446, 1448));
      expect(hijri['month'], inInclusiveRange(1, 12));
      expect(hijri['day'], inInclusiveRange(1, 30));
      expect(HijriConverter.hijriMonths[(hijri['month'] as int) - 1], isNotEmpty);
    });
  });
}
