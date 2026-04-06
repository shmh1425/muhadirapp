import 'package:cloud_firestore/cloud_firestore.dart';

import 'academic_term.dart';

/// Model for a document in academic_terms/{termId}/weeks subcollection.
class TermWeek {
  const TermWeek({
    required this.weekId,
    required this.officialWeekNumber,
    this.effectiveWeekNumber,
    required this.status,
    required this.countInAttendance,
    this.startDate,
    this.endDate,
    this.label,
    this.createdAt,
    this.updatedAt,
  });

  final String weekId;
  final int officialWeekNumber;
  final int? effectiveWeekNumber;
  final WeekStatus status;
  final bool countInAttendance;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? label;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isBreak => status == WeekStatus.break_;

  factory TermWeek.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final startRaw = data['startDate'];
    final endRaw = data['endDate'];
    return TermWeek(
      weekId: (data['weekId'] ?? doc.id).toString(),
      officialWeekNumber: _safeInt(data['officialWeekNumber']),
      effectiveWeekNumber: _optionalInt(data['effectiveWeekNumber']),
      status: data['status'] == 'break' ? WeekStatus.break_ : WeekStatus.instructional,
      countInAttendance: data['countInAttendance'] == true,
      startDate: startRaw is Timestamp ? startRaw.toDate() : _parseDate(startRaw),
      endDate: endRaw is Timestamp ? endRaw.toDate() : _parseDate(endRaw),
      label: (data['label'] ?? '').toString().trim().isEmpty ? null : (data['label'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weekId': weekId,
      'officialWeekNumber': officialWeekNumber,
      'effectiveWeekNumber': effectiveWeekNumber,
      'status': status == WeekStatus.break_ ? 'break' : 'instructional',
      'countInAttendance': countInAttendance,
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      if (label != null && label!.isNotEmpty) 'label': label,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  static int? _optionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final n = int.tryParse(value.toString());
    return n;
  }
}
