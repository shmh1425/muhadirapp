import 'package:cloud_firestore/cloud_firestore.dart';

enum ExcuseRequestStatus { pending, accepted, rejected }

class ExcuseRequest {
  const ExcuseRequest({
    required this.id,
    required this.studentId,
    required this.sectionId,
    required this.courseNameAr,
    required this.lectureDate,
    required this.lectureStartTime,
    required this.lectureEndTime,
    required this.status,
    this.reasonText,
    this.attachmentUrl,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final int studentId;
  final String sectionId;
  final String courseNameAr;
  final DateTime lectureDate;
  final String lectureStartTime;
  final String lectureEndTime;
  final ExcuseRequestStatus status;
  final String? reasonText;
  final String? attachmentUrl;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static ExcuseRequestStatus statusFromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'accepted':
        return ExcuseRequestStatus.accepted;
      case 'rejected':
        return ExcuseRequestStatus.rejected;
      case 'pending':
      default:
        return ExcuseRequestStatus.pending;
    }
  }

  static String statusToString(ExcuseRequestStatus status) {
    switch (status) {
      case ExcuseRequestStatus.pending:
        return 'pending';
      case ExcuseRequestStatus.accepted:
        return 'accepted';
      case ExcuseRequestStatus.rejected:
        return 'rejected';
    }
  }

  factory ExcuseRequest.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final ts = data['lectureDate'];
    DateTime lectureDate;
    if (ts is Timestamp) {
      final d = ts.toDate();
      lectureDate = DateTime(d.year, d.month, d.day);
    } else {
      final y = _safeInt(data['lectureYear']);
      final m = _safeInt(data['lectureMonth']);
      final d = _safeInt(data['lectureDay']);
      lectureDate = (y > 0 && m > 0 && d > 0) ? DateTime(y, m, d) : DateTime.now();
    }

    DateTime? parseTs(dynamic v) => v is Timestamp ? v.toDate() : null;

    return ExcuseRequest(
      id: doc.id,
      studentId: _safeInt(data['studentId']),
      sectionId: (data['sectionId'] ?? '').toString().trim(),
      courseNameAr: (data['courseNameAr'] ?? data['courseName_Ar'] ?? '').toString().trim(),
      lectureDate: lectureDate,
      lectureStartTime: (data['lectureStartTime'] ?? '').toString().trim(),
      lectureEndTime: (data['lectureEndTime'] ?? '').toString().trim(),
      status: statusFromString((data['status'] ?? '').toString()),
      reasonText: (data['reasonText'] ?? data['reason'] ?? '').toString().trim().isEmpty
          ? null
          : (data['reasonText'] ?? data['reason'] ?? '').toString().trim(),
      attachmentUrl: (data['attachmentUrl'] ?? data['attachmentURL'] ?? '').toString().trim().isEmpty
          ? null
          : (data['attachmentUrl'] ?? data['attachmentURL'] ?? '').toString().trim(),
      rejectionReason: (data['rejectionReason'] ?? '').toString().trim().isEmpty
          ? null
          : (data['rejectionReason'] ?? '').toString().trim(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'studentId': studentId,
      'sectionId': sectionId,
      'courseNameAr': courseNameAr,
      'lectureDate': Timestamp.fromDate(DateTime(lectureDate.year, lectureDate.month, lectureDate.day)),
      'lectureYear': lectureDate.year,
      'lectureMonth': lectureDate.month,
      'lectureDay': lectureDate.day,
      'lectureStartTime': lectureStartTime,
      'lectureEndTime': lectureEndTime,
      'status': statusToString(status),
      if (reasonText != null) 'reasonText': reasonText,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}

