import '../../../services/offline/offline_operation.dart';
import '../../../services/offline/offline_operation_status.dart';
import '../identity/attendance_operation_identity.dart';

/// Frozen contract between queue, sync engine, and processors (read-only view).
abstract interface class AttendanceSyncContract {
  String get operationId;
  String? get operationKey;
  int get retryCount;
  OfflineOperationStatus get status;
  String get operationType;
}

/// Adapter over [OfflineOperation] — avoids Map access outside service layer.
final class OfflineOperationSyncView implements AttendanceSyncContract {
  OfflineOperationSyncView(this._operation);

  final OfflineOperation _operation;

  factory OfflineOperationSyncView.fromOperation(OfflineOperation operation) {
    return OfflineOperationSyncView(operation);
  }

  @override
  String get operationId => _operation.id;

  @override
  String? get operationKey =>
      AttendanceOperationIdentity.operationKeyFromPayload(_operation.payload);

  @override
  int get retryCount => _operation.retryCount;

  @override
  OfflineOperationStatus get status => _operation.status;

  @override
  String get operationType => _operation.type;

  String? get lastError => _operation.lastError;

  String get sessionId =>
      (_operation.payload['sessionId'] ?? '').toString().trim();

  String get studentId =>
      (_operation.payload['studentId'] ?? '').toString().trim();
}
