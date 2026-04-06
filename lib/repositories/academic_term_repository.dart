import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/academic_term.dart';
import '../models/calendar_exception.dart';
import '../models/term_week.dart';

/// Repository for academic_terms and academic_terms/{termId}/weeks.
/// Admin/database only; no Student/Lecturer/Security UI.
class AcademicTermRepository {
  AcademicTermRepository._();
  static final AcademicTermRepository instance = AcademicTermRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _termsCollection = 'academic_terms';
  static const String _weeksSubcollection = 'weeks';
  static const String _exceptionsSubcollection = 'calendar_exceptions';

  CollectionReference<Map<String, dynamic>> get _termsRef =>
      _firestore.collection(_termsCollection);

  /// Returns all terms ordered by startDate descending.
  Future<List<AcademicTerm>> getTerms() async {
    final snapshot = await _termsRef.orderBy('startDate', descending: true).get();
    return snapshot.docs.map(AcademicTerm.fromDoc).toList();
  }

  /// Stream of all terms.
  Stream<List<AcademicTerm>> watchTerms() {
    return _termsRef.orderBy('startDate', descending: true).snapshots().map(
          (s) => s.docs.map(AcademicTerm.fromDoc).toList(),
        );
  }

  /// Get a single term by id.
  Future<AcademicTerm?> getTerm(String termId) async {
    if (termId.trim().isEmpty) return null;
    final doc = await _termsRef.doc(termId).get();
    if (!doc.exists) return null;
    return AcademicTerm.fromDoc(doc);
  }

  /// Validate term: startDate < endDate, officialWeeksCount > 0.
  String? validateTerm(AcademicTerm term) {
    if (term.startDate.isAfter(term.endDate) || term.startDate.isAtSameMomentAs(term.endDate)) {
      return 'تاريخ البداية يجب أن يكون قبل تاريخ النهاية';
    }
    if (term.officialWeeksCount < 1) {
      return 'عدد الأسابيع الرسمية يجب أن يكون 1 على الأقل';
    }
    if (term.effectiveTeachingWeeks < 0 || term.effectiveTeachingWeeks > term.officialWeeksCount) {
      return 'عدد أسابيع التدريس الفعلية غير صالح';
    }
    return null;
  }

  /// Create a new term. termId can be provided or auto-generated.
  Future<String> createTerm(AcademicTerm term) async {
    final err = validateTerm(term);
    if (err != null) throw ArgumentError(err);

    final id = term.termId.trim().isNotEmpty ? term.termId : _termsRef.doc().id;
    debugPrint('[AcademicTermRepo] WRITE path: $_termsCollection/$id (set)');
    final data = term.toMap()
      ..['createdAt'] = FieldValue.serverTimestamp();
    await _termsRef.doc(id).set(data);
    return id;
  }

  /// Update an existing term.
  Future<void> updateTerm(AcademicTerm term) async {
    final err = validateTerm(term);
    if (err != null) throw ArgumentError(err);

    debugPrint('[AcademicTermRepo] WRITE path: $_termsCollection/${term.termId} (set merge)');
    await _termsRef.doc(term.termId).set(term.toMap(), SetOptions(merge: true));
  }

  /// Set isActive for a term.
  Future<void> setTermActive(String termId, bool isActive) async {
    debugPrint('[AcademicTermRepo] WRITE path: $_termsCollection/$termId (update isActive)');
    await _termsRef.doc(termId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get all weeks for a term, ordered by officialWeekNumber.
  Future<List<TermWeek>> getWeeks(String termId) async {
    if (termId.trim().isEmpty) return [];
    final snapshot = await _termsRef
        .doc(termId)
        .collection(_weeksSubcollection)
        .orderBy('officialWeekNumber')
        .get();
    return snapshot.docs.map(TermWeek.fromDoc).toList();
  }

  /// Validate weeks: no duplicate officialWeekNumber, break weeks have null effective, instructional sequential.
  String? validateWeeks(List<TermWeek> weeks, int officialWeeksCount) {
    final officialSet = <int>{};
    int nextEffective = 1;
    for (final w in weeks) {
      if (w.officialWeekNumber < 1 || w.officialWeekNumber > officialWeeksCount) {
        return 'رقم الأسبوع الرسمي ${w.officialWeekNumber} خارج النطاق 1-$officialWeeksCount';
      }
      if (officialSet.contains(w.officialWeekNumber)) {
        return 'تكرار رقم الأسبوع الرسمي ${w.officialWeekNumber}';
      }
      officialSet.add(w.officialWeekNumber);

      if (w.isBreak) {
        if (w.effectiveWeekNumber != null) {
          return 'أسبوع الإجازة يجب ألا يحمل رقماً فعلياً';
        }
        if (w.countInAttendance) return 'أسبوع الإجازة لا يُحسب في الحضور';
      } else {
        if (w.effectiveWeekNumber != nextEffective) {
          return 'الرقم الفعلي للأسبوع التعليمي يجب أن يكون $nextEffective';
        }
        nextEffective++;
        if (!w.countInAttendance) return 'الأسبوع التعليمي يجب أن يُحسب في الحضور';
      }
    }
    return null;
  }

  /// Save weeks for a term. Recomputes effectiveWeekNumber for instructional weeks and updates term.effectiveTeachingWeeks.
  /// [weeks] must be ordered by officialWeekNumber and already have status set; this method assigns effectiveWeekNumber.
  Future<void> saveWeeks(String termId, List<TermWeek> weeks) async {
    if (termId.trim().isEmpty) return;

    final term = await getTerm(termId);
    if (term == null) throw StateError('Term not found: $termId');

    int nextEffective = 1;
    final updated = <TermWeek>[];
    for (final w in weeks) {
      if (w.isBreak) {
        updated.add(TermWeek(
          weekId: w.weekId,
          officialWeekNumber: w.officialWeekNumber,
          effectiveWeekNumber: null,
          status: w.status,
          countInAttendance: false,
          startDate: w.startDate,
          endDate: w.endDate,
          label: w.label,
          createdAt: w.createdAt,
          updatedAt: w.updatedAt,
        ));
      } else {
        updated.add(TermWeek(
          weekId: w.weekId,
          officialWeekNumber: w.officialWeekNumber,
          effectiveWeekNumber: nextEffective,
          status: w.status,
          countInAttendance: true,
          startDate: w.startDate,
          endDate: w.endDate,
          label: w.label,
          createdAt: w.createdAt,
          updatedAt: w.updatedAt,
        ));
        nextEffective++;
      }
    }

    final effectiveTeachingWeeks = nextEffective - 1;
    final err = validateWeeks(updated, term.officialWeeksCount);
    if (err != null) throw ArgumentError(err);

    debugPrint('[AcademicTermRepo] WRITE path: $_termsCollection/$termId (update effectiveTeachingWeeks)');
    for (final w in updated) {
      debugPrint('[AcademicTermRepo] WRITE path: $_termsCollection/$termId/$_weeksSubcollection/${w.weekId} (set)');
    }
    final batch = _firestore.batch();
    final weeksRef = _termsRef.doc(termId).collection(_weeksSubcollection);

    for (final w in updated) {
      final docId = w.weekId;
      final data = w.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      batch.set(weeksRef.doc(docId), data, SetOptions(merge: true));
    }

    batch.update(_termsRef.doc(termId), {
      'effectiveTeachingWeeks': effectiveTeachingWeeks,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Build week documents from range-based input. Example: [(1,5,instructional), (6,7,break), (8,9,instructional)].
  /// Returns list of TermWeek with weekId = "w1", "w2", ... and status set; effective numbers assigned in saveWeeks.
  static List<TermWeek> weeksFromRanges(
    List<({int start, int end, WeekStatus status})> ranges,
    int officialWeeksCount,
  ) {
    final list = <TermWeek>[];
    for (final r in ranges) {
      for (int o = r.start; o <= r.end; o++) {
        if (o < 1 || o > officialWeeksCount) continue;
        list.add(TermWeek(
          weekId: 'w$o',
          officialWeekNumber: o,
          effectiveWeekNumber: null,
          status: r.status,
          countInAttendance: r.status == WeekStatus.instructional,
          label: 'أسبوع $o',
        ));
      }
    }
    list.sort((a, b) => a.officialWeekNumber.compareTo(b.officialWeekNumber));
    return list;
  }

  /// Get week info for a given date within a term (by termId). Returns the week if date falls in term range and week exists.
  Future<TermWeek?> getWeekForDate(String termId, DateTime date) async {
    final weeks = await getWeeks(termId);
    final normalized = DateTime(date.year, date.month, date.day);
    for (final w in weeks) {
      if (w.startDate != null && w.endDate != null) {
        final start = DateTime(w.startDate!.year, w.startDate!.month, w.startDate!.day);
        final end = DateTime(w.endDate!.year, w.endDate!.month, w.endDate!.day);
        if ((normalized.isAfter(start) || normalized.isAtSameMomentAs(start)) &&
            (normalized.isBefore(end) || normalized.isAtSameMomentAs(end))) {
          return w;
        }
      }
    }
    return null;
  }

  /// Get week by official week number.
  Future<TermWeek?> getWeekByOfficialNumber(String termId, int officialWeekNumber) async {
    final snapshot = await _termsRef
        .doc(termId)
        .collection(_weeksSubcollection)
        .where('officialWeekNumber', isEqualTo: officialWeekNumber)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return TermWeek.fromDoc(snapshot.docs.first);
  }

  // ─── Calendar exceptions (date-specific exclusions) ───────────────────────

  CollectionReference<Map<String, dynamic>> _exceptionsRef(String termId) =>
      _termsRef.doc(termId).collection(_exceptionsSubcollection);

  Future<List<CalendarException>> getCalendarExceptions(String termId) async {
    if (termId.trim().isEmpty) return [];
    final snapshot = await _exceptionsRef(termId).orderBy('startDate').get();
    return snapshot.docs.map(CalendarException.fromDoc).toList();
  }

  Stream<List<CalendarException>> watchCalendarExceptions(String termId) {
    if (termId.trim().isEmpty) return Stream.value([]);
    return _exceptionsRef(termId).orderBy('startDate').snapshots().map(
          (s) => s.docs.map(CalendarException.fromDoc).toList(),
        );
  }

  Future<String> addCalendarException(String termId, CalendarException exception) async {
    final id = exception.exceptionId.trim().isNotEmpty ? exception.exceptionId : _exceptionsRef(termId).doc().id;
    debugPrint('[AcademicTermRepo] WRITE path: $_termsCollection/$termId/$_exceptionsSubcollection/$id (set)');
    final data = exception.exceptionId == id ? exception.toMap() : {...exception.toMap(), 'exceptionId': id};
    data['createdAt'] = FieldValue.serverTimestamp();
    await _exceptionsRef(termId).doc(id).set(data);
    return id;
  }

  Future<void> updateCalendarException(String termId, CalendarException exception) async {
    debugPrint('[AcademicTermRepo] WRITE path: $_termsCollection/$termId/$_exceptionsSubcollection/${exception.exceptionId} (set merge)');
    await _exceptionsRef(termId).doc(exception.exceptionId).set(exception.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteCalendarException(String termId, String exceptionId) async {
    debugPrint('[AcademicTermRepo] WRITE path: $_termsCollection/$termId/$_exceptionsSubcollection/$exceptionId (delete)');
    await _exceptionsRef(termId).doc(exceptionId).delete();
  }

  /// Returns true if [date] falls inside any calendar exception with excludeFromAttendance = true.
  /// Used to set countInAttendance = false for sessions on excluded dates.
  Future<bool> isDateExcludedFromAttendance(String termId, DateTime date) async {
    if (termId.trim().isEmpty) return false;
    final exceptions = await getCalendarExceptions(termId);
    final d = DateTime(date.year, date.month, date.day);
    for (final ex in exceptions) {
      if (ex.excludeFromAttendance && ex.containsDate(d)) return true;
    }
    return false;
  }
}
