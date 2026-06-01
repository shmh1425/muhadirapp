import 'package:flutter/foundation.dart';

import '../../../features/attendance/attendance_payload.dart';
import '../../../services/attendance/bluetooth_attendance_service.dart';
import '../offline_operation.dart';
import '../offline_operation_types.dart';
import 'offline_operation_processor.dart';

/// Replays queued Bluetooth signals through the existing Bluetooth service.
class BluetoothAttendanceProcessor implements OfflineOperationProcessor {
  @override
  String get type => OfflineOperationTypes.bluetoothAttendance;

  @override
  Future<void> process(OfflineOperation operation) async {
    final payload = AttendancePayload.fromQueueMap(operation.payload);
    final meta = payload.metadata ?? payload.toQueuePayload();
    try {
      await _submit(meta, payload);
    } on BluetoothAttendanceException catch (e) {
      if (e.code == BluetoothAttendanceErrorCode.alreadyMarked) {
        if (kDebugMode) {
          debugPrint(
            '[ATTENDANCE_SYNC] bluetooth already marked — treating as success '
            'operationId=${operation.id}',
          );
        }
        return;
      }
      rethrow;
    }
  }

  Future<void> _submit(
    Map<String, dynamic> meta,
    AttendancePayload payload,
  ) async {
    await BluetoothAttendanceService.instance.submitAttendanceFromBluetoothSignal(
      sessionId: (meta['sessionId'] ?? payload.sessionId).toString(),
      bluetoothSessionToken: meta['bluetoothSessionToken']?.toString(),
      sessionIdHash: meta['sessionIdHash']?.toString(),
      tokenFragment: meta['tokenFragment']?.toString(),
      tokenVersion: _safeInt(meta['tokenVersion']),
      detectedSignalStrength: _safeInt(meta['detectedSignalStrength']),
      detectedSignalId: meta['detectedSignalId']?.toString(),
      rawPayload: meta['rawPayload']?.toString(),
      currentTime: payload.timestamp.toLocal(),
      queueReplay: true,
    );
  }

  static int? _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString());
  }
}
