/// نموذج بيانات الطالب من مجموعة external_students في Firestore
class ExternalStudent {
  const ExternalStudent({
    required this.studentId,
    required this.email,
    required this.name,
    required this.gender,
    required this.level,
    required this.major,
  });

  final int studentId;
  final String email;
  final String name;
  final String gender;
  final int level;
  final String major;

  factory ExternalStudent.fromMap(Map<String, dynamic> map) {
    return ExternalStudent(
      studentId: (map['studentId'] as num?)?.toInt() ?? 0,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      gender: map['gender'] as String? ?? '',
      level: (map['level'] as num?)?.toInt() ?? 0,
      major: map['major'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'email': email,
        'name': name,
        'gender': gender,
        'level': level,
        'major': major,
      };
}
