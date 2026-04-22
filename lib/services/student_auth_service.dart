import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/external_student.dart';

/// خدمة التحقق من الطالب وعرض بياناته
/// تبحث في مجموعة external_students بالإيميل فقط (بدون باسورد)
class StudentAuthService {
  StudentAuthService._();
  static final StudentAuthService instance = StudentAuthService._();

  ExternalStudent? _currentStudent;
  String? _currentStudentDocId;

  /// الطالب المسجل حالياً (إن وجد)
  ExternalStudent? get currentStudent => _currentStudent;

  /// Apply a live Firestore snapshot to the currently logged-in student.
  /// Returns the updated student, or null if snapshot is invalid.
  ExternalStudent? applyCurrentStudentSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists) return null;
    final updated = _fromDocSnapshot(doc);
    _currentStudent = updated;
    _currentStudentDocId = doc.id;
    return updated;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentStudentDoc() {
    final docId = (_currentStudentDocId ?? '').trim();
    final fallbackStudentId = _currentStudent?.studentId;
    final resolvedDocId = docId.isNotEmpty
        ? docId
        : (fallbackStudentId == null || fallbackStudentId <= 0
              ? ''
              : fallbackStudentId.toString());
    if (resolvedDocId.isEmpty) {
      return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }
    return FirebaseFirestore.instance
        .collection('external_students')
        .doc(resolvedDocId)
        .snapshots();
  }

  ExternalStudent _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    data['studentId'] ??= int.tryParse(doc.id);
    return ExternalStudent.fromMap(Map<String, dynamic>.from(data));
  }

  ExternalStudent _fromDocSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    data['studentId'] ??= int.tryParse(doc.id);
    return ExternalStudent.fromMap(Map<String, dynamic>.from(data));
  }

  bool _hasStudentRole(Map<String, dynamic>? data) {
    final role = (data?['role'] ?? '').toString().trim().toLowerCase();
    return role == 'student';
  }

  /// التحقق من الإيميل واسترجاع بيانات الطالب من Firestore
  /// يرجع null إذا لم يُعثر على الطالب
  Future<ExternalStudent?> verifyEmailAndGetStudent(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    _currentStudentDocId = null;

    // 1) محاولة مباشرة بالإيميل (مطابقة حرفية)
    final snapshot = await FirebaseFirestore.instance
        .collection('external_students')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      if (!_hasStudentRole(snapshot.docs.first.data())) {
        return null;
      }
      _currentStudent = _fromDoc(snapshot.docs.first);
      _currentStudentDocId = snapshot.docs.first.id;
      return _currentStudent;
    }

    // 2) إذا ما لقي بالإيميل، جرّب رقم الطالب من قبل @
    final localPart = normalized.split('@').first;
    final idFromEmail = int.tryParse(localPart);

    if (idFromEmail != null) {
      // 2.a) محاولة جلب الوثيقة مباشرة إذا كان الـ docId هو رقم الطالب
      final docSnap = await FirebaseFirestore.instance
          .collection('external_students')
          .doc(localPart)
          .get();
      if (docSnap.exists) {
        if (!_hasStudentRole(docSnap.data())) {
          return null;
        }
        _currentStudent = _fromDocSnapshot(docSnap);
        _currentStudentDocId = docSnap.id;
        // إذا كان الإيميل محفوظ لكنه مختلف، نخليه ينعكس في الإعدادات كما هو
        return _currentStudent;
      }

      // 2.b) محاولة البحث بحقل studentId (إذا كان موجوداً كـ int)
      final snapshotById = await FirebaseFirestore.instance
          .collection('external_students')
          .where('studentId', isEqualTo: idFromEmail)
          .limit(1)
          .get();
      if (snapshotById.docs.isNotEmpty) {
        if (!_hasStudentRole(snapshotById.docs.first.data())) {
          return null;
        }
        _currentStudent = _fromDoc(snapshotById.docs.first);
        _currentStudentDocId = snapshotById.docs.first.id;
        return _currentStudent;
      }
    }

    return null;
  }

  /// تسجيل الخروج (مسح بيانات الطالب الحالي)
  void logout() {
    _currentStudent = null;
    _currentStudentDocId = null;
  }
}
