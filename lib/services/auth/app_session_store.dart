import 'package:hive_flutter/hive_flutter.dart';

import '../../models/external_lecturer_model.dart';
import '../../models/external_student.dart';
import '../../shared/profile/user_profile_image_url.dart';

/// Persisted app role + profile snapshot for offline session restore.
enum AppSessionRole { student, lecturer, security, admin }

/// Last resolved HTTP profile photo (disk cache key + offline display).
class CachedProfilePhoto {
  const CachedProfilePhoto({
    required this.resolvedHttpUrl,
    this.photoVersion = '',
    this.imageCacheKey = '',
  });

  /// Firebase HTTP download URL (no cache-bust query).
  final String resolvedHttpUrl;
  final String photoVersion;

  /// Exact key passed to [DefaultCacheManager] / [CachedNetworkImage].
  final String imageCacheKey;
}

class AppSessionSnapshot {
  const AppSessionSnapshot({
    required this.role,
    required this.email,
    this.student,
    this.studentDocId,
    this.lecturer,
    this.lecturerProfileName,
    this.lecturerProfileCollege,
    this.lecturerProfileDepartment,
    this.cachedProfilePhoto,
  });

  final AppSessionRole role;
  final String email;
  final ExternalStudent? student;
  final String? studentDocId;
  final ExternalLecturerModel? lecturer;
  final String? lecturerProfileName;
  final String? lecturerProfileCollege;
  final String? lecturerProfileDepartment;
  final CachedProfilePhoto? cachedProfilePhoto;
}

class AppSessionStore {
  AppSessionStore._();
  static final AppSessionStore instance = AppSessionStore._();

  static const boxName = 'app_session';
  static const _roleKey = 'role';
  static const _emailKey = 'email';
  static const _studentKey = 'student';
  static const _studentDocIdKey = 'studentDocId';
  static const _lecturerKey = 'lecturer';
  static const _lecturerProfileNameKey = 'lecturerProfileName';
  static const _lecturerProfileCollegeKey = 'lecturerProfileCollege';
  static const _lecturerProfileDepartmentKey = 'lecturerProfileDepartment';
  static const _cachedProfilePhotoUrlKey = 'cachedProfilePhotoUrl';
  static const _cachedProfilePhotoVersionKey = 'cachedProfilePhotoVersion';
  static const _cachedProfilePhotoCacheKeyKey = 'cachedProfilePhotoCacheKey';

  Box<dynamic> get _box => Hive.box<dynamic>(boxName);

  CachedProfilePhoto? readCachedProfilePhoto() {
    final url = (_box.get(_cachedProfilePhotoUrlKey) ?? '').toString().trim();
    if (url.isEmpty) return null;
    final cacheKey =
        (_box.get(_cachedProfilePhotoCacheKeyKey) ?? '').toString().trim();
    return CachedProfilePhoto(
      resolvedHttpUrl: url,
      photoVersion:
          (_box.get(_cachedProfilePhotoVersionKey) ?? '').toString().trim(),
      imageCacheKey: cacheKey.isNotEmpty ? cacheKey : url,
    );
  }

  Future<void> writeCachedProfilePhoto({
    required String resolvedHttpUrl,
    String? photoVersion,
    String? imageCacheKey,
  }) async {
    final url = resolvedHttpUrl.trim();
    if (url.isEmpty) return;
    final version = (photoVersion ?? '').trim();
    final key = (imageCacheKey ?? '').trim().isNotEmpty
        ? imageCacheKey!.trim()
        : url;
    await _box.put(_cachedProfilePhotoUrlKey, url);
    await _box.put(_cachedProfilePhotoVersionKey, version);
    await _box.put(_cachedProfilePhotoCacheKeyKey, key);
  }

  Future<void> mergeStudentPhotoFields({
    required String resolvedHttpUrl,
    String? photoVersion,
  }) async {
    final studentRaw = _box.get(_studentKey);
    if (studentRaw is! Map) return;
    final map = Map<String, dynamic>.from(studentRaw);
    map['photoUrl'] = resolvedHttpUrl.trim();
    map['photoVersion'] = (photoVersion ?? '').trim();
    await _box.put(_studentKey, map);
  }

  Future<void> mergeLecturerPhotoFields({
    required String resolvedHttpUrl,
    String? photoVersion,
  }) async {
    final lecturerRaw = _box.get(_lecturerKey);
    if (lecturerRaw is! Map) return;
    final map = Map<String, dynamic>.from(lecturerRaw);
    map['photoUrl'] = resolvedHttpUrl.trim();
    map['photoVersion'] = (photoVersion ?? '').trim();
    await _box.put(_lecturerKey, map);
  }

  Future<void> mergeSecurityPhotoFields({
    required String resolvedHttpUrl,
    String? photoVersion,
  }) async {
    final version = (photoVersion ?? '').trim();
    await writeCachedProfilePhoto(
      resolvedHttpUrl: resolvedHttpUrl,
      photoVersion: version,
      imageCacheKey: UserProfileImageUrl.buildCacheUrl(
        resolvedHttpUrl,
        photoVersion: version,
      ),
    );
  }

  Future<void> saveStudent({
    required String email,
    required ExternalStudent student,
    String? studentDocId,
  }) async {
    await _box.putAll({
      _roleKey: AppSessionRole.student.name,
      _emailKey: email.trim().toLowerCase(),
      _studentKey: student.toMap(),
      _studentDocIdKey: studentDocId,
      _lecturerKey: null,
      _lecturerProfileNameKey: null,
      _lecturerProfileCollegeKey: null,
      _lecturerProfileDepartmentKey: null,
    });
    final photo = student.photoUrl.trim();
    if (UserProfileImageUrl.isDirectHttpUrl(photo)) {
      await writeCachedProfilePhoto(
        resolvedHttpUrl: photo,
        photoVersion: student.photoVersion,
        imageCacheKey: UserProfileImageUrl.buildCacheUrl(
          photo,
          photoVersion: student.photoVersion,
        ),
      );
    }
  }

  Future<void> saveLecturer({
    required String email,
    required ExternalLecturerModel lecturer,
    required String profileName,
    required String profileCollege,
    required String profileDepartment,
  }) async {
    await _box.putAll({
      _roleKey: AppSessionRole.lecturer.name,
      _emailKey: email.trim().toLowerCase(),
      _studentKey: null,
      _studentDocIdKey: null,
      _lecturerKey: _lecturerToPersistedMap(lecturer),
      _lecturerProfileNameKey: profileName,
      _lecturerProfileCollegeKey: profileCollege,
      _lecturerProfileDepartmentKey: profileDepartment,
    });
    final photo = (lecturer.photoUrl ?? '').trim();
    if (UserProfileImageUrl.isDirectHttpUrl(photo)) {
      await writeCachedProfilePhoto(
        resolvedHttpUrl: photo,
        imageCacheKey: photo,
      );
    }
  }

  Future<void> saveSecurity({
    required String email,
    String? photoUrl,
    String? photoVersion,
  }) async {
    final resolved = (photoUrl ?? '').trim();
    final version = (photoVersion ?? '').trim();
    await _box.putAll({
      _roleKey: AppSessionRole.security.name,
      _emailKey: email.trim().toLowerCase(),
      _studentKey: null,
      _studentDocIdKey: null,
      _lecturerKey: null,
      _lecturerProfileNameKey: null,
      _lecturerProfileCollegeKey: null,
      _lecturerProfileDepartmentKey: null,
    });
    if (UserProfileImageUrl.isDirectHttpUrl(resolved)) {
      await writeCachedProfilePhoto(
        resolvedHttpUrl: resolved,
        photoVersion: version,
        imageCacheKey: UserProfileImageUrl.buildCacheUrl(
          resolved,
          photoVersion: version,
        ),
      );
    }
  }

  Future<void> saveAdmin({required String email}) async {
    await _box.putAll({
      _roleKey: AppSessionRole.admin.name,
      _emailKey: email.trim().toLowerCase(),
      _studentKey: null,
      _studentDocIdKey: null,
      _lecturerKey: null,
      _lecturerProfileNameKey: null,
      _lecturerProfileCollegeKey: null,
      _lecturerProfileDepartmentKey: null,
    });
  }

  Future<void> clear() async {
    await _box.delete(_roleKey);
    await _box.delete(_emailKey);
    await _box.delete(_studentKey);
    await _box.delete(_studentDocIdKey);
    await _box.delete(_lecturerKey);
    await _box.delete(_lecturerProfileNameKey);
    await _box.delete(_lecturerProfileCollegeKey);
    await _box.delete(_lecturerProfileDepartmentKey);
    await _box.delete(_cachedProfilePhotoUrlKey);
    await _box.delete(_cachedProfilePhotoVersionKey);
    await _box.delete(_cachedProfilePhotoCacheKeyKey);
  }

  AppSessionSnapshot? read() {
    final roleRaw = (_box.get(_roleKey) ?? '').toString().trim();
    final email = (_box.get(_emailKey) ?? '').toString().trim().toLowerCase();
    if (roleRaw.isEmpty || email.isEmpty) return null;

    AppSessionRole? role;
    for (final candidate in AppSessionRole.values) {
      if (candidate.name == roleRaw) {
        role = candidate;
        break;
      }
    }
    if (role == null) return null;

    ExternalStudent? student;
    final studentRaw = _box.get(_studentKey);
    if (studentRaw is Map) {
      student = ExternalStudent.fromMap(
        Map<String, dynamic>.from(studentRaw),
      );
    }

    ExternalLecturerModel? lecturer;
    final lecturerRaw = _box.get(_lecturerKey);
    if (lecturerRaw is Map) {
      lecturer = ExternalLecturerModel.fromMap(
        Map<String, dynamic>.from(lecturerRaw),
      );
    }

    return AppSessionSnapshot(
      role: role,
      email: email,
      student: student,
      studentDocId: (_box.get(_studentDocIdKey) ?? '').toString().trim().isEmpty
          ? null
          : (_box.get(_studentDocIdKey) ?? '').toString(),
      lecturer: lecturer,
      cachedProfilePhoto: readCachedProfilePhoto(),
      lecturerProfileName: (_box.get(_lecturerProfileNameKey) ?? '')
          .toString()
          .trim()
          .isEmpty
          ? null
          : (_box.get(_lecturerProfileNameKey) ?? '').toString(),
      lecturerProfileCollege: (_box.get(_lecturerProfileCollegeKey) ?? '')
          .toString(),
      lecturerProfileDepartment:
          (_box.get(_lecturerProfileDepartmentKey) ?? '').toString(),
    );
  }

  static Map<String, dynamic> _lecturerToPersistedMap(
    ExternalLecturerModel lecturer,
  ) {
    return {
      'lecturerId': lecturer.lecturerId,
      'nameAr': lecturer.nameAr,
      'nameEn': lecturer.nameEn,
      'email': lecturer.email,
      'college': lecturer.college,
      'department': lecturer.department,
      'source': lecturer.source,
      'sourceId': lecturer.sourceId,
      'lecturerCardId': lecturer.lecturerCardId,
      'photoUrl': lecturer.photoUrl,
      'role': lecturer.role,
      'linkedUserUid': lecturer.linkedUserUid,
      'isImported': lecturer.isImported,
      'isActive': lecturer.isActive,
    };
  }
}
