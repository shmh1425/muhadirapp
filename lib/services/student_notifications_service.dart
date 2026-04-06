import 'package:cloud_firestore/cloud_firestore.dart';

class StudentNotificationsService {
  StudentNotificationsService._();
  static final StudentNotificationsService instance =
      StudentNotificationsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _recordsCollection = 'manual_attendance_records';
  static const String _studentsCollection = 'external_students';
  static const String _lastSeenField = 'notificationsLastSeenAt';
  static const String _readIdsField = 'readNotificationIds';
  static const String _hiddenIdsField = 'hiddenNotificationIds';

  Stream<int> watchUnreadAbsenceCount(int studentId) {
    final studentQuery = _firestore
        .collection(_studentsCollection)
        .where('studentId', isEqualTo: studentId)
        .limit(1);
    final recordsQuery = _firestore
        .collection(_recordsCollection)
        .where('studentId', isEqualTo: studentId)
        .where('status', whereIn: const ['absent', 'excused']);

    return studentQuery.snapshots().asyncExpand((studentSnap) {
      final studentData = studentSnap.docs.isNotEmpty
          ? studentSnap.docs.first.data()
          : <String, dynamic>{};
      final readIds = ((studentData[_readIdsField] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet();
      final hiddenIds = ((studentData[_hiddenIdsField] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet();
      return recordsQuery.snapshots().map((recordsSnap) {
        int unread = 0;
        for (final doc in recordsSnap.docs) {
          if (hiddenIds.contains(doc.id)) continue;
          if (!readIds.contains(doc.id)) unread++;
        }
        return unread;
      });
    });
  }

  Future<void> markAllAsRead(int studentId) async {
    if (studentId <= 0) return;
    final ref = await _resolveStudentRef(studentId);
    await ref.set({
      'studentId': studentId,
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
    final ref = await _resolveStudentRef(studentId);
    await ref.set({
      'studentId': studentId,
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
    final ref = await _resolveStudentRef(studentId);
    final doc = await ref.get();
    final data = doc.data() ?? <String, dynamic>{};
    final ids = ((data[_hiddenIdsField] as List<dynamic>?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    return ids;
  }

  Future<Set<String>> getReadNotificationIds(int studentId) async {
    if (studentId <= 0) return <String>{};
    final ref = await _resolveStudentRef(studentId);
    final doc = await ref.get();
    final data = doc.data() ?? <String, dynamic>{};
    final ids = ((data[_readIdsField] as List<dynamic>?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    return ids;
  }

  Future<void> hideNotification(int studentId, String notificationId) async {
    if (studentId <= 0 || notificationId.trim().isEmpty) return;
    final ref = await _resolveStudentRef(studentId);
    await ref.set({
      'studentId': studentId,
      _hiddenIdsField: FieldValue.arrayUnion(<String>[notificationId.trim()]),
    }, SetOptions(merge: true));
  }

  Future<void> hideNotifications(int studentId, List<String> notificationIds) async {
    if (studentId <= 0) return;
    final ids = notificationIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return;
    final ref = await _resolveStudentRef(studentId);
    await ref.set({
      'studentId': studentId,
      _hiddenIdsField: FieldValue.arrayUnion(ids),
    }, SetOptions(merge: true));
  }

  Future<DocumentReference<Map<String, dynamic>>> _resolveStudentRef(
    int studentId,
  ) async {
    final query = await _firestore
        .collection(_studentsCollection)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return query.docs.first.reference;
    }
    // Fallback إذا كان docId = studentId
    return _firestore.collection(_studentsCollection).doc(studentId.toString());
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

