import 'package:cloud_firestore/cloud_firestore.dart';

enum StudentNotificationCategory { attendance, lectures, excuses }

enum StudentNotificationSource { attendanceRecord, studentNotificationDoc }

class StudentNotification {
  const StudentNotification({
    required this.id,
    required this.rawId,
    required this.studentId,
    required this.category,
    required this.source,
    required this.titleAr,
    required this.titleEn,
    required this.messageAr,
    required this.messageEn,
    required this.createdAt,
    required this.isRead,
    required this.firestoreDocId,
    required this.courseName,
    required this.section,
    required this.sectionId,
    required this.sessionId,
    required this.lectureDate,
    required this.lectureStartTime,
    required this.lectureEndTime,
    required this.attendanceRecordId,
    required this.excuseStatus,
    required this.rejectionReason,
    required this.attachmentUrl,
    required this.attachmentName,
    required this.actionType,
  });

  /// UI id used for hiding (may include prefixes).
  final String id;

  /// Raw document id (attendance doc id or student_notifications doc id).
  final String rawId;

  final int studentId;
  final StudentNotificationCategory category;
  final StudentNotificationSource source;

  final String titleAr;
  final String titleEn;
  final String messageAr;
  final String messageEn;

  final DateTime createdAt;
  final bool isRead;

  /// When source is [StudentNotificationSource.studentNotificationDoc].
  final String? firestoreDocId;

  // ---- navigation/meta (parsed from docs; empty when not applicable) ----
  final String courseName;
  final String section;
  final String sectionId;
  final String sessionId;
  final DateTime? lectureDate;
  final String lectureStartTime;
  final String lectureEndTime;

  /// For attendance-related flows and excuse notifications.
  final String attendanceRecordId;

  /// pending / accepted / rejected (from `student_notifications.excuseStatus`).
  final String excuseStatus;

  final String rejectionReason;
  final String? attachmentUrl;
  final String? attachmentName;

  /// delay / cancel / ... (from `student_notifications.actionType`)
  final String actionType;

  static const String attendancePrefix = 'attendance::';
  static const String lectureActionPrefix = 'lecture_action::';

  static String attendanceUiId(String rawId) => '$attendancePrefix$rawId';
  static String studentNotifUiId(String rawId) => '$lectureActionPrefix$rawId';

  factory StudentNotification.fromAttendanceDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required int studentId,
    required bool isRead,
  }) {
    final data = doc.data();
    final rawStatus = (data['status'] ?? '').toString().trim().toLowerCase();
    final courseName = (data['courseName'] ?? data['courseTitle'] ?? '')
        .toString()
        .trim();
    final section = (data['section'] ?? '').toString().trim();
    final date = _extractDate(data);
    final sectionId = (data['sectionId'] ?? '').toString().trim();
    final sessionId = (data['sessionId'] ?? '').toString().trim();
    final start = (data['lectureStartTime'] ?? '').toString().trim();
    final end = (data['lectureEndTime'] ?? '').toString().trim();
    final statusLabelAr = rawStatus == 'excused' ? 'بعذر' : 'بدون عذر';
    final statusLabelEn = rawStatus == 'excused' ? 'with excuse' : 'without excuse';
    final sectionAr = section.isEmpty ? '' : ' - الشعبة $section';
    final sectionEn = section.isEmpty ? '' : ' — Section $section';
    final courseAr = courseName.isEmpty ? 'المقرر' : courseName;
    final courseEn = courseName.isEmpty ? 'Course' : courseName;

    return StudentNotification(
      id: attendanceUiId(doc.id),
      rawId: doc.id,
      studentId: studentId,
      category: StudentNotificationCategory.attendance,
      source: StudentNotificationSource.attendanceRecord,
      titleAr: rawStatus == 'excused' ? 'إشعار غياب بعذر' : 'إشعار غياب',
      titleEn: rawStatus == 'excused' ? 'Absence (excused)' : 'Absence recorded',
      messageAr: 'تم تسجيل غيابك ($statusLabelAr) في "$courseAr"$sectionAr.',
      messageEn: 'Your absence ($statusLabelEn) was recorded for "$courseEn"$sectionEn.',
      createdAt: date,
      isRead: isRead,
      firestoreDocId: null,
      courseName: courseName,
      section: section,
      sectionId: sectionId,
      sessionId: sessionId,
      lectureDate: date,
      lectureStartTime: start,
      lectureEndTime: end,
      attendanceRecordId: doc.id,
      excuseStatus: '',
      rejectionReason: '',
      attachmentUrl: null,
      attachmentName: null,
      actionType: rawStatus,
    );
  }

  factory StudentNotification.fromStudentNotificationDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required int studentId,
  }) {
    final data = doc.data();
    DateTime parseTs(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();

    final actionType = (data['actionType'] ?? '').toString().trim().toLowerCase();
    final categoryRaw = (data['category'] ?? '').toString().trim().toLowerCase();

    final titleAr = (data['titleAr'] ?? '').toString().trim();
    final titleEn = (data['titleEn'] ?? '').toString().trim();
    final messageAr = (data['messageAr'] ?? '').toString().trim();
    final messageEn = (data['messageEn'] ?? '').toString().trim();

    final createdAt = parseTs(data['createdAt']);
    final updatedAt = parseTs(data['updatedAt']);
    final sortAt = data['updatedAt'] is Timestamp ? updatedAt : createdAt;

    final isRead = data['isRead'] == true;
    final isExcuse = data['isExcuseSubmission'] == true || categoryRaw == 'excuses';
    final excuseStatus =
        (data['excuseStatus'] ?? '').toString().trim().toLowerCase();
    final rejectionReason = (data['rejectionReason'] ?? '').toString().trim();
    final attendanceRecordId =
        (data['attendanceRecordId'] ?? '').toString().trim();
    final sectionId = (data['sectionId'] ?? '').toString().trim();
    final sessionId = (data['sessionId'] ?? '').toString().trim();
    final lectureDateTs = data['lectureDate'];
    DateTime? lectureDate;
    if (lectureDateTs is Timestamp) {
      final d = lectureDateTs.toDate();
      lectureDate = DateTime(d.year, d.month, d.day);
    }
    final start = (data['lectureStartTime'] ?? '').toString().trim();
    final end = (data['lectureEndTime'] ?? '').toString().trim();
    final section = (data['section'] ?? '').toString().trim();
    final courseName = (data['courseName'] ?? '').toString().trim();
    final attachmentUrl = (data['attachmentUrl'] ?? data['attachmentURL'])
        ?.toString()
        .trim();
    final attachmentName = (data['attachmentName'] ?? '').toString().trim();

    return StudentNotification(
      id: studentNotifUiId(doc.id),
      rawId: doc.id,
      studentId: studentId,
      category: isExcuse ? StudentNotificationCategory.excuses : StudentNotificationCategory.lectures,
      source: StudentNotificationSource.studentNotificationDoc,
      titleAr: titleAr.isNotEmpty
          ? titleAr
          : (actionType == 'delay' ? 'تنبيه تأخير محاضرة' : 'تنبيه'),
      titleEn: titleEn.isNotEmpty
          ? titleEn
          : (actionType == 'delay' ? 'Class delayed' : 'Notification'),
      messageAr: messageAr,
      messageEn: messageEn,
      createdAt: sortAt,
      isRead: isRead,
      firestoreDocId: doc.id,
      courseName: courseName,
      section: section,
      sectionId: sectionId,
      sessionId: sessionId,
      lectureDate: lectureDate,
      lectureStartTime: start,
      lectureEndTime: end,
      attendanceRecordId: attendanceRecordId,
      excuseStatus: excuseStatus,
      rejectionReason: rejectionReason,
      attachmentUrl: (attachmentUrl?.isEmpty ?? true) ? null : attachmentUrl,
      attachmentName: attachmentName.isEmpty ? null : attachmentName,
      actionType: actionType,
    );
  }

  static DateTime _extractDate(Map<String, dynamic> data) {
    final lectureDate = data['lectureDate'];
    if (lectureDate is Timestamp) return lectureDate.toDate();
    final year = _safeInt(data['lectureYear']);
    final month = _safeInt(data['lectureMonth']);
    final day = _safeInt(data['lectureDay']);
    if (year > 0 && month > 0 && day > 0) return DateTime(year, month, day);
    final dateKey = (data['dateKey'] ?? '').toString().trim();
    if (dateKey.length == 8) {
      final y = int.tryParse(dateKey.substring(0, 4));
      final m = int.tryParse(dateKey.substring(4, 6));
      final d = int.tryParse(dateKey.substring(6, 8));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateTime.now();
  }

  static int _safeInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }
}

