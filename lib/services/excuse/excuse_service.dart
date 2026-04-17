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

  /// Student-side streams remain gated until student submission + rules are ready.
  static const bool enabled = false;

  static const String excusesCollection = 'excuse_requests';

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
