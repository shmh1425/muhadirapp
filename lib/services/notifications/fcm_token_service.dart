import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmTokenMetadata {
  const FcmTokenMetadata({this.role, this.studentId, this.lecturerId});

  final String? role;
  final int? studentId;
  final String? lecturerId;

  Map<String, dynamic> toFirestoreFields() {
    final fields = <String, dynamic>{};
    final normalizedRole = role?.trim();
    if (normalizedRole != null && normalizedRole.isNotEmpty) {
      fields['role'] = normalizedRole;
    }
    if (studentId != null && studentId! > 0) {
      fields['studentId'] = studentId;
    }
    final normalizedLecturerId = lecturerId?.trim();
    if (normalizedLecturerId != null && normalizedLecturerId.isNotEmpty) {
      fields['lecturerId'] = normalizedLecturerId;
    }
    return fields;
  }
}

class FcmTokenService {
  FcmTokenService._();
  static final FcmTokenService instance = FcmTokenService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSub;
  FcmTokenMetadata _lastMetadata = const FcmTokenMetadata();

  Future<void> registerDeviceToken({
    String? role,
    int? studentId,
    String? lecturerId,
  }) async {
    final metadata = FcmTokenMetadata(
      role: role,
      studentId: studentId,
      lecturerId: lecturerId,
    );
    _lastMetadata = metadata;
    _attachTokenRefreshListener();

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final notificationsEnabled = _notificationsEnabled(settings);
      _debugLog('FCM_PERMISSION_STATUS ${settings.authorizationStatus.name}');

      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        _debugLog('FCM_TOKEN_UNAVAILABLE');
        return;
      }

      _debugLog('FCM_TOKEN_CREATED token=$token');
      await _saveToken(
        token: token,
        notificationsEnabled: notificationsEnabled,
        metadata: metadata,
      );
    } catch (error, stackTrace) {
      _debugLog('FCM_TOKEN_SAVE_FAILED $error');
      if (kDebugMode) {
        debugPrintStack(
          label: 'FCM_TOKEN_SAVE_FAILED stack',
          stackTrace: stackTrace,
        );
      }
    }
  }

  void _attachTokenRefreshListener() {
    if (_tokenRefreshSub != null) return;
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(
      (token) async {
        _debugLog('FCM_TOKEN_REFRESHED token=$token');
        try {
          final settings = await _messaging.getNotificationSettings();
          await _saveToken(
            token: token,
            notificationsEnabled: _notificationsEnabled(settings),
            metadata: _lastMetadata,
          );
        } catch (error, stackTrace) {
          _debugLog('FCM_TOKEN_SAVE_FAILED $error');
          if (kDebugMode) {
            debugPrintStack(
              label: 'FCM_TOKEN_SAVE_FAILED stack',
              stackTrace: stackTrace,
            );
          }
        }
      },
      onError: (Object error) {
        _debugLog('FCM_TOKEN_SAVE_FAILED token_refresh_listener_error=$error');
      },
    );
  }

  Future<void> _saveToken({
    required String token,
    required bool notificationsEnabled,
    required FcmTokenMetadata metadata,
  }) async {
    final user = _auth.currentUser;
    final uid = user?.uid.trim() ?? '';
    if (uid.isEmpty) {
      _debugLog('FCM_TOKEN_SAVE_FAILED missing_auth_uid');
      return;
    }

    final ref = _firestore
        .collection('user_device_tokens')
        .doc(uid)
        .collection('tokens')
        .doc(token);
    final snap = await ref.get();
    final now = FieldValue.serverTimestamp();
    final fields = <String, dynamic>{
      'token': token,
      'uid': uid,
      'platform': _platformLabel(),
      'notificationsEnabled': notificationsEnabled,
      'updatedAt': now,
      'lastSeenAt': now,
      ...metadata.toFirestoreFields(),
    };
    if (!snap.exists) {
      fields['createdAt'] = now;
    }

    await ref.set(fields, SetOptions(merge: true));
    _debugLog('FCM_TOKEN_SAVED path=${ref.path}');
  }

  bool _notificationsEnabled(NotificationSettings settings) {
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
