import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of calendar exception.
enum CalendarExceptionType { holiday, break_, suspension, other }

/// Model for academic_terms/{termId}/calendar_exceptions/{exceptionId}.
/// Date or date-range exclusions that can exclude sessions from attendance counting.
class CalendarException {
  const CalendarException({
    required this.exceptionId,
    required this.titleAr,
    required this.titleEn,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.excludeFromAttendance,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String exceptionId;
  final String titleAr;
  final String titleEn;
  final DateTime startDate;
  final DateTime endDate;
  final CalendarExceptionType type;
  final bool excludeFromAttendance;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool containsDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return (d.isAfter(start) || d.isAtSameMomentAs(start)) &&
        (d.isBefore(end) || d.isAtSameMomentAs(end));
  }

  static CalendarExceptionType typeFromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'break':
        return CalendarExceptionType.break_;
      case 'suspension':
        return CalendarExceptionType.suspension;
      case 'other':
        return CalendarExceptionType.other;
      case 'holiday':
      default:
        return CalendarExceptionType.holiday;
    }
  }

  static String typeToString(CalendarExceptionType t) {
    switch (t) {
      case CalendarExceptionType.holiday:
        return 'holiday';
      case CalendarExceptionType.break_:
        return 'break';
      case CalendarExceptionType.suspension:
        return 'suspension';
      case CalendarExceptionType.other:
        return 'other';
    }
  }

  factory CalendarException.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final startRaw = data['startDate'];
    final endRaw = data['endDate'];
    final startDate = startRaw is Timestamp
        ? startRaw.toDate()
        : DateTime.tryParse((startRaw ?? '').toString()) ?? DateTime.now();
    final endDate = endRaw is Timestamp
        ? endRaw.toDate()
        : DateTime.tryParse((endRaw ?? '').toString()) ?? DateTime.now();
    return CalendarException(
      exceptionId: (data['exceptionId'] ?? doc.id).toString(),
      titleAr: (data['titleAr'] ?? '').toString(),
      titleEn: (data['titleEn'] ?? '').toString(),
      startDate: startDate,
      endDate: endDate,
      type: typeFromString((data['type'] ?? '').toString()),
      excludeFromAttendance: data['excludeFromAttendance'] == true,
      notes: (data['notes'] ?? '').toString().trim().isEmpty ? null : (data['notes'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exceptionId': exceptionId,
      'titleAr': titleAr,
      'titleEn': titleEn,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'type': typeToString(type),
      'excludeFromAttendance': excludeFromAttendance,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
