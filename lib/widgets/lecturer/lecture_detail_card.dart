import 'package:flutter/material.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../utils/shared/time_utils.dart';

/// Card component لعرض تفاصيل المحاضرة في BottomSheet
class LectureDetailCard extends StatelessWidget {
  final LectureItem lecture;
  final bool canEdit;

  const LectureDetailCard({
    super.key,
    required this.lecture,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    // الحصول على وصف المحاضرة (يمكن جلبها من API لاحقاً)
    final courseDescription = _getCourseDescription(lecture.courseName);
    // الحصول على الموقع (يمكن جلبها من API لاحقاً)
    final location = 'ام القرى العابدية'; // أو lecture.location إذا كان موجوداً
    
    // تحويل الوقت إلى تنسيق AM/PM
    final timeRange = TimeUtils.formatTimeRange(lecture.startTime, lecture.endTime);
    
    // اختيار أيقونة حسب نوع المحاضرة
    final iconData = lecture.activity == 'عملي' 
        ? Icons.science 
        : Icons.menu_book;
    final iconColor = lecture.activity == 'عملي'
        ? const Color(0xFF4A90E2) // أزرق
        : const Color(0xFF8B6F47); // بني/بيج

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصف العلوي: الوقت والأيقونة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الوقت في الأعلى يمين
              Text(
                timeRange,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
              // الأيقونة
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  iconData,
                  size: 20,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // عنوان المحاضرة
          Text(
            lecture.courseName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
              fontFamily: 'Cairo',
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          // وصف المحاضرة
          Text(
            courseDescription,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontFamily: 'Cairo',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // الموقع في الأسفل
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 18,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                location,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // الحصول على وصف المحاضرة (يمكن استبدالها ببيانات حقيقية من API)
  String _getCourseDescription(String courseName) {
    final descriptions = {
      'هندسة البرمجيات': 'مقرر تمهيدي يعرف الطلاب على المبادئ الأساسية في هندسة البرمجيات.',
      'قواعد البيانات': 'مقرر يركز على تصميم وإدارة قواعد البيانات وأنظمة المعلومات.',
      'الذكاء الاصطناعي': 'مقرر يعرف الطلاب على مفاهيم وتقنيات الذكاء الاصطناعي والتعلم الآلي.',
      'أمن المعلومات': 'مقرر يغطي أساسيات أمن المعلومات وحماية الأنظمة والشبكات.',
      'الشبكات الحاسوبية': 'مقرر يتناول مبادئ الشبكات وبروتوكولات الاتصال.',
      'تطوير التطبيقات': 'مقرر يركز على تطوير التطبيقات الحديثة وتقنيات الويب.',
    };
    return descriptions[courseName] ?? 'مقرر أكاديمي في مجال الحاسوب وتقنية المعلومات.';
  }
}

