/// أدوات مساعدة لحسابات الوقت
class TimeUtils {
  /// تحويل String إلى (hour, minute)
  static (int, int) parseTimeString(String time) {
    final parts = time.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  /// تحويل الوقت إلى تنسيق AM/PM
  static String formatTimeRange(String startTime, String endTime) {
    final start = parseTimeString(startTime);
    final end = parseTimeString(endTime);
    
    String formatTime((int, int) time) {
      final (hour, minute) = time;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    }
    
    return '${formatTime(start)} - ${formatTime(end)}';
  }

  /// ترتيب المحاضرات حسب وقت البداية (من الأقدم للأحدث)
  static List<T> sortLecturesByTime<T>(List<T> lectures, String Function(T) getStartTime) {
    final sorted = List<T>.from(lectures);
    sorted.sort((a, b) {
      final aTime = parseTimeString(getStartTime(a));
      final bTime = parseTimeString(getStartTime(b));
      final aMinutes = aTime.$1 * 60 + aTime.$2;
      final bMinutes = bTime.$1 * 60 + bTime.$2;
      return aMinutes.compareTo(bMinutes);
    });
    return sorted;
  }
}

