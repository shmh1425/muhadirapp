import 'package:flutter/material.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../utils/shared/time_utils.dart';
import 'lecture_card.dart';

/// Timeline component لعرض المحاضرات بترتيب زمني
class LectureTimeline extends StatelessWidget {
  final List<LectureItem> lectures;

  const LectureTimeline({
    super.key,
    required this.lectures,
  });

  @override
  Widget build(BuildContext context) {
    if (lectures.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'لا توجد محاضرات',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF999999),
              fontFamily: 'Cairo',
            ),
          ),
        ),
      );
    }

    // ترتيب المحاضرات حسب وقت البداية (من الأقدم للأحدث - الصبح فوق)
    final sortedLectures = TimeUtils.sortLecturesByTime(
      lectures,
      (lecture) => lecture.startTime,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sortedLectures.asMap().entries.map((entry) {
            final index = entry.key;
            final lecture = entry.value;
            final isLast = index == sortedLectures.length - 1;
            final timeSlots = lecture.timeSlots;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Padding يمين للعمود الزمني
                    const SizedBox(width: 10),
                    // النقاط الزمنية لهذه المحاضرة - بمحاذاة الكارد مباشرة
                    SizedBox(
                      width: 100,
                      child: Stack(
                        children: [
                          // خط صغير يربط النقاط (للمحاضرة الزوجية)
                          if (timeSlots.length > 1)
                            Positioned(
                              right: 50,
                              top: 24,
                              bottom: 22,
                              child: Container(
                                width: 1.5,
                                color: const Color(0xFF006571).withValues(alpha: 0.22),
                              ),
                            ),
                          // النقطة الأولى
                          if (timeSlots.length == 1)
                            Positioned(
                              top: 0,
                              bottom: 0,
                              right: 0,
                              child: Center(
                                child: _buildTimeNode(timeSlots[0]),
                              ),
                            )
                          else
                            Positioned(
                              top: 18,
                              right: 0,
                              child: _buildTimeNode(timeSlots[0]),
                            ),
                          // النقطة الثانية (إن وجدت)
                          if (timeSlots.length > 1)
                            Positioned(
                              bottom: 16,
                              right: 0,
                              child: _buildTimeNode(timeSlots[1]),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // الكارد
                    Expanded(
                      child: LectureCard(lecture: lecture),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTimeNode(String timeRange) {
    const dotSize = 12.0;
    return SizedBox(
      width: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // الوقت (ثابت مكانه)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                timeRange,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF006571),
                  fontFamily: 'Cairo',
                  height: 1.3,
                ),
              ),
            ),
          ),
          // النقطة (مثبتة يمين)
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: const Color(0xFF006571),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF006571).withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

