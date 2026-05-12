import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Single-query load of current academic term week count + start date for attendance UI.
///
/// Replaces per-screen Firestore access from [AttendanceTrackingScreen].
class AcademicTermContextRepository {
  AcademicTermContextRepository._();
  static final AcademicTermContextRepository instance =
      AcademicTermContextRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return DateTime(d.year, d.month, d.day);
    }
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    if (value is String) {
      final d = DateTime.tryParse(value.trim());
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day);
    }
    return null;
  }

  int? _readPositiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return null;
    final direct = int.tryParse(raw);
    if (direct != null && direct > 0) return direct;
    final m = RegExp(r'(\d{1,3})').firstMatch(raw);
    if (m == null) return null;
    final parsed = int.tryParse(m.group(1)!);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  /// Returns effective teaching weeks (clamped 1–40) and term start date, or `null` on failure.
  Future<({int weeks, DateTime? start})?> loadCurrentWeekContext() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('academic_terms')
          .orderBy('startDate', descending: true)
          .limit(25)
          .get()
          .timeout(const Duration(seconds: 8));
      if (snapshot.docs.isEmpty) return null;

      QueryDocumentSnapshot<Map<String, dynamic>> preferred =
          snapshot.docs.first;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final start = _readDate(data['startDate']);
        final end = _readDate(data['endDate']);
        if (start == null || end == null) continue;
        final inRange =
            (now.isAfter(start) || now.isAtSameMomentAs(start)) &&
                (now.isBefore(end) || now.isAtSameMomentAs(end));
        if (inRange) {
          preferred = doc;
          break;
        }
      }

      if (preferred == snapshot.docs.first) {
        final sorted = [...snapshot.docs];
        sorted.sort((a, b) {
          final aStart = _readDate(a.data()['startDate']) ?? DateTime(1970);
          final bStart = _readDate(b.data()['startDate']) ?? DateTime(1970);
          return bStart.compareTo(aStart);
        });
        preferred = sorted.first;
      }

      final data = preferred.data();
      final termEffectiveWeeks =
          _readPositiveInt(data['effectiveTeachingWeeks']);
      var weeks = 15;
      if (termEffectiveWeeks != null && termEffectiveWeeks > 0) {
        weeks = termEffectiveWeeks.clamp(1, 40);
      }
      final start = _readDate(data['startDate']);
      return (weeks: weeks, start: start);
    } catch (_) {
      return null;
    }
  }
}
