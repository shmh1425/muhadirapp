import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/external_lecturer_model.dart';

class ExternalLecturerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _lecturersRef =>
      _firestore.collection('external_lecturers');

  bool _hasLecturerRole(Map<String, dynamic>? data) {
    final role = (data?['role'] ?? '').toString().trim().toLowerCase();
    return role == 'lecturer';
  }

  Future<void> createLecturer(ExternalLecturerModel lecturer) async {
    await _lecturersRef.doc(lecturer.lecturerId).set(lecturer.toMap());
  }

  Future<void> updateLecturer(
    String lecturerId,
    Map<String, dynamic> data,
  ) async {
    await _lecturersRef.doc(lecturerId).update(data);
  }

  Future<void> deleteLecturer(String lecturerId) async {
    await _lecturersRef.doc(lecturerId).delete();
  }

  Future<ExternalLecturerModel?> getLecturer(String lecturerId) async {
    final doc = await _lecturersRef.doc(lecturerId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    if (!_hasLecturerRole(doc.data())) {
      return null;
    }

    return ExternalLecturerModel.fromMap(doc.data()!);
  }

  Future<ExternalLecturerModel?> getLecturerByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final snapshot = await _lecturersRef
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final data = Map<String, dynamic>.from(snapshot.docs.first.data());
    if (!_hasLecturerRole(data)) {
      return null;
    }
    data['lecturerId'] ??= snapshot.docs.first.id;
    return ExternalLecturerModel.fromMap(data);
  }

  Stream<List<ExternalLecturerModel>> streamLecturers() {
    return _lecturersRef
        .orderBy('nameAr')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ExternalLecturerModel.fromMap(doc.data()))
              .toList(),
        );
  }
}
