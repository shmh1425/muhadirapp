import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ExcuseRequestStatus { pending, accepted, rejected, expired }

class ExcuseRequest {
  /// Window to correct a wrong upload while the excuse is still pending review.
  static const Duration pendingEditWindow = Duration(minutes: 3);

  /// Calendar days after rejection during which the student may resubmit.
  static const int rejectedResubmitGraceDays = 3;
  const ExcuseRequest({
    required this.id,
    required this.studentId,
    required this.sectionId,
    required this.courseNameAr,
    required this.courseNameEn,
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
    this.isPartialDocument = false,
  });

  final String id;
  final int studentId;
  final String sectionId;
  final String courseNameAr;
  final String courseNameEn;
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

  /// True when key fields are missing (legacy / minimal Firestore documents).
  final bool isPartialDocument;

  /// Deadline to correct a pending excuse after the first upload.
  DateTime? get pendingEditDeadline {
    if (status != ExcuseRequestStatus.pending) return null;
    final base = submittedAt ?? createdAt;
    return base?.add(pendingEditWindow);
  }

  bool get pendingEditStillAllowed {
    final deadline = pendingEditDeadline;
    if (deadline == null) return true;
    return !DateTime.now().isAfter(deadline);
  }

  static DateTime rejectedResubmitDeadlineFromReviewedAt(DateTime reviewed) {
    final reviewedDay = DateTime(reviewed.year, reviewed.month, reviewed.day);
    return reviewedDay.add(Duration(days: rejectedResubmitGraceDays));
  }

  static bool rejectedResubmitStillAllowedAt(DateTime reviewed) {
    final reviewedDay = DateTime(reviewed.year, reviewed.month, reviewed.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(reviewedDay).inDays < rejectedResubmitGraceDays;
  }

  /// Resubmit deadline after rejection; null when not applicable.
  DateTime? get rejectedResubmitDeadline {
    if (status != ExcuseRequestStatus.rejected) return null;
    if (reviewDeadlineAt != null) return reviewDeadlineAt;
    final reviewed = reviewedAt ?? updatedAt;
    if (reviewed != null) {
      return rejectedResubmitDeadlineFromReviewedAt(reviewed);
    }
    return null;
  }

  bool get rejectedResubmitStillAllowed {
    if (status != ExcuseRequestStatus.rejected) return false;
    if (reviewDeadlineAt != null) {
      return !DateTime.now().isAfter(reviewDeadlineAt!);
    }
    final reviewed = reviewedAt ?? updatedAt;
    if (reviewed != null) {
      return rejectedResubmitStillAllowedAt(reviewed);
    }
    return true;
  }

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
      if (y > 0 && m > 0 && d > 0) {
        lectureDate = DateTime(y, m, d);
      } else {
        // Avoid misleading "today" for empty legacy docs; UI can show a dash.
        lectureDate = DateTime.utc(2000, 1, 1);
        debugPrint(
          '[ExcuseRequest] fromDoc ${doc.id}: missing lectureDate / lectureYear fields; '
          'using placeholder date.',
        );
      }
    }

    DateTime? parseTs(dynamic v) => v is Timestamp ? v.toDate() : null;

    final sid = (data['sessionId'] ?? '').toString().trim();
    final attId = (data['attendanceRecordId'] ?? '').toString().trim();
    final parsedStudentId = _safeInt(data['studentId']);
    final parsedSectionId = (data['sectionId'] ?? '').toString().trim();
    if (parsedStudentId <= 0) {
      debugPrint(
        '[ExcuseRequest] fromDoc ${doc.id}: missing or invalid studentId.',
      );
    }
    if (parsedSectionId.isEmpty) {
      debugPrint('[ExcuseRequest] fromDoc ${doc.id}: missing sectionId.');
    }
    if (sid.isEmpty) {
      debugPrint('[ExcuseRequest] fromDoc ${doc.id}: missing sessionId.');
    }
    if (attId.isEmpty) {
      debugPrint(
        '[ExcuseRequest] fromDoc ${doc.id}: missing attendanceRecordId.',
      );
    }

    final courseAr = (data['courseNameAr'] ?? data['courseName_Ar'] ?? '')
        .toString()
        .trim();
    final courseEn = (data['courseNameEn'] ?? data['courseName'] ?? '')
        .toString()
        .trim();
    final partial =
        parsedStudentId <= 0 || parsedSectionId.isEmpty || courseAr.isEmpty;
    final parsedAttachmentName = (data['attachmentName'] ?? '')
        .toString()
        .trim();
    final parsedAttachmentUrl =
        (data['attachmentUrl'] ?? data['attachmentURL'] ?? '')
            .toString()
            .trim();
    debugPrint(
      '[ExcuseRequest] fromDoc ${doc.id}: '
      'hasAttachment=${parsedAttachmentUrl.isNotEmpty} '
      'attachmentName="$parsedAttachmentName" '
      'attachmentUrl="$parsedAttachmentUrl"',
    );

    return ExcuseRequest(
      id: doc.id,
      studentId: parsedStudentId,
      sectionId: parsedSectionId,
      courseNameAr: courseAr,
      courseNameEn: courseEn,
      lectureDate: lectureDate,
      lectureStartTime: (data['lectureStartTime'] ?? '').toString().trim(),
      lectureEndTime: (data['lectureEndTime'] ?? '').toString().trim(),
      status: statusFromString((data['status'] ?? '').toString()),
      reasonText:
          (data['reasonText'] ?? data['reason'] ?? '').toString().trim().isEmpty
          ? null
          : (data['reasonText'] ?? data['reason'] ?? '').toString().trim(),
      attachmentUrl: parsedAttachmentUrl.isEmpty ? null : parsedAttachmentUrl,
      attachmentName: parsedAttachmentName.isEmpty
          ? null
          : parsedAttachmentName,
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
      isPartialDocument: partial,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'studentId': studentId,
      'sectionId': sectionId,
      'courseNameAr': courseNameAr,
      if (courseNameEn.trim().isNotEmpty) 'courseNameEn': courseNameEn,
      'lectureDate': Timestamp.fromDate(
        DateTime(lectureDate.year, lectureDate.month, lectureDate.day),
      ),
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
      if (reviewDeadlineAt != null)
        'reviewDeadlineAt': Timestamp.fromDate(reviewDeadlineAt!),
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
