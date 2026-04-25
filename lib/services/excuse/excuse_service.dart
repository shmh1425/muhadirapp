import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/excuse/excuse_request.dart';
import '../lecturer_auth_service.dart';

/// One lecturer decision to persist for a single excuse document.
class LecturerExcuseDecision {
  const LecturerExcuseDecision({
    required this.excuseRequestId,
    required this.studentId,
    required this.oldStatus,
    required this.newStatus,
    this.rejectionReason,
    this.attendanceRecordId,
    this.notificationSessionId,
    this.courseNameAr = '',
    this.sectionId = '',
  });

  final String excuseRequestId;
  final int studentId;
  final ExcuseRequestStatus oldStatus;
  final ExcuseRequestStatus newStatus;
  final String? rejectionReason;

  /// From `excuse_requests.attendanceRecordId` when present.
  final String? attendanceRecordId;

  /// Prefer request session id; falls back to attendance screen session in service.
  final String? notificationSessionId;

  /// For student notification copy (may be empty on legacy docs).
  final String courseNameAr;

  /// For student notification copy (may be empty on legacy docs).
  final String sectionId;
}

class ExcuseService {
  ExcuseService._();
  static final ExcuseService instance = ExcuseService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const bool enabled = true;

  static const String excusesCollection = 'excuse_requests';
  static const String _sectionsCollection = 'sections';
  static const String _lecturerNotificationsCollection = 'lecturer_notifications';
  static const String _studentNotificationsCollection = 'student_notifications';
  static const String _manualAttendanceRecordsCollection = 'manual_attendance_records';

  Stream<List<ExcuseRequest>> watchStudentRequests(int studentId) {
    if (!enabled || studentId <= 0) {
      return const Stream<List<ExcuseRequest>>.empty();
    }
    return _firestore
        .collection(excusesCollection)
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(ExcuseRequest.fromDoc).toList();
      list.sort((a, b) {
        final byDate = b.lectureDate.compareTo(a.lectureDate);
        if (byDate != 0) return byDate;
        return b.lectureStartTime.compareTo(a.lectureStartTime);
      });
      return list;
    });
  }

  /// Attendance record ids marked as an excuse submission pending review (student side).
  Stream<Set<String>> watchPendingExcuseAttendanceRecordIds(int studentId) {
    if (!enabled || studentId <= 0) {
      return const Stream<Set<String>>.empty();
    }
    return _firestore
        .collection(_studentNotificationsCollection)
        .where('studentId', isEqualTo: studentId)
        .where('isExcuseSubmission', isEqualTo: true)
        .where('excuseStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final ids = <String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final id = (data['attendanceRecordId'] ?? '').toString().trim();
        if (id.isNotEmpty) ids.add(id);
      }
      return ids;
    });
  }

  /// Lecturer: all excuse requests tied to a manual attendance session.
  Stream<List<ExcuseRequest>> watchSessionExcuseRequests(String sessionId) {
    final sid = sessionId.trim();
    if (sid.isEmpty) {
      return const Stream<List<ExcuseRequest>>.empty();
    }
    debugPrint('[ExcuseService] watchSessionExcuseRequests start: sessionId=$sid');
    return _firestore
        .collection(excusesCollection)
        .where('sessionId', isEqualTo: sid)
        .snapshots()
        .map((snap) {
      debugPrint(
        '[ExcuseService] watchSessionExcuseRequests success: sessionId=$sid docs=${snap.docs.length}',
      );
      final list = snap.docs.map(ExcuseRequest.fromDoc).toList();
      list.sort((a, b) {
        final sa = a.submittedAt ?? a.createdAt;
        final sb = b.submittedAt ?? b.createdAt;
        if (sa != null && sb != null) {
          final c = sb.compareTo(sa);
          if (c != 0) return c;
        }
        return a.studentId.compareTo(b.studentId);
      });
      return list;
    });
  }

  /// Same calendar day and [sectionId] as the attendance session (narrow query).
  Stream<List<ExcuseRequest>> _watchSectionDayExcuseRequests(
    String sectionId,
    DateTime sessionDay,
  ) {
    final sec = sectionId.trim();
    if (sec.isEmpty) {
      return const Stream<List<ExcuseRequest>>.empty();
    }
    final start = DateTime(sessionDay.year, sessionDay.month, sessionDay.day);
    final end = start.add(const Duration(days: 1));
    debugPrint(
      '[ExcuseService] watchSectionDayExcuseRequests start: '
      'sectionId=$sec start=$start end=$end',
    );
    return _firestore
        .collection(excusesCollection)
        .where('sectionId', isEqualTo: sec)
        .where('lectureDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('lectureDate', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) {
      debugPrint(
        '[ExcuseService] watchSectionDayExcuseRequests success: '
        'sectionId=$sec docs=${snap.docs.length}',
      );
      return snap.docs.map(ExcuseRequest.fromDoc).toList();
    });
  }

  static bool _mergeIncludesFromSectionDayQuery(
    ExcuseRequest e, {
    required String sessionId,
    required String lectureStartTime,
    required String lecturerId,
  }) {
    final docSid = e.sessionId?.trim() ?? '';
    if (docSid.isNotEmpty) {
      return docSid == sessionId;
    }
    final lid = e.lecturerId?.trim() ?? '';
    if (lecturerId.isNotEmpty &&
        lid.isNotEmpty &&
        lid != lecturerId) {
      return false;
    }
    final t = e.lectureStartTime.trim();
    final want = lectureStartTime.trim();
    if (t.isNotEmpty && want.isNotEmpty && t != want) {
      return false;
    }
    return true;
  }

  static List<ExcuseRequest> _sortLecturerExcuseList(List<ExcuseRequest> list) {
    list.sort((a, b) {
      final sa = a.submittedAt ?? a.createdAt;
      final sb = b.submittedAt ?? b.createdAt;
      if (sa != null && sb != null) {
        final c = sb.compareTo(sa);
        if (c != 0) return c;
      }
      return a.studentId.compareTo(b.studentId);
    });
    return list;
  }

  /// Session-scoped excuses plus same-day / same-section orphans (missing `sessionId`),
  /// filtered by current lecturer id when present on the document.
  Stream<List<ExcuseRequest>> watchExcuseRequestsForAttendanceSession({
    required String sessionId,
    required String? sectionId,
    required DateTime sessionDay,
    required String lectureStartTime,
  }) {
    final sid = sessionId.trim();
    if (sid.isEmpty) {
      return const Stream<List<ExcuseRequest>>.empty();
    }
    final sec = (sectionId ?? '').trim();
    final wantStart = lectureStartTime.trim();
    final currentLecturerId =
        (LecturerAuthService.instance.currentLecturer?.lecturerId ?? '').trim();
    debugPrint(
      '[ExcuseService] watchExcuseRequestsForAttendanceSession params: '
      'sessionId=$sid sectionId=$sec sessionDay=$sessionDay '
      'lectureStartTime=$wantStart lecturerId=$currentLecturerId',
    );

    return _ExcuseSessionMergeStream(
      service: this,
      sessionId: sid,
      sectionId: sec,
      sessionDay: sessionDay,
      lectureStartTime: wantStart,
      lecturerId: currentLecturerId,
    ).stream;
  }

  Future<void> submitRequest(ExcuseRequest request) async {
    if (!enabled) return;
    await _firestore
        .collection(excusesCollection)
        .doc(request.id)
        .set(request.toMap(), SetOptions(merge: true));
  }

  /// Returns true if the request was stored in `excuse_requests`.
  /// Returns false if rules blocked storing there (permission-denied), while still
  /// creating a lecturer notification + student pending marker.
  Future<bool> submitRequestAndNotifyLecturer({
    required ExcuseRequest request,
    required String studentDisplayName,
  }) async {
    if (!enabled) return false;

    final lecturerId = await _lookupLecturerIdForSection(request.sectionId);
    var storedInExcuseRequests = true;
    try {
      await submitRequest(request);
    } on FirebaseException catch (e) {
      // Some deployments still deny `create` on `excuse_requests` via rules.
      // Storage upload can succeed while Firestore write fails. In that case,
      // we still create a lecturer notification (rules allow it) so the request
      // is reflected in the lecturer UI without requiring lecturer-side changes.
      storedInExcuseRequests = false;
      if (e.code != 'permission-denied') rethrow;
    }

    if (lecturerId.isEmpty) return storedInExcuseRequests;

    final ref = _firestore.collection(_lecturerNotificationsCollection).doc();
    await ref.set({
      'notificationId': ref.id,
      'lecturerId': lecturerId,
      'sectionId': request.sectionId,
      'courseName': request.courseNameAr,
      'lectureStartTime': request.lectureStartTime,
      'lectureEndTime': request.lectureEndTime,
      'lectureDate': Timestamp.fromDate(
        DateTime(request.lectureDate.year, request.lectureDate.month, request.lectureDate.day),
      ),
      'category': 'students',
      'titleAr': 'طلب عذر من طالب',
      'titleEn': 'Student excuse request',
      'messageAr': 'تم رفع عذر لمادة "${request.courseNameAr}". يمكنك مراجعة الطلب واتخاذ إجراء.',
      'messageEn': 'A new excuse was submitted for "${request.courseNameAr}". You can review and take action.',
      'isRead': false,
      'isExcuseRequest': true,
      'excuseRequestId': request.id,
      // Helps debugging if Firestore rules block storing in `excuse_requests`.
      'storedInExcuseRequests': storedInExcuseRequests,
      // Include request payload for lecturer-side consumption if needed.
      'excuseRequestSnapshot': request.toMap(),
      'excuseDetails': {
        'studentName': studentDisplayName,
        'academicNumber': request.studentId.toString(),
        'submissionDate': '${request.lectureDate.year}-${request.lectureDate.month.toString().padLeft(2, '0')}-${request.lectureDate.day.toString().padLeft(2, '0')}',
        'submissionTime': request.lectureStartTime,
        'excuseText': request.reasonText ?? '',
        'attachmentName': request.attachmentName ?? '',
        'attachmentUrl': request.attachmentUrl ?? '',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Also add a student-side pending marker so the student UI can reflect
    // "قيد الانتظار" even if `excuse_requests` storage is blocked by rules.
    final studentRef = _firestore.collection(_studentNotificationsCollection).doc();
    await studentRef.set({
      'notificationId': studentRef.id,
      'studentId': request.studentId,
      'sectionId': request.sectionId,
      if (request.sessionId != null) 'sessionId': request.sessionId,
      if (request.attendanceRecordId != null) 'attendanceRecordId': request.attendanceRecordId,
      'category': 'excuses',
      'titleAr': 'تم رفع العذر',
      'titleEn': 'Excuse submitted',
      'messageAr': 'تم رفع العذر وهو الآن قيد المراجعة لدى الدكتور.',
      'messageEn': 'Your excuse was submitted and is pending lecturer review.',
      'isRead': false,
      'isExcuseSubmission': true,
      'excuseStatus': 'pending',
      'excuseRequestId': request.id,
      // Store the student's text for the pending-details UI.
      'excuseText': request.reasonText ?? '',
      // Client-side timestamp for reliable sorting even before serverTimestamp resolves.
      'clientCreatedAt': Timestamp.now(),
      'attachmentName': request.attachmentName ?? '',
      'attachmentUrl': request.attachmentUrl ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return storedInExcuseRequests;
  }

  Future<String> _lookupLecturerIdForSection(String sectionId) async {
    final id = sectionId.trim();
    if (id.isEmpty) return '';
    try {
      final snap = await _firestore.collection(_sectionsCollection).doc(id).get();
      if (!snap.exists) return '';
      final data = snap.data() ?? <String, dynamic>{};
      return (data['lecturerId'] ?? data['instructorId'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  /// Persists lecturer decisions on `excuse_requests`, optionally updates
  /// `manual_attendance_records` by explicit [attendanceRecordId], and syncs
  /// `student_notifications` when possible.
  Future<void> applyLecturerDecisions({
    required String sessionId,
    required List<LecturerExcuseDecision> decisions,
  }) async {
    final sid = sessionId.trim();
    if (sid.isEmpty || decisions.isEmpty) return;

    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId ?? '';
    for (final d in decisions) {
      final excuseRef =
          _firestore.collection(excusesCollection).doc(d.excuseRequestId);
      final newStatus = ExcuseRequest.statusToString(d.newStatus);
      final rejectionReason = (d.rejectionReason ?? '').trim();
      final attendanceRecordId = (d.attendanceRecordId ?? '').trim();
      try {
        await _firestore.runTransaction((tx) async {
          final excuseSnap = await tx.get(excuseRef);
          final excuseData = excuseSnap.data() ?? <String, dynamic>{};
          final oldStatus = (excuseData['status'] ?? ExcuseRequest.statusToString(d.oldStatus))
              .toString()
              .trim()
              .toLowerCase();

          final payload = <String, dynamic>{
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
            'reviewedBy': lecturerId,
            'reviewedAt': FieldValue.serverTimestamp(),
            'decisionHistory': FieldValue.arrayUnion([
              <String, dynamic>{
                'oldStatus': oldStatus,
                'newStatus': newStatus,
                'changedBy': lecturerId,
                'changedAt': Timestamp.now(),
                if (newStatus == 'rejected') 'rejectionReason': rejectionReason,
              }
            ]),
          };
          if (newStatus == 'rejected') {
            payload['rejectionReason'] = rejectionReason;
          } else {
            payload['rejectionReason'] = FieldValue.delete();
          }

          if (attendanceRecordId.isNotEmpty) {
            final attendanceRef = _firestore
                .collection(_manualAttendanceRecordsCollection)
                .doc(attendanceRecordId);
            final attendanceSnap = await tx.get(attendanceRef);
            if (attendanceSnap.exists) {
              final attendanceData = attendanceSnap.data() ?? <String, dynamic>{};
              final currentAttendanceStatus =
                  (attendanceData['status'] ?? '').toString().trim().toLowerCase();

              final shouldSetExcused = newStatus == 'accepted';
              final shouldRestoreFromExcused =
                  oldStatus == 'accepted' && newStatus == 'rejected';

              if (shouldSetExcused) {
                final previousStored = (excuseData['previousAttendanceStatus'] ?? '')
                    .toString()
                    .trim();
                if (previousStored.isEmpty && currentAttendanceStatus.isNotEmpty) {
                  payload['previousAttendanceStatus'] = currentAttendanceStatus;
                  final prevMethod =
                      (attendanceData['attendanceMethod'] ?? '').toString().trim();
                  if (prevMethod.isNotEmpty) {
                    payload['previousAttendanceMethod'] = prevMethod;
                  }
                }
                tx.set(
                  attendanceRef,
                  <String, dynamic>{
                    'status': 'excused',
                    'attendanceTime': '--',
                    'updatedAt': FieldValue.serverTimestamp(),
                    'updatedBy': lecturerId,
                    'attendanceMethod': 'manual',
                  },
                  SetOptions(merge: true),
                );
              } else if (shouldRestoreFromExcused) {
                var restoreStatus = (excuseData['previousAttendanceStatus'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
                if (restoreStatus.isEmpty) {
                  restoreStatus = 'absent';
                  debugPrint(
                    '[ExcuseService] previousAttendanceStatus missing for '
                    '${d.excuseRequestId}; restoring attendance to absent.',
                  );
                }
                tx.set(
                  attendanceRef,
                  <String, dynamic>{
                    'status': restoreStatus,
                    'attendanceTime': _attendanceTimeForStatusValue(restoreStatus),
                    'updatedAt': FieldValue.serverTimestamp(),
                    'updatedBy': lecturerId,
                    'attendanceMethod': 'manual',
                  },
                  SetOptions(merge: true),
                );
              }
            } else {
              debugPrint(
                '[ExcuseService] attendanceRecordId=$attendanceRecordId not found for '
                'excuse ${d.excuseRequestId}.',
              );
            }
          } else {
            debugPrint(
              '[ExcuseService] attendanceRecordId missing for excuse '
              '${d.excuseRequestId}; attendance update skipped.',
            );
          }

          tx.set(excuseRef, payload, SetOptions(merge: true));
        });
      } on FirebaseException catch (e, st) {
        debugPrint(
          '[ExcuseService] applyLecturerDecisions transaction failed for '
          '${d.excuseRequestId}: $e\n$st',
        );
        rethrow;
      } catch (e, st) {
        debugPrint(
          '[ExcuseService] applyLecturerDecisions transaction failed for '
          '${d.excuseRequestId}: $e\n$st',
        );
        rethrow;
      }
    }

    for (final d in decisions) {
      try {
        await _syncStudentNotificationAfterExcuseDecision(
          decision: d,
          sessionIdFallback: sid,
        );
      } on FirebaseException catch (e, st) {
        debugPrint(
          '[ExcuseService] student_notifications sync failed for '
          '${d.excuseRequestId}: $e\n$st',
        );
      }
    }
  }

  static String _attendanceTimeForStatusValue(String status) {
    switch (status.trim().toLowerCase()) {
      case 'present':
      case 'late':
        return '';
      case 'absent':
      case 'excused':
      default:
        return '--';
    }
  }

  static int _studentIdFromFirestore(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  Future<void> _syncStudentNotificationAfterExcuseDecision({
    required LecturerExcuseDecision decision,
    required String sessionIdFallback,
  }) async {
    if (decision.studentId <= 0) {
      debugPrint(
        '[ExcuseService] skip student_notifications: invalid studentId for '
        'excuse ${decision.excuseRequestId}',
      );
      return;
    }

    final courseLabel = decision.courseNameAr.trim().isEmpty
        ? 'المادة'
        : decision.courseNameAr.trim();
    final accepted = decision.newStatus == ExcuseRequestStatus.accepted;
    final excuseStatus = ExcuseRequest.statusToString(decision.newStatus);
    final titleAr = accepted ? 'تم قبول عذرك' : 'تم رفض عذرك';
    final titleEn = accepted ? 'Your excuse was accepted' : 'Your excuse was rejected';
    final reason = (decision.rejectionReason ?? '').trim();
    final messageAr = accepted
        ? 'قبل الأستاذ عذرك لمادة "$courseLabel".'
        : 'رفض الأستاذ عذرك لمادة "$courseLabel".${reason.isEmpty ? '' : ' السبب: $reason'}';
    final messageEn = accepted
        ? 'Your excuse for "$courseLabel" was accepted by the instructor.'
        : 'Your excuse for "$courseLabel" was rejected by the instructor.'
            '${reason.isEmpty ? '' : ' Reason: $reason'}';

    final sessionForDoc =
        (decision.notificationSessionId ?? '').trim().isNotEmpty
            ? decision.notificationSessionId!.trim()
            : sessionIdFallback;
    final attId = (decision.attendanceRecordId ?? '').trim();

    final snap = await _firestore
        .collection(_studentNotificationsCollection)
        .where('excuseRequestId', isEqualTo: decision.excuseRequestId)
        .limit(40)
        .get();

    final targets = snap.docs.where((doc) {
      final data = doc.data();
      if (data['isExcuseSubmission'] != true) return false;
      return _studentIdFromFirestore(data['studentId']) == decision.studentId;
    }).toList();

    final patch = <String, dynamic>{
      'excuseStatus': excuseStatus,
      'titleAr': titleAr,
      'titleEn': titleEn,
      'messageAr': messageAr,
      'messageEn': messageEn,
      'isRead': false,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!accepted) 'rejectionReason': reason,
      if (accepted) 'rejectionReason': FieldValue.delete(),
    };

    if (targets.isNotEmpty) {
      final batch = _firestore.batch();
      for (final t in targets) {
        batch.update(t.reference, patch);
      }
      await batch.commit();
      return;
    }

    final ref = _firestore.collection(_studentNotificationsCollection).doc();
    await ref.set(<String, dynamic>{
      'notificationId': ref.id,
      'studentId': decision.studentId,
      'sectionId': decision.sectionId.trim(),
      if (sessionForDoc.isNotEmpty) 'sessionId': sessionForDoc,
      if (attId.isNotEmpty) 'attendanceRecordId': attId,
      'category': 'excuses',
      'titleAr': titleAr,
      'titleEn': titleEn,
      'messageAr': messageAr,
      'messageEn': messageEn,
      'isRead': false,
      'isExcuseSubmission': true,
      'excuseStatus': excuseStatus,
      'excuseRequestId': decision.excuseRequestId,
      if (!accepted) 'rejectionReason': reason,
      'clientCreatedAt': Timestamp.now(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Merges `sessionId` excuse stream with a narrow same-day `sectionId` query so
/// legacy documents missing `sessionId` can still appear for the lecturer.
class _ExcuseSessionMergeStream {
  _ExcuseSessionMergeStream({
    required this.service,
    required this.sessionId,
    required this.sectionId,
    required this.sessionDay,
    required this.lectureStartTime,
    required this.lecturerId,
  }) {
    _controller = StreamController<List<ExcuseRequest>>(
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  final ExcuseService service;
  final String sessionId;
  final String sectionId;
  final DateTime sessionDay;
  final String lectureStartTime;
  final String lecturerId;

  late final StreamController<List<ExcuseRequest>> _controller;

  List<ExcuseRequest> _listA = const [];
  List<ExcuseRequest> _listB = const [];
  StreamSubscription<List<ExcuseRequest>>? _subA;
  StreamSubscription<List<ExcuseRequest>>? _subB;

  Stream<List<ExcuseRequest>> get stream => _controller.stream;

  void _onListen() {
    debugPrint(
      '[ExcuseService] merge stream listen start: '
      'sessionId=$sessionId sectionId=$sectionId sessionDay=$sessionDay '
      'lectureStartTime=$lectureStartTime lecturerId=$lecturerId',
    );
    _subA = service.watchSessionExcuseRequests(sessionId).listen(
      (list) {
        _listA = list;
        debugPrint(
          '[ExcuseService] merge stream primary(sessionId) update: '
          'count=${_listA.length}',
        );
        _emit();
      },
      onError: (Object e, StackTrace st) {
        debugPrint(
          '[ExcuseService] primary sessionId stream failed: $e\n$st',
        );
        _controller.addError(e, st);
      },
    );
    if (sectionId.isNotEmpty) {
      _subB = service._watchSectionDayExcuseRequests(sectionId, sessionDay).listen(
        (list) {
          _listB = list;
          debugPrint(
            '[ExcuseService] merge stream fallback(section/day) update: '
            'count=${_listB.length}',
          );
          _emit();
        },
        onError: (Object e, StackTrace st) {
          // Keep base session stream alive even if the supplemental query fails
          // (e.g. transient permissions/index mismatch).
          debugPrint(
            '[ExcuseService] supplemental section/day excuse stream failed: $e\n$st',
          );
          _listB = const [];
          _emit();
        },
      );
    } else {
      _listB = const [];
    }
  }

  void _onCancel() {
    _subA?.cancel();
    _subB?.cancel();
  }

  void _emit() {
    final byId = <String, ExcuseRequest>{};
    for (final e in _listA) {
      byId[e.id] = e;
    }
    for (final e in _listB) {
      if (!ExcuseService._mergeIncludesFromSectionDayQuery(
        e,
        sessionId: sessionId,
        lectureStartTime: lectureStartTime,
        lecturerId: lecturerId,
      )) {
        continue;
      }
      byId.putIfAbsent(e.id, () => e);
    }
    final merged = ExcuseService._sortLecturerExcuseList(byId.values.toList());
    debugPrint(
      '[ExcuseService] merge stream emit: primary=${_listA.length} '
      'fallback=${_listB.length} merged=${merged.length}',
    );
    _controller.add(merged);
  }
}
