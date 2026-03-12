import 'package:cloud_firestore/cloud_firestore.dart';

class ExternalLecturerModel {
  final String lecturerId;
  final String nameAr;
  final String nameEn;
  final String email;
  final String college;
  final String department;
  final String source;
  final String sourceId;
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
    required this.department,
    required this.source,
    required this.sourceId,
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
      college: map['college'] ?? '',
      department: map['department'] ?? '',
      source: map['source'] ?? '',
      sourceId: map['sourceId'] ?? '',
      role: map['role'] ?? 'lecturer',
      linkedUserUid: map['linkedUserUid'],
      isImported: map['isImported'] ?? false,
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lecturerId': lecturerId,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'email': email,
      'college': college,
      'department': department,
      'source': source,
      'sourceId': sourceId,
      'role': role,
      'linkedUserUid': linkedUserUid,
      'isImported': isImported,
      'isActive': isActive,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
