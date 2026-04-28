import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notifications/student_notification.dart';

class StudentNotificationsService {
  StudentNotificationsService._();
  static final StudentNotificationsService instance =
      StudentNotificationsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _recordsCollection = 'manual_attendance_records';
  static const String _lastSeenField = 'notificationsLastSeenAt';
  static const String _readIdsField = 'readNotificationIds';
  static const String _hiddenIdsField = 'hiddenNotificationIds';
  static const String _studentNotifCollection = 'student_notifications';
  static const String _prefsCollection = 'student_notification_prefs';
  static const String _lectureActionIdPrefix = StudentNotification.lectureActionPrefix;
  static const String _attendanceIdPrefix = StudentNotification.attendancePrefix;

  DocumentReference<Map<String, dynamic>>? _prefsRef() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return null;
    return _firestore.collection(_prefsCollection).doc(uid);
  }

  Stream<({Set<String> readIds, Set<String> hiddenIds})> watchReadHiddenIds(
    int studentId,
  ) {
    if (studentId <= 0) {
      return Stream<({Set<String> readIds, Set<String> hiddenIds})>.value(
        (readIds: <String>{}, hiddenIds: <String>{}),
      );
    }
    final ref = _prefsRef();
    if (ref == null) {
      return Stream<({Set<String> readIds, Set<String> hiddenIds})>.value(
        (readIds: <String>{}, hiddenIds: <String>{}),
      );
    }
    return ref.snapshots().map((snap) {
      final data = snap.data() ?? <String, dynamic>{};
      final readIds = ((data[_readIdsField] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet();
      final hiddenIds = ((data[_hiddenIdsField] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet();
      return (readIds: readIds, hiddenIds: hiddenIds);
    });
  }

  Stream<int> watchUnreadAbsenceCount(int studentId) {
    final prefsRef = _prefsRef();
    final recordsQuery = _firestore
        .collection(_recordsCollection)
        .where('studentId', isEqualTo: studentId)
        .where('status', whereIn: const ['absent', 'excused']);

    final prefsStream = prefsRef == null
        ? Stream<Map<String, dynamic>>.value(<String, dynamic>{})
        : prefsRef.snapshots().map((s) => s.data() ?? <String, dynamic>{});

    return prefsStream.asyncExpand((prefsData) {
      final readIds = ((prefsData[_readIdsField] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet();
      final hiddenIds =
          ((prefsData[_hiddenIdsField] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toSet();
      return recordsQuery.snapshots().map((recordsSnap) {
        int unread = 0;
        for (final doc in recordsSnap.docs) {
          if (hiddenIds.contains(doc.id) ||
              hiddenIds.contains('$_attendanceIdPrefix${doc.id}')) {
            continue;
          }
          if (!readIds.contains(doc.id)) unread++;
        }
        return unread;
      });
    });
  }

  /// Total unread count used by the bell badge:
  /// - attendance records: unread if not in prefs.readNotificationIds and not hidden
  /// - student_notifications docs: unread if isRead != true and not hidden/deleted
  Stream<int> watchTotalUnreadCount(int studentId) {
    final prefsRef = _prefsRef();
    if (studentId <= 0) {
      return Stream<int>.value(0);
    }

    final recordsQuery = _firestore
        .collection(_recordsCollection)
        .where('studentId', isEqualTo: studentId)
        .where('status', whereIn: const ['absent', 'excused']);
    final notifQuery = _firestore
        .collection(_studentNotifCollection)
        .where('studentId', isEqualTo: studentId);

    final prefsStream = prefsRef == null
        ? Stream<Map<String, dynamic>>.value(<String, dynamic>{})
        : prefsRef.snapshots().map((s) => s.data() ?? <String, dynamic>{});

    return prefsStream.asyncExpand((prefsData) {
      final readIds = ((prefsData[_readIdsField] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet();
      final hiddenIds = ((prefsData[_hiddenIdsField] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet();

      bool attendanceHidden(String recordId) {
        return hiddenIds.contains(recordId) ||
            hiddenIds.contains('$_attendanceIdPrefix$recordId');
      }

      bool studentNotifHidden(String notifId) {
        return hiddenIds.contains(notifId) ||
            hiddenIds.contains('$_lectureActionIdPrefix$notifId');
      }

      return recordsQuery.snapshots().asyncExpand((recordsSnap) {
        return notifQuery.snapshots().map((notifSnap) {
          var total = 0;

          for (final doc in recordsSnap.docs) {
            if (attendanceHidden(doc.id)) continue;
            if (!readIds.contains(doc.id)) total++;
          }

          for (final doc in notifSnap.docs) {
            if (studentNotifHidden(doc.id)) continue;
            final data = doc.data();
            if (data['isDeleted'] == true) continue;
            if (data['isRead'] == true) continue;
            total++;
          }

          return total;
        });
      });
    });
  }

  Future<void> markAllAsRead(int studentId) async {
    if (studentId <= 0) return;
    final ref = _prefsRef();
    if (ref == null) return;
    await ref.set({
      _lastSeenField: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markNotificationsAsRead(int studentId, List<String> notificationIds) async {
    if (studentId <= 0) return;
    final ids = notificationIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    final ref = _prefsRef();
    if (ref == null) return;
    await ref.set({
      _readIdsField: FieldValue.arrayUnion(ids),
      _lastSeenField: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAllAbsenceNotificationsAsRead(int studentId) async {
    if (studentId <= 0) return;
    final snapshot = await _firestore
        .collection(_recordsCollection)
        .where('studentId', isEqualTo: studentId)
        .where('status', whereIn: const ['absent', 'excused'])
        .get();
    final ids = snapshot.docs.map((d) => d.id).toList();
    await markNotificationsAsRead(studentId, ids);
  }

  Future<Set<String>> getHiddenNotificationIds(int studentId) async {
    if (studentId <= 0) return <String>{};
    final ref = _prefsRef();
    if (ref == null) return <String>{};
    final doc = await ref.get();
    final data = doc.data() ?? <String, dynamic>{};
    final ids = ((data[_hiddenIdsField] as List<dynamic>?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    return ids;
  }

  Future<Set<String>> getReadNotificationIds(int studentId) async {
    if (studentId <= 0) return <String>{};
    final ref = _prefsRef();
    if (ref == null) return <String>{};
    final doc = await ref.get();
    final data = doc.data() ?? <String, dynamic>{};
    final ids = ((data[_readIdsField] as List<dynamic>?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    return ids;
  }

  Future<void> hideNotification(int studentId, String notificationId) async {
    if (studentId <= 0 || notificationId.trim().isEmpty) return;
    final ref = _prefsRef();
    if (ref == null) return;
    await ref.set({
      _hiddenIdsField: FieldValue.arrayUnion(<String>[notificationId.trim()]),
    }, SetOptions(merge: true));
  }

  Future<void> hideNotifications(int studentId, List<String> notificationIds) async {
    if (studentId <= 0) return;
    final ids = notificationIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return;
    final ref = _prefsRef();
    if (ref == null) return;
    await ref.set({
      _hiddenIdsField: FieldValue.arrayUnion(ids),
    }, SetOptions(merge: true));
  }

  Future<DocumentReference<Map<String, dynamic>>?> _getOwnedStudentNotifRef(
    int studentId,
    String notificationDocId,
  ) async {
    final sid = studentId;
    final id = notificationDocId.trim();
    if (sid <= 0 || id.isEmpty) return null;

    final ref = _firestore.collection(_studentNotifCollection).doc(id);
    final snap = await ref.get();
    if (!snap.exists) return null;

    final data = snap.data() ?? <String, dynamic>{};
    final ownerRaw = (data['studentId'] ?? '').toString().trim();
    final owner = int.tryParse(ownerRaw) ?? 0;
    if (owner != sid) return null;
    return ref;
  }

  /// Marks one Firestore `student_notifications` doc as read (no-op if empty id).
  Future<void> markStudentNotificationDocRead({
    required int studentId,
    required String notificationDocId,
  }) async {
    final ref = await _getOwnedStudentNotifRef(studentId, notificationDocId);
    if (ref == null) return;
    await ref.set(
      <String, dynamic>{
        'isRead': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteStudentNotificationDoc({
    required int studentId,
    required String notificationDocId,
  }) async {
    final ref = await _getOwnedStudentNotifRef(studentId, notificationDocId);
    if (ref == null) return;
    await ref.delete();
  }

  /// Lecturer-style: one stream that returns the merged list of student notifications.
  Stream<List<StudentNotification>> watchCurrentStudentNotifications(int studentId) {
    if (studentId <= 0) {
      return const Stream<List<StudentNotification>>.empty();
    }

    final prefsRef = _prefsRef();
    final recordsQuery = _firestore
        .collection(_recordsCollection)
        .where('studentId', isEqualTo: studentId)
        .where('status', whereIn: const ['absent', 'excused']);
    final notifQuery = _firestore
        .collection(_studentNotifCollection)
        .where('studentId', isEqualTo: studentId);

    bool attendanceHidden(Set<String> hiddenIds, String recordId) {
      return hiddenIds.contains(recordId) ||
          hiddenIds.contains('$_attendanceIdPrefix$recordId');
    }

    bool studentNotifHidden(Set<String> hiddenIds, String notifId) {
      return hiddenIds.contains(notifId) ||
          hiddenIds.contains('$_lectureActionIdPrefix$notifId');
    }

    final prefsStream = prefsRef == null
        ? Stream<Map<String, dynamic>>.value(<String, dynamic>{})
        : prefsRef.snapshots().map((s) => s.data() ?? <String, dynamic>{});

    return prefsStream.asyncExpand((prefsData) {
      final readIds = ((prefsData[_readIdsField] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet();
      final hiddenIds =
          ((prefsData[_hiddenIdsField] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toSet();

      return recordsQuery.snapshots().asyncExpand((recordsSnap) {
        return notifQuery.snapshots().map((notifSnap) {
          final list = <StudentNotification>[];

          for (final doc in recordsSnap.docs) {
            if (attendanceHidden(hiddenIds, doc.id)) continue;
            list.add(
              StudentNotification.fromAttendanceDoc(
                doc,
                studentId: studentId,
                isRead: readIds.contains(doc.id),
              ),
            );
          }

          for (final doc in notifSnap.docs) {
            if (studentNotifHidden(hiddenIds, doc.id)) continue;
            final data = doc.data();
            if (data['isDeleted'] == true) continue;
            list.add(
              StudentNotification.fromStudentNotificationDoc(
                doc,
                studentId: studentId,
              ),
            );
          }

          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
      });
    });
  }

  /// Lecturer-style: mark one merged notification as read.
  Future<void> markAsRead({
    required int studentId,
    required StudentNotification notification,
  }) async {
    if (studentId <= 0) return;
    if (notification.isRead) return;

    if (notification.source == StudentNotificationSource.attendanceRecord) {
      await markNotificationsAsRead(studentId, [notification.rawId]);
      return;
    }
    final docId = notification.firestoreDocId;
    if (docId != null && docId.isNotEmpty) {
      await markStudentNotificationDocRead(
        studentId: studentId,
        notificationDocId: docId,
      );
    }
  }

  /// Lecturer-style: delete single notification (attendance -> hide; doc -> delete).
  Future<void> deleteNotification({
    required int studentId,
    required StudentNotification notification,
  }) async {
    if (studentId <= 0) return;
    if (notification.source == StudentNotificationSource.studentNotificationDoc) {
      final docId = notification.firestoreDocId;
      if (docId != null && docId.isNotEmpty) {
        await deleteStudentNotificationDoc(
          studentId: studentId,
          notificationDocId: docId,
        );
        return;
      }
    }
    await hideNotification(studentId, notification.id);
  }

  Future<void> deleteAllForStudent({
    required int studentId,
    required List<StudentNotification> visibleNotifications,
  }) async {
    if (studentId <= 0) return;
    final idsToHide = <String>[];
    final docIdsToDelete = <String>[];

    for (final n in visibleNotifications) {
      if (n.source == StudentNotificationSource.studentNotificationDoc &&
          (n.firestoreDocId ?? '').trim().isNotEmpty) {
        docIdsToDelete.add(n.firestoreDocId!.trim());
      } else {
        idsToHide.add(n.id);
      }
    }

    if (idsToHide.isNotEmpty) {
      await hideNotifications(studentId, idsToHide);
    }

    if (docIdsToDelete.isEmpty) return;

    // Delete in batches (lecturer-style).
    WriteBatch batch = _firestore.batch();
    var ops = 0;
    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit();
      batch = _firestore.batch();
      ops = 0;
    }

    for (final docId in docIdsToDelete) {
      final ref = await _getOwnedStudentNotifRef(studentId, docId);
      if (ref == null) continue;
      batch.delete(ref);
      ops++;
      if (ops >= 450) {
        await flush();
      }
    }
    await flush();
  }
}

