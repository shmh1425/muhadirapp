import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/lecturer/lecture_item.dart';
import '../lecturer_auth_service.dart';

enum LectureActionType { delay, cancel }

class LectureActionDispatchResult {
  const LectureActionDispatchResult({
    required this.actionType,
    required this.recipientCount,
    required this.lecturerMessageAr,
    required this.lecturerMessageEn,
  });

  final LectureActionType actionType;
  final int recipientCount;
  final String lecturerMessageAr;
  final String lecturerMessageEn;
}

class LectureActionNotificationService {
  LectureActionNotificationService._();
  static final LectureActionNotificationService instance =
      LectureActionNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _enrollmentsCollection = 'student_section_enrollments';
  static const String _studentNotificationsCollection = 'student_notifications';
  static const String _lecturerNotificationsCollection =
      'lecturer_notifications';

  Future<LectureActionDispatchResult> sendDelayNotification({
    required LectureItem lecture,
    required int delayMinutes,
    required int lectureDayOfWeek,
    DateTime? lectureDate,
  }) async {
    if (delayMinutes <= 0) {
      throw ArgumentError('Delay minutes must be greater than zero.');
    }
    return _dispatch(
      lecture: lecture,
      actionType: LectureActionType.delay,
      lectureDayOfWeek: lectureDayOfWeek,
      lectureDate: lectureDate,
      delayMinutes: delayMinutes,
    );
  }

  Future<LectureActionDispatchResult> sendCancellationNotification({
    required LectureItem lecture,
    required int lectureDayOfWeek,
    DateTime? lectureDate,
  }) async {
    return _dispatch(
      lecture: lecture,
      actionType: LectureActionType.cancel,
      lectureDayOfWeek: lectureDayOfWeek,
      lectureDate: lectureDate,
      delayMinutes: null,
    );
  }

  Future<LectureActionDispatchResult> _dispatch({
    required LectureItem lecture,
    required LectureActionType actionType,
    required int lectureDayOfWeek,
    required DateTime? lectureDate,
    required int? delayMinutes,
  }) async {
    final sectionId = (lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) {
      throw StateError('Section ID is required to notify students.');
    }

    final lecturer = LecturerAuthService.instance.currentLecturer;
    final lecturerId = (lecturer?.lecturerId ?? '').trim();
    if (lecturerId.isEmpty) {
      throw StateError('Lecturer session is missing. Please log in again.');
    }

    final lecturerDisplayName = lecturer!.nameAr.trim().isNotEmpty
        ? lecturer.nameAr.trim()
        : lecturer.nameEn.trim();

    final studentIds = await _loadStudentIdsForSection(sectionId);

    if (studentIds.isNotEmpty) {
      await _createStudentNotifications(
        studentIds: studentIds,
        lecture: lecture,
        actionType: actionType,
        lectureDayOfWeek: lectureDayOfWeek,
        lectureDate: lectureDate,
        lecturerId: lecturerId,
        lecturerDisplayName: lecturerDisplayName,
        delayMinutes: delayMinutes,
      );
    }

    final lecturerMessageAr = _buildLecturerMessageAr(
      actionType: actionType,
      recipientCount: studentIds.length,
      courseName: lecture.courseName,
      section: lecture.section,
      delayMinutes: delayMinutes,
    );
    final lecturerMessageEn = _buildLecturerMessageEn(
      actionType: actionType,
      recipientCount: studentIds.length,
      courseName: lecture.courseName,
      section: lecture.section,
      delayMinutes: delayMinutes,
    );

    await _createLecturerConfirmationNotification(
      lecturerId: lecturerId,
      lecturerDisplayName: lecturerDisplayName,
      lecture: lecture,
      actionType: actionType,
      lectureDayOfWeek: lectureDayOfWeek,
      lectureDate: lectureDate,
      delayMinutes: delayMinutes,
      recipientCount: studentIds.length,
      messageAr: lecturerMessageAr,
      messageEn: lecturerMessageEn,
    );

    return LectureActionDispatchResult(
      actionType: actionType,
      recipientCount: studentIds.length,
      lecturerMessageAr: lecturerMessageAr,
      lecturerMessageEn: lecturerMessageEn,
    );
  }

  Future<Set<int>> _loadStudentIdsForSection(String sectionId) async {
    final snapshot = await _firestore
        .collection(_enrollmentsCollection)
        .where('sectionId', isEqualTo: sectionId)
        .get();

    final studentIds = <int>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final isActive = data['isActive'];
      if (isActive == false) continue;

      final id = _safeInt(data['studentId']);
      if (id > 0) {
        studentIds.add(id);
      }
    }
    return studentIds;
  }

  Future<void> _createStudentNotifications({
    required Set<int> studentIds,
    required LectureItem lecture,
    required LectureActionType actionType,
    required int lectureDayOfWeek,
    required DateTime? lectureDate,
    required String lecturerId,
    required String lecturerDisplayName,
    required int? delayMinutes,
  }) async {
    final titleAr = _studentTitleAr(actionType);
    final titleEn = _studentTitleEn(actionType);
    final messageAr = _studentMessageAr(
      actionType: actionType,
      lecture: lecture,
      delayMinutes: delayMinutes,
    );
    final messageEn = _studentMessageEn(
      actionType: actionType,
      lecture: lecture,
      delayMinutes: delayMinutes,
    );

    WriteBatch batch = _firestore.batch();
    int operations = 0;

    Future<void> flushBatch() async {
      if (operations == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      operations = 0;
    }

    for (final studentId in studentIds) {
      final ref = _firestore.collection(_studentNotificationsCollection).doc();
      batch.set(ref, {
        'notificationId': ref.id,
        'studentId': studentId,
        'sectionId': lecture.sectionId,
        'courseCode': lecture.crn,
        'courseName': lecture.courseName,
        'section': lecture.section,
        'lectureStartTime': lecture.startTime,
        'lectureEndTime': lecture.endTime,
        'lectureDayOfWeek': lectureDayOfWeek,
        if (lectureDate != null)
          'lectureDate': Timestamp.fromDate(
            DateTime(lectureDate.year, lectureDate.month, lectureDate.day),
          ),
        'lectureHall': lecture.hall,
        'lectureActivity': lecture.activity,
        'actionType': _actionTypeValue(actionType),
        'delayMinutes': delayMinutes,
        'titleAr': titleAr,
        'titleEn': titleEn,
        'messageAr': messageAr,
        'messageEn': messageEn,
        'isRead': false,
        'createdByLecturerId': lecturerId,
        'createdByLecturerName': lecturerDisplayName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      operations++;

      if (operations >= 450) {
        await flushBatch();
      }
    }

    await flushBatch();
  }

  Future<void> _createLecturerConfirmationNotification({
    required String lecturerId,
    required String lecturerDisplayName,
    required LectureItem lecture,
    required LectureActionType actionType,
    required int lectureDayOfWeek,
    required DateTime? lectureDate,
    required int? delayMinutes,
    required int recipientCount,
    required String messageAr,
    required String messageEn,
  }) async {
    final ref = _firestore.collection(_lecturerNotificationsCollection).doc();
    await ref.set({
      'notificationId': ref.id,
      'lecturerId': lecturerId,
      'lecturerName': lecturerDisplayName,
      'sectionId': lecture.sectionId,
      'courseCode': lecture.crn,
      'courseName': lecture.courseName,
      'section': lecture.section,
      'lectureStartTime': lecture.startTime,
      'lectureEndTime': lecture.endTime,
      'lectureDayOfWeek': lectureDayOfWeek,
      if (lectureDate != null)
        'lectureDate': Timestamp.fromDate(
          DateTime(lectureDate.year, lectureDate.month, lectureDate.day),
        ),
      'lectureHall': lecture.hall,
      'lectureActivity': lecture.activity,
      'actionType': _actionTypeValue(actionType),
      'delayMinutes': delayMinutes,
      'recipientsCount': recipientCount,
      'category': 'students',
      'titleAr': 'تأكيد إرسال إشعارات الطلاب',
      'titleEn': 'Student notifications sent',
      'messageAr': messageAr,
      'messageEn': messageEn,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static String _actionTypeValue(LectureActionType type) {
    switch (type) {
      case LectureActionType.delay:
        return 'delay';
      case LectureActionType.cancel:
        return 'cancel';
    }
  }

  static String _studentTitleAr(LectureActionType type) {
    switch (type) {
      case LectureActionType.delay:
        return 'تأخير المحاضرة';
      case LectureActionType.cancel:
        return 'إلغاء المحاضرة';
    }
  }

  static String _studentTitleEn(LectureActionType type) {
    switch (type) {
      case LectureActionType.delay:
        return 'Lecture delayed';
      case LectureActionType.cancel:
        return 'Lecture cancelled';
    }
  }

  static String _studentMessageAr({
    required LectureActionType actionType,
    required LectureItem lecture,
    required int? delayMinutes,
  }) {
    switch (actionType) {
      case LectureActionType.delay:
        return 'تم تأخير محاضرة "${lecture.courseName}" للشعبة ${lecture.section} لمدة ${delayMinutes ?? 0} دقيقة.';
      case LectureActionType.cancel:
        return 'تم إلغاء محاضرة "${lecture.courseName}" للشعبة ${lecture.section}.';
    }
  }

  static String _studentMessageEn({
    required LectureActionType actionType,
    required LectureItem lecture,
    required int? delayMinutes,
  }) {
    switch (actionType) {
      case LectureActionType.delay:
        return '"${lecture.courseName}" lecture for section ${lecture.section} has been delayed by ${delayMinutes ?? 0} minutes.';
      case LectureActionType.cancel:
        return '"${lecture.courseName}" lecture for section ${lecture.section} has been cancelled.';
    }
  }

  static String _buildLecturerMessageAr({
    required LectureActionType actionType,
    required int recipientCount,
    required String courseName,
    required String section,
    required int? delayMinutes,
  }) {
    if (recipientCount <= 0) {
      return 'لم يتم العثور على طلاب مسجلين للشعبة $section في "$courseName" لإرسال الإشعار.';
    }

    switch (actionType) {
      case LectureActionType.delay:
        return 'تم إشعار $recipientCount طالب/ـة بتأخير محاضرة "$courseName" للشعبة $section لمدة ${delayMinutes ?? 0} دقيقة.';
      case LectureActionType.cancel:
        return 'تم إشعار $recipientCount طالب/ـة بإلغاء محاضرة "$courseName" للشعبة $section.';
    }
  }

  static String _buildLecturerMessageEn({
    required LectureActionType actionType,
    required int recipientCount,
    required String courseName,
    required String section,
    required int? delayMinutes,
  }) {
    if (recipientCount <= 0) {
      return 'No enrolled students were found for section $section in "$courseName".';
    }

    switch (actionType) {
      case LectureActionType.delay:
        return '$recipientCount students were notified about delaying "$courseName" (section $section) by ${delayMinutes ?? 0} minutes.';
      case LectureActionType.cancel:
        return '$recipientCount students were notified about cancelling "$courseName" (section $section).';
    }
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
