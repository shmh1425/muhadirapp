import 'package:cloud_firestore/cloud_firestore.dart';

/// Term calendar reads used for student-facing "is today a holiday?" checks.
///
/// Keeps Firestore access out of widgets and out of the unified courses mapper.
class AcademicCalendarRepository {
  AcademicCalendarRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static final AcademicCalendarRepository instance =
      AcademicCalendarRepository();

  /// Short-lived cache to avoid repeated calendar reads when navigating between
  /// student screens that all resolve the same "today" holiday flag.
  final Map<String, ({DateTime at, bool holiday})> _holidayCache =
      <String, ({DateTime at, bool holiday})>{};
  static const Duration _holidayCacheTtl = Duration(minutes: 5);

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime? _parseFirestoreDate(dynamic value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.isUtc ? value.toLocal() : value;
    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      return parsed?.toLocal();
    }
    if (value is int) {
      if (value <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    }
    if (value is num) {
      final ms = value.toInt();
      if (ms <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    }
    return null;
  }

  bool _isDateInRange({
    required DateTime date,
    required DateTime start,
    required DateTime end,
  }) {
    final d = _dateOnly(date);
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    return (d.isAfter(s) || d.isAtSameMomentAs(s)) &&
        (d.isBefore(e) || d.isAtSameMomentAs(e));
  }

  bool _isDateWithinTermData(Map<String, dynamic> data, DateTime date) {
    final start = _parseFirestoreDate(
      data['startDate'] ?? data['semesterStartDate'],
    );
    final end = _parseFirestoreDate(data['endDate'] ?? data['semesterEndDate']);
    if (start == null || end == null) return false;
    return _isDateInRange(date: date, start: start, end: end);
  }

  Future<String?> resolveTermIdForDate(DateTime date) async {
    String? preferredTermId;

    try {
      final currentDoc = await _firestore
          .collection('academic_calendar')
          .doc('current')
          .get();
      if (currentDoc.exists) {
        final current = currentDoc.data() ?? <String, dynamic>{};
        preferredTermId =
            (current['activeTermId'] ??
                    current['termId'] ??
                    current['currentTermId'] ??
                    '')
                .toString()
                .trim();
      }
    } catch (_) {
      // Ignore and fallback to active terms.
    }

    if (preferredTermId != null && preferredTermId.isNotEmpty) {
      try {
        final preferredDoc = await _firestore
            .collection('academic_terms')
            .doc(preferredTermId)
            .get();
        if (preferredDoc.exists) {
          final data = preferredDoc.data() ?? <String, dynamic>{};
          final isActive = data['isActive'] == true;
          if (isActive || _isDateWithinTermData(data, date)) {
            return preferredDoc.id;
          }
        }
      } catch (_) {
        // Ignore and fallback.
      }
    }

    try {
      final activeTerms = await _firestore
          .collection('academic_terms')
          .where('isActive', isEqualTo: true)
          .get();
      if (activeTerms.docs.isEmpty) return preferredTermId;

      for (final doc in activeTerms.docs) {
        if (_isDateWithinTermData(doc.data(), date)) {
          return doc.id;
        }
      }
      return activeTerms.docs.first.id;
    } catch (_) {
      return preferredTermId;
    }
  }

  /// `true` when [date] falls on a calendar exception marked holiday-like
  /// for the resolved active term (same rules as legacy student schedule).
  Future<bool> isHolidayForStudent(DateTime date) async {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final hit = _holidayCache[key];
    if (hit != null && now.difference(hit.at) < _holidayCacheTtl) {
      return hit.holiday;
    }
    final result = await _isHolidayForStudentUncached(date);
    _holidayCache[key] = (at: now, holiday: result);
    return result;
  }

  Future<bool> _isHolidayForStudentUncached(DateTime date) async {
    final termId = await resolveTermIdForDate(date);
    if (termId == null || termId.trim().isEmpty) return false;

    try {
      final snap = await _firestore
          .collection('academic_terms')
          .doc(termId)
          .collection('calendar_exceptions')
          .get();
      final d = _dateOnly(date);
      for (final doc in snap.docs) {
        final data = doc.data();
        final start = _parseFirestoreDate(data['startDate']);
        final end = _parseFirestoreDate(data['endDate']) ?? start;
        if (start == null || end == null) continue;
        final exclude = data['excludeFromAttendance'] == true;
        final type = (data['type'] ?? '').toString().trim().toLowerCase();
        final holidayLike =
            exclude ||
            type == 'holiday' ||
            type == 'break' ||
            type == 'suspension' ||
            type == 'other';
        if (!holidayLike) continue;
        if (_isDateInRange(date: d, start: start, end: end)) {
          return true;
        }
      }
    } catch (_) {
      // If fetch fails, fallback to not a holiday.
    }
    return false;
  }
}
