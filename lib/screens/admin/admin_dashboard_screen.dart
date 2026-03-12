import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/admin/admin_auth_service.dart';

String _firebaseErrorMessage(FirebaseException e) {
  return switch (e.code) {
    'permission-denied' =>
      'ما عندك صلاحية تنفيذ العملية. تأكدي من Firestore Rules.',
    'failed-precondition' =>
      'الاستعلام يحتاج إعداد إضافي (غالباً Firestore Index).',
    'unavailable' => 'الخدمة غير متاحة حالياً. تأكدي من الاتصال بالإنترنت.',
    'not-found' => 'العنصر المطلوب غير موجود.',
    _ => 'خطأ Firebase (${e.code}) ${e.message ?? ''}'.trim(),
  };
}

bool _isValidCourseCode(String value) {
  final code = value.trim().toUpperCase();
  return RegExp(r'^[A-Z]{2,5}[0-9]{3,4}$').hasMatch(code);
}

const List<int> _levelOptions = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
const List<String> _sectionNumberOptions = <String>[
  '01',
  '02',
  '03',
  '04',
  '05',
  '06',
  '07',
  '08',
  '09',
  '10',
];
const List<String> _termOptions = <String>[
  '2026-1',
  '2026-2',
  '2027-1',
  '2027-2',
];

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isSigningOut = false;

  Future<void> _onSignOut() async {
    setState(() => _isSigningOut = true);
    await AdminAuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('لوحة تحكم الأدمن'),
            actions: [
              IconButton(
                onPressed: _isSigningOut ? null : _onSignOut,
                icon: _isSigningOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                tooltip: 'تسجيل خروج',
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'الطلاب'),
                Tab(text: 'المحاضرين'),
                Tab(text: 'المقررات'),
                Tab(text: 'التسجيل'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _AdminStudentsTab(),
              _AdminLecturersTab(),
              _AdminCoursesTab(),
              _AdminEnrollmentTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminStudentsTab extends StatefulWidget {
  const _AdminStudentsTab();

  @override
  State<_AdminStudentsTab> createState() => _AdminStudentsTabState();
}

class _AdminStudentsTabState extends State<_AdminStudentsTab> {
  final _studentsRef = FirebaseFirestore.instance.collection(
    'external_students',
  );

  final _studentIdController = TextEditingController();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _emailController = TextEditingController();
  final _majorController = TextEditingController();

  String _selectedGender = 'F';
  int _selectedLevel = 1;
  bool _isSaving = false;

  @override
  void dispose() {
    _studentIdController.dispose();
    _nameArController.dispose();
    _nameEnController.dispose();
    _emailController.dispose();
    _majorController.dispose();
    super.dispose();
  }

  Future<void> _saveStudent() async {
    final studentId = int.tryParse(_studentIdController.text.trim());
    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final major = _majorController.text.trim();

    if (studentId == null || nameAr.isEmpty || email.isEmpty) {
      _showMessage(
        'أكملي البيانات الأساسية: رقم الطالب، الاسم العربي، الإيميل، المستوى',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _studentsRef.doc(studentId.toString()).set({
        'studentId': studentId,
        'name_ar': nameAr,
        'name': nameEn,
        'email': email,
        'role': 'student',
        'major': major,
        'level': _selectedLevel,
        'gender': _selectedGender,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _studentIdController.clear();
      _nameArController.clear();
      _nameEnController.clear();
      _emailController.clear();
      _majorController.clear();
      if (!mounted) return;
      _showMessage('تم حفظ بيانات الطالب');
    } on FirebaseException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteStudent(String docId) async {
    try {
      await _studentsRef.doc(docId).delete();
      if (!mounted) return;
      _showMessage('تم حذف الطالب');
    } on FirebaseException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _SectionTitle('إضافة/تحديث طالب'),
          _AdminTextField(
            controller: _studentIdController,
            label: 'رقم الطالب',
            keyboardType: TextInputType.number,
          ),
          _AdminTextField(
            controller: _nameArController,
            label: 'الاسم بالعربي',
          ),
          _AdminTextField(
            controller: _nameEnController,
            label: 'الاسم بالإنجليزي',
          ),
          _AdminTextField(
            controller: _emailController,
            label: 'الإيميل الجامعي',
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
          ),
          _AdminTextField(controller: _majorController, label: 'التخصص'),
          DropdownButtonFormField<int>(
            initialValue: _selectedLevel,
            decoration: const InputDecoration(
              labelText: 'المستوى',
              border: OutlineInputBorder(),
            ),
            items: _levelOptions
                .map(
                  (level) => DropdownMenuItem<int>(
                    value: level,
                    child: Text('مستوى $level'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedLevel = value);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('الجنس:'),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedGender,
                items: const [
                  DropdownMenuItem(value: 'F', child: Text('طالبة F')),
                  DropdownMenuItem(value: 'M', child: Text('طالب M')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedGender = value);
                },
              ),
              const Spacer(),
              FilledButton(
                onPressed: _isSaving ? null : _saveStudent,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ الطالب'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionTitle('الطلاب الحاليين'),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _studentsRef.orderBy('studentId').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('لا يوجد طلاب حالياً'));
                }

                final docs = snapshot.data!.docs;
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final displayName = (data['name_ar'] ?? data['name'] ?? '')
                        .toString();
                    final email = (data['email'] ?? '').toString();
                    final level = (data['level'] ?? '').toString();
                    final major = (data['major'] ?? '').toString();

                    return ListTile(
                      title: Text(
                        displayName.isEmpty ? 'بدون اسم' : displayName,
                      ),
                      subtitle: Text(
                        'ID: ${doc.id} | $email | مستوى $level | $major',
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _deleteStudent(doc.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminLecturersTab extends StatefulWidget {
  const _AdminLecturersTab();

  @override
  State<_AdminLecturersTab> createState() => _AdminLecturersTabState();
}

class _AdminLecturersTabState extends State<_AdminLecturersTab> {
  final _lecturersRef = FirebaseFirestore.instance.collection(
    'external_lecturers',
  );

  final _lecturerIdController = TextEditingController();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _emailController = TextEditingController();
  final _collegeController = TextEditingController();
  final _departmentController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _lecturerIdController.dispose();
    _nameArController.dispose();
    _nameEnController.dispose();
    _emailController.dispose();
    _collegeController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _saveLecturer() async {
    final lecturerId = _lecturerIdController.text.trim();
    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final college = _collegeController.text.trim();
    final department = _departmentController.text.trim();

    if (lecturerId.isEmpty || nameAr.isEmpty || email.isEmpty) {
      _showMessage(
        'أكملي البيانات الأساسية: معرف المحاضر، الاسم العربي، الإيميل',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _lecturersRef.doc(lecturerId).set({
        'lecturerId': lecturerId,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'email': email,
        'role': 'lecturer',
        'employeeNumber': FieldValue.delete(),
        'college': college,
        'department': department,
        'source': 'admin_dashboard',
        'sourceId': lecturerId,
        'isImported': false,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _lecturerIdController.clear();
      _nameArController.clear();
      _nameEnController.clear();
      _emailController.clear();
      _collegeController.clear();
      _departmentController.clear();
      if (!mounted) return;
      _showMessage('تم حفظ بيانات المحاضر');
    } on FirebaseException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteLecturer(String docId) async {
    try {
      await _lecturersRef.doc(docId).delete();
      if (!mounted) return;
      _showMessage('تم حذف المحاضر');
    } on FirebaseException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _SectionTitle('إضافة/تحديث محاضر'),
          _AdminTextField(
            controller: _lecturerIdController,
            label: 'معرف المحاضر',
          ),
          _AdminTextField(
            controller: _nameArController,
            label: 'الاسم بالعربي',
          ),
          _AdminTextField(
            controller: _nameEnController,
            label: 'الاسم بالإنجليزي',
          ),
          _AdminTextField(
            controller: _emailController,
            label: 'الإيميل الجامعي',
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
          ),
          _AdminTextField(controller: _collegeController, label: 'الكلية'),
          _AdminTextField(controller: _departmentController, label: 'القسم'),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveLecturer,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ المحاضر'),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('المحاضرين الحاليين'),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _lecturersRef.orderBy('nameAr').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('لا يوجد محاضرين حالياً'));
                }

                final docs = snapshot.data!.docs;
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final name = (data['nameAr'] ?? data['nameEn'] ?? '')
                        .toString();
                    final email = (data['email'] ?? '').toString();
                    final department = (data['department'] ?? '').toString();

                    return ListTile(
                      title: Text(name.isEmpty ? 'بدون اسم' : name),
                      subtitle: Text('ID: ${doc.id} | $email | $department'),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _deleteLecturer(doc.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCoursesTab extends StatefulWidget {
  const _AdminCoursesTab();

  @override
  State<_AdminCoursesTab> createState() => _AdminCoursesTabState();
}

class _AdminCoursesTabState extends State<_AdminCoursesTab> {
  final _coursesRef = FirebaseFirestore.instance.collection('courses');
  final _sectionsRef = FirebaseFirestore.instance.collection('sections');
  final _lecturersRef = FirebaseFirestore.instance.collection(
    'external_lecturers',
  );

  final _courseCodeController = TextEditingController();
  final _courseNameController = TextEditingController();
  final _courseMajorController = TextEditingController();
  final _courseHoursController = TextEditingController();
  int _selectedCourseLevel = 1;

  String? _selectedSectionCourseCode;
  String _selectedSectionNumber = '01';
  String? _selectedSectionLecturerId;
  String _selectedSectionTerm = '2026-2';

  bool _isSavingCourse = false;
  bool _isSavingSection = false;
  bool _isSeeding = false;

  @override
  void dispose() {
    _courseCodeController.dispose();
    _courseNameController.dispose();
    _courseMajorController.dispose();
    _courseHoursController.dispose();
    super.dispose();
  }

  Future<void> _saveCourse() async {
    final courseCode = _courseCodeController.text.trim().toUpperCase();
    final courseName = _courseNameController.text.trim();
    final major = _courseMajorController.text.trim();
    final creditHours = int.tryParse(_courseHoursController.text.trim());

    if (courseCode.isEmpty || courseName.isEmpty || major.isEmpty) {
      _showMessage(
        'أكملي بيانات المقرر الأساسية: الرمز، الاسم، التخصص، المستوى',
      );
      return;
    }

    if (!_isValidCourseCode(courseCode)) {
      _showMessage('صيغة رمز المقرر غير صحيحة. مثال صحيح: SE3321');
      return;
    }

    if (_selectedCourseLevel < 1 || _selectedCourseLevel > 12) {
      _showMessage('المستوى لازم يكون بين 1 و 12');
      return;
    }

    setState(() => _isSavingCourse = true);
    try {
      final existing = await _coursesRef.doc(courseCode).get();
      final data = <String, dynamic>{
        'courseCode': courseCode,
        'courseName': courseName,
        'major': major,
        'level': _selectedCourseLevel,
        'creditHours': creditHours ?? 0,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!existing.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await _coursesRef.doc(courseCode).set(data, SetOptions(merge: true));

      _courseCodeController.clear();
      _courseNameController.clear();
      _courseMajorController.clear();
      _courseHoursController.clear();
      _selectedCourseLevel = 1;
      if (!mounted) return;
      _showMessage(existing.exists ? 'تم تحديث المقرر' : 'تم حفظ المقرر');
    } on FirebaseException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isSavingCourse = false);
      }
    }
  }

  Future<void> _saveSection() async {
    if (_selectedSectionCourseCode == null ||
        _selectedSectionCourseCode!.isEmpty) {
      _showMessage('اختاري المقرر أولاً');
      return;
    }

    if (_selectedSectionLecturerId == null ||
        _selectedSectionLecturerId!.isEmpty) {
      _showMessage('اختاري المحاضر أولاً');
      return;
    }

    final courseCode = _selectedSectionCourseCode!;
    final sectionNumber = _selectedSectionNumber;
    final sectionId = '$courseCode-$sectionNumber';

    setState(() => _isSavingSection = true);
    try {
      final courseDoc = await _coursesRef.doc(courseCode).get();
      if (!courseDoc.exists) {
        _showMessage('المقرر المختار غير موجود. أعيدي اختياره.');
        return;
      }

      final lecturerDoc = await _lecturersRef
          .doc(_selectedSectionLecturerId!)
          .get();
      if (!lecturerDoc.exists) {
        _showMessage('المحاضر المختار غير موجود. أعيدي اختياره.');
        return;
      }

      final courseData = courseDoc.data() ?? <String, dynamic>{};
      final lecturerData = lecturerDoc.data() ?? <String, dynamic>{};
      final lecturerName =
          (lecturerData['nameAr'] ?? lecturerData['nameEn'] ?? '').toString();
      final existing = await _sectionsRef.doc(sectionId).get();

      final data = <String, dynamic>{
        'sectionId': sectionId,
        'courseCode': courseCode,
        'courseName': (courseData['courseName'] ?? '').toString(),
        'major': (courseData['major'] ?? '').toString(),
        'level': (courseData['level'] as num?)?.toInt() ?? 0,
        'lecturerId': _selectedSectionLecturerId,
        'lecturerName': lecturerName,
        'term': _selectedSectionTerm,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!existing.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await _sectionsRef.doc(sectionId).set(data, SetOptions(merge: true));
      if (!mounted) return;
      _showMessage(existing.exists ? 'تم تحديث السكشن' : 'تم حفظ السكشن');
    } on FirebaseException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isSavingSection = false);
      }
    }
  }

  Future<void> _seedDummyData() async {
    setState(() => _isSeeding = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final courses = <Map<String, dynamic>>[
        {
          'courseCode': 'SE3321',
          'courseName': 'بحوث العمليات',
          'major': 'هندسة البرمجيات',
          'level': 8,
          'creditHours': 3,
        },
        {
          'courseCode': 'SE3322',
          'courseName': 'جودة البرمجيات',
          'major': 'هندسة البرمجيات',
          'level': 8,
          'creditHours': 3,
        },
        {
          'courseCode': 'SE3323',
          'courseName': 'هندسة البيانات',
          'major': 'هندسة البرمجيات',
          'level': 8,
          'creditHours': 3,
        },
      ];

      final sections = <Map<String, dynamic>>[
        {
          'sectionId': 'SE3321-01',
          'courseCode': 'SE3321',
          'courseName': 'بحوث العمليات',
          'major': 'هندسة البرمجيات',
          'level': 8,
          'lecturerId': 'L1001',
          'lecturerName': 'د. فاطمة أحمد',
          'term': '2026-2',
        },
        {
          'sectionId': 'SE3322-01',
          'courseCode': 'SE3322',
          'courseName': 'جودة البرمجيات',
          'major': 'هندسة البرمجيات',
          'level': 8,
          'lecturerId': 'L1002',
          'lecturerName': 'د. نورة علي',
          'term': '2026-2',
        },
      ];

      final students = <Map<String, dynamic>>[
        {
          'studentId': 441000111,
          'name_ar': 'سارة القحطاني',
          'name': 'Sara Alqahtani',
          'email': '441000111@uqu.edu.sa',
          'role': 'student',
          'major': 'هندسة البرمجيات',
          'level': 8,
          'gender': 'F',
        },
        {
          'studentId': 441000112,
          'name_ar': 'ريم الغامدي',
          'name': 'Reem Alghamdi',
          'email': '441000112@uqu.edu.sa',
          'role': 'student',
          'major': 'هندسة البرمجيات',
          'level': 8,
          'gender': 'F',
        },
        {
          'studentId': 441000113,
          'name_ar': 'نجلاء الزهراني',
          'name': 'Najla Alzahrani',
          'email': '441000113@uqu.edu.sa',
          'role': 'student',
          'major': 'هندسة البرمجيات',
          'level': 8,
          'gender': 'F',
        },
      ];

      final lecturers = <Map<String, dynamic>>[
        {
          'lecturerId': 'L1001',
          'nameAr': 'د. فاطمة أحمد',
          'nameEn': 'Dr. Fatimah Ahmed',
          'email': 'l1001@uqu.edu.sa',
          'role': 'lecturer',
          'college': 'كلية الحاسبات',
          'department': 'هندسة البرمجيات',
        },
        {
          'lecturerId': 'L1002',
          'nameAr': 'د. نورة علي',
          'nameEn': 'Dr. Nora Ali',
          'email': 'l1002@uqu.edu.sa',
          'role': 'lecturer',
          'college': 'كلية الحاسبات',
          'department': 'هندسة البرمجيات',
        },
      ];

      for (final item in courses) {
        final docId = item['courseCode'] as String;
        batch.set(_coursesRef.doc(docId), {
          ...item,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      for (final item in sections) {
        final docId = item['sectionId'] as String;
        batch.set(_sectionsRef.doc(docId), {
          ...item,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      for (final item in students) {
        final studentId = (item['studentId'] as int).toString();
        batch.set(
          firestore.collection('external_students').doc(studentId),
          {
            ...item,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      for (final item in lecturers) {
        final lecturerId = item['lecturerId'] as String;
        batch.set(
          firestore.collection('external_lecturers').doc(lecturerId),
          {
            ...item,
            'source': 'dummy_seed',
            'sourceId': lecturerId,
            'isImported': false,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      if (!mounted) return;
      _showMessage('تمت إضافة بيانات تجريبية كاملة بنجاح');
    } on FirebaseException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isSeeding = false);
      }
    }
  }

  Future<void> _deleteCourse(String docId) async {
    try {
      await _coursesRef.doc(docId).delete();
      if (!mounted) return;
      _showMessage('تم حذف المقرر');
    } on FirebaseException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    }
  }

  Future<void> _deleteSection(String docId) async {
    try {
      await _sectionsRef.doc(docId).delete();
      if (!mounted) return;
      _showMessage('تم حذف السكشن');
    } on FirebaseException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _isSeeding ? null : _seedDummyData,
            icon: _isSeeding
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high),
            label: const Text('إضافة بيانات تجريبية'),
          ),
        ),
        const SizedBox(height: 8),
        const _SectionTitle('إضافة مقرر'),
        _AdminTextField(
          controller: _courseCodeController,
          label: 'رمز المقرر (SE3321)',
        ),
        _AdminTextField(controller: _courseNameController, label: 'اسم المقرر'),
        _AdminTextField(controller: _courseMajorController, label: 'التخصص'),
        DropdownButtonFormField<int>(
          initialValue: _selectedCourseLevel,
          decoration: const InputDecoration(
            labelText: 'المستوى',
            border: OutlineInputBorder(),
          ),
          items: _levelOptions
              .map(
                (level) => DropdownMenuItem<int>(
                  value: level,
                  child: Text('مستوى $level'),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedCourseLevel = value);
          },
        ),
        const SizedBox(height: 10),
        _AdminTextField(
          controller: _courseHoursController,
          label: 'الساعات (اختياري)',
          keyboardType: TextInputType.number,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _isSavingCourse ? null : _saveCourse,
            child: _isSavingCourse
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('حفظ المقرر'),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('إضافة سكشن'),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _coursesRef.orderBy('courseCode').snapshots(),
          builder: (context, coursesSnapshot) {
            final courseDocs = coursesSnapshot.data?.docs ?? const [];
            final selectedCourseExists = courseDocs.any(
              (doc) => doc.id == _selectedSectionCourseCode,
            );
            final selectedCourseCode = selectedCourseExists
                ? _selectedSectionCourseCode
                : null;
            final selectedCourseData = courseDocs
                .where((doc) => doc.id == selectedCourseCode)
                .map((doc) => doc.data())
                .cast<Map<String, dynamic>>()
                .toList();
            final courseData = selectedCourseData.isNotEmpty
                ? selectedCourseData.first
                : null;

            return Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCourseCode,
                  decoration: const InputDecoration(
                    labelText: 'المقرر',
                    border: OutlineInputBorder(),
                  ),
                  items: courseDocs.map((doc) {
                    final data = doc.data();
                    final code = (data['courseCode'] ?? doc.id).toString();
                    final name = (data['courseName'] ?? '').toString();
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text('$code - $name'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSectionCourseCode = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                if (courseData != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'تخصص: ${(courseData['major'] ?? '')} | مستوى: ${(courseData['level'] ?? '')}',
                    ),
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSectionNumber,
                  decoration: const InputDecoration(
                    labelText: 'رقم السكشن',
                    border: OutlineInputBorder(),
                  ),
                  items: _sectionNumberOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedSectionNumber = value);
                  },
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _lecturersRef.orderBy('nameAr').snapshots(),
                  builder: (context, lecturersSnapshot) {
                    final lecturerDocs =
                        lecturersSnapshot.data?.docs ?? const [];
                    final selectedLecturerExists = lecturerDocs.any(
                      (doc) => doc.id == _selectedSectionLecturerId,
                    );
                    final selectedLecturerId = selectedLecturerExists
                        ? _selectedSectionLecturerId
                        : null;

                    return DropdownButtonFormField<String>(
                      initialValue: selectedLecturerId,
                      decoration: const InputDecoration(
                        labelText: 'المحاضر',
                        border: OutlineInputBorder(),
                      ),
                      items: lecturerDocs.map((doc) {
                        final data = doc.data();
                        final name = (data['nameAr'] ?? data['nameEn'] ?? '')
                            .toString();
                        final lecturerId = (data['lecturerId'] ?? doc.id)
                            .toString();
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text('$name ($lecturerId)'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedSectionLecturerId = value);
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSectionTerm,
                  decoration: const InputDecoration(
                    labelText: 'الفصل الدراسي',
                    border: OutlineInputBorder(),
                  ),
                  items: _termOptions
                      .map(
                        (term) => DropdownMenuItem<String>(
                          value: term,
                          child: Text(term),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedSectionTerm = value);
                  },
                ),
                const SizedBox(height: 10),
                if (_selectedSectionCourseCode != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'معرف السكشن النهائي: $_selectedSectionCourseCode-$_selectedSectionNumber',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _isSavingSection ? null : _saveSection,
            child: _isSavingSection
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('حفظ السكشن'),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('المقررات الحالية'),
        SizedBox(
          height: 220,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _coursesRef.orderBy('courseCode').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('لا توجد مقررات حالياً'));
              }

              final docs = snapshot.data!.docs;
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final courseCode = (data['courseCode'] ?? doc.id).toString();
                  final courseName = (data['courseName'] ?? '').toString();
                  final major = (data['major'] ?? '').toString();
                  final level = (data['level'] ?? '').toString();

                  return ListTile(
                    dense: true,
                    title: Text('$courseCode - $courseName'),
                    subtitle: Text('تخصص: $major | مستوى: $level'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteCourse(doc.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        const _SectionTitle('السكاشن الحالية'),
        SizedBox(
          height: 220,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _sectionsRef
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('لا توجد سكاشن حالياً'));
              }

              final docs = snapshot.data!.docs;
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final sectionId = (data['sectionId'] ?? doc.id).toString();
                  final courseCode = (data['courseCode'] ?? '').toString();
                  final major = (data['major'] ?? '').toString();
                  final level = (data['level'] ?? '').toString();

                  return ListTile(
                    dense: true,
                    title: Text('سكشن $sectionId - $courseCode'),
                    subtitle: Text('تخصص: $major | مستوى: $level'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteSection(doc.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminEnrollmentTab extends StatefulWidget {
  const _AdminEnrollmentTab();

  @override
  State<_AdminEnrollmentTab> createState() => _AdminEnrollmentTabState();
}

class _AdminEnrollmentTabState extends State<_AdminEnrollmentTab> {
  final _studentsRef = FirebaseFirestore.instance.collection(
    'external_students',
  );
  final _sectionsRef = FirebaseFirestore.instance.collection('sections');
  final _enrollmentsRef = FirebaseFirestore.instance.collection(
    'student_section_enrollments',
  );

  String? _selectedMajor;
  int? _selectedLevel;
  String? _selectedSectionId;

  final Map<String, bool> _selectedStudents = {};
  bool _isSaving = false;

  Query<Map<String, dynamic>> _buildStudentsQuery() {
    Query<Map<String, dynamic>> query = _studentsRef;

    if (_selectedMajor != null && _selectedMajor!.isNotEmpty) {
      query = query.where('major', isEqualTo: _selectedMajor);
    }

    if (_selectedLevel != null) {
      query = query.where('level', isEqualTo: _selectedLevel);
    }

    return query;
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _normalize(dynamic value) =>
      value?.toString().trim().toLowerCase() ?? '';

  String _studentName(Map<String, dynamic> data) {
    final nameAr = (data['name_ar'] ?? '').toString().trim();
    if (nameAr.isNotEmpty) return nameAr;
    return (data['name'] ?? '').toString().trim();
  }

  Future<void> _enrollSelectedStudents({
    required Map<String, dynamic> sectionData,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> studentDocs,
  }) async {
    final selectedIds = _selectedStudents.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (_selectedSectionId == null || selectedIds.isEmpty) {
      _showMessage('اختاري سكشن وحددي طالب واحد على الأقل');
      return;
    }

    final studentsByDocId = {for (final doc in studentDocs) doc.id: doc.data()};
    final sectionId = (sectionData['sectionId'] ?? _selectedSectionId!)
        .toString();

    setState(() => _isSaving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final studentDocId in selectedIds) {
        final studentData = studentsByDocId[studentDocId];
        if (studentData == null) continue;

        final enrollmentId = '${studentDocId}_$sectionId';
        final studentId = _safeInt(studentData['studentId']);

        batch.set(_enrollmentsRef.doc(enrollmentId), {
          'enrollmentId': enrollmentId,
          'studentDocId': studentDocId,
          'studentId': studentId,
          'studentName': _studentName(studentData),
          'studentEmail': (studentData['email'] ?? '').toString(),
          'major': (studentData['major'] ?? '').toString(),
          'level': _safeInt(studentData['level']),
          'sectionId': sectionId,
          'term': (sectionData['term'] ?? '').toString(),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      if (!mounted) return;
      _selectedStudents.clear();
      setState(() {});
      _showMessage('تم تسجيل الطلاب في السكشن بنجاح');
    } on FirebaseException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _removeEnrollment(String enrollmentDocId) async {
    try {
      await _enrollmentsRef.doc(enrollmentDocId).delete();
      if (!mounted) return;
      _showMessage('تم حذف تسجيل الطالب من السكشن');
    } on FirebaseException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('تسجيل الطلاب في السكشن'),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _studentsRef.snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];

              final majors =
                  docs
                      .map(
                        (doc) => (doc.data()['major'] ?? '').toString().trim(),
                      )
                      .where((major) => major.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();

              final levels =
                  docs
                      .map((doc) => _safeInt(doc.data()['level']))
                      .where((level) => level > 0)
                      .toSet()
                      .toList()
                    ..sort();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedMajor,
                    decoration: const InputDecoration(
                      labelText: 'التخصص',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('الكل'),
                      ),
                      ...majors.map(
                        (major) => DropdownMenuItem<String?>(
                          value: major,
                          child: Text(major),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedMajor = value;
                        _selectedSectionId = null;
                        _selectedStudents.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedLevel,
                    decoration: const InputDecoration(
                      labelText: 'المستوى',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('الكل'),
                      ),
                      ...levels.map(
                        (level) => DropdownMenuItem<int?>(
                          value: level,
                          child: Text('مستوى $level'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedLevel = value;
                        _selectedSectionId = null;
                        _selectedStudents.clear();
                      });
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _sectionsRef.snapshots(),
              builder: (context, sectionsSnapshot) {
                if (sectionsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allSectionDocs = sectionsSnapshot.data?.docs ?? const [];
                final activeSectionDocs = allSectionDocs
                    .where((doc) => doc.data()['isActive'] != false)
                    .toList();
                final filteredSectionDocs = activeSectionDocs.where((doc) {
                  final data = doc.data();
                  final majorMatches =
                      _selectedMajor == null ||
                      _selectedMajor!.isEmpty ||
                      _normalize(data['major']) == _normalize(_selectedMajor);
                  final levelMatches =
                      _selectedLevel == null ||
                      _safeInt(data['level']) == _selectedLevel;
                  return majorMatches && levelMatches;
                }).toList();
                final hasFilters =
                    (_selectedMajor != null && _selectedMajor!.isNotEmpty) ||
                    _selectedLevel != null;
                final usingFallback =
                    hasFilters &&
                    filteredSectionDocs.isEmpty &&
                    activeSectionDocs.isNotEmpty;
                final sectionDocs = usingFallback
                    ? activeSectionDocs
                    : filteredSectionDocs;
                final hasSelectedSection = sectionDocs.any(
                  (doc) => doc.id == _selectedSectionId,
                );
                final sectionValue = hasSelectedSection
                    ? _selectedSectionId
                    : null;

                final selectedSectionData = sectionDocs
                    .where((doc) => doc.id == sectionValue)
                    .map((doc) => doc.data())
                    .cast<Map<String, dynamic>>()
                    .toList();

                final currentSection = selectedSectionData.isNotEmpty
                    ? selectedSectionData.first
                    : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: sectionValue,
                      decoration: const InputDecoration(
                        labelText: 'اختيار السكشن',
                        border: OutlineInputBorder(),
                      ),
                      items: sectionDocs.map((doc) {
                        final data = doc.data();
                        final sectionId = (data['sectionId'] ?? doc.id)
                            .toString();
                        final courseCode = (data['courseCode'] ?? '')
                            .toString();
                        final courseName = (data['courseName'] ?? '')
                            .toString();
                        final level = (data['level'] ?? '').toString();
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(
                            '$sectionId | $courseCode | $courseName | مستوى $level',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSectionId = value;
                          _selectedStudents.clear();
                        });
                      },
                    ),
                    if (usingFallback) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'لا يوجد سكشن مطابق للتخصص/المستوى، تم عرض السكاشن المتاحة كلها.',
                        style: TextStyle(color: Color(0xFF8A6D3B)),
                      ),
                    ],
                    if (sectionDocs.isEmpty) ...[
                      const SizedBox(height: 6),
                      const Text('لا يوجد سكاشن متاحة حالياً.'),
                    ],
                    const SizedBox(height: 8),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _buildStudentsQuery().limit(300).snapshots(),
                        builder: (context, studentsSnapshot) {
                          if (studentsSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final studentDocs =
                              (studentsSnapshot.data?.docs ??
                                      const <
                                        QueryDocumentSnapshot<
                                          Map<String, dynamic>
                                        >
                                      >[])
                                  .toList()
                                ..sort((a, b) {
                                  final aId = _safeInt(a.data()['studentId']);
                                  final bId = _safeInt(b.data()['studentId']);
                                  return aId.compareTo(bId);
                                });
                          if (studentDocs.isEmpty) {
                            return const Center(
                              child: Text(
                                'لا يوجد طلاب مطابقين للتخصص/المستوى',
                              ),
                            );
                          }

                          final selectedCount = _selectedStudents.values
                              .where((isSelected) => isSelected)
                              .length;

                          return Column(
                            children: [
                              Row(
                                children: [
                                  Text('المختارون: $selectedCount'),
                                  const Spacer(),
                                  FilledButton.icon(
                                    onPressed:
                                        _isSaving ||
                                            currentSection == null ||
                                            selectedCount == 0
                                        ? null
                                        : () => _enrollSelectedStudents(
                                            sectionData: currentSection,
                                            studentDocs: studentDocs,
                                          ),
                                    icon: _isSaving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.how_to_reg),
                                    label: const Text(
                                      'تسجيل المختارين في السكشن',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: studentDocs.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final doc = studentDocs[index];
                                    final data = doc.data();
                                    final name = _studentName(data);
                                    final studentId =
                                        (data['studentId'] ?? doc.id)
                                            .toString();
                                    final major = (data['major'] ?? '')
                                        .toString();
                                    final level = (data['level'] ?? '')
                                        .toString();
                                    final checked =
                                        _selectedStudents[doc.id] ?? false;

                                    return CheckboxListTile(
                                      value: checked,
                                      contentPadding: EdgeInsets.zero,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedStudents[doc.id] =
                                              value ?? false;
                                        });
                                      },
                                      title: Text(
                                        name.isEmpty ? 'بدون اسم' : name,
                                      ),
                                      subtitle: Text(
                                        'ID: $studentId | $major | مستوى $level',
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'المسجلون حالياً في السكشن المختار:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 150,
                      child: sectionValue == null
                          ? const Center(
                              child: Text('اختاري سكشن لعرض المسجلين'),
                            )
                          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _enrollmentsRef
                                  .where(
                                    'sectionId',
                                    isEqualTo:
                                        (currentSection?['sectionId'] ??
                                                sectionValue)
                                            .toString(),
                                  )
                                  .snapshots(),
                              builder: (context, enrollmentsSnapshot) {
                                if (enrollmentsSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final docs =
                                    enrollmentsSnapshot.data?.docs ?? const [];
                                if (docs.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'لا يوجد طلاب مسجلين في هذا السكشن',
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final doc = docs[index];
                                    final data = doc.data();
                                    final studentName =
                                        (data['studentName'] ?? '').toString();
                                    final studentId = (data['studentId'] ?? '')
                                        .toString();

                                    return ListTile(
                                      dense: true,
                                      title: Text(studentName),
                                      subtitle: Text('ID: $studentId'),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _removeEnrollment(doc.id),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.textDirection,
    this.textAlign = TextAlign.right,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textDirection: textDirection,
        textAlign: textAlign,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
