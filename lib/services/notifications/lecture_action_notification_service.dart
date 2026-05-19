import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/lecturer/lecture_item.dart';
import '../../utils/lecture_action_eligibility.dart';
import '../../utils/localized_firestore_fields.dart';
import '../lecturer_auth_service.dart';

enum LectureActionType { delay, cancel }

enum LectureActionBlockReason {
  alreadyDelayed,
  alreadyCanceled,
  canceledCannotDelay,
  lectureExpired,
}

class LectureActionBlockedException implements Exception {
  const LectureActionBlockedException(this.reason);

  final LectureActionBlockReason reason;
}

class LectureActionPartialFailureException implements Exception {
  const LectureActionPartialFailureException({
    required this.actionId,
    required this.message,
  });

  final String actionId;
  final String message;
}

class LectureActionStatus {
  const LectureActionStatus({
    required this.actionId,
    required this.isCanceled,
    required this.isDelayed,
    required this.delayMinutes,
  });

  const LectureActionStatus.normal()
      : actionId = '',
        isCanceled = false,
        isDelayed = false,
        delayMinutes = null;

  final String actionId;
  final bool isCanceled;
  final bool isDelayed;
  final int? delayMinutes;
}

class LectureActionDispatchResult {
  const LectureActionDispatchResult({
    required this.actionId,
    required this.actionType,
    required this.recipientCount,
    required this.studentNotificationIds,
    required this.lecturerNotificationId,
    required this.lecturerMessageAr,
    required this.lecturerMessageEn,
  });

  final String actionId;
  final LectureActionType actionType;
  final int recipientCount;
  final List<String> studentNotificationIds;
  final String lecturerNotificationId;
  final String lecturerMessageAr;
  final String lecturerMessageEn;
}

class LectureActionNotificationService {
  LectureActionNotificationService._();
  static final LectureActionNotificationService instance =
      LectureActionNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _enrollmentsCollection = 'student_section_enrollments';
  static const String _studentNotificationsCollection = 'student_notifications';
  static const String _lecturerNotificationsCollection =
      'lecturer_notifications';
  static const String _lectureActionsCollection = 'lecture_actions';

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

    final normalizedDate = _normalizeDate(lectureDate);
    if (!LectureActionEligibility.isLectureItemActionable(
      lecture: lecture,
      lectureDate: normalizedDate,
    )) {
      throw const LectureActionBlockedException(
        LectureActionBlockReason.lectureExpired,
      );
    }

    final lecturer = LecturerAuthService.instance.currentLecturer;
    final lecturerId = (lecturer?.lecturerId ?? '').trim();
    if (lecturerId.isEmpty) {
      throw StateError('Lecturer session is missing. Please log in again.');
    }

    final lecturerDisplayName = lecturer!.nameAr.trim().isNotEmpty
        ? lecturer.nameAr.trim()
        : lecturer.nameEn.trim();
    final dateKey = _dateKey(normalizedDate);
    final actionId = _buildActionId(
      sectionId: sectionId,
      dateKey: dateKey,
      lectureStartTime: lecture.startTime,
      actionType: actionType,
    );

    await _createOrValidateLectureActionRecord(
      actionId: actionId,
      actionType: actionType,
      lecture: lecture,
      sectionId: sectionId,
      dateKey: dateKey,
      lectureDayOfWeek: lectureDayOfWeek,
      lectureDate: normalizedDate,
      lecturerId: lecturerId,
      lecturerDisplayName: lecturerDisplayName,
      delayMinutes: delayMinutes,
    );

    final studentIds = await _loadStudentIdsForSection(sectionId);
    List<String> studentNotificationIds = const [];
    String lecturerNotificationId = '';
    int recipientsCount = 0;

    try {
      if (studentIds.isNotEmpty) {
        studentNotificationIds = await _createStudentNotifications(
          studentIds: studentIds,
          lecture: lecture,
          actionId: actionId,
          dateKey: dateKey,
          actionType: actionType,
          lectureDayOfWeek: lectureDayOfWeek,
          lectureDate: normalizedDate,
          lecturerId: lecturerId,
          lecturerDisplayName: lecturerDisplayName,
          delayMinutes: delayMinutes,
        );
      }
      recipientsCount = studentNotificationIds.length;

      final courseNameAr =
          (lecture.courseNameAr ?? lecture.courseName).trim();
      final courseNameEn =
          (lecture.courseNameEn ?? lecture.courseName).trim();
      final lecturerMessageAr = _buildLecturerMessageAr(
        actionType: actionType,
        recipientCount: recipientsCount,
        courseName: courseNameAr.isNotEmpty ? courseNameAr : lecture.courseName,
        section: lecture.section,
        delayMinutes: delayMinutes,
      );
      final lecturerMessageEn = _buildLecturerMessageEn(
        actionType: actionType,
        recipientCount: recipientsCount,
        courseName: courseNameEn.isNotEmpty ? courseNameEn : lecture.courseName,
        section: lecture.section,
        delayMinutes: delayMinutes,
      );

      lecturerNotificationId = await _createLecturerConfirmationNotification(
        actionId: actionId,
        lecturerId: lecturerId,
        lecturerDisplayName: lecturerDisplayName,
        lecture: lecture,
        actionType: actionType,
        lectureDayOfWeek: lectureDayOfWeek,
        dateKey: dateKey,
        lectureDate: normalizedDate,
        delayMinutes: delayMinutes,
        recipientCount: recipientsCount,
        messageAr: lecturerMessageAr,
        messageEn: lecturerMessageEn,
      );

      await _finalizeLectureActionRecord(
        actionId: actionId,
        affectedStudentsCount: recipientsCount,
        studentNotificationIds: studentNotificationIds,
        lecturerNotificationId: lecturerNotificationId,
      );

      return LectureActionDispatchResult(
        actionId: actionId,
        actionType: actionType,
        recipientCount: recipientsCount,
        studentNotificationIds: studentNotificationIds,
        lecturerNotificationId: lecturerNotificationId,
        lecturerMessageAr: lecturerMessageAr,
        lecturerMessageEn: lecturerMessageEn,
      );
    } catch (e) {
      debugPrint(
        '[LectureActionNotificationService] notification pipeline failed '
        'for actionId=$actionId type=${_actionTypeValue(actionType)} error=$e',
      );
      await _markLectureActionUpdated(actionId);
      throw LectureActionPartialFailureException(
        actionId: actionId,
        message:
            'Action recorded, but notification delivery failed for some recipients.',
      );
    }
  }

  Future<Map<String, LectureActionStatus>> loadLectureActionStatuses({
    required List<LectureItem> lectures,
    required DateTime lectureDate,
  }) async {
    if (lectures.isEmpty) return const <String, LectureActionStatus>{};
    final normalizedDate = _normalizeDate(lectureDate);
    final dateKey = _dateKey(normalizedDate);
    final statuses = <String, LectureActionStatus>{};
    final requests = <Future<void>>[];

    for (final lecture in lectures) {
      final sectionId = (lecture.sectionId ?? '').trim();
      final lectureKey = _statusLookupKey(lecture);
      if (sectionId.isEmpty) {
        statuses[lectureKey] = const LectureActionStatus.normal();
        continue;
      }
      requests.add(() async {
        final delayId = _buildActionId(
          sectionId: sectionId,
          dateKey: dateKey,
          lectureStartTime: lecture.startTime,
          actionType: LectureActionType.delay,
        );
        final cancelId = _buildActionId(
          sectionId: sectionId,
          dateKey: dateKey,
          lectureStartTime: lecture.startTime,
          actionType: LectureActionType.cancel,
        );
        final delaySnap = await _firestore
            .collection(_lectureActionsCollection)
            .doc(delayId)
            .get();
        final cancelSnap = await _firestore
            .collection(_lectureActionsCollection)
            .doc(cancelId)
            .get();

        if (_isActive(cancelSnap.data())) {
          statuses[lectureKey] = LectureActionStatus(
            actionId: cancelId,
            isCanceled: true,
            isDelayed: false,
            delayMinutes: null,
          );
          return;
        }

        final delayData = delaySnap.data();
        if (_isActive(delayData)) {
          statuses[lectureKey] = LectureActionStatus(
            actionId: delayId,
            isCanceled: false,
            isDelayed: true,
            delayMinutes: _safeIntNullable(delayData?['delayMinutes']),
          );
          return;
        }
        statuses[lectureKey] = const LectureActionStatus.normal();
      }());
    }

    await Future.wait(requests);
    return statuses;
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

  Future<List<String>> _createStudentNotifications({
    required Set<int> studentIds,
    required LectureItem lecture,
    required String actionId,
    required String dateKey,
    required LectureActionType actionType,
    required int lectureDayOfWeek,
    required DateTime lectureDate,
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
    final notificationIds = <String>[];
    final clientNow = Timestamp.now();

    Future<void> flushBatch() async {
      if (operations == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      operations = 0;
    }

    for (final studentId in studentIds) {
      final ref = _firestore.collection(_studentNotificationsCollection).doc();
      notificationIds.add(ref.id);
      batch.set(ref, {
        'notificationId': ref.id,
        'actionId': actionId,
        'studentId': studentId,
        'sectionId': lecture.sectionId,
        'courseCode': lecture.crn,
        'courseName': lecture.courseName,
        'section': lecture.section,
        'dateKey': dateKey,
        'lectureStartTime': lecture.startTime,
        'lectureEndTime': lecture.endTime,
        'lectureDayOfWeek': lectureDayOfWeek,
        'lectureDate': Timestamp.fromDate(lectureDate),
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
        'clientCreatedAt': clientNow,
      });
      operations++;

      if (operations >= 450) {
        await flushBatch();
      }
    }

    await flushBatch();
    return notificationIds;
  }

  Future<String> _createLecturerConfirmationNotification({
    required String actionId,
    required String lecturerId,
    required String lecturerDisplayName,
    required LectureItem lecture,
    required LectureActionType actionType,
    required int lectureDayOfWeek,
    required String dateKey,
    required DateTime lectureDate,
    required int? delayMinutes,
    required int recipientCount,
    required String messageAr,
    required String messageEn,
  }) async {
    final ref = _firestore.collection(_lecturerNotificationsCollection).doc();
    final clientNow = Timestamp.now();
    await ref.set({
      'notificationId': ref.id,
      'actionId': actionId,
      'lecturerId': lecturerId,
      'lecturerName': lecturerDisplayName,
      'sectionId': lecture.sectionId,
      'courseCode': lecture.crn,
      'courseName': _englishCourseSnapshot(lecture),
      'courseNameAr': (lecture.courseNameAr ?? '').trim().isNotEmpty
          ? (lecture.courseNameAr ?? '').trim()
          : (LocalizedFirestoreFields.containsArabicScript(lecture.courseName)
              ? lecture.courseName
              : ''),
      'courseNameEn': _englishCourseSnapshot(lecture),
      'section': lecture.section,
      'dateKey': dateKey,
      'lectureStartTime': lecture.startTime,
      'lectureEndTime': lecture.endTime,
      'lectureDayOfWeek': lectureDayOfWeek,
      'lectureDate': Timestamp.fromDate(lectureDate),
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
      'clientCreatedAt': clientNow,
    });
    return ref.id;
  }

  Future<void> _createOrValidateLectureActionRecord({
    required String actionId,
    required LectureActionType actionType,
    required LectureItem lecture,
    required String sectionId,
    required String dateKey,
    required int lectureDayOfWeek,
    required DateTime lectureDate,
    required String lecturerId,
    required String lecturerDisplayName,
    required int? delayMinutes,
  }) async {
    final actionRef = _firestore.collection(_lectureActionsCollection).doc(actionId);
    final delayActionId = _buildActionId(
      sectionId: sectionId,
      dateKey: dateKey,
      lectureStartTime: lecture.startTime,
      actionType: LectureActionType.delay,
    );
    final cancelActionId = _buildActionId(
      sectionId: sectionId,
      dateKey: dateKey,
      lectureStartTime: lecture.startTime,
      actionType: LectureActionType.cancel,
    );
    final delayRef = _firestore.collection(_lectureActionsCollection).doc(delayActionId);
    final cancelRef = _firestore
        .collection(_lectureActionsCollection)
        .doc(cancelActionId);

    try {
      final delaySnap = await delayRef.get();
      final cancelSnap = await cancelRef.get();
      final delayActive = _isActive(delaySnap.data());
      final cancelActive = _isActive(cancelSnap.data());

      if (actionType == LectureActionType.delay) {
        if (cancelActive) {
          throw const LectureActionBlockedException(
            LectureActionBlockReason.canceledCannotDelay,
          );
        }
        if (delayActive) {
          throw const LectureActionBlockedException(
            LectureActionBlockReason.alreadyDelayed,
          );
        }
      } else {
        if (cancelActive) {
          throw const LectureActionBlockedException(
            LectureActionBlockReason.alreadyCanceled,
          );
        }
      }

      await _firestore.runTransaction((tx) async {
        if (actionType == LectureActionType.cancel && delayActive) {
          tx.set(delayRef, {
            'status': 'replaced',
            'supersededByActionId': actionId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        tx.set(actionRef, {
          'actionId': actionId,
          'actionType': _actionTypeValue(actionType),
          'status': 'active',
          'lecturerId': lecturerId,
          'lecturerName': lecturerDisplayName,
          'courseCode': lecture.crn,
          'courseName': lecture.courseName,
          'sectionId': sectionId,
          'section': lecture.section,
          'lectureDate': Timestamp.fromDate(lectureDate),
          'dateKey': dateKey,
          'lectureStartTime': lecture.startTime,
          'lectureEndTime': lecture.endTime,
          'lectureDayOfWeek': lectureDayOfWeek,
          'delayMinutes': delayMinutes,
          'reason': null,
          'affectedStudentsCount': 0,
          'studentNotificationIds': const <String>[],
          'lecturerNotificationId': null,
          'createdBy': lecturerId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } on LectureActionBlockedException {
      rethrow;
    } on FirebaseException catch (e, st) {
      final uid = _auth.currentUser?.uid;
      debugPrint(
        '[LectureActionNotificationService] failed to persist lecture_actions '
        'doc=$actionId type=${_actionTypeValue(actionType)} '
        'runtimeType=${e.runtimeType} code=${e.code} message=${e.message} plugin=${e.plugin} '
        'authUid=${uid ?? 'null'}\n'
        'stackTrace=$st',
      );
      throw StateError(
        'Failed to persist lecture action record: $actionId '
        '(firebase:${e.code}) ${e.message ?? ''}',
      );
    } catch (e, st) {
      final uid = _auth.currentUser?.uid;
      debugPrint(
        '[LectureActionNotificationService] failed to persist lecture_actions '
        'doc=$actionId type=${_actionTypeValue(actionType)} '
        'runtimeType=${e.runtimeType} authUid=${uid ?? 'null'} '
        'error=$e\nstackTrace=$st',
      );
      debugPrint(
        '[LectureActionNotificationService] hint: if web prints '
        '"Dart exception thrown from converted Future", inspect browser console '
        'for boxed error details (e.g. permission-denied).',
      );
      throw StateError('Failed to persist lecture action record: $actionId');
    }
  }

  Future<void> _finalizeLectureActionRecord({
    required String actionId,
    required int affectedStudentsCount,
    required List<String> studentNotificationIds,
    required String lecturerNotificationId,
  }) async {
    await _firestore.collection(_lectureActionsCollection).doc(actionId).set({
      'affectedStudentsCount': affectedStudentsCount,
      'studentNotificationIds': studentNotificationIds,
      'lecturerNotificationId': lecturerNotificationId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _markLectureActionUpdated(String actionId) async {
    try {
      await _firestore.collection(_lectureActionsCollection).doc(actionId).set({
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // ignore secondary update errors
    }
  }

  static String _actionTypeValue(LectureActionType type) {
    switch (type) {
      case LectureActionType.delay:
        return 'delay';
      case LectureActionType.cancel:
        return 'cancel';
    }
  }

  static String _statusLookupKey(LectureItem lecture) {
    final sectionKey = (lecture.sectionId ?? '').trim().isNotEmpty
        ? (lecture.sectionId ?? '').trim()
        : lecture.section.trim();
    return '$sectionKey|${lecture.startTime}';
  }

  static String _buildActionId({
    required String sectionId,
    required String dateKey,
    required String lectureStartTime,
    required LectureActionType actionType,
  }) {
    final compactTime = lectureStartTime.replaceAll(':', '');
    return '${sectionId}_${dateKey}_${compactTime}_${_actionTypeValue(actionType)}';
  }

  static DateTime _normalizeDate(DateTime? value) {
    final base = value ?? DateTime.now();
    return DateTime(base.year, base.month, base.day);
  }

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  static bool _isActive(Map<String, dynamic>? data) {
    if (data == null) return false;
    return (data['status'] ?? '').toString().trim().toLowerCase() == 'active';
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

  int? _safeIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static String _englishCourseSnapshot(LectureItem lecture) {
    final en = (lecture.courseNameEn ?? '').trim();
    if (en.isNotEmpty) return en;
    final display = lecture.courseName.trim();
    if (display.isNotEmpty &&
        !LocalizedFirestoreFields.containsArabicScript(display)) {
      return display;
    }
    return en;
  }
}
