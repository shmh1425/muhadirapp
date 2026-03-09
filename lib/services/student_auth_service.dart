import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/external_student.dart';

/// خدمة التحقق من الطالب وعرض بياناته
/// تبحث في مجموعة external_students بالإيميل فقط (بدون باسورد)
class StudentAuthService {
  StudentAuthService._();
  static final StudentAuthService instance = StudentAuthService._();

  ExternalStudent? _currentStudent;

  /// الطالب المسجل حالياً (إن وجد)
  ExternalStudent? get currentStudent => _currentStudent;

  ExternalStudent _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    data['studentId'] ??= int.tryParse(doc.id);
    return ExternalStudent.fromMap(data);
  }

  ExternalStudent _fromDocSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    data['studentId'] ??= int.tryParse(doc.id);
    return ExternalStudent.fromMap(data);
  }

  /// التحقق من الإيميل واسترجاع بيانات الطالب من Firestore
  /// يرجع null إذا لم يُعثر على الطالب
  Future<ExternalStudent?> verifyEmailAndGetStudent(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    // 1) محاولة مباشرة بالإيميل (مطابقة حرفية)
    final snapshot = await FirebaseFirestore.instance
        .collection('external_students')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      _currentStudent = _fromDoc(snapshot.docs.first);
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
        _currentStudent = _fromDocSnapshot(docSnap);
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
        _currentStudent = _fromDoc(snapshotById.docs.first);
        return _currentStudent;
      }
    }

    return null;
  }

  /// تسجيل الخروج (مسح بيانات الطالب الحالي)
  void logout() {
    _currentStudent = null;
  }
}
