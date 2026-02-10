/// موديل بيانات المحاضرة
class LectureItem {
  final String courseName;
  final String crn;
  final String hall;
  final String section;
  final String activity;
  final String startTime;
  final bool isDouble; // true = محاضرة زوجية (حصتان), false = محاضرة فردية (حصة واحدة)
  final int dayOfWeek; // 1=الاثنين, 2=الثلاثاء, 3=الأربعاء, 4=الخميس, 5=الجمعة, 6=السبت, 7=الأحد

  LectureItem({
    required this.courseName,
    required this.crn,
    required this.hall,
    required this.section,
    required this.activity,
    required this.startTime,
    this.isDouble = false, // افتراضياً محاضرة فردية
    required this.dayOfWeek,
  });

  // حساب الوقت النهائي للمحاضرة
  String get endTime {
    if (isDouble) {
      // محاضرة زوجية: من startTime إلى startTime+50 ثم من startTime+60 إلى startTime+110
      final start = _parseTime(startTime);
      final secondEnd = _addMinutes(start, 110);
      return _formatTime(secondEnd);
    } else {
      // محاضرة فردية: من startTime إلى startTime+50
      final start = _parseTime(startTime);
      final end = _addMinutes(start, 50);
      return _formatTime(end);
    }
  }

  // الحصول على جميع الحصص للمحاضرة (بداية - نهاية)
  List<String> get timeSlots {
    final start = _parseTime(startTime);
    if (isDouble) {
      // محاضرة زوجية: حصتان
      final firstStart = start;
      final firstEnd = _addMinutes(start, 50);
      final secondStart = _addMinutes(start, 60);
      final secondEnd = _addMinutes(start, 110);
      return [
        '${_formatTime(firstStart)}–${_formatTime(firstEnd)}',
        '${_formatTime(secondStart)}–${_formatTime(secondEnd)}',
      ];
    } else {
      // محاضرة فردية: حصة واحدة
      final end = _addMinutes(start, 50);
      return ['${_formatTime(start)}–${_formatTime(end)}'];
    }
  }

  // الحصول على وقت بداية حصة معينة
  String getSlotStartTime(int slotIndex) {
    final start = _parseTime(startTime);
    if (isDouble) {
      if (slotIndex == 0) {
        return _formatTime(start);
      } else {
        return _formatTime(_addMinutes(start, 60));
      }
    } else {
      return _formatTime(start);
    }
  }

  // تحويل الوقت من String إلى (hour, minute)
  (int, int) _parseTime(String time) {
    final parts = time.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  // إضافة دقائق للوقت
  (int, int) _addMinutes((int, int) time, int minutes) {
    final (hour, minute) = time;
    final totalMinutes = hour * 60 + minute + minutes;
    final newHour = (totalMinutes ~/ 60) % 24;
    final newMinute = totalMinutes % 60;
    return (newHour, newMinute);
  }

  // تحويل الوقت من (hour, minute) إلى String
  String _formatTime((int, int) time) {
    final (hour, minute) = time;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

