import 'offline_operation_status.dart';

/// A single deferred operation stored in the unified offline queue.
class OfflineOperation {
  OfflineOperation({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.retryCount,
    required this.payload,
    this.lastError,
  });

  final String id;
  final String type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final OfflineOperationStatus status;
  final int retryCount;
  final Map<String, dynamic> payload;
  final String? lastError;

  OfflineOperation copyWith({
    String? id,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    OfflineOperationStatus? status,
    int? retryCount,
    Map<String, dynamic>? payload,
    String? lastError,
    bool clearLastError = false,
  }) {
    return OfflineOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      payload: payload ?? Map<String, dynamic>.from(this.payload),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'status': status.storageValue,
      'retryCount': retryCount,
      'payload': Map<String, dynamic>.from(payload),
      if (lastError != null && lastError!.trim().isNotEmpty)
        'lastError': lastError!.trim(),
    };
  }

  static OfflineOperation? tryFromMap(dynamic raw) {
    if (raw is! Map) return null;
    try {
      final map = Map<String, dynamic>.from(raw);
      final id = (map['id'] ?? '').toString().trim();
      final type = (map['type'] ?? '').toString().trim();
      if (id.isEmpty || type.isEmpty) return null;

      final status =
          OfflineOperationStatus.tryParse(map['status']?.toString()) ??
          OfflineOperationStatus.pending;

      final createdAt = _parseDate(map['createdAt']);
      final updatedAt = _parseDate(map['updatedAt']) ?? createdAt;
      if (createdAt == null) return null;

      final payloadRaw = map['payload'];
      final payload = payloadRaw is Map
          ? Map<String, dynamic>.from(payloadRaw)
          : <String, dynamic>{};

      final retryCount = _parseInt(map['retryCount']) ?? 0;
      final lastError = (map['lastError'] ?? '').toString().trim();

      return OfflineOperation(
        id: id,
        type: type,
        createdAt: createdAt,
        updatedAt: updatedAt ?? createdAt,
        status: status,
        retryCount: retryCount < 0 ? 0 : retryCount,
        payload: payload,
        lastError: lastError.isEmpty ? null : lastError,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toUtc();
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString());
  }
}
