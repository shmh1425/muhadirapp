import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/excuse/excuse_request.dart';
import '../../models/notifications/lecturer_notification.dart';
import '../excuse/excuse_service.dart';
import '../lecturer_auth_service.dart';

class ExcuseDecisionResult {
  const ExcuseDecisionResult({
    required this.success,
    required this.messageAr,
    required this.messageEn,
  });

  final bool success;
  final String messageAr;
  final String messageEn;
}

class LecturerNotificationService {
  LecturerNotificationService._();
  static final LecturerNotificationService instance = LecturerNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'lecturer_notifications';
  static const String _excuseRequestsCollection = 'excuse_requests';

  String get _currentLecturerId {
    return (LecturerAuthService.instance.currentLecturer?.lecturerId ?? '').trim();
  }

  Stream<List<LecturerNotification>> watchCurrentLecturerNotifications() {
    final lecturerId = _currentLecturerId;
    if (lecturerId.isEmpty) {
      return const Stream<List<LecturerNotification>>.empty();
    }

    return _firestore
        .collection(_collection)
        .where('lecturerId', isEqualTo: lecturerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(LecturerNotification.fromDoc).toList();
      list.sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  Future<void> markAsRead(String notificationId) async {
    final docRef = await _getOwnedNotificationRef(notificationId);
    if (docRef == null) return;
    await docRef.update({
      'isRead': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNotification(String notificationId) async {
    final docRef = await _getOwnedNotificationRef(notificationId);
    if (docRef == null) return;
    await docRef.delete();
  }

  Future<void> deleteAllForCurrentLecturer() async {
    final lecturerId = _currentLecturerId;
    if (lecturerId.isEmpty) return;

    final snap = await _firestore
        .collection(_collection)
        .where('lecturerId', isEqualTo: lecturerId)
        .get();
    if (snap.docs.isEmpty) return;

    WriteBatch batch = _firestore.batch();
    var ops = 0;

    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      ops = 0;
    }

    for (final doc in snap.docs) {
      batch.delete(doc.reference);
      ops++;
      if (ops >= 450) {
        await flush();
      }
    }
    await flush();
  }

  Future<ExcuseDecisionResult> applyExcuseDecisionFromNotification({
    required LecturerNotification notification,
    required bool approve,
    String rejectionReason = '',
  }) async {
    if (!notification.isExcuseRequest || notification.excuseRequestId.isEmpty) {
      return const ExcuseDecisionResult(
        success: false,
        messageAr: 'لا يحتوي هذا الإشعار على طلب عذر صالح.',
        messageEn: 'This notification does not include a valid excuse request.',
      );
    }

    if (notification.storedInExcuseRequests == false) {
      return const ExcuseDecisionResult(
        success: false,
        messageAr: 'هذا الطلب محفوظ كنسخة داخل الإشعار فقط، ولا يوجد مستند فعلي في طلبات الأعذار.',
        messageEn: 'This request is only stored as a notification snapshot; no primary excuse request document exists.',
      );
    }

    final reqRef = _firestore
        .collection(_excuseRequestsCollection)
        .doc(notification.excuseRequestId);
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) {
      return const ExcuseDecisionResult(
        success: false,
        messageAr: 'لم يتم العثور على مستند طلب العذر في قاعدة البيانات.',
        messageEn: 'The related excuse request document was not found in Firestore.',
      );
    }

    final reqData = reqSnap.data() ?? <String, dynamic>{};
    final studentId = _safeInt(reqData['studentId']);
    if (studentId <= 0) {
      return const ExcuseDecisionResult(
        success: false,
        messageAr: 'رقم الطالب غير متوفر في مستند العذر، لا يمكن إتمام القرار.',
        messageEn: 'Student ID is missing in the excuse document, so the decision cannot be applied.',
      );
    }

    final currentStatus = ExcuseRequest.statusFromString(
      (reqData['status'] ?? notification.statusFromSnapshot).toString(),
    );
    final sessionId = (reqData['sessionId'] ?? notification.sessionIdFromSnapshot)
        .toString()
        .trim();
    if (sessionId.isEmpty) {
      return const ExcuseDecisionResult(
        success: false,
        messageAr: 'المعرف الجلسي لطلب العذر غير متوفر، لا يمكن تطبيق القرار بأمان.',
        messageEn: 'Session ID is missing for this excuse request, so the decision cannot be safely applied.',
      );
    }

    final decision = LecturerExcuseDecision(
      excuseRequestId: notification.excuseRequestId,
      studentId: studentId,
      oldStatus: currentStatus,
      newStatus: approve ? ExcuseRequestStatus.accepted : ExcuseRequestStatus.rejected,
      rejectionReason: approve ? null : rejectionReason.trim(),
      attendanceRecordId: (reqData['attendanceRecordId'] ?? '').toString().trim(),
      notificationSessionId: sessionId,
      courseNameAr: (reqData['courseNameAr'] ?? notification.courseName).toString().trim(),
      sectionId: (reqData['sectionId'] ?? notification.sectionId).toString().trim(),
    );

    await ExcuseService.instance.applyLecturerDecisions(
      sessionId: sessionId,
      decisions: [decision],
    );

    return ExcuseDecisionResult(
      success: true,
      messageAr: approve ? 'تم قبول طلب العذر بنجاح.' : 'تم رفض طلب العذر بنجاح.',
      messageEn: approve
          ? 'Excuse request approved successfully.'
          : 'Excuse request rejected successfully.',
    );
  }

  Future<DocumentReference<Map<String, dynamic>>?> _getOwnedNotificationRef(
    String notificationId,
  ) async {
    final id = notificationId.trim();
    final lecturerId = _currentLecturerId;
    if (id.isEmpty || lecturerId.isEmpty) return null;

    final ref = _firestore.collection(_collection).doc(id);
    final snap = await ref.get();
    if (!snap.exists) return null;

    final data = snap.data() ?? <String, dynamic>{};
    final owner = (data['lecturerId'] ?? '').toString().trim();
    if (owner != lecturerId) {
      debugPrint(
        '[LecturerNotificationService] Ownership mismatch for doc=$id '
        'owner=$owner current=$lecturerId',
      );
      return null;
    }
    return ref;
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
