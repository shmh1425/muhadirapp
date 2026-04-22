import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../services/student_auth_service.dart';
import '../models/attendance_context.dart';

/// Fetches real attendance data from Firestore for the chatbot.
/// Supports all 3 methods: Manual, QR Code, NFC — with deduplication by lecture date.
/// All calculations (absence rate, remaining, totalLectures) are done in Dart only — not stored in Firestore.
class ChatbotRepository {
  ChatbotRepository._();
  static final ChatbotRepository instance = ChatbotRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _enrollmentsCollection = 'student_section_enrollments';
  static const String _sectionsCollection = 'sections';
  static const String _coursesCollection = 'courses';
  static const String _academicRulesCollection = 'academic_rules';
  static const String _lecturersCollection = 'external_lecturers';
  static const String _studentsCollection = 'external_students';
  static const String _academicTermsCollection = 'academic_terms';

  /// All attendance collections — merge and deduplicate by date.
  static const List<String> _attendanceCollections = [
    'manual_attendance_records', // ✅ current method (active)
    'qr_attendance_records',     // ✅ QR Code (coming soon)
    'nfc_attendance_records',    // ✅ NFC (coming soon)
  ];

  /// Returns attendance context for the current student, or null if not logged in / no data.
  Future<AttendanceContext?> getAttendanceContext() async {
    final student = StudentAuthService.instance.currentStudent;
    if (student == null) return null;

    final int studentId = student.studentId; // keep as int for Firestore queries
    String studentName = student.displayName;

    try {
      // A) Fetch student profile from external_students
      String universityId = '';
      String major = '';
      try {
        final studentDoc = await _firestore
            .collection(_studentsCollection)
            .where('studentId', isEqualTo: studentId)
            .limit(1)
            .get();

        if (studentDoc.docs.isNotEmpty) {
          final data = studentDoc.docs.first.data();
          universityId =
              data['universityId']?.toString() ?? data['studentId']?.toString() ?? '';
          // Prefer Arabic name for Arabic UI; fall back to English.
          studentName =
              data['nameAr']?.toString() ?? data['name']?.toString() ?? studentName;
          major = data['major']?.toString() ?? data['majorAr']?.toString() ?? '';
        }
      } catch (_) {
        // collection missing / permissions → skip silently
      }

      // B) Fetch current academic term from academic_terms
      String currentTermName = '';
      String termStartDate = '';
      String termEndDate = '';
      int currentWeekNumber = 0;
      int totalWeeks = 10; // default
      int remainingWeeks = 0;
      try {
        final termsSnap = await _firestore
            .collection(_academicTermsCollection)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (termsSnap.docs.isNotEmpty) {
          final termData = termsSnap.docs.first.data();
          currentTermName =
              termData['termName']?.toString() ?? termData['name']?.toString() ?? '';
          totalWeeks = (termData['semesterWeeks'] as num?)?.toInt() ??
              (termData['totalWeeks'] as num?)?.toInt() ??
              10;

          final startRaw = termData['startDate'];
          final endRaw = termData['endDate'];

          if (startRaw is Timestamp) {
            final startDate = startRaw.toDate();
            final endDate = endRaw is Timestamp ? endRaw.toDate() : null;
            final now = DateTime.now();
            termStartDate = '${startDate.day}/${startDate.month}/${startDate.year}';
            if (endDate != null) {
              termEndDate = '${endDate.day}/${endDate.month}/${endDate.year}';
              remainingWeeks = endDate.difference(now).inDays ~/ 7;
            }
            currentWeekNumber = now.difference(startDate).inDays ~/ 7 + 1;
            if (currentWeekNumber < 1) currentWeekNumber = 1;
            if (currentWeekNumber > totalWeeks) currentWeekNumber = totalWeeks;
          }
        }
      } catch (_) {
        // collection missing / permissions → skip silently
      }

      final enrollmentsSnap = await _firestore
          .collection(_enrollmentsCollection)
          .where('studentId', isEqualTo: studentId)
          .get();

      final enrollmentDocs = enrollmentsSnap.docs;
      if (enrollmentDocs.isEmpty) return null;

      int warningPercent = 15;
      int deprivationPercent = 25;
      try {
        final rulesRef =
            _firestore.collection(_academicRulesCollection).doc('default');
        final rulesDoc = await rulesRef.get();
        if (rulesDoc.exists) {
          final data = rulesDoc.data();
          if (data != null) {
            warningPercent = (data['warningPercent'] as num?)?.toInt() ?? 15;
            deprivationPercent =
                (data['maxAbsencePercent'] as num?)?.toInt() ?? 25;
          }
        } else {
          await rulesRef.set({
            'maxAbsencePercent': 25,
            'warningPercent': 15,
            'maxUnexcusedPercent': 15,
          });
        }
      } catch (_) {}

      final List<CourseAttendanceSummary> courses = [];
      final List<String> contextLines = [];
      final List<Map<String, dynamic>> coursesWithLecturers = [];
      final List<Map<String, dynamic>> todaySchedule = [];
      final List<Map<String, dynamic>> weekSchedule = [];
      final Map<String, List<Map<String, dynamic>>> weekScheduleByDay = {
        'الأحد': [],
        'الاثنين': [],
        'الثلاثاء': [],
        'الأربعاء': [],
        'الخميس': [],
        'الجمعة': [],
        'السبت': [],
      };
      final String todayName = _getTodayArabic();
      final String todayNameEn = _getTodayEnglish().toLowerCase();
      final int todayDayOfWeek = DateTime.now().weekday;
      int totalCreditHours = 0;

      for (final enrollDoc in enrollmentDocs) {
        final sectionId =
            (enrollDoc.data()['sectionId'] ?? '').toString().trim();
        if (sectionId.isEmpty) continue;

        final sectionDoc =
            await _firestore.collection(_sectionsCollection).doc(sectionId).get();
        if (!sectionDoc.exists) continue;

        final sectionData = sectionDoc.data() ?? {};
        final courseCode =
            (sectionData['courseCode'] ?? sectionData['courseId'] ?? '')
                .toString()
                .trim();
        final courseName =
            (sectionData['courseName'] ?? '').toString().trim();

        String courseNameAr = '';
        int creditHours = 0;
        if (courseCode.isNotEmpty) {
          final courseDoc = await _firestore
              .collection(_coursesCollection)
              .doc(courseCode)
              .get();
          if (courseDoc.exists) {
            final courseData = courseDoc.data() ?? {};
            courseNameAr =
                (courseData['courseName_Ar'] ?? courseData['courseNameAr'] ?? '')
                    .toString()
                    .trim();
            creditHours = (courseData['creditHours'] as num?)?.toInt() ?? 0;
          }
        }
        final displayCourseName =
            courseNameAr.isNotEmpty ? courseNameAr : courseName;
        if (displayCourseName.isEmpty) continue;

        // C) Collect course + lecturer + schedule info
        final lecturerId = (sectionData['lecturerId'] ?? sectionData['instructorId'] ?? '')
            .toString()
            .trim();
        String lecturerName = '';
        if (lecturerId.isNotEmpty) {
          try {
            final lecturerDoc =
                await _firestore.collection(_lecturersCollection).doc(lecturerId).get();
            if (lecturerDoc.exists) {
              final lecturerData = lecturerDoc.data() ?? {};
              lecturerName =
                  lecturerData['name']?.toString() ?? lecturerData['nameAr']?.toString() ?? '';
            }
          } catch (_) {
            // skip silently
          }
        }

        // Support both formats:
        // - legacy: scheduleDays/days + scheduleTime/location
        // - current: schedule: [{dayOfWeek,startTime,endTime,location,hall...}, ...]
        final List<dynamic> scheduleEntries =
            (sectionData['schedule'] as List?) ?? const <dynamic>[];

        final scheduleDaysFromEntries = scheduleEntries
            .map((e) {
              final m = Map<String, dynamic>.from(e is Map ? e as Map : <String, dynamic>{});
              final dow = m['dayOfWeek'] is int
                  ? m['dayOfWeek'] as int
                  : int.tryParse((m['dayOfWeek'] ?? '').toString()) ?? 0;
              return _dayOfWeekToArabicName(dow);
            })
            .where((d) => d.isNotEmpty)
            .toSet()
            .toList();

        final scheduleDays = scheduleDaysFromEntries.isNotEmpty
            ? scheduleDaysFromEntries
            : ((sectionData['scheduleDays'] as List?) ??
                (sectionData['days'] as List?) ??
                const <dynamic>[]);

        final String scheduleTime;
        final String location;
        final String room;
        if (scheduleEntries.isNotEmpty) {
          // pick today's entry if exists, else first
          Map<String, dynamic>? chosen;
          for (final e in scheduleEntries) {
            final m = Map<String, dynamic>.from(e is Map ? e as Map : <String, dynamic>{});
            final dow = m['dayOfWeek'] is int
                ? m['dayOfWeek'] as int
                : int.tryParse((m['dayOfWeek'] ?? '').toString()) ?? 0;
            if (dow == todayDayOfWeek) {
              chosen = m;
              break;
            }
          }
          chosen ??= Map<String, dynamic>.from(scheduleEntries.first is Map ? scheduleEntries.first as Map : <String, dynamic>{});
          final start = (chosen['startTime'] ?? '').toString().trim();
          final end = (chosen['endTime'] ?? '').toString().trim();
          scheduleTime = (start.isNotEmpty && end.isNotEmpty) ? '$start - $end' : (start.isNotEmpty ? start : '');
          final loc = (chosen['location'] ?? chosen['مقر'] ?? '').toString().trim();
          final hall = (chosen['hall'] ?? '').toString().trim();
          location = loc.isNotEmpty ? loc : (hall.isNotEmpty ? hall : '');
          room = hall.isNotEmpty ? hall : (chosen['room'] ?? '').toString().trim();
        } else {
          scheduleTime =
              (sectionData['scheduleTime'] ?? sectionData['time'] ?? '').toString();
          location =
              (sectionData['location'] ?? sectionData['room'] ?? '').toString();
          room = (sectionData['room'] ?? sectionData['hall'] ?? '').toString();
        }

        final courseInfo = <String, dynamic>{
          'courseName': courseName,
          'courseNameAr': courseNameAr,
          'courseCode': courseCode,
          'creditHours': creditHours,
          'lecturerName': lecturerName,
          'scheduleDays': scheduleDays,
          'scheduleTime': scheduleTime,
          'location': location,
          'room': room,
          'sectionId': sectionId,
        };

        coursesWithLecturers.add(courseInfo);
        weekSchedule.add(courseInfo);
        totalCreditHours += creditHours;

        for (final day in scheduleDays) {
          final dayStr = day.toString();
          if (dayStr.contains(todayName) || dayStr.toLowerCase().contains(todayNameEn)) {
            todaySchedule.add(courseInfo);
            break;
          }
        }

        // If schedule is stored as entries with dayOfWeek, use that as the source of truth for today's schedule
        if (scheduleEntries.isNotEmpty) {
          final hasToday = scheduleEntries.any((e) {
            final m = Map<String, dynamic>.from(e is Map ? e as Map : <String, dynamic>{});
            final dow = m['dayOfWeek'] is int
                ? m['dayOfWeek'] as int
                : int.tryParse((m['dayOfWeek'] ?? '').toString()) ?? 0;
            return dow == todayDayOfWeek;
          });
          if (hasToday && !todaySchedule.contains(courseInfo)) {
            todaySchedule.add(courseInfo);
          }
        }

        for (final day in scheduleDays) {
          final dayKey = _normalizeDayToArabic(day.toString());
          if (dayKey.isNotEmpty && weekScheduleByDay.containsKey(dayKey)) {
            weekScheduleByDay[dayKey]!.add(courseInfo);
          }
        }

        // STEP 1: Fetch from all attendance collections and deduplicate by date
        final Map<String, Map<String, dynamic>> uniqueRecords = {};

        for (final collection in _attendanceCollections) {
          try {
            final snap = await _firestore
                .collection(collection)
                .where('studentId', isEqualTo: studentId)
                .where('sectionId', isEqualTo: sectionId)
                .get();

            for (final doc in snap.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final date = data['lectureDate'] is Timestamp
                  ? (data['lectureDate'] as Timestamp)
                      .toDate()
                      .toIso8601String()
                      .substring(0, 10) // YYYY-MM-DD
                  : data['lectureDate']?.toString() ?? doc.id;

              // First record for this date wins — no duplicates
              uniqueRecords.putIfAbsent(date, () => data);
            }
          } catch (_) {
            // collection doesn't exist yet → skip silently
          }
        }

        final allRecords = uniqueRecords.values.toList();

        // STEP 2: Count statuses from deduplicated records
        int absent = allRecords
            .where((d) => d['status']?.toString() == 'absent')
            .length;

        int excused = allRecords
            .where((d) => d['status']?.toString() == 'excused')
            .length;

        int present = allRecords
            .where((d) => d['status']?.toString() == 'present')
            .length;

        // STEP 3: Calculate totalLectures dynamically
        // First: get lecturesPerWeek from the section document
        int lecturesPerWeek = 2; // default fallback
        final lecturesPerWeekRaw = sectionData['lecturesPerWeek'];
        if (lecturesPerWeekRaw is int && lecturesPerWeekRaw > 0) {
          lecturesPerWeek = lecturesPerWeekRaw;
        } else if (lecturesPerWeekRaw is num) {
          lecturesPerWeek = lecturesPerWeekRaw.toInt();
        }

        // Second: get semesterWeeks
        // Priority 1 → fetch from Firestore collection 'academic_calendar' doc 'current'
        // Priority 2 → fallback to 10 weeks (temporary default until calendar is added)
        int semesterWeeks = 10; // temporary default
        try {
          final calendarDoc = await _firestore
              .collection('academic_calendar')
              .doc('current')
              .get();
          if (calendarDoc.exists) {
            final calendarData = calendarDoc.data();
            final weeksRaw = calendarData?['semesterWeeks'];
            if (weeksRaw is int && weeksRaw > 0) {
              semesterWeeks = weeksRaw;
            } else if (weeksRaw is num) {
              semesterWeeks = weeksRaw.toInt();
            }
          }
        } catch (_) {
          // calendar not added yet → keep default 10 weeks
        }

        // Third: calculate total lectures
        int totalLectures = lecturesPerWeek * semesterWeeks;
        if (totalLectures <= 0) totalLectures = 20; // absolute fallback

        // STEP 4: Calculate absence rate and remaining lectures (in Dart only — not stored in Firestore)
        double absenceRate = totalLectures > 0
            ? (absent + excused) / totalLectures * 100
            : 0.0;
        double remaining = (totalLectures * 0.25) - (absent + excused);

        final isWarning =
            absenceRate >= warningPercent && absenceRate < deprivationPercent;
        final isDeprivation = absenceRate >= deprivationPercent;

        courses.add(CourseAttendanceSummary(
          courseName: courseName,
          courseNameAr: courseNameAr,
          sectionId: sectionId,
          totalLectures: totalLectures,
          presentCount: present,
          absentCount: absent,
          excusedCount: excused,
          absenceRate: absenceRate,
          remainingBeforeDeprivation: remaining.clamp(0, totalLectures).toInt(),
          isWarning: isWarning,
          isDeprivation: isDeprivation,
        ));

        // Build context string for OpenAI (exact format requested)
        final context = '''
Student Attendance Data:
- Course: $courseName / $courseNameAr
- Lectures Per Week: $lecturesPerWeek
- Semester Weeks: $semesterWeeks
- Total Lectures (calculated): $totalLectures
- Unexcused Absences: $absent
- Excused Absences: $excused
- Present: $present
- Absence Rate: ${absenceRate.toStringAsFixed(1)}%
- Remaining Before Deprivation (25% rule): ${remaining.toStringAsFixed(0)} lectures
- Warning Threshold: $warningPercent%
- Deprivation Threshold: $deprivationPercent%
''';
        contextLines.add(context.trim());
      }

      final rawContextString = contextLines.isEmpty
          ? 'No enrollments or attendance data.'
          : '''
=== STUDENT PROFILE ===
- Name: $studentName
- University ID: $universityId
- Major: $major
- Total Credit Hours (Enrolled): $totalCreditHours

=== CURRENT ACADEMIC TERM ===
- Term: $currentTermName
- Start Date: $termStartDate
- End Date: $termEndDate
- Current Week: $currentWeekNumber of $totalWeeks
- Remaining Weeks: $remainingWeeks weeks until end of semester

=== TODAY'S SCHEDULE (${_getTodayArabic()}) ===
${todaySchedule.isEmpty ? 'No classes today' : todaySchedule.map((c) => '''
- ${c['courseNameAr'] ?? c['courseName']}
  Time: ${c['scheduleTime']}
  Room: ${c['room']}
  Location: ${c['location']}
  Lecturer: ${c['lecturerName']}
''').join()}

=== WEEKLY SCHEDULE (Grouped by Day) ===
${weekScheduleByDay.entries.where((e) => e.value.isNotEmpty).isEmpty ? 'No weekly schedule found' : weekScheduleByDay.entries.where((e) => e.value.isNotEmpty).map((e) => '''
- ${e.key}:
${e.value.map((c) => '  • ${c['courseNameAr'] ?? c['courseName']} — ${c['scheduleTime']} — Room: ${c['room']} — ${c['location']} — ${c['lecturerName']}').join('\n')}
''').join()}

=== ENROLLED COURSES WITH LECTURERS ===
${coursesWithLecturers.map((c) => '''
- ${c['courseNameAr'] ?? c['courseName']} (${c['courseCode']})
  Credit Hours: ${c['creditHours']}
  Lecturer: ${c['lecturerName']}
  Schedule: ${(c['scheduleDays'] as List).join(', ')} at ${c['scheduleTime']}
  Room: ${c['room']}
  Location: ${c['location']}
''').join()}

=== ATTENDANCE SUMMARY ===
${contextLines.join('\n')}
''';

      return AttendanceContext(
        studentId: studentId.toString(), // only convert for display
        studentName: studentName,
        universityId: universityId,
        major: major,
        todaySchedule: todaySchedule,
        weekSchedule: weekSchedule,
        currentTermName: currentTermName,
        termStartDate: termStartDate,
        termEndDate: termEndDate,
        currentWeekNumber: currentWeekNumber,
        totalWeeks: totalWeeks,
        remainingWeeks: remainingWeeks,
        coursesWithLecturers: coursesWithLecturers,
        courses: courses,
        warningPercent: warningPercent,
        deprivationPercent: deprivationPercent,
        rawContextString: rawContextString,
      );
    } catch (e) {
      rethrow;
    }
  }

  String _getTodayArabic() {
    const days = {
      1: 'الاثنين',
      2: 'الثلاثاء',
      3: 'الأربعاء',
      4: 'الخميس',
      5: 'الجمعة',
      6: 'السبت',
      7: 'الأحد',
    };
    return days[DateTime.now().weekday] ?? '';
  }

  String _getTodayEnglish() {
    const days = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    return days[DateTime.now().weekday] ?? '';
  }

  String _normalizeDayToArabic(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    const arDays = [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    for (final d in arDays) {
      if (s.contains(d)) return d;
    }
    final lower = s.toLowerCase();
    if (lower.contains('sunday')) return 'الأحد';
    if (lower.contains('monday')) return 'الاثنين';
    if (lower.contains('tuesday')) return 'الثلاثاء';
    if (lower.contains('wednesday')) return 'الأربعاء';
    if (lower.contains('thursday')) return 'الخميس';
    if (lower.contains('friday')) return 'الجمعة';
    if (lower.contains('saturday')) return 'السبت';
    return '';
  }

  String _dayOfWeekToArabicName(int dayOfWeek) {
    // Match the app's convention in schedule_screen.dart:
    // 7=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday
    const map = <int, String>{
      7: 'الأحد',
      1: 'الاثنين',
      2: 'الثلاثاء',
      3: 'الأربعاء',
      4: 'الخميس',
      5: 'الجمعة',
      6: 'السبت',
    };
    return map[dayOfWeek] ?? '';
  }
}
