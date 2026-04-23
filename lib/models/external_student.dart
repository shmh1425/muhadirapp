/// نموذج بيانات الطالب من مجموعة external_students في Firestore
class ExternalStudent {
  const ExternalStudent({
    required this.studentId,
    required this.email,
    required this.name,
    this.nameAr = '',
    this.photoUrl = '',
    this.photoVersion = '',
    required this.gender,
    required this.level,
    this.college,
    this.collegeAr,
    required this.major,
    this.majorAr,
    this.department,
    this.departmentAr,
  });

  final int studentId;
  final String email;
  final String name;

  /// الاسم بالعربية للعرض في الهوم والبطاقة
  final String nameAr;
  final String photoUrl;
  final String photoVersion;
  final String gender;
  final int level;

  /// College/Faculty label (English).
  final String? college;

  /// College/Faculty label (Arabic).
  final String? collegeAr;

  final String major;
  final String? majorAr;
  final String? department;
  final String? departmentAr;

  String get collegeSafe => (college ?? '').toString();
  String get collegeArSafe => (collegeAr ?? '').toString();
  String get majorArSafe => (majorAr ?? '').toString();
  String get departmentSafe => (department ?? '').toString();
  String get departmentArSafe => (departmentAr ?? '').toString();

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
      nameAr: safeStr(map['name_ar']).isNotEmpty
          ? safeStr(map['name_ar'])
          : safeStr(map['nameAr']),
      photoUrl: safeStr(
        safeStr(map['photoUrl']).isNotEmpty ? map['photoUrl'] : map['photoURL'],
      ),
      photoVersion: safeStr(map['photoVersion']),
      gender: safeStr(map['gender']),
      level: safeInt(map['level']),
      college: safeStr(map['college']).isNotEmpty
          ? safeStr(map['college'])
          : safeStr(map['collegeName']).isNotEmpty
              ? safeStr(map['collegeName'])
              : safeStr(map['faculty']),
      collegeAr: safeStr(map['college_ar']).isNotEmpty
          ? safeStr(map['college_ar'])
          : safeStr(map['collegeAr']).isNotEmpty
              ? safeStr(map['collegeAr'])
              : safeStr(map['faculty_ar']),
      major: safeStr(map['major']),
      majorAr: safeStr(map['major_ar']).isNotEmpty
          ? safeStr(map['major_ar'])
          : safeStr(map['majorAr']),
      department: safeStr(map['department']),
      departmentAr: safeStr(map['department_ar']).isNotEmpty
          ? safeStr(map['department_ar'])
          : safeStr(map['departmentAr']),
    );
  }

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'email': email,
    'name': name,
    'name_ar': nameAr,
    'nameAr': nameAr,
    'photoUrl': photoUrl,
    'photoVersion': photoVersion,
    'gender': gender,
    'level': level,
    'college': collegeSafe,
    'college_ar': collegeArSafe,
    'collegeAr': collegeArSafe,
    'major': major,
    'major_ar': majorArSafe,
    'majorAr': majorArSafe,
    'department': departmentSafe,
    'department_ar': departmentArSafe,
    'departmentAr': departmentArSafe,
  };
}
