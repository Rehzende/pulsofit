import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Bluetooth controller for heart rate monitor (Magene H303)
class BluetoothController with ChangeNotifier {
  // Standard Bluetooth SIG UUIDs for Heart Rate Service
  static final Guid heartRateServiceUuid = Guid("0000180d-0000-1000-8000-00805f9b34fb");
  static final Guid heartRateCharacteristicUuid = Guid("00002a37-0000-1000-8000-00805f9b34fb");

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _heartRateCharacteristic;
  StreamSubscription<List<int>>? _heartRateSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  int _heartRate = 0;
  bool _isScanning = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isPairing = false;
  String? _errorMessage;
  String _deviceName = '';
  final List<ScanResult> _scanResults = [];

  // Brand keywords that indicate a device is likely a HR strap or fitness watch.
  // We use these as a fallback when the device doesn't advertise the HR service
  // (e.g. paired Polar watches stop advertising after pairing).
  static const List<String> _hrDeviceKeywords = [
    'polar', 'garmin', 'magene', 'wahoo', 'coros', 'suunto', 'tickr',
    'h10', 'h9', 'oh1', 'verity', 'h303', 'h64',
    'heart', 'hr', 'cardio', 'strap', 'pulse', 'rhythm', 'sensor',
    'fenix', 'forerunner', 'epix', 'venu', 'vivoactive', 'instinct',
    'pacer', 'vantage', 'ignite', 'grit',
  ];

  // Getters
  int get heartRate => _heartRate;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isPairing => _isPairing;
  String? get errorMessage => _errorMessage;
  String get deviceName => _deviceName;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);

  /// Scan results filtered to HR-capable devices only.
  /// A device passes the filter if it advertises the HR service OR if its
  /// name matches one of the known HR/watch brand keywords. Unnamed devices
  /// without the HR service are hidden (almost always headphones, mice, etc).
  List<ScanResult> get filteredScanResults {
    bool isLikelyHrDevice(ScanResult r) {
      if (r.advertisementData.serviceUuids.contains(heartRateServiceUuid)) {
        return true;
      }
      final name = (r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName)
          .toLowerCase();
      if (name.isEmpty) return false;
      return _hrDeviceKeywords.any(name.contains);
    }

    return List.unmodifiable(_scanResults.where(isLikelyHrDevice));
  }
  
  @override
  void dispose() {
    _scanSubscription?.cancel();
    disconnect();
    super.dispose();
  }
  
  /// Get list of already paired/bonded Bluetooth devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await FlutterBluePlus.systemDevices([]);
    } catch (e) {
      debugPrint('Error getting paired devices: $e');
      return [];
    }
  }

  /// Scan for nearby heart rate monitors and populate [scanResults] for user selection.
  Future<void> startScan() async {
    if (_isScanning || _isConnected) return;

    _isScanning = true;
    _scanResults.clear();
    _errorMessage = null;
    notifyListeners();

    try {
      if (await FlutterBluePlus.isSupported == false) {
        _errorMessage = 'Bluetooth não suportado neste dispositivo';
        _isScanning = false;
        notifyListeners();
        return;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _errorMessage = 'Ative o Bluetooth para continuar';
        _isScanning = false;
        notifyListeners();
        return;
      }

      debugPrint('Starting BLE scan for heart rate monitors...');
      // Note: Don't filter by service UUID because paired devices (e.g., Polar)
      // may stop advertising the HR service after pairing. Show all devices.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );

      await _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResults
          ..clear()
          ..addAll(results);
        notifyListeners();
      });

      // Wait for the scan timeout to elapse before stopping.
      await Future.delayed(const Duration(seconds: 10));
      await stopScan();

      if (_scanResults.isEmpty && !_isConnected) {
        _errorMessage = 'Nenhum dispositivo encontrado. Verifique se está ligado e próximo.';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Erro ao escanear: ${e.toString()}';
      debugPrint('Bluetooth scan error: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stop an ongoing scan.
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    notifyListeners();
  }

  /// Connect to a user-selected device.
  Future<void> connectToDevice(BluetoothDevice device) async {
    _scanResults.clear();
    await _connectToDevice(device);
  }
  
  /// Connect to a specific Bluetooth device, handling bonding on Android.
  Future<void> _connectToDevice(BluetoothDevice device) async {
    _isConnecting = true;
    _isPairing = false;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('Connecting to ${device.platformName}...');
      await device.connect(timeout: const Duration(seconds: 15));

      _connectedDevice = device;
      _deviceName = device.platformName.isNotEmpty
          ? device.platformName
          : 'Monitor Cardíaco';

      // Watch for disconnection
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('Device disconnected');
          _handleDisconnection();
        }
      });

      // Try service discovery WITHOUT bonding first.
      // Many BLE HR straps (Magene H303, generic chest straps) work without
      // any bond — forcing createBond() on them causes pairing failures.
      // Only request a bond if discovery fails with an auth/encryption error
      // (which Android-paired devices like Polar require).
      List<BluetoothService>? services;
      try {
        debugPrint('Discovering services (no bond)...');
        services = await device.discoverServices();
      } catch (e) {
        final msg = e.toString().toLowerCase();
        final needsBond = Platform.isAndroid &&
            (msg.contains('insufficient') ||
                msg.contains('encryption') ||
                msg.contains('authentication') ||
                msg.contains('not permitted') ||
                msg.contains('gatt_auth'));

        if (!needsBond) rethrow;

        debugPrint('Service discovery requires bond, requesting...');
        await _ensureBonded(device);
        // Retry after bond
        services = await device.discoverServices();
      }

      // Look for the standard Heart Rate service
      for (final service in services) {
        if (service.uuid == heartRateServiceUuid) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid == heartRateCharacteristicUuid) {
              try {
                await characteristic.setNotifyValue(true);
              } catch (e) {
                // setNotifyValue can also require bond on some devices
                final msg = e.toString().toLowerCase();
                if (Platform.isAndroid &&
                    (msg.contains('insufficient') ||
                        msg.contains('encryption') ||
                        msg.contains('authentication'))) {
                  await _ensureBonded(device);
                  await characteristic.setNotifyValue(true);
                } else {
                  rethrow;
                }
              }
              _heartRateCharacteristic = characteristic;
              _heartRateSubscription =
                  characteristic.lastValueStream.listen(_parseHeartRateData);
              debugPrint('Heart rate notifications enabled');
              break;
            }
          }
          break;
        }
      }

      if (_heartRateCharacteristic != null) {
        // Only mark connected after everything is working
        _isConnected = true;
      } else {
        _errorMessage =
            'Característica de frequência cardíaca não encontrada. O dispositivo suporta monitor cardíaco?';
        await disconnect();
      }
    } catch (e) {
      _errorMessage = 'Erro ao conectar: ${e.toString()}';
      debugPrint('Bluetooth connection error: $e');
      _isPairing = false;
      _isConnected = false;
      try {
        await _connectedDevice?.disconnect();
      } catch (_) {}
      _handleDisconnection();
    } finally {
      _isConnecting = false;
      _isPairing = false;
      notifyListeners();
    }
  }

  /// Bond with the device (Android only). Idempotent — no-op if already bonded.
  /// Does NOT call removeBond() preemptively: that was the source of a PIN race
  /// on devices like Polar PacePro where the OS pairing dialog would show a
  /// stale PIN before the new bond request had time to register.
  Future<void> _ensureBonded(BluetoothDevice device) async {
    if (!Platform.isAndroid) return;

    final currentBond = await device.bondState.first;
    if (currentBond == BluetoothBondState.bonded) return;

    _isPairing = true;
    notifyListeners();

    try {
      await device.createBond();
      final finalBond = await device.bondState
          .where((s) => s != BluetoothBondState.bonding)
          .first
          .timeout(const Duration(seconds: 30));

      if (finalBond != BluetoothBondState.bonded) {
        throw FlutterBluePlusException(
          ErrorPlatform.android,
          'createBond',
          -1,
          'Bonding rejected (state=$finalBond)',
        );
      }
    } on FlutterBluePlusException catch (e) {
      debugPrint('Bond failed: $e');
      _errorMessage =
          'Falha no pareamento. Vá em Configurações > Bluetooth, esqueça o dispositivo e tente novamente.';
      rethrow;
    } finally {
      _isPairing = false;
      notifyListeners();
    }
  }
  
  /// Parse heart rate data according to Bluetooth SIG specification
  /// https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0/
  void _parseHeartRateData(List<int> data) {
    if (data.isEmpty) return;
    
    // First byte is flags
    int flags = data[0];
    
    // Bit 0 of flags indicates heart rate value format
    // 0 = uint8, 1 = uint16
    bool isUint16 = (flags & 0x01) != 0;
    
    int newHeartRate;
    if (isUint16) {
      // Heart rate is in bytes 1 and 2 (little endian)
      if (data.length >= 3) {
        newHeartRate = data[1] + (data[2] << 8);
      } else {
        return;
      }
    } else {
      // Heart rate is in byte 1
      if (data.length >= 2) {
        newHeartRate = data[1];
      } else {
        return;
      }
    }
    
    // Validate heart rate (reasonable range: 30-220 BPM)
    if (newHeartRate >= 30 && newHeartRate <= 220) {
      _heartRate = newHeartRate;
      debugPrint('Heart rate: $_heartRate BPM');
      notifyListeners();
    }
  }
  
  /// Handle device disconnection
  void _handleDisconnection() {
    _isConnected = false;
    _heartRate = 0;
    _connectedDevice = null;
    _heartRateCharacteristic = null;
    _heartRateSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    notifyListeners();
  }
  
  /// Disconnect from the current device
  Future<void> disconnect() async {
    try {
      await _heartRateSubscription?.cancel();
      await _connectionStateSubscription?.cancel();
      
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      
      _handleDisconnection();
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }
  
  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
