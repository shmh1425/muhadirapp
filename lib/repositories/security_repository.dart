import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../services/female_security/security_gate_scan_service.dart';

/// Central API for security staff: realtime scans stay as streams; metadata may be cached.
class SecurityRepository {
  SecurityRepository._();
  static final SecurityRepository instance = SecurityRepository._();

  static const String metadataBoxName = 'securityMetadataBox';

  Box<dynamic> get _box => Hive.box<dynamic>(metadataBoxName);

  final FemaleSecurityGateScanService _gate = FemaleSecurityGateScanService.instance;

  Stream<List<SecurityGateScanRecord>> watchAcceptedScans({
    required String gateId,
    required DateTime date,
  }) =>
      _gate.getAcceptedScans(gateId: gateId, date: date);

  Stream<List<SecurityGateScanRecord>> watchRejectedScans({
    required String gateId,
    required DateTime date,
  }) =>
      _gate.getRejectedScans(gateId: gateId, date: date);

  Future<List<SecurityRejectionReason>> getActiveRejectionReasons() =>
      _gate.getActiveRejectionReasons();

  /// Cache-first profile lookup for repeated verification of the same id.
  Future<SecurityStudentProfile?> findStudentByUniversityId(
    String universityId,
  ) async {
    final norm = universityId.trim();
    if (norm.isEmpty) return null;
    final cacheKey = 'ext_stu_$norm';
    try {
      if (_box.isOpen) {
        final hit = _box.get(cacheKey);
        if (hit is Map) {
          final m = Map<String, dynamic>.from(
            hit.map((k, v) => MapEntry(k.toString(), v)),
          );
          final docId = (m.remove('_docId') ?? norm).toString();
          unawaited(_refreshStudentCache(norm, cacheKey));
          return SecurityStudentProfile.fromMap(m, docId);
        }
      }
    } catch (_) {}

    final profile = await _gate.findStudentByUniversityId(norm);
    if (profile != null) {
      await _putStudentProfile(cacheKey, profile, docIdForCache: norm);
    }
    return profile;
  }

  Future<void> _putStudentProfile(
    String cacheKey,
    SecurityStudentProfile p, {
    required String docIdForCache,
  }) async {
    try {
      if (!_box.isOpen) return;
      await _box.put(cacheKey, <String, dynamic>{
        '_docId': docIdForCache,
        'studentId': p.studentId,
        'name_ar': p.fullName,
        'email': p.email,
        'major': p.major,
        'college': p.college,
        'degree': p.degree,
        'nationality': p.nationality,
        'nationalIdOrIqama': p.nationalIdOrIqama,
        'photoUrl': p.photoUrl,
        'attendanceStatus': p.attendanceStatus,
        'studentAcademicStatus': p.studentAcademicStatus,
        'studentCardStatus': p.studentCardStatus,
      });
    } catch (_) {}
  }

  Future<void> _refreshStudentCache(String universityId, String cacheKey) async {
    try {
      final profile = await _gate.findStudentByUniversityId(universityId);
      if (profile != null) {
        await _putStudentProfile(cacheKey, profile, docIdForCache: universityId);
      }
    } catch (_) {}
  }
}
