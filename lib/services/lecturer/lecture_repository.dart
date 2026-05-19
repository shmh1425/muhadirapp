import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/lecturer/lecture_item.dart';
import '../../screens/lecturer/lecturer_language.dart';

/// Repository لإدارة بيانات المحاضرات والتقويم الأكاديمي.
class LectureRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _currentDateTime = DateTime.now();
  DateTime _semesterStartDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _semesterEndDate = DateTime(DateTime.now().year, 12, 31);
  int _semesterWeeks = 16;
  int _editableWindowDays = 14;
  Set<int> _weekendDays = <int>{DateTime.friday, DateTime.saturday};
  Set<DateTime> _officialHolidays = <DateTime>{};
  Map<DateTime, String> _holidayTypeByDate = <DateTime, String>{};
  Map<int, _TermWeekSchedule> _weeksByOfficialNumber = <int, _TermWeekSchedule>{};
  List<_TermWeekSchedule> _termWeeks = <_TermWeekSchedule>[];
  int _officialWeeksCount = 16;

  DateTime get currentDateTime => _currentDateTime;
  DateTime get currentDate => DateTime(
    _currentDateTime.year,
    _currentDateTime.month,
    _currentDateTime.day,
  );
  DateTime get semesterStartDate => _semesterStartDate;
  DateTime get semesterEndDate => _semesterEndDate;
  int get semesterWeeks => _semesterWeeks;
  int get officialWeeksCount => _officialWeeksCount;
  int get editableWindowDays => _editableWindowDays;

  /// Max official week index for Manage Lectures (not [semesterWeeks] / effective weeks).
  ///
  /// Priority: term `officialWeeksCount` → highest `officialWeekNumber` in loaded
  /// `weeks` subcollection → [semesterWeeks] fallback.
  int get manageLecturesWeekUpperBound {
    var bound = _officialWeeksCount;
    if (_termWeeks.isNotEmpty) {
      for (final week in _termWeeks) {
        if (week.officialWeekNumber > bound) {
          bound = week.officialWeekNumber;
        }
      }
    }
    if (bound <= 0) {
      bound = _semesterWeeks;
    }
    return bound.clamp(1, 60);
  }
  Set<String> get loadedHolidayTypes => _holidayTypeByDate.values
      .map((t) => t.trim().toLowerCase())
      .where((t) => t.isNotEmpty)
      .toSet();

  String? holidayTypeForDate(DateTime date) {
    final d = _normalizeDate(date);
    if (_holidayTypeByDate.containsKey(d)) return _holidayTypeByDate[d];
    if (_weekendDays.contains(d.weekday)) return 'weekend';
    return null;
  }

  /// يحدّث إعدادات التقويم من Firestore:
  /// 1) يقرأ academic_calendar/current (خصوصًا currentDateTime والخيارات العامة)
  /// 2) يقرأ academic_terms (الترم النشط) ويأخذ منه أولوية تاريخ/أسابيع الفصل
  Future<void> refreshAcademicCalendar() async {
    final now = DateTime.now();

    DateTime? fetchedCurrentDate;
    DateTime? fetchedStartDate;
    DateTime? fetchedEndDate;
    int? fetchedWeeks;
    int? fetchedEditableWindowDays;
    Set<int>? fetchedWeekendDays;
    final fetchedHolidays = <DateTime>{};
    final fetchedHolidayTypes = <DateTime, String>{};
    var fetchedTermWeeks = <_TermWeekSchedule>[];
    int? fetchedOfficialWeeksCount;
    String? activeTermId;
    String? preferredTermIdFromCurrent;
    bool hasActiveTerm = false;
    Map<String, dynamic>? preferredTermData;
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activeTermDocs =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    bool isCurrentDateWithinActiveTerm = false;

    void applyTermData(Map<String, dynamic> termData) {
      final termStart = _readDateTime(termData, const [
        'startDate',
        'semesterStartDate',
      ]);
      final termEnd = _readDateTime(termData, const [
        'endDate',
        'semesterEndDate',
      ]);
      final termWeeks = _readPositiveInt(termData, const [
        'effectiveTeachingWeeks',
        'officialWeeksCount',
        'semesterWeeks',
        'totalWeeks',
      ]);
      final officialWeeks = _readPositiveInt(termData, const [
        'officialWeeksCount',
      ]);
      final termWeekendDays = _readWeekendDays(termData, const ['weekendDays']);

      fetchedStartDate = termStart;
      fetchedEndDate = termEnd;
      fetchedWeeks = termWeeks ?? fetchedWeeks;
      fetchedOfficialWeeksCount = officialWeeks ?? fetchedOfficialWeeksCount;
      if (termWeekendDays != null) {
        fetchedWeekendDays = termWeekendDays;
      }
    }

    try {
      final currentDoc = await _firestore
          .collection('academic_calendar')
          .doc('current')
          .get(const GetOptions(source: Source.server));
      if (currentDoc.exists) {
        final data = currentDoc.data() ?? <String, dynamic>{};
        fetchedCurrentDate = _readDateTime(data, const [
          'currentDateTime',
          'currentDate',
        ]);
        fetchedStartDate = _readDateTime(data, const [
          'semesterStartDate',
          'startDate',
        ]);
        fetchedEndDate = _readDateTime(data, const [
          'semesterEndDate',
          'endDate',
        ]);
        fetchedWeeks = _readPositiveInt(data, const [
          'semesterWeeks',
          'totalWeeks',
        ]);
        fetchedEditableWindowDays = _readPositiveInt(data, const [
          'editableWindowDays',
        ]);
        fetchedWeekendDays = _readWeekendDays(data, const ['weekendDays']);
        preferredTermIdFromCurrent = _readNonEmptyString(data, const [
          'activeTermId',
          'termId',
          'currentTermId',
        ]);
      }
    } catch (_) {
      // Keep local defaults/fallback.
    }

    try {
      if (preferredTermIdFromCurrent != null &&
          preferredTermIdFromCurrent.isNotEmpty) {
        final preferredTermDoc = await _firestore
            .collection('academic_terms')
            .doc(preferredTermIdFromCurrent)
            .get(const GetOptions(source: Source.server));
        if (preferredTermDoc.exists) {
          preferredTermData = preferredTermDoc.data() ?? <String, dynamic>{};
        }
      }
    } catch (_) {
      // Keep local defaults/fallback.
    }

    try {
      final activeTerms = await _firestore
          .collection('academic_terms')
          .where('isActive', isEqualTo: true)
          .get(const GetOptions(source: Source.server));
      activeTermDocs = activeTerms.docs;
    } catch (_) {
      // Keep local defaults/fallback.
    }

    QueryDocumentSnapshot<Map<String, dynamic>>? selectedActiveTermDoc;
    if (activeTermDocs.isNotEmpty) {
      QueryDocumentSnapshot<Map<String, dynamic>>? preferredActiveTermDoc;
      if (preferredTermIdFromCurrent != null &&
          preferredTermIdFromCurrent.isNotEmpty) {
        for (final doc in activeTermDocs) {
          if (doc.id == preferredTermIdFromCurrent) {
            preferredActiveTermDoc = doc;
            break;
          }
        }
      }

      if (preferredActiveTermDoc != null &&
          (_isDateWithinTerm(preferredActiveTermDoc.data(), now) ||
              activeTermDocs.length == 1)) {
        selectedActiveTermDoc = preferredActiveTermDoc;
      } else {
        selectedActiveTermDoc = _resolvePreferredTerm(activeTermDocs, now);
      }
    }

    if (selectedActiveTermDoc != null) {
      hasActiveTerm = true;
      activeTermId = selectedActiveTermDoc.id;
      applyTermData(selectedActiveTermDoc.data());
    } else if (preferredTermIdFromCurrent != null &&
        preferredTermIdFromCurrent.isNotEmpty &&
        preferredTermData != null) {
      // Fallback only when no active term exists.
      hasActiveTerm = true;
      activeTermId = preferredTermIdFromCurrent;
      applyTermData(preferredTermData);
    }

    if (hasActiveTerm && activeTermId != null && activeTermId.isNotEmpty) {
      final currentDateOnly = _normalizeDate(fetchedCurrentDate ?? now);
      if (fetchedStartDate != null && fetchedEndDate != null) {
        final start = fetchedStartDate!;
        final end = fetchedEndDate!;
        isCurrentDateWithinActiveTerm =
            (currentDateOnly.isAfter(start) ||
                currentDateOnly.isAtSameMomentAs(start)) &&
            (currentDateOnly.isBefore(end) ||
                currentDateOnly.isAtSameMomentAs(end));
      }
      // الاستثناءات من Firebase هي مصدر الحقيقة، تُطبّق مباشرة كما سُجلت.
      final typedHolidays = await _loadTypedTermHolidays(activeTermId);
      fetchedHolidayTypes.addAll(typedHolidays);
      fetchedHolidays.addAll(typedHolidays.keys);
      fetchedTermWeeks = await _loadTermWeeks(activeTermId);
    }

    _currentDateTime = fetchedCurrentDate ?? now;
    _semesterStartDate = _normalizeDate(
      fetchedStartDate ?? DateTime(_currentDateTime.year, 1, 1),
    );
    final fallbackWeeks = (fetchedWeeks ?? _semesterWeeks).clamp(1, 60);
    _semesterEndDate = _normalizeDate(
      fetchedEndDate ??
          _semesterStartDate.add(Duration(days: (fallbackWeeks * 7) - 1)),
    );

    if (_semesterEndDate.isBefore(_semesterStartDate)) {
      _semesterEndDate = _semesterStartDate.add(const Duration(days: 111));
    }

    _semesterWeeks =
        (fetchedWeeks ??
                _calculateWeeksBetween(_semesterStartDate, _semesterEndDate))
            .clamp(1, 60);
    _editableWindowDays = (fetchedEditableWindowDays ?? _editableWindowDays)
        .clamp(1, 60);

    _weekendDays =
        fetchedWeekendDays ?? <int>{DateTime.friday, DateTime.saturday};
    _officialHolidays = fetchedHolidays;
    _holidayTypeByDate = fetchedHolidayTypes;
    _termWeeks = fetchedTermWeeks;
    _weeksByOfficialNumber = {
      for (final week in fetchedTermWeeks) week.officialWeekNumber: week,
    };
    _officialWeeksCount =
        (fetchedOfficialWeeksCount ?? _semesterWeeks).clamp(1, 60);
    debugPrint(
      '[CalendarSync] term=$activeTermId hasActiveTerm=$hasActiveTerm '
      'preferredTermFromCurrent=$preferredTermIdFromCurrent '
      'activeTermsFound=${activeTermDocs.length} '
      'inRange=$isCurrentDateWithinActiveTerm '
      'start=$_semesterStartDate end=$_semesterEndDate weeks=$_semesterWeeks '
      'officialWeeks=$_officialWeeksCount termWeeks=${_termWeeks.length} '
      'nonAttendanceWeeks=${_termWeeks.where((w) => w.isNonAttendance).length} '
      'weekendDays=$_weekendDays holidays=${_officialHolidays.length} '
      'typedHolidays=${_holidayTypeByDate.length}',
    );
  }

  /// هل التاريخ عطلة؟ (نهاية أسبوع + العطل الرسمية).
  bool isHoliday(DateTime date) {
    final dateOnly = _normalizeDate(date);
    if (_weekendDays.contains(dateOnly.weekday)) return true;
    return _officialHolidays.contains(dateOnly);
  }

  /// Weekends, [calendar_exceptions], and term weeks marked non-attendance.
  ///
  /// Used by Lecturer Home to hide schedule-driven lectures on excluded dates.
  bool isScheduledLecturesExcluded(DateTime date) {
    return isHoliday(date) || isNonAttendanceWeekDate(date);
  }

  /// Whether [date] falls in a term week with `countInAttendance == false` or
  /// `status == break`, using week doc date ranges when present or official
  /// week blocks from the active term start.
  bool isNonAttendanceWeekDate(DateTime date) {
    if (_termWeeks.isEmpty) return false;
    final d = _normalizeDate(date);

    for (final week in _termWeeks) {
      if (!week.isNonAttendance) continue;
      final start = week.startDate;
      final end = week.endDate;
      if (start == null || end == null) continue;
      if (_isDateInInclusiveRange(d, start, end)) return true;
    }

    final officialWeek = _officialWeekNumberForDate(d);
    return _weeksByOfficialNumber[officialWeek]?.isNonAttendance ?? false;
  }

  /// Whether [date] falls within the active term start/end (inclusive, date-only).
  bool isWithinActiveTerm(DateTime date) {
    final d = _normalizeDate(date);
    final start = _normalizeDate(_semesterStartDate);
    final end = _normalizeDate(_semesterEndDate);
    return (d.isAfter(start) || d.isAtSameMomentAs(start)) &&
        (d.isBefore(end) || d.isAtSameMomentAs(end));
  }

  int _officialWeekNumberForDate(DateTime date) {
    final start = _normalizeDate(_semesterStartDate);
    final d = _normalizeDate(date);
    final days = d.difference(start).inDays;
    if (days < 0) return 1;
    final week = (days ~/ 7) + 1;
    return week.clamp(1, _officialWeeksCount.clamp(1, 60));
  }

  bool _isDateInInclusiveRange(DateTime date, DateTime start, DateTime end) {
    final d = _normalizeDate(date);
    final s = _normalizeDate(start);
    final e = _normalizeDate(end);
    return (d.isAfter(s) || d.isAtSameMomentAs(s)) &&
        (d.isBefore(e) || d.isAtSameMomentAs(e));
  }

  /// رقم الأسبوع الأكاديمي بناءً على تاريخ بداية الفصل.
  int getWeekNumber(DateTime date) {
    final d = _normalizeDate(date);
    if (d.isBefore(_semesterStartDate)) return 1;
    final daysDiff = d.difference(_semesterStartDate).inDays;
    final week = (daysDiff ~/ 7) + 1;
    return week.clamp(1, _semesterWeeks);
  }

  /// Official week index from term start (for Manage Lectures week selection).
  int getOfficialWeekNumber(DateTime date) => _officialWeekNumberForDate(date);

  /// يحوّل (رقم أسبوع + يوم أسبوع) إلى تاريخ فعلي داخل التقويم.
  DateTime? dateForWeekAndWeekday(int weekNumber, int weekday) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) return null;
    if (weekNumber < 1) return null;

    final normalizedWeek = weekNumber.clamp(1, _semesterWeeks);
    final weekStart = _semesterStartDate.add(
      Duration(days: (normalizedWeek - 1) * 7),
    );
    final dayOffset = (weekday - weekStart.weekday + 7) % 7;
    final target = weekStart.add(Duration(days: dayOffset));
    return _normalizeDate(target);
  }

  /// Maps official week number + weekday to a date (Manage Lectures).
  DateTime? dateForOfficialWeekAndWeekday(int weekNumber, int weekday) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) return null;
    final maxWeek = manageLecturesWeekUpperBound;
    if (weekNumber < 1 || weekNumber > maxWeek) return null;

    final weekStart = _semesterStartDate.add(
      Duration(days: (weekNumber - 1) * 7),
    );
    final dayOffset = (weekday - weekStart.weekday + 7) % 7;
    final target = weekStart.add(Duration(days: dayOffset));
    return _normalizeDate(target);
  }

  /// جلب جميع المحاضرات (Mock data)
  /// dayOfWeek: 1=الاثنين, 2=الثلاثاء, 3=الأربعاء, 4=الخميس, 5=الجمعة, 6=السبت, 7=الأحد
  List<LectureItem> getAllLectures() {
    final now = _currentDateTime;
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);
    return [
      LectureItem(
        courseName: tr('هندسة البرمجيات', 'Software Engineering'),
        crn: 'SE3310',
        hall: 'DEN01',
        section: '1',
        activity: 'نظري',
        startTime: '8:00',
        isDouble: true,
        dayOfWeek: 7,
      ),
      LectureItem(
        courseName: tr('قواعد البيانات', 'Databases'),
        crn: 'CS3320',
        hall: 'DEN02',
        section: '2',
        activity: 'نظري',
        startTime: '10:00',
        isDouble: true,
        dayOfWeek: 7,
      ),
      LectureItem(
        courseName: tr('الذكاء الاصطناعي', 'Artificial Intelligence'),
        crn: 'CS3330',
        hall: 'DEN03',
        section: '1',
        activity: 'نظري',
        startTime: '12:00',
        isDouble: false,
        dayOfWeek: 7,
      ),
      LectureItem(
        courseName: tr('أمن المعلومات', 'Information Security'),
        crn: 'CS3340',
        hall: 'DEN04',
        section: '3',
        activity: 'نظري',
        startTime: '2:00',
        isDouble: true,
        dayOfWeek: 7,
      ),
      LectureItem(
        courseName: tr('الشبكات الحاسوبية', 'Computer Networks'),
        crn: 'CS3350',
        hall: 'DEN05',
        section: '2',
        activity: 'نظري',
        startTime: '4:00',
        isDouble: false,
        dayOfWeek: 7,
      ),
      LectureItem(
        courseName: tr('تطوير التطبيقات', 'Application Development'),
        crn: 'SE3360',
        hall: 'DEN06',
        section: '1',
        activity: 'نظري',
        startTime: '8:00',
        isDouble: true,
        dayOfWeek: 1,
      ),
      LectureItem(
        courseName: tr('الخوارزميات المتقدمة', 'Advanced Algorithms'),
        crn: 'CS3370',
        hall: 'DEN07',
        section: '2',
        activity: 'نظري',
        startTime: '10:00',
        isDouble: false,
        dayOfWeek: 1,
      ),
      LectureItem(
        courseName: tr('أنظمة التشغيل', 'Operating Systems'),
        crn: 'CS3380',
        hall: 'DEN08',
        section: '3',
        activity: 'نظري',
        startTime: '8:00',
        isDouble: true,
        dayOfWeek: 2,
      ),
      LectureItem(
        courseName: tr('البرمجة المتقدمة', 'Advanced Programming'),
        crn: 'CS3390',
        hall: 'DEN09',
        section: '1',
        activity: 'نظري',
        startTime: '10:00',
        isDouble: false,
        dayOfWeek: 2,
      ),
      LectureItem(
        courseName: tr('مشروع التخرج', 'Graduation Project'),
        crn: 'CS3400',
        hall: 'DEN10',
        section: '1',
        activity: 'عملي',
        startTime: '12:00',
        isDouble: true,
        dayOfWeek: 2,
      ),
      LectureItem(
        courseName: tr('تحليل النظم', 'Systems Analysis'),
        crn: 'SE3410',
        hall: 'DEN11',
        section: '2',
        activity: 'نظري',
        startTime: '2:00',
        isDouble: false,
        dayOfWeek: 2,
      ),
      LectureItem(
        courseName: tr('قواعد البيانات المتقدمة', 'Advanced Databases'),
        crn: 'CS3420',
        hall: 'DEN12',
        section: '1',
        activity: 'نظري',
        startTime: '8:00',
        isDouble: true,
        dayOfWeek: 4,
      ),
      LectureItem(
        courseName: tr('هندسة المتطلبات', 'Requirements Engineering'),
        crn: 'SE3430',
        hall: 'DEN01',
        section: '2',
        activity: 'نظري',
        startTime: '10:00',
        isDouble: false,
        dayOfWeek: 4,
      ),
      LectureItem(
        courseName: tr(
          'الذكاء الاصطناعي التطبيقي',
          'Applied Artificial Intelligence',
        ),
        crn: 'CS3440',
        hall: 'DEN02',
        section: '1',
        activity: 'نظري',
        startTime: '12:00',
        isDouble: true,
        dayOfWeek: 4,
      ),
      LectureItem(
        courseName: tr('محاضرة اليوم', "Today's Lecture"),
        crn: 'TODAY1',
        hall: 'DEN01',
        section: '1',
        activity: 'نظري',
        startTime: '9:00',
        isDouble: false,
        dayOfWeek: now.weekday,
      ),
      LectureItem(
        courseName: tr('محاضرة الغد', "Tomorrow's Lecture"),
        crn: 'TOMORROW1',
        hall: 'DEN02',
        section: '1',
        activity: 'نظري',
        startTime: '11:00',
        isDouble: true,
        dayOfWeek: now.add(const Duration(days: 1)).weekday,
      ),
    ];
  }

  /// جلب المحاضرات ليوم معين
  List<LectureItem> getLecturesForDay(
    int dayOfWeek, {
    List<LectureItem>? allLectures,
  }) {
    final lectures = allLectures ?? getAllLectures();
    return lectures.where((lecture) => lecture.dayOfWeek == dayOfWeek).toList();
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  int _calculateWeeksBetween(DateTime start, DateTime end) {
    final days = _normalizeDate(end).difference(_normalizeDate(start)).inDays;
    if (days < 0) return 1;
    return (days ~/ 7) + 1;
  }

  DateTime? _readDateTime(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final parsed = _parseDateTime(data[key]);
      if (parsed != null) return _normalizeDate(parsed);
    }
    return null;
  }

  int? _readPositiveInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final parsed = _safeInt(data[key]);
      if (parsed > 0) return parsed;
    }
    return null;
  }

  Set<int>? _readWeekendDays(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final raw = data[key];
      if (raw is! Iterable) continue;
      final parsed = raw
          .map(_parseWeekday)
          .whereType<int>()
          .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
          .toSet();
      if (parsed.isNotEmpty) return parsed;
    }
    return null;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.isUtc ? value.toLocal() : value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final parsed = DateTime.tryParse(trimmed);
      return parsed?.toLocal();
    }
    if (value is int) {
      if (value <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      final v = value.toInt();
      if (v <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    return null;
  }

  int? _parseWeekday(dynamic value) {
    final n = _safeInt(value);
    if (n >= DateTime.monday && n <= DateTime.sunday) return n;
    if (value is String) {
      final raw = value.trim().toLowerCase();
      switch (raw) {
        case 'mon':
        case 'monday':
        case 'الاثنين':
          return DateTime.monday;
        case 'tue':
        case 'tuesday':
        case 'الثلاثاء':
          return DateTime.tuesday;
        case 'wed':
        case 'wednesday':
        case 'الأربعاء':
          return DateTime.wednesday;
        case 'thu':
        case 'thursday':
        case 'الخميس':
          return DateTime.thursday;
        case 'fri':
        case 'friday':
        case 'الجمعة':
          return DateTime.friday;
        case 'sat':
        case 'saturday':
        case 'السبت':
          return DateTime.saturday;
        case 'sun':
        case 'sunday':
        case 'الأحد':
          return DateTime.sunday;
      }
    }
    return null;
  }

  QueryDocumentSnapshot<Map<String, dynamic>> _resolvePreferredTerm(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    DateTime now,
  ) {
    final today = _normalizeDate(now);
    for (final doc in docs) {
      final data = doc.data();
      final start = _readDateTime(data, const [
        'startDate',
        'semesterStartDate',
      ]);
      final end = _readDateTime(data, const ['endDate', 'semesterEndDate']);
      if (start == null || end == null) continue;
      final inRange =
          (today.isAfter(start) || today.isAtSameMomentAs(start)) &&
          (today.isBefore(end) || today.isAtSameMomentAs(end));
      if (inRange) {
        return doc;
      }
    }
    docs.sort((a, b) {
      final aDate =
          _readDateTime(a.data(), const ['startDate']) ?? DateTime(1970);
      final bDate =
          _readDateTime(b.data(), const ['startDate']) ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return docs.first;
  }

  Future<Map<DateTime, String>> _loadTypedTermHolidays(String termId) async {
    final holidays = <DateTime, String>{};

    try {
      final exceptionsSnapshot = await _firestore
          .collection('academic_terms')
          .doc(termId)
          .collection('calendar_exceptions')
          .get(const GetOptions(source: Source.server));
      for (final doc in exceptionsSnapshot.docs) {
        final data = doc.data();
        final start = _readDateTime(data, const ['startDate']);
        final end = _readDateTime(data, const ['endDate']) ?? start;
        if (start == null || end == null) continue;
        final type = (data['type'] ?? '').toString().trim().toLowerCase();
        final exclude = data['excludeFromAttendance'] == true;
        final isKnownType =
            type == 'holiday' ||
            type == 'break' ||
            type == 'suspension' ||
            type == 'other';
        final isHolidayLike = exclude || isKnownType;
        if (!isHolidayLike) continue;
        final normalizedType = _normalizeHolidayType(type, exclude: exclude);
        for (final date in _expandDateRange(start, end)) {
          _putHolidayTypeWithPriority(holidays, date, normalizedType);
        }
      }
    } catch (_) {
      // Ignore and continue with other sources.
    }

    return holidays;
  }

  Future<List<_TermWeekSchedule>> _loadTermWeeks(String termId) async {
    final weeks = <_TermWeekSchedule>[];
    try {
      final snapshot = await _firestore
          .collection('academic_terms')
          .doc(termId)
          .collection('weeks')
          .get(const GetOptions(source: Source.server));
      for (final doc in snapshot.docs) {
        final week = _TermWeekSchedule.fromFirestore(doc.data());
        if (week.officialWeekNumber > 0) {
          weeks.add(week);
        }
      }
    } catch (_) {
      // Keep empty; Home still uses calendar_exceptions/weekends.
    }
    return weeks;
  }

  String _normalizeHolidayType(String raw, {required bool exclude}) {
    switch (raw.trim().toLowerCase()) {
      case 'holiday':
        return 'holiday';
      case 'break':
        return 'break';
      case 'suspension':
        return 'suspension';
      case 'other':
        return 'other';
      default:
        return 'other';
    }
  }

  void _putHolidayTypeWithPriority(
    Map<DateTime, String> target,
    DateTime date,
    String type,
  ) {
    final d = _normalizeDate(date);
    final existing = target[d];
    if (existing == null) {
      target[d] = type;
      return;
    }
    if (_holidayTypePriority(type) > _holidayTypePriority(existing)) {
      target[d] = type;
    }
  }

  int _holidayTypePriority(String type) {
    switch (type) {
      case 'suspension':
        return 4;
      case 'holiday':
        return 3;
      case 'break':
        return 2;
      case 'other':
        return 1;
      default:
        return 0;
    }
  }

  Set<DateTime> _expandDateRange(DateTime start, DateTime end) {
    final s = _normalizeDate(start);
    final e = _normalizeDate(end);
    final from = s.isBefore(e) ? s : e;
    final to = s.isAfter(e) ? s : e;
    final dates = <DateTime>{};
    var cursor = from;
    while (cursor.isBefore(to) || cursor.isAtSameMomentAs(to)) {
      dates.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return dates;
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  bool _isDateWithinTerm(Map<String, dynamic> termData, DateTime date) {
    final start = _readDateTime(termData, const [
      'startDate',
      'semesterStartDate',
    ]);
    final end = _readDateTime(termData, const ['endDate', 'semesterEndDate']);
    if (start == null || end == null) return false;
    final d = _normalizeDate(date);
    return (d.isAfter(start) || d.isAtSameMomentAs(start)) &&
        (d.isBefore(end) || d.isAtSameMomentAs(end));
  }

  String? _readNonEmptyString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }
}

class _TermWeekSchedule {
  const _TermWeekSchedule({
    required this.officialWeekNumber,
    required this.countInAttendance,
    required this.isBreak,
    this.startDate,
    this.endDate,
  });

  final int officialWeekNumber;
  final bool countInAttendance;
  final bool isBreak;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get isNonAttendance => !countInAttendance || isBreak;

  factory _TermWeekSchedule.fromFirestore(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    return _TermWeekSchedule(
      officialWeekNumber: _readOfficialWeekNumber(data['officialWeekNumber']),
      countInAttendance: data['countInAttendance'] == true,
      isBreak: status == 'break',
      startDate: _readOptionalDate(data['startDate']),
      endDate: _readOptionalDate(data['endDate']),
    );
  }

  static int _readOfficialWeekNumber(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    final parsed = int.tryParse((value ?? '').toString());
    if (parsed != null && parsed > 0) return parsed;
    return 0;
  }

  static DateTime? _readOptionalDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return DateTime(d.year, d.month, d.day);
    }
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed == null) return null;
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return null;
  }
}
