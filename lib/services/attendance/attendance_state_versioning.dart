import 'package:cloud_firestore/cloud_firestore.dart';

/// Queue-payload versioning (no Firestore schema changes).
abstract final class AttendanceStateVersioning {
  static const String stateVersionField = 'stateVersion';
  static const String serverStateHashField = 'serverStateHash';
  static const String clientMutationIdField = 'clientMutationId';

  static int nextVersionMillis() => DateTime.now().toUtc().millisecondsSinceEpoch;

  static Map<String, dynamic> enrichPayload(
    Map<String, dynamic> payload, {
    required String clientMutationId,
    String? serverStateHash,
  }) {
    final map = Map<String, dynamic>.from(payload);
    map[clientMutationIdField] = clientMutationId;
    map[stateVersionField] = nextVersionMillis();
    if (serverStateHash != null && serverStateHash.isNotEmpty) {
      map[serverStateHashField] = serverStateHash;
    }
    return map;
  }

  static String computeServerStateHash(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return 'empty';
    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    final updatedAt = _serializeUpdatedAt(data['updatedAt']);
    final mutation = (data[clientMutationIdField] ?? '').toString().trim();
    return '$status|$updatedAt|$mutation';
  }

  static bool isStaleComparedToServer({
    required Map<String, dynamic>? serverData,
    required int stateVersionMs,
  }) {
    if (serverData == null || stateVersionMs <= 0) return false;
    final updatedAt = serverData['updatedAt'];
    if (updatedAt is Timestamp) {
      return updatedAt.millisecondsSinceEpoch > stateVersionMs;
    }
    if (updatedAt is DateTime) {
      return updatedAt.toUtc().millisecondsSinceEpoch > stateVersionMs;
    }
    return false;
  }

  /// Skip when server already reflects this mutation and state hash.
  static bool shouldSkipDuplicateApply({
    required Map<String, dynamic> payload,
    required Map<String, dynamic>? serverData,
    required String operationId,
  }) {
    final targetStatus =
        (payload['attendanceStatus'] ?? '').toString().trim().toLowerCase();
    if (targetStatus.isEmpty) return false;

    final serverStatus =
        (serverData?['status'] ?? '').toString().trim().toLowerCase();
    final payloadHash = (payload[serverStateHashField] ?? '').toString();
    final serverHash = computeServerStateHash(serverData);
    final payloadMutation =
        (payload[clientMutationIdField] ?? operationId).toString();
    final serverMutation =
        (serverData?[clientMutationIdField] ?? '').toString();

    if (serverStatus == targetStatus &&
        payloadHash.isNotEmpty &&
        payloadHash == serverHash) {
      return true;
    }
    if (serverMutation.isNotEmpty && serverMutation == payloadMutation) {
      return true;
    }
    if (serverMutation == operationId) {
      return true;
    }
    return false;
  }

  static int stateVersionFromPayload(Map<String, dynamic> payload) {
    final raw = payload[stateVersionField];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse((raw ?? '').toString()) ?? 0;
  }

  static String _serializeUpdatedAt(dynamic value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch.toString();
    }
    if (value is DateTime) {
      return value.toUtc().millisecondsSinceEpoch.toString();
    }
    return (value ?? '').toString();
  }
}
