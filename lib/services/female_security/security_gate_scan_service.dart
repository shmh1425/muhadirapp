import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../screens/female_security/models/student_card_info.dart';

class SecurityGateOption {
  const SecurityGateOption({
    required this.gateId,
    required this.gateNumber,
    required this.campusId,
    required this.campusName,
    required this.labelAr,
  });

  final String gateId;
  final int gateNumber;
  final String campusId;
  final String campusName;
  final String labelAr;

  factory SecurityGateOption.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return SecurityGateOption(
      gateId: (data['gateId'] ?? doc.id).toString(),
      gateNumber: _safeInt(data['gateNumber']) ?? _extractGateNumber(doc.id),
      campusId: (data['campusId'] ?? 'zaher').toString(),
      campusName: (data['campusName'] ?? 'الزاهر').toString(),
      labelAr:
          (data['gateLabelAr'] ??
                  'بوابة ${_extractGateNumber(doc.id)} - الزاهر')
              .toString(),
    );
  }

  factory SecurityGateOption.fallback(String gateId) {
    final gateNumber = _extractGateNumber(gateId);
    return SecurityGateOption(
      gateId: gateId,
      gateNumber: gateNumber,
      campusId: 'zaher',
      campusName: 'الزاهر',
      labelAr: 'بوابة $gateNumber - الزاهر',
    );
  }
}

class SecurityRejectionReason {
  const SecurityRejectionReason({
    required this.reasonId,
    required this.titleAr,
    this.titleEn = '',
    this.code = '',
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String reasonId;
  final String titleAr;
  final String titleEn;
  final String code;
  final bool isActive;
  final int sortOrder;

  factory SecurityRejectionReason.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return SecurityRejectionReason(
      reasonId: (data['reasonId'] ?? doc.id).toString(),
      titleAr: (data['titleAr'] ?? '').toString(),
      titleEn: (data['titleEn'] ?? '').toString(),
      code: (data['code'] ?? '').toString(),
      isActive: data['isActive'] != false,
      sortOrder: _safeInt(data['sortOrder']) ?? 0,
    );
  }
}

class SecurityStudentProfile {
  const SecurityStudentProfile({
    required this.studentId,
    required this.universityId,
    required this.fullName,
    required this.email,
    required this.major,
    this.college = '',
    this.degree = 'بكالوريوس',
    this.nationality = 'غير محدد',
    this.nationalIdOrIqama = '',
    this.photoUrl,
    this.attendanceStatus = 'منتظم',
    this.studentAcademicStatus = 'active',
    this.studentCardStatus = 'active',
    this.cardExpiryDate,
  });

  final int studentId;
  final String universityId;
  final String fullName;
  final String email;
  final String major;
  final String college;
  final String degree;
  final String nationality;
  final String nationalIdOrIqama;
  final String? photoUrl;
  final String attendanceStatus;
  final String studentAcademicStatus;
  final String studentCardStatus;
  final Timestamp? cardExpiryDate;

  factory SecurityStudentProfile.fromMap(
    Map<String, dynamic> data,
    String docId,
  ) {
    final studentId = _safeInt(data['studentId']) ?? _safeInt(docId) ?? 0;
    return SecurityStudentProfile(
      studentId: studentId,
      universityId: studentId > 0 ? '$studentId' : docId,
      fullName: (data['name_ar'] ?? data['name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      major: (data['major'] ?? '').toString(),
      college: (data['college'] ?? data['collegeName'] ?? '').toString(),
      degree: (data['degree'] ?? data['degreeName'] ?? 'بكالوريوس').toString(),
      nationality: (data['nationality'] ?? 'غير محدد').toString(),
      nationalIdOrIqama:
          (data['nationalIdOrIqama'] ??
                  data['nationalId'] ??
                  data['idNumber'] ??
                  '')
              .toString(),
      photoUrl: (data['photoUrl'] ?? data['photoURL'])?.toString(),
      attendanceStatus: (data['attendanceStatus'] ?? 'منتظم').toString(),
      studentAcademicStatus: (data['studentAcademicStatus'] ?? 'active')
          .toString(),
      studentCardStatus: (data['studentCardStatus'] ?? 'active').toString(),
      cardExpiryDate: data['cardExpiryDate'] as Timestamp?,
    );
  }
}

class SecurityGateScanRecord {
  const SecurityGateScanRecord({
    required this.scanId,
    required this.studentId,
    required this.universityId,
    required this.studentName,
    required this.major,
    required this.scanTime,
    required this.status,
    required this.gateId,
    required this.gateNumber,
    this.college = '',
    this.degree = 'بكالوريوس',
    this.nationality = 'غير محدد',
    this.nationalIdOrIqama = '',
    this.photoUrl,
    this.rejectionReasonId = '',
    this.rejectionReasonText = '',
    this.attendanceStatus = 'منتظم',
    this.dayLabelAr = '',
    this.campusId = 'zaher',
    this.campusName = 'الزاهر',
  });

  final String scanId;
  final int studentId;
  final String universityId;
  final String studentName;
  final String major;
  final String college;
  final String degree;
  final String nationality;
  final String nationalIdOrIqama;
  final String? photoUrl;
  final Timestamp? scanTime;
  final String status;
  final String gateId;
  final int gateNumber;
  final String campusId;
  final String campusName;
  final String rejectionReasonId;
  final String rejectionReasonText;
  final String attendanceStatus;
  final String dayLabelAr;

  factory SecurityGateScanRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return SecurityGateScanRecord(
      scanId: (data['scanId'] ?? doc.id).toString(),
      studentId: _safeInt(data['studentId']) ?? 0,
      universityId: (data['universityId'] ?? data['studentId'] ?? '')
          .toString(),
      studentName: (data['studentName'] ?? '').toString(),
      major: (data['major'] ?? '').toString(),
      college: (data['college'] ?? '').toString(),
      degree: (data['degree'] ?? 'بكالوريوس').toString(),
      nationality: (data['nationality'] ?? 'غير محدد').toString(),
      nationalIdOrIqama: (data['nationalIdOrIqama'] ?? '').toString(),
      photoUrl: (data['photoUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (data['photoUrl']).toString(),
      scanTime: data['scanTime'] as Timestamp?,
      status: (data['status'] ?? '').toString(),
      gateId: (data['gateId'] ?? 'gate_3').toString(),
      gateNumber: _safeInt(data['gateNumber']) ?? 3,
      campusId: (data['campusId'] ?? 'zaher').toString(),
      campusName: (data['campusName'] ?? 'الزاهر').toString(),
      rejectionReasonId: (data['rejectionReasonId'] ?? '').toString(),
      rejectionReasonText: (data['rejectionReasonText'] ?? '').toString(),
      attendanceStatus: (data['attendanceStatus'] ?? 'منتظم').toString(),
      dayLabelAr: (data['dayLabelAr'] ?? '').toString(),
    );
  }

  String get formattedTime {
    final value = scanTime?.toDate();
    if (value == null) return '--:--';
    return _formatTime(value);
  }

  StudentCardInfo toStudentCardInfo() {
    final value = scanTime?.toDate();
    final effectiveDate = value ?? DateTime.now();
    final day = dayLabelAr.isNotEmpty
        ? dayLabelAr
        : _arabicDayName(effectiveDate);
    return StudentCardInfo(
      fullName: studentName,
      universityId: universityId,
      entryTime: formattedTime,
      dayLabel: 'اليوم: $day',
      dateLabel: 'التاريخ: ${_formatDate(effectiveDate)}',
      attendanceStatus: attendanceStatus,
      college: college.isNotEmpty ? college : 'غير محدد',
      major: major.isNotEmpty ? major : 'غير محدد',
      degree: degree,
      nationality: nationality,
      extraId: nationalIdOrIqama.isNotEmpty ? nationalIdOrIqama : universityId,
      gateLabel: 'بوابة $gateNumber - $campusName',
      photoUrl: photoUrl,
    );
  }
}

class SecurityVerificationDecision {
  const SecurityVerificationDecision._({
    required this.isApproved,
    this.rejectionReason,
  });

  const SecurityVerificationDecision.approved() : this._(isApproved: true);

  const SecurityVerificationDecision.rejected(
    SecurityRejectionReason rejectionReason,
  ) : this._(isApproved: false, rejectionReason: rejectionReason);

  final bool isApproved;
  final SecurityRejectionReason? rejectionReason;
}

class FemaleSecurityGateScanService {
  FemaleSecurityGateScanService._();
  static final FemaleSecurityGateScanService instance =
      FemaleSecurityGateScanService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<SecurityGateScanRecord>> watchScans({
    required String gateId,
    required DateTime date,
    required String status,
  }) {
    return _firestore
        .collection('student_gate_scans')
        .where('gateId', isEqualTo: gateId)
        .where('scanDateKey', isEqualTo: formatScanDateKey(date))
        .where('status', isEqualTo: status)
        .orderBy('scanTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SecurityGateScanRecord.fromDoc)
              .toList(growable: false),
        );
  }

  Future<SecurityStudentProfile?> findStudentByUniversityId(
    String universityId,
  ) async {
    final normalized = universityId.trim();
    if (normalized.isEmpty) return null;

    final directDoc = await _firestore
        .collection('external_students')
        .doc(normalized)
        .get();
    if (directDoc.exists) {
      return SecurityStudentProfile.fromMap(
        directDoc.data() ?? <String, dynamic>{},
        directDoc.id,
      );
    }

    final parsedId = _safeInt(normalized);
    if (parsedId != null) {
      final snapshot = await _firestore
          .collection('external_students')
          .where('studentId', isEqualTo: parsedId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return SecurityStudentProfile.fromMap(doc.data(), doc.id);
      }
    }

    return null;
  }

  Future<List<SecurityRejectionReason>> getActiveRejectionReasons() async {
    final snapshot = await _firestore
        .collection('security_rejection_reasons')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .get();

    final reasons = snapshot.docs
        .map(SecurityRejectionReason.fromDoc)
        .toList(growable: false);
    if (reasons.isNotEmpty) return reasons;

    return const [
      SecurityRejectionReason(reasonId: 'graduated', titleAr: 'الطالبة متخرجة'),
      SecurityRejectionReason(
        reasonId: 'card_expired',
        titleAr: 'البطاقة منتهية الصلاحية',
      ),
      SecurityRejectionReason(
        reasonId: 'not_registered_in_system',
        titleAr: 'غير مسجلة في النظام',
      ),
      SecurityRejectionReason(
        reasonId: 'invalid_card',
        titleAr: 'البطاقة غير صالحة',
      ),
    ];
  }

  Future<List<SecurityGateOption>> loadAssignedGatesForCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return [SecurityGateOption.fallback('gate_3')];
    }

    final staffDoc = await _firestore
        .collection('security_staff')
        .doc(uid)
        .get();
    final data = staffDoc.data() ?? <String, dynamic>{};
    final defaultGateId = (data['defaultGateId'] ?? 'gate_3').toString();
    final assignedGateIds =
        ((data['assignedGateIds'] as List?) ?? [defaultGateId])
            .map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false);

    final gates = await Future.wait(
      assignedGateIds.map((gateId) async {
        final doc = await _firestore
            .collection('campus_gates')
            .doc(gateId)
            .get();
        if (doc.exists) {
          return SecurityGateOption.fromDoc(doc);
        }
        return SecurityGateOption.fallback(gateId);
      }),
    );

    gates.sort((a, b) => a.gateNumber.compareTo(b.gateNumber));
    return gates;
  }

  Future<String> loadDefaultGateIdForCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'gate_3';

    final staffDoc = await _firestore
        .collection('security_staff')
        .doc(uid)
        .get();
    return (staffDoc.data()?['defaultGateId'] ?? 'gate_3').toString();
  }

  Future<void> updateDefaultGateForCurrentUser(String gateId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('security_staff').doc(uid).set({
      'defaultGateId': gateId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> recordGateScanDecision({
    required SecurityStudentProfile student,
    required SecurityGateOption gate,
    required SecurityVerificationDecision decision,
  }) async {
    final uid = _auth.currentUser?.uid;
    final email = _auth.currentUser?.email ?? '';
    final staffDoc = uid == null
        ? null
        : await _firestore.collection('security_staff').doc(uid).get();
    final staffData = staffDoc?.data() ?? <String, dynamic>{};
    final staffName = (staffData['fullName'] ?? email).toString();
    final now = DateTime.now();
    final scanRef = _firestore.collection('student_gate_scans').doc();

    final rejectionReason = decision.rejectionReason;
    await scanRef.set({
      'scanId': scanRef.id,
      'studentId': student.studentId,
      'universityId': student.universityId,
      'studentName': student.fullName,
      'major': student.major,
      'college': student.college,
      'degree': student.degree,
      'nationality': student.nationality,
      'nationalIdOrIqama': student.nationalIdOrIqama,
      'photoUrl': student.photoUrl ?? '',
      'gateId': gate.gateId,
      'gateNumber': gate.gateNumber,
      'campusId': gate.campusId,
      'campusName': gate.campusName,
      'scanSource': 'security_manual_review',
      'scanTime': Timestamp.fromDate(now),
      'scanDateKey': formatScanDateKey(now),
      'dayLabelAr': _arabicDayName(now),
      'status': decision.isApproved ? 'accepted' : 'rejected',
      'decisionStatus': decision.isApproved ? 'approved' : 'rejected',
      'attendanceStatus': student.attendanceStatus,
      'rejectionReasonId': rejectionReason?.reasonId ?? '',
      'rejectionReasonText': rejectionReason?.titleAr ?? '',
      'decisionByUid': uid ?? '',
      'decisionByName': staffName,
      'decisionAt': FieldValue.serverTimestamp(),
      'notes': '',
      'studentAcademicStatus': student.studentAcademicStatus,
      'studentCardStatus': student.studentCardStatus,
      'cardExpiryDate': student.cardExpiryDate,
      'requiresManualReview': false,
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

String formatScanDateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

String _formatTime(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  final s = date.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _arabicDayName(DateTime date) {
  const days = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];
  return days[date.weekday % 7];
}

int _extractGateNumber(String gateId) {
  final match = RegExp(r'(\d+)').firstMatch(gateId);
  return int.tryParse(match?.group(1) ?? '') ?? 3;
}

int? _safeInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
