import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/localized_firestore_fields.dart';

class ExternalLecturerModel {
  final String lecturerId;
  final String nameAr;
  final String nameEn;
  final String email;
  final String college;
  final String collegeAr;
  final String collegeEn;
  final String department;
  final String departmentAr;
  final String departmentEn;
  final String source;
  final String sourceId;
  final String? lecturerCardId;
  final String? photoUrl;
  final String role;
  final String? linkedUserUid;
  final bool isImported;
  final bool isActive;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  ExternalLecturerModel({
    required this.lecturerId,
    required this.nameAr,
    required this.nameEn,
    required this.email,
    required this.college,
    this.collegeAr = '',
    this.collegeEn = '',
    required this.department,
    this.departmentAr = '',
    this.departmentEn = '',
    required this.source,
    required this.sourceId,
    this.lecturerCardId,
    this.photoUrl,
    this.role = 'lecturer',
    this.linkedUserUid,
    required this.isImported,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory ExternalLecturerModel.fromMap(Map<String, dynamic> map) {
    return ExternalLecturerModel(
      lecturerId: map['lecturerId'] ?? '',
      nameAr: map['nameAr'] ?? '',
      nameEn: map['nameEn'] ?? '',
      email: map['email'] ?? '',
      college: (map['college'] ?? '').toString().trim(),
      collegeAr: (map['collegeAr'] ?? map['college_ar'] ?? '').toString().trim(),
      collegeEn: (map['collegeEn'] ??
              map['college_en'] ??
              map['college'] ??
              '')
          .toString()
          .trim(),
      department: (map['department'] ?? '').toString().trim(),
      departmentAr: (map['departmentAr'] ?? map['department_ar'] ?? '')
          .toString()
          .trim(),
      departmentEn: (map['departmentEn'] ??
              map['department_en'] ??
              map['department'] ??
              '')
          .toString()
          .trim(),
      source: map['source'] ?? '',
      sourceId: map['sourceId'] ?? '',
      lecturerCardId: (map['lecturerCardId'] ?? '').toString().trim().isEmpty
          ? null
          : (map['lecturerCardId']).toString().trim(),
      photoUrl: (map['photoUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (map['photoUrl']).toString().trim(),
      role: map['role'] ?? 'lecturer',
      linkedUserUid: map['linkedUserUid'],
      isImported: map['isImported'] ?? false,
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  /// Display name for the current UI language (Arabic preferred when [isArabic]).
  String displayNameFor(bool isArabic) {
    final ar = nameAr.trim();
    final en = nameEn.trim();
    if (isArabic) {
      return ar.isNotEmpty ? ar : (en.isNotEmpty ? en : lecturerId);
    }
    return en.isNotEmpty ? en : (ar.isNotEmpty ? ar : lecturerId);
  }

  Map<String, dynamic> get _localizationMap => {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'college': college,
        'collegeAr': collegeAr,
        'collegeEn': collegeEn,
        'department': department,
        'departmentAr': departmentAr,
        'departmentEn': departmentEn,
      };

  String displayCollegeFor(bool isArabic) {
    return LocalizedFirestoreFields.localizedCollege(
      _localizationMap,
      isArabic: isArabic,
      fallback: college.trim(),
    );
  }

  String displayDepartmentFor(bool isArabic) {
    return LocalizedFirestoreFields.localizedDepartment(
      _localizationMap,
      isArabic: isArabic,
      fallback: department.trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lecturerId': lecturerId,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'email': email,
      'college': college,
      if (collegeAr.isNotEmpty) 'collegeAr': collegeAr,
      if (collegeEn.isNotEmpty) 'collegeEn': collegeEn,
      'department': department,
      if (departmentAr.isNotEmpty) 'departmentAr': departmentAr,
      if (departmentEn.isNotEmpty) 'departmentEn': departmentEn,
      'source': source,
      'sourceId': sourceId,
      'lecturerCardId': lecturerCardId,
      'photoUrl': photoUrl,
      'role': role,
      'linkedUserUid': linkedUserUid,
      'isImported': isImported,
      'isActive': isActive,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
