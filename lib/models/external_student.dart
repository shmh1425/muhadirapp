/// نموذج بيانات الطالب من مجموعة external_students في Firestore
class ExternalStudent {
  const ExternalStudent({
    required this.studentId,
    required this.email,
    required this.name,
    this.nameAr = '',
    required this.gender,
    required this.level,
    required this.major,
  });

  final int studentId;
  final String email;
  final String name;
  /// الاسم بالعربية للعرض في الهوم والبطاقة
  final String nameAr;
  final String gender;
  final int level;
  final String major;

  /// للعرض في الواجهة: الاسم العربي إن وُجد وإلا الإنجليزي
  String get displayName => nameAr.trim().isNotEmpty ? nameAr : name;

  factory ExternalStudent.fromMap(Map<String, dynamic>? map) {
    if (map == null) map = {};
    String safeStr(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      return v.toString();
    }
    int safeInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v.toString();
      return int.tryParse(s) ?? 0;
    }
    return ExternalStudent(
      studentId: safeInt(map['studentId']),
      email: safeStr(map['email']),
      name: safeStr(map['name']),
      nameAr: safeStr(map['name_ar']),
      gender: safeStr(map['gender']),
      level: safeInt(map['level']),
      major: safeStr(map['major']),
    );
  }

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'email': email,
        'name': name,
        'name_ar': nameAr,
        'gender': gender,
        'level': level,
        'major': major,
      };
}
