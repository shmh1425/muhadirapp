import 'package:cloud_firestore/cloud_firestore.dart';

enum ExcuseRequestStatus { pending, accepted, rejected, expired }

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
    this.attachmentName,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.sessionId,
    this.attendanceRecordId,
    this.lecturerId,
    this.studentName,
    this.submittedAt,
    this.reviewDeadlineAt,
    this.reviewedBy,
    this.reviewedAt,
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
  final String? attachmentName;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Matches [ManualAttendanceService.buildSessionId] when student team aligns data.
  final String? sessionId;

  /// Expected: `${sessionId}_${studentId}` — may be absent; lecturer flow can derive.
  final String? attendanceRecordId;

  /// Section lecturer — used for rules / display; may be absent in older docs.
  final String? lecturerId;

  /// Denormalized display name from student team (optional).
  final String? studentName;

  final DateTime? submittedAt;
  final DateTime? reviewDeadlineAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  static ExcuseRequestStatus statusFromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'accepted':
      case 'approved':
        return ExcuseRequestStatus.accepted;
      case 'rejected':
        return ExcuseRequestStatus.rejected;
      case 'expired':
      case 'expired_unresolved':
        return ExcuseRequestStatus.expired;
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
      case ExcuseRequestStatus.expired:
        return 'expired';
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

    final sid = (data['sessionId'] ?? '').toString().trim();
    final attId = (data['attendanceRecordId'] ?? '').toString().trim();

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
      attachmentName: (data['attachmentName'] ?? '').toString().trim().isEmpty
          ? null
          : (data['attachmentName'] ?? '').toString().trim(),
      rejectionReason: (data['rejectionReason'] ?? '').toString().trim().isEmpty
          ? null
          : (data['rejectionReason'] ?? '').toString().trim(),
      createdAt: parseTs(data['createdAt']),
      updatedAt: parseTs(data['updatedAt']),
      sessionId: sid.isEmpty ? null : sid,
      attendanceRecordId: attId.isEmpty ? null : attId,
      lecturerId: (data['lecturerId'] ?? '').toString().trim().isEmpty
          ? null
          : (data['lecturerId'] ?? '').toString().trim(),
      studentName: (data['studentName'] ?? '').toString().trim().isEmpty
          ? null
          : (data['studentName'] ?? '').toString().trim(),
      submittedAt: parseTs(data['submittedAt']),
      reviewDeadlineAt: parseTs(data['reviewDeadlineAt']),
      reviewedBy: (data['reviewedBy'] ?? '').toString().trim().isEmpty
          ? null
          : (data['reviewedBy'] ?? '').toString().trim(),
      reviewedAt: parseTs(data['reviewedAt']),
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
      if (attachmentName != null) 'attachmentName': attachmentName,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (sessionId != null) 'sessionId': sessionId,
      if (attendanceRecordId != null) 'attendanceRecordId': attendanceRecordId,
      if (lecturerId != null) 'lecturerId': lecturerId,
      if (studentName != null) 'studentName': studentName,
      if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
      if (reviewDeadlineAt != null) 'reviewDeadlineAt': Timestamp.fromDate(reviewDeadlineAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
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

