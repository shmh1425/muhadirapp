import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/excuse/excuse_request.dart';

class ExcuseService {
  ExcuseService._();
  static final ExcuseService instance = ExcuseService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// اتركها false لحين تفعيل الـ collection فعلياً في الداتابيس.
  static const bool enabled = false;

  /// اسم الـ collection المقترح لطلبات الأعذار.
  /// عند التفعيل، غيّر الاسم لاسم الـ collection الحقيقي.
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

  Future<void> submitRequest(ExcuseRequest request) async {
    if (!enabled) return;
    await _firestore
        .collection(excusesCollection)
        .doc(request.id)
        .set(request.toMap(), SetOptions(merge: true));
  }
}

