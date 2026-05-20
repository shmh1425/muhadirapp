import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../services/auth/app_session_store.dart';
import '../services/lecturer_auth_service.dart';
import '../services/student_auth_service.dart';
import '../shared/profile/user_profile_image_url.dart';

/// Resolves profile photo URLs for offline display and persists the last valid
/// HTTP URL + disk cache key in [AppSessionStore].
class ProfilePhotoSessionService {
  ProfilePhotoSessionService._();
  static final ProfilePhotoSessionService instance =
      ProfilePhotoSessionService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CacheManager _cacheManager = DefaultCacheManager();

  /// Ensures Hive has a cache key after cold restore (no network).
  Future<void> hydrateCacheKeyFromSessionSnapshot() async {
    final cached = AppSessionStore.instance.readCachedProfilePhoto();
    if (cached != null && cached.imageCacheKey.trim().isNotEmpty) {
      return;
    }

    final snapshot = AppSessionStore.instance.read();
    if (snapshot == null) return;

    switch (snapshot.role) {
      case AppSessionRole.student:
        final student = snapshot.student;
        if (student == null) return;
        final photo = student.photoUrl.trim();
        if (!UserProfileImageUrl.isDirectHttpUrl(photo)) return;
        await AppSessionStore.instance.writeCachedProfilePhoto(
          resolvedHttpUrl: photo,
          photoVersion: student.photoVersion,
          imageCacheKey: UserProfileImageUrl.buildCacheUrl(
            photo,
            photoVersion: student.photoVersion,
          ),
        );
      case AppSessionRole.lecturer:
        final lecturer = snapshot.lecturer;
        final photo = (lecturer?.photoUrl ?? '').trim();
        if (!UserProfileImageUrl.isDirectHttpUrl(photo)) return;
        await AppSessionStore.instance.writeCachedProfilePhoto(
          resolvedHttpUrl: photo,
          imageCacheKey: photo,
        );
      case AppSessionRole.security:
        break;
      case AppSessionRole.admin:
        break;
    }
  }

  String? resolveStudentDisplayUrl({Map<String, dynamic>? firestoreData}) {
    final student = StudentAuthService.instance.currentStudent;
    return _resolveDisplayUrl(
      firestoreData: firestoreData,
      sessionRawUrl: student?.photoUrl,
      sessionPhotoVersion: student?.photoVersion,
    );
  }

  String? resolveLecturerDisplayUrl({Map<String, dynamic>? firestoreData}) {
    final lecturer = LecturerAuthService.instance.currentLecturer;
    final cached = AppSessionStore.instance.readCachedProfilePhoto();
    return _resolveDisplayUrl(
      firestoreData: firestoreData,
      sessionRawUrl: lecturer?.photoUrl ?? cached?.resolvedHttpUrl,
      sessionPhotoVersion: cached?.photoVersion,
    );
  }

  String? resolveSecurityDisplayUrl({Map<String, dynamic>? firestoreData}) {
    final cached = AppSessionStore.instance.readCachedProfilePhoto();
    return _resolveDisplayUrl(
      firestoreData: firestoreData,
      sessionRawUrl: cached?.resolvedHttpUrl,
      sessionPhotoVersion: cached?.photoVersion,
    );
  }

  String? _resolveDisplayUrl({
    Map<String, dynamic>? firestoreData,
    String? sessionRawUrl,
    String? sessionPhotoVersion,
  }) {
    final cached = AppSessionStore.instance.readCachedProfilePhoto();
    final cachedKey = cached?.imageCacheKey.trim() ?? '';

    var raw = UserProfileImageUrl.pickRawUrl(firestoreData);
    var version = UserProfileImageUrl.pickPhotoVersion(firestoreData);

    if (raw.isEmpty) {
      raw = (sessionRawUrl ?? '').trim();
      if (version.isEmpty) {
        version = (sessionPhotoVersion ?? '').trim();
      }
    }

    final cachedHttp = cached?.resolvedHttpUrl.trim() ?? '';
    final cachedVersion = cached?.photoVersion.trim() ?? '';

    String? builtFromLiveData() {
      if (UserProfileImageUrl.isDirectHttpUrl(raw)) {
        return UserProfileImageUrl.buildCacheUrl(
          raw,
          photoVersion: version.isNotEmpty ? version : cachedVersion,
        );
      }
      if (raw.isNotEmpty && UserProfileImageUrl.needsStorageResolution(raw)) {
        if (cachedHttp.isNotEmpty) {
          return UserProfileImageUrl.buildCacheUrl(
            cachedHttp,
            photoVersion: version.isNotEmpty ? version : cachedVersion,
          );
        }
        return null;
      }
      if (cachedHttp.isNotEmpty) {
        return UserProfileImageUrl.buildCacheUrl(
          cachedHttp,
          photoVersion: version.isNotEmpty ? version : cachedVersion,
        );
      }
      return null;
    }

    final liveKey = builtFromLiveData();
    if (liveKey != null &&
        liveKey.isNotEmpty &&
        version.isNotEmpty &&
        version != cachedVersion) {
      return liveKey;
    }

    if (cachedKey.isNotEmpty) {
      return cachedKey;
    }

    return liveKey;
  }

  Future<void> persistFromFirestoreMap(
    Map<String, dynamic> data, {
    required AppSessionRole role,
  }) async {
    final raw = UserProfileImageUrl.pickRawUrl(data);
    if (raw.isEmpty) return;
    final version = UserProfileImageUrl.pickPhotoVersion(data);
    await _persistResolved(role: role, raw: raw, photoVersion: version);
  }

  Future<void> persistExplicit({
    required AppSessionRole role,
    required String rawPhotoUrl,
    String? photoVersion,
  }) async {
    final raw = rawPhotoUrl.trim();
    if (raw.isEmpty) return;
    await _persistResolved(role: role, raw: raw, photoVersion: photoVersion);
  }

  Future<void> _persistResolved({
    required AppSessionRole role,
    required String raw,
    String? photoVersion,
  }) async {
    try {
      final httpUrl = await _toResolvedHttpUrl(raw);
      if (httpUrl == null || httpUrl.isEmpty) return;

      final version = (photoVersion ?? '').trim();
      final cacheKey = UserProfileImageUrl.buildCacheUrl(
        httpUrl,
        photoVersion: version,
      );

      try {
        await _cacheManager.downloadFile(cacheKey);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ProfilePhotoSession] disk prefetch failed: $e');
        }
      }

      await AppSessionStore.instance.writeCachedProfilePhoto(
        resolvedHttpUrl: httpUrl,
        photoVersion: version,
        imageCacheKey: cacheKey,
      );

      switch (role) {
        case AppSessionRole.student:
          await AppSessionStore.instance.mergeStudentPhotoFields(
            resolvedHttpUrl: httpUrl,
            photoVersion: version,
          );
        case AppSessionRole.lecturer:
          await AppSessionStore.instance.mergeLecturerPhotoFields(
            resolvedHttpUrl: httpUrl,
            photoVersion: version,
          );
        case AppSessionRole.security:
          await AppSessionStore.instance.mergeSecurityPhotoFields(
            resolvedHttpUrl: httpUrl,
            photoVersion: version,
          );
        case AppSessionRole.admin:
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProfilePhotoSession] persist failed: $e');
      }
    }
  }

  Future<String?> _toResolvedHttpUrl(String raw) async {
    final v = raw.trim();
    if (v.isEmpty) return null;
    if (UserProfileImageUrl.isDirectHttpUrl(v)) return v;

    if (v.startsWith('gs://')) {
      return _storage.refFromURL(v).getDownloadURL();
    }
    if (UserProfileImageUrl.needsStorageResolution(v)) {
      return _storage.ref().child(v).getDownloadURL();
    }
    return null;
  }
}
