import '../../models/attendance/bluetooth_attendance_session.dart';

enum BluetoothBleRole { broadcaster, scanner }

enum BluetoothBleSupportStatus { supported, unsupported, permissionDenied, off }

enum BluetoothBroadcastState {
  idle,
  requestingPermission,
  broadcasting,
  unsupported,
  error,
}

enum BluetoothScanState {
  idle,
  requestingPermission,
  scanning,
  detected,
  notFound,
  unsupported,
  error,
}

class BluetoothBleSupportResult {
  const BluetoothBleSupportResult({
    required this.status,
    required this.message,
  });

  final BluetoothBleSupportStatus status;
  final String message;

  bool get isSupported => status == BluetoothBleSupportStatus.supported;
}

class BluetoothBroadcastResult {
  const BluetoothBroadcastResult({required this.state, required this.message});

  final BluetoothBroadcastState state;
  final String message;

  bool get isBroadcasting => state == BluetoothBroadcastState.broadcasting;
}

class BluetoothScanDetection {
  const BluetoothScanDetection({
    required this.deviceId,
    required this.deviceName,
    required this.rssi,
    required this.advertisedServiceUuid,
    this.rawPayload,
    this.sessionIdHash,
    this.tokenFragment,
    this.tokenVersion,
  });

  final String deviceId;
  final String deviceName;
  final int rssi;
  final String advertisedServiceUuid;
  final String? rawPayload;
  final String? sessionIdHash;
  final String? tokenFragment;
  final int? tokenVersion;
}

class BluetoothScanResult {
  const BluetoothScanResult({
    required this.state,
    required this.message,
    this.detection,
  });

  final BluetoothScanState state;
  final String message;
  final BluetoothScanDetection? detection;
}

class BluetoothBleService {
  BluetoothBleService._();
  static final BluetoothBleService instance = BluetoothBleService._();

  static const String muhadirServiceUuid =
      '6d756861-6469-722d-6174-74656e64616e';

  BluetoothBroadcastState get broadcastState => BluetoothBroadcastState.idle;

  BluetoothScanState get scanState => BluetoothScanState.idle;

  Future<BluetoothBleSupportResult> checkPlatformSupport(
    BluetoothBleRole role,
  ) async {
    final action = role == BluetoothBleRole.broadcaster
        ? 'broadcasting'
        : 'scanning';
    return BluetoothBleSupportResult(
      status: BluetoothBleSupportStatus.unsupported,
      message: 'Bluetooth $action is not supported on web in this phase.',
    );
  }

  Future<BluetoothBleSupportResult> requestPermissions(BluetoothBleRole role) {
    return checkPlatformSupport(role);
  }

  Future<BluetoothBroadcastResult> startAdvertisingSession(
    BluetoothAttendanceSession session,
  ) async {
    return const BluetoothBroadcastResult(
      state: BluetoothBroadcastState.unsupported,
      message: 'Bluetooth broadcasting is not supported on web in this phase.',
    );
  }

  Future<void> stopAdvertisingSession() async {}

  Stream<BluetoothScanResult> startScanningForMuhadirSession({
    Duration timeout = const Duration(seconds: 18),
  }) async* {
    yield const BluetoothScanResult(
      state: BluetoothScanState.unsupported,
      message: 'Bluetooth scanning requires a supported mobile device.',
    );
  }

  Future<void> stopScanning() async {}
}
