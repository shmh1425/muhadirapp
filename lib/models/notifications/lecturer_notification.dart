import 'package:cloud_firestore/cloud_firestore.dart';

enum LecturerNotificationCategory { academic, personal, students }

class LecturerNotification {
  const LecturerNotification({
    required this.id,
    required this.notificationId,
    required this.lecturerId,
    required this.categoryRaw,
    required this.titleAr,
    required this.titleEn,
    required this.messageAr,
    required this.messageEn,
    required this.createdAt,
    required this.isRead,
    required this.actionType,
    required this.delayMinutes,
    required this.recipientsCount,
    required this.courseCode,
    required this.courseName,
    required this.section,
    required this.sectionId,
    required this.lectureDate,
    required this.lectureStartTime,
    required this.lectureEndTime,
    required this.lectureHall,
    required this.lectureActivity,
    required this.isExcuseRequest,
    required this.excuseRequestId,
    required this.excuseDetails,
    required this.excuseRequestSnapshot,
    required this.storedInExcuseRequests,
  });

  final String id;
  final String notificationId;
  final String lecturerId;
  final String categoryRaw;
  final String titleAr;
  final String titleEn;
  final String messageAr;
  final String messageEn;
  final DateTime? createdAt;
  final bool isRead;
  final String actionType;
  final int? delayMinutes;
  final int? recipientsCount;
  final String courseCode;
  final String courseName;
  final String section;
  final String sectionId;
  final DateTime? lectureDate;
  final String lectureStartTime;
  final String lectureEndTime;
  final String lectureHall;
  final String lectureActivity;
  final bool isExcuseRequest;
  final String excuseRequestId;
  final Map<String, dynamic> excuseDetails;
  final Map<String, dynamic> excuseRequestSnapshot;
  final bool? storedInExcuseRequests;

  factory LecturerNotification.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    final excuseDetails = _safeMap(data['excuseDetails']);
    final excuseSnapshot = _safeMap(data['excuseRequestSnapshot']);
    final rawExcuseId = (data['excuseRequestId'] ?? '').toString().trim();
    final snapshotExcuseId = (excuseSnapshot['id'] ?? '').toString().trim();
    final resolvedExcuseId = rawExcuseId.isNotEmpty ? rawExcuseId : snapshotExcuseId;

    return LecturerNotification(
      id: doc.id,
      notificationId: (data['notificationId'] ?? doc.id).toString(),
      lecturerId: (data['lecturerId'] ?? '').toString().trim(),
      categoryRaw: (data['category'] ?? '').toString().trim().toLowerCase(),
      titleAr: (data['titleAr'] ?? '').toString(),
      titleEn: (data['titleEn'] ?? '').toString(),
      messageAr: (data['messageAr'] ?? '').toString(),
      messageEn: (data['messageEn'] ?? '').toString(),
      createdAt: parseDate(data['createdAt']) ?? parseDate(data['clientCreatedAt']),
      isRead: data['isRead'] == true,
      actionType: (data['actionType'] ?? '').toString().trim().toLowerCase(),
      delayMinutes: _safeIntNullable(data['delayMinutes']),
      recipientsCount: _safeIntNullable(data['recipientsCount']),
      courseCode: (data['courseCode'] ?? '').toString().trim(),
      courseName: (data['courseName'] ?? '').toString().trim(),
      section: (data['section'] ?? '').toString().trim(),
      sectionId: (data['sectionId'] ?? '').toString().trim(),
      lectureDate: parseDate(data['lectureDate']),
      lectureStartTime: (data['lectureStartTime'] ?? '').toString().trim(),
      lectureEndTime: (data['lectureEndTime'] ?? '').toString().trim(),
      lectureHall: (data['lectureHall'] ?? '').toString().trim(),
      lectureActivity: (data['lectureActivity'] ?? '').toString().trim(),
      isExcuseRequest: data['isExcuseRequest'] == true || resolvedExcuseId.isNotEmpty,
      excuseRequestId: resolvedExcuseId,
      excuseDetails: excuseDetails,
      excuseRequestSnapshot: excuseSnapshot,
      storedInExcuseRequests: data['storedInExcuseRequests'] is bool
          ? data['storedInExcuseRequests'] as bool
          : null,
    );
  }

  LecturerNotificationCategory get mappedCategory {
    if (categoryRaw == 'academic' ||
        categoryRaw == 'official' ||
        categoryRaw == 'system' ||
        categoryRaw == 'general') {
      return LecturerNotificationCategory.academic;
    }
    if (actionType == 'delay' || actionType == 'cancel') {
      return LecturerNotificationCategory.personal;
    }
    if (categoryRaw == 'students' || isExcuseRequest) {
      return LecturerNotificationCategory.students;
    }
    return LecturerNotificationCategory.academic;
  }

  bool get isStudentRelated {
    return mappedCategory == LecturerNotificationCategory.students;
  }

  bool get isPersonalLectureAction {
    return mappedCategory == LecturerNotificationCategory.personal;
  }

  bool get isAcademic {
    return mappedCategory == LecturerNotificationCategory.academic;
  }

  String get sessionIdFromSnapshot {
    return (excuseRequestSnapshot['sessionId'] ?? '').toString().trim();
  }

  String get statusFromSnapshot {
    return (excuseRequestSnapshot['status'] ?? '').toString().trim().toLowerCase();
  }
}

Map<String, dynamic> _safeMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (key, val) => MapEntry(key.toString(), val),
    );
  }
  return <String, dynamic>{};
}

int? _safeIntNullable(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse((value ?? '').toString());
  return parsed;
}
