import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

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
  static const int _manufacturerId = 0x02E5;
  static const String _marker = 'MHD';

  final FlutterReactiveBle _scanner = FlutterReactiveBle();
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamController<BluetoothScanResult>? _scanController;
  Timer? _scanTimeout;
  BluetoothBroadcastState _broadcastState = BluetoothBroadcastState.idle;
  BluetoothScanState _scanState = BluetoothScanState.idle;

  BluetoothBroadcastState get broadcastState => _broadcastState;

  BluetoothScanState get scanState => _scanState;

  Future<BluetoothBleSupportResult> checkPlatformSupport(
    BluetoothBleRole role,
  ) async {
    _debugLog('support_check platform=$_platformLabel role=$role');
    if (!Platform.isAndroid && !Platform.isIOS) {
      return BluetoothBleSupportResult(
        status: BluetoothBleSupportStatus.unsupported,
        message: role == BluetoothBleRole.broadcaster
            ? 'Bluetooth broadcasting is not supported on this device in this phase.'
            : 'Bluetooth scanning is not supported on this device.',
      );
    }

    if (role == BluetoothBleRole.broadcaster) {
      final supported = await _peripheral.isSupported;
      _debugLog(
        'broadcast_support platform=$_platformLabel supported=$supported',
      );
      if (!supported) {
        return const BluetoothBleSupportResult(
          status: BluetoothBleSupportStatus.unsupported,
          message:
              'Bluetooth broadcasting is not supported on this device in this phase.',
        );
      }
      final isOn = await _peripheral.isBluetoothOn;
      _debugLog(
        'broadcast_support platform=$_platformLabel isBluetoothOn=$isOn',
      );
      if (!isOn) {
        return const BluetoothBleSupportResult(
          status: BluetoothBleSupportStatus.off,
          message: 'Bluetooth is turned off.',
        );
      }
      if (Platform.isIOS) {
        final stableStatus = await _waitForStableBleStatus();
        _debugLog(
          'broadcast_support platform=$_platformLabel stableBleStatus=$stableStatus '
          'allowUnknown=${stableStatus == BleStatus.unknown}',
        );
      }
      return const BluetoothBleSupportResult(
        status: BluetoothBleSupportStatus.supported,
        message: 'Bluetooth broadcasting is available.',
      );
    }

    final status = _scanner.status;
    switch (status) {
      case BleStatus.ready:
      case BleStatus.unknown:
        return const BluetoothBleSupportResult(
          status: BluetoothBleSupportStatus.supported,
          message: 'Bluetooth scanning is available.',
        );
      case BleStatus.unsupported:
        return const BluetoothBleSupportResult(
          status: BluetoothBleSupportStatus.unsupported,
          message: 'Bluetooth is not supported on this device.',
        );
      case BleStatus.unauthorized:
        return const BluetoothBleSupportResult(
          status: BluetoothBleSupportStatus.permissionDenied,
          message: 'Bluetooth permission is required.',
        );
      case BleStatus.poweredOff:
        return const BluetoothBleSupportResult(
          status: BluetoothBleSupportStatus.off,
          message: 'Bluetooth is turned off.',
        );
      case BleStatus.locationServicesDisabled:
        return const BluetoothBleSupportResult(
          status: BluetoothBleSupportStatus.off,
          message: 'Location services are disabled for Bluetooth scanning.',
        );
    }
  }

  Future<BluetoothBleSupportResult> requestPermissions(
    BluetoothBleRole role,
  ) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return checkPlatformSupport(role);
    }

    if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      _debugLog(
        'permission_check platform=$_platformLabel role=$role status=$status',
      );
      if (!status.isGranted && !status.isLimited) {
        return const BluetoothBleSupportResult(
          status: BluetoothBleSupportStatus.permissionDenied,
          message: 'Bluetooth permission is required.',
        );
      }
      return checkPlatformSupport(role);
    }

    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      if (role == BluetoothBleRole.broadcaster) Permission.bluetoothAdvertise,
      if (await _androidSdkInt() <= 30) Permission.locationWhenInUse,
    ];
    final statuses = await permissions.request();
    final denied = statuses.values.any(
      (status) => !status.isGranted && !status.isLimited,
    );
    if (denied) {
      return const BluetoothBleSupportResult(
        status: BluetoothBleSupportStatus.permissionDenied,
        message: 'Bluetooth permission is required.',
      );
    }

    if (role == BluetoothBleRole.broadcaster) {
      final peripheralPermission = await _peripheral.requestPermission();
      if (!_isPeripheralPermissionReady(peripheralPermission)) {
        return BluetoothBleSupportResult(
          status: BluetoothBleSupportStatus.permissionDenied,
          message: _messageForPeripheralState(peripheralPermission),
        );
      }
    }

    return checkPlatformSupport(role);
  }

  Future<BluetoothBroadcastResult> startAdvertisingSession(
    BluetoothAttendanceSession session,
  ) async {
    _broadcastState = BluetoothBroadcastState.requestingPermission;
    final permission = await requestPermissions(BluetoothBleRole.broadcaster);
    if (!permission.isSupported) {
      _broadcastState = permission.status == BluetoothBleSupportStatus.off
          ? BluetoothBroadcastState.error
          : BluetoothBroadcastState.unsupported;
      return BluetoothBroadcastResult(
        state: _broadcastState,
        message: permission.message,
      );
    }

    final data = _buildAdvertiseData(session);
    final stableStatus = _scanner.status;
    final attemptedDespiteUnknown =
        Platform.isIOS && stableStatus == BleStatus.unknown;
    _debugLog(
      'advertising_attempt platform=$_platformLabel bleStatus=$stableStatus '
      'attemptedDespiteUnknown=$attemptedDespiteUnknown',
    );
    try {
      await _peripheral.stop();
    } catch (_) {
      // Ignore stale advertiser cleanup failures before starting a new payload.
    }

    try {
      final state = await _peripheral.start(advertiseData: data);
      _debugLog(
        'advertising_start_return platform=$_platformLabel state=$state',
      );
      if (_isPeripheralPermissionReady(state) ||
          state == BluetoothPeripheralState.ready) {
        _broadcastState = BluetoothBroadcastState.broadcasting;
        _debugLog(
          'advertising_start_success platform=$_platformLabel state=$state',
        );
        return const BluetoothBroadcastResult(
          state: BluetoothBroadcastState.broadcasting,
          message: 'Bluetooth broadcast is active.',
        );
      }
      if (Platform.isIOS && state == BluetoothPeripheralState.unknown) {
        final isAdvertising = await _waitForAdvertisingState();
        _debugLog(
          'advertising_unknown_result platform=$_platformLabel '
          'isAdvertising=$isAdvertising',
        );
        if (isAdvertising) {
          _broadcastState = BluetoothBroadcastState.broadcasting;
          _debugLog(
            'advertising_start_success platform=$_platformLabel '
            'source=isAdvertising',
          );
          return const BluetoothBroadcastResult(
            state: BluetoothBroadcastState.broadcasting,
            message: 'Bluetooth broadcast is active.',
          );
        }
      }
      _broadcastState = BluetoothBroadcastState.error;
      _debugLog(
        'advertising_start_failure platform=$_platformLabel state=$state',
      );
      return BluetoothBroadcastResult(
        state: BluetoothBroadcastState.error,
        message: _messageForPeripheralState(state),
      );
    } catch (e) {
      _broadcastState = BluetoothBroadcastState.error;
      _debugLog(
        'advertising_start_exception platform=$_platformLabel error=$e',
      );
      return BluetoothBroadcastResult(
        state: BluetoothBroadcastState.error,
        message:
            'Unable to start Bluetooth broadcast. Make sure Bluetooth is on and try again.',
      );
    }
  }

  Future<void> stopAdvertisingSession() async {
    try {
      await _peripheral.stop();
    } finally {
      _broadcastState = BluetoothBroadcastState.idle;
    }
  }

  Stream<BluetoothScanResult> startScanningForMuhadirSession({
    Duration timeout = const Duration(seconds: 18),
  }) {
    stopScanning();
    _scanState = BluetoothScanState.requestingPermission;
    _scanController = StreamController<BluetoothScanResult>(
      onCancel: () => stopScanning(),
    );
    _startScan(timeout);
    return _scanController!.stream;
  }

  Future<void> stopScanning() async {
    final controller = _scanController;
    _scanController = null;
    _scanTimeout?.cancel();
    _scanTimeout = null;
    await _scanSub?.cancel();
    _scanSub = null;
    if (_scanState == BluetoothScanState.scanning) {
      _scanState = BluetoothScanState.idle;
    }
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  Future<void> _startScan(Duration timeout) async {
    final controller = _scanController;
    if (controller == null || controller.isClosed) return;

    final support = await requestPermissions(BluetoothBleRole.scanner);
    if (!support.isSupported) {
      _scanState = support.status == BluetoothBleSupportStatus.unsupported
          ? BluetoothScanState.unsupported
          : BluetoothScanState.error;
      controller.add(
        BluetoothScanResult(state: _scanState, message: support.message),
      );
      await stopScanning();
      return;
    }

    _scanState = BluetoothScanState.scanning;
    controller.add(
      const BluetoothScanResult(
        state: BluetoothScanState.scanning,
        message: 'Searching for lecture signal...',
      ),
    );

    _scanTimeout = Timer(timeout, () {
      if (_scanState == BluetoothScanState.detected) return;
      _scanState = BluetoothScanState.notFound;
      controller.add(
        const BluetoothScanResult(
          state: BluetoothScanState.notFound,
          message: 'No lecture signal found.',
        ),
      );
      stopScanning();
    });

    // iOS often misses Android advertisers when filtering by service UUID only
    // (UUID may appear in scan response, not the primary advertisement packet).
    final scanServiceFilter = Platform.isIOS
        ? const <Uuid>[]
        : [Uuid.parse(muhadirServiceUuid)];
    _debugLog(
      'scan_start platform=$_platformLabel '
      'filtered=${scanServiceFilter.isNotEmpty}',
    );

    try {
      _scanSub = _scanner
          .scanForDevices(
            withServices: scanServiceFilter,
            scanMode: ScanMode.lowLatency,
            requireLocationServicesEnabled: false,
          )
          .listen(
            (device) {
              final detection = _parseDetection(device);
              if (detection == null || controller.isClosed) return;
              _scanState = BluetoothScanState.detected;
              controller.add(
                BluetoothScanResult(
                  state: BluetoothScanState.detected,
                  message: 'Lecture signal found.',
                  detection: detection,
                ),
              );
            },
            onError: (Object error) {
              if (controller.isClosed) return;
              _scanState = BluetoothScanState.error;
              controller.add(
                BluetoothScanResult(
                  state: BluetoothScanState.error,
                  message: 'Bluetooth scan failed: $error',
                ),
              );
              stopScanning();
            },
          );
    } catch (e) {
      if (controller.isClosed) return;
      _scanState = BluetoothScanState.error;
      controller.add(
        BluetoothScanResult(
          state: BluetoothScanState.error,
          message: 'Bluetooth scan failed: $e',
        ),
      );
      await stopScanning();
    }
  }

  AdvertiseData _buildAdvertiseData(BluetoothAttendanceSession session) {
    final payload = _buildCompactPayload(session);
    final payloadBytes = Uint8List.fromList(utf8.encode(payload));
    return AdvertiseData(
      serviceUuid: muhadirServiceUuid,
      serviceUuids: const [muhadirServiceUuid],
      localName: 'MUHADIR',
      manufacturerId: _manufacturerId,
      manufacturerData: payloadBytes,
      serviceDataUuid: muhadirServiceUuid,
      serviceData: payloadBytes,
      // Helps iOS discover Android broadcasts when service UUID is not in the
      // primary advertisement packet.
      includeDeviceName: true,
      includePowerLevel: false,
    );
  }

  BluetoothScanDetection? _parseDetection(DiscoveredDevice device) {
    final serviceUuid = Uuid.parse(muhadirServiceUuid);
    final hasService = device.serviceUuids.any(
      (uuid) => uuid.expanded == serviceUuid.expanded,
    );
    String? servicePayload;
    for (final entry in device.serviceData.entries) {
      if (entry.key.expanded != serviceUuid.expanded) continue;
      final value = _payloadFromBytes(entry.value);
      if (value != null) {
        servicePayload = value;
        break;
      }
    }
    final rawPayload = servicePayload ?? _payloadFromManufacturerData(
      device.manufacturerData,
    );
    final nameMatches = device.name.toUpperCase().contains('MUHADIR');

    if (!hasService && rawPayload == null && !nameMatches) return null;

    final parts = rawPayload?.split('|') ?? const <String>[];
    int? tokenVersion;
    if (parts.length >= 2) {
      tokenVersion = int.tryParse(parts[1], radix: 36);
    }

    return BluetoothScanDetection(
      deviceId: device.id,
      deviceName: device.name.isEmpty ? 'MUHADIR BLE' : device.name,
      rssi: device.rssi,
      advertisedServiceUuid: muhadirServiceUuid,
      rawPayload: rawPayload,
      sessionIdHash: parts.length >= 3 ? parts[2] : null,
      tokenFragment: parts.length >= 4 ? parts[3] : null,
      tokenVersion: tokenVersion,
    );
  }

  String? _decodePayloadBytes(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  /// Extracts `MHD|...` from service/manufacturer bytes (with optional company id).
  String? _payloadFromBytes(Uint8List bytes) {
    final decoded = _decodePayloadBytes(bytes);
    if (decoded != null && decoded.contains(_marker)) {
      return decoded.substring(decoded.indexOf(_marker));
    }
    if (bytes.length <= 2) return null;
    // BLE manufacturer data often prefixes a 2-byte company identifier.
    final withoutCompanyId = _decodePayloadBytes(
      Uint8List.sublistView(bytes, 2),
    );
    if (withoutCompanyId != null && withoutCompanyId.contains(_marker)) {
      return withoutCompanyId.substring(withoutCompanyId.indexOf(_marker));
    }
    return null;
  }

  String? _payloadFromManufacturerData(Uint8List bytes) {
    return _payloadFromBytes(bytes);
  }

  String _buildCompactPayload(BluetoothAttendanceSession session) {
    final sessionHash = _shortHash(session.sessionId, 6);
    final token = session.bluetoothSessionToken;
    final tokenFragment = token.length <= 8 ? token : token.substring(0, 8);
    final version = session.tokenVersion.toRadixString(36);
    return '$_marker|$version|$sessionHash|$tokenFragment';
  }

  String _shortHash(String input, int length) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(input)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0').substring(0, length);
  }

  bool _isPeripheralPermissionReady(BluetoothPeripheralState state) {
    return state == BluetoothPeripheralState.granted ||
        state == BluetoothPeripheralState.ready;
  }

  Future<BleStatus> _waitForStableBleStatus({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final initial = _scanner.status;
    _debugLog(
      'ble_status platform=$_platformLabel source=initial raw=$initial',
    );
    if (initial != BleStatus.unknown) return initial;

    final completer = Completer<BleStatus>();
    late final StreamSubscription<BleStatus> subscription;
    Timer? timer;
    var latest = initial;

    subscription = _scanner.statusStream.listen(
      (status) {
        latest = status;
        _debugLog(
          'ble_status platform=$_platformLabel source=stream raw=$status',
        );
        if (status != BleStatus.unknown && !completer.isCompleted) {
          completer.complete(status);
        }
      },
      onError: (Object error) {
        _debugLog('ble_status_error platform=$_platformLabel error=$error');
      },
    );
    timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(latest);
    });

    try {
      final status = await completer.future;
      _debugLog('ble_status_stable platform=$_platformLabel raw=$status');
      return status;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }

  Future<bool> _waitForAdvertisingState({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final isAdvertising = await _peripheral.isAdvertising;
      _debugLog(
        'advertising_state platform=$_platformLabel isAdvertising=$isAdvertising',
      );
      if (isAdvertising) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final isAdvertising = await _peripheral.isAdvertising;
    _debugLog(
      'advertising_state platform=$_platformLabel final=$isAdvertising',
    );
    return isAdvertising;
  }

  String get _platformLabel {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[BluetoothBleService] $message');
    }
  }

  String _messageForPeripheralState(BluetoothPeripheralState state) {
    switch (state) {
      case BluetoothPeripheralState.granted:
      case BluetoothPeripheralState.ready:
        return 'Bluetooth is ready.';
      case BluetoothPeripheralState.denied:
      case BluetoothPeripheralState.permanentlyDenied:
      case BluetoothPeripheralState.restricted:
      case BluetoothPeripheralState.limited:
        return 'Bluetooth permission is required.';
      case BluetoothPeripheralState.turnedOff:
        return 'Bluetooth is turned off.';
      case BluetoothPeripheralState.unsupported:
        return 'Bluetooth broadcasting is not supported on this device in this phase.';
      case BluetoothPeripheralState.unknown:
        return 'Bluetooth is still getting ready. Make sure Bluetooth is on and try again.';
    }
  }

  Future<int> _androidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    try {
      return (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    } catch (_) {
      return 31;
    }
  }
}
