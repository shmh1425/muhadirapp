import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/attendance/manual_attendance_record.dart';
import '../../models/excuse/excuse_request.dart';
import '../attendance/manual_attendance_service.dart';
import '../lecturer_auth_service.dart';

/// One lecturer decision to persist for a single excuse document.
class LecturerExcuseDecision {
  const LecturerExcuseDecision({
    required this.excuseRequestId,
    required this.studentId,
    required this.newStatus,
    this.rejectionReason,
  });

  final String excuseRequestId;
  final int studentId;
  final ExcuseRequestStatus newStatus;
  final String? rejectionReason;
}

class ExcuseService {
  ExcuseService._();
  static final ExcuseService instance = ExcuseService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const bool enabled = true;

  static const String excusesCollection = 'excuse_requests';
  static const String _sectionsCollection = 'sections';
  static const String _lecturerNotificationsCollection = 'lecturer_notifications';
  static const String _studentNotificationsCollection = 'student_notifications';

  Stream<List<ExcuseRequest>> watchStudentRequests(int studentId) {
    if (!enabled || studentId <= 0) {
      return const Stream<List<ExcuseRequest>>.empty();
    }
    return _firestore
        .collection(excusesCollection)
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(ExcuseRequest.fromDoc).toList();
      list.sort((a, b) {
        final byDate = b.lectureDate.compareTo(a.lectureDate);
        if (byDate != 0) return byDate;
        return b.lectureStartTime.compareTo(a.lectureStartTime);
      });
      return list;
    });
  }

  /// Attendance record ids marked as an excuse submission pending review (student side).
  Stream<Set<String>> watchPendingExcuseAttendanceRecordIds(int studentId) {
    if (!enabled || studentId <= 0) {
      return const Stream<Set<String>>.empty();
    }
    return _firestore
        .collection(_studentNotificationsCollection)
        .where('studentId', isEqualTo: studentId)
        .where('isExcuseSubmission', isEqualTo: true)
        .where('excuseStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final ids = <String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final id = (data['attendanceRecordId'] ?? '').toString().trim();
        if (id.isNotEmpty) ids.add(id);
      }
      return ids;
    });
  }

  /// Lecturer: all excuse requests tied to a manual attendance session.
  Stream<List<ExcuseRequest>> watchSessionExcuseRequests(String sessionId) {
    final sid = sessionId.trim();
    if (sid.isEmpty) {
      return const Stream<List<ExcuseRequest>>.empty();
    }
    return _firestore
        .collection(excusesCollection)
        .where('sessionId', isEqualTo: sid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(ExcuseRequest.fromDoc).toList();
      list.sort((a, b) {
        final sa = a.submittedAt ?? a.createdAt;
        final sb = b.submittedAt ?? b.createdAt;
        if (sa != null && sb != null) {
          final c = sb.compareTo(sa);
          if (c != 0) return c;
        }
        return a.studentId.compareTo(b.studentId);
      });
      return list;
    });
  }

  Future<void> submitRequest(ExcuseRequest request) async {
    if (!enabled) return;
    await _firestore
        .collection(excusesCollection)
        .doc(request.id)
        .set(request.toMap(), SetOptions(merge: true));
  }

  Future<void> submitRequestAndNotifyLecturer({
    required ExcuseRequest request,
    required String studentDisplayName,
  }) async {
    if (!enabled) return;

    final lecturerId = await _lookupLecturerIdForSection(request.sectionId);
    var storedInExcuseRequests = true;
    try {
      await submitRequest(request);
    } on FirebaseException catch (e) {
      // Some deployments still deny `create` on `excuse_requests` via rules.
      // Storage upload can succeed while Firestore write fails. In that case,
      // we still create a lecturer notification (rules allow it) so the request
      // is reflected in the lecturer UI without requiring lecturer-side changes.
      storedInExcuseRequests = false;
      if (e.code != 'permission-denied') rethrow;
    }

    if (lecturerId.isEmpty) return;

    final ref = _firestore.collection(_lecturerNotificationsCollection).doc();
    await ref.set({
      'notificationId': ref.id,
      'lecturerId': lecturerId,
      'sectionId': request.sectionId,
      'courseName': request.courseNameAr,
      'lectureStartTime': request.lectureStartTime,
      'lectureEndTime': request.lectureEndTime,
      'lectureDate': Timestamp.fromDate(
        DateTime(request.lectureDate.year, request.lectureDate.month, request.lectureDate.day),
      ),
      'category': 'students',
      'titleAr': 'طلب عذر من طالب',
      'titleEn': 'Student excuse request',
      'messageAr': 'تم رفع عذر لمادة "${request.courseNameAr}". يمكنك مراجعة الطلب واتخاذ إجراء.',
      'messageEn': 'A new excuse was submitted for "${request.courseNameAr}". You can review and take action.',
      'isRead': false,
      'isExcuseRequest': true,
      'excuseRequestId': request.id,
      // Helps debugging if Firestore rules block storing in `excuse_requests`.
      'storedInExcuseRequests': storedInExcuseRequests,
      // Include request payload for lecturer-side consumption if needed.
      'excuseRequestSnapshot': request.toMap(),
      'excuseDetails': {
        'studentName': studentDisplayName,
        'academicNumber': request.studentId.toString(),
        'submissionDate': '${request.lectureDate.year}-${request.lectureDate.month.toString().padLeft(2, '0')}-${request.lectureDate.day.toString().padLeft(2, '0')}',
        'submissionTime': request.lectureStartTime,
        'excuseText': request.reasonText ?? '',
        'attachmentName': request.attachmentName ?? '',
        'attachmentUrl': request.attachmentUrl ?? '',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Also add a student-side pending marker so the student UI can reflect
    // "قيد الانتظار" even if `excuse_requests` storage is blocked by rules.
    final studentRef = _firestore.collection(_studentNotificationsCollection).doc();
    await studentRef.set({
      'notificationId': studentRef.id,
      'studentId': request.studentId,
      'sectionId': request.sectionId,
      if (request.sessionId != null) 'sessionId': request.sessionId,
      if (request.attendanceRecordId != null) 'attendanceRecordId': request.attendanceRecordId,
      'category': 'excuses',
      'titleAr': 'تم رفع العذر',
      'titleEn': 'Excuse submitted',
      'messageAr': 'تم رفع العذر وهو الآن قيد المراجعة لدى الدكتور.',
      'messageEn': 'Your excuse was submitted and is pending lecturer review.',
      'isRead': false,
      'isExcuseSubmission': true,
      'excuseStatus': 'pending',
      'excuseRequestId': request.id,
      // Store the student's text for the pending-details UI.
      'excuseText': request.reasonText ?? '',
      // Client-side timestamp for reliable sorting even before serverTimestamp resolves.
      'clientCreatedAt': Timestamp.now(),
      'attachmentName': request.attachmentName ?? '',
      'attachmentUrl': request.attachmentUrl ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> _lookupLecturerIdForSection(String sectionId) async {
    final id = sectionId.trim();
    if (id.isEmpty) return '';
    try {
      final snap = await _firestore.collection(_sectionsCollection).doc(id).get();
      if (!snap.exists) return '';
      final data = snap.data() ?? <String, dynamic>{};
      return (data['lecturerId'] ?? data['instructorId'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  /// Persists lecturer decisions: updates each `excuse_requests` doc, then sets
  /// `manual_attendance_records` to [excused] for approvals in one follow-up batch.
  Future<void> applyLecturerDecisions({
    required String sessionId,
    required List<LecturerExcuseDecision> decisions,
  }) async {
    final sid = sessionId.trim();
    if (sid.isEmpty || decisions.isEmpty) return;

    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId ?? '';
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    final approvals = <int, ManualAttendanceStatus>{};

    for (final d in decisions) {
      final ref = _firestore.collection(excusesCollection).doc(d.excuseRequestId);
      final payload = <String, dynamic>{
        'status': ExcuseRequest.statusToString(d.newStatus),
        'updatedAt': now,
        'reviewedBy': lecturerId,
        'reviewedAt': now,
      };
      if (d.newStatus == ExcuseRequestStatus.rejected) {
        payload['rejectionReason'] = (d.rejectionReason ?? '').trim();
      } else {
        payload['rejectionReason'] = FieldValue.delete();
      }
      batch.update(ref, payload);

      if (d.newStatus == ExcuseRequestStatus.accepted && d.studentId > 0) {
        approvals[d.studentId] = ManualAttendanceStatus.excused;
      }
    }

    await batch.commit();

    if (approvals.isNotEmpty) {
      await ManualAttendanceService.instance.updateSessionStatuses(
        sessionId: sid,
        updates: approvals,
      );
    }
  }
}
