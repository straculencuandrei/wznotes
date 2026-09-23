import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'network_helper.dart';

class DiscoveredPeer {
  final String deviceName;
  final String ip;
  final int port;
  final String pin;
  final int noteCount;
  final DateTime lastSeen;

  const DiscoveredPeer({
    required this.deviceName,
    required this.ip,
    required this.port,
    required this.pin,
    required this.noteCount,
    required this.lastSeen,
  });

  DiscoveredPeer copyWith({
    String? deviceName,
    String? ip,
    int? port,
    String? pin,
    int? noteCount,
    DateTime? lastSeen,
  }) {
    return DiscoveredPeer(
      deviceName: deviceName ?? this.deviceName,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      pin: pin ?? this.pin,
      noteCount: noteCount ?? this.noteCount,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

/// Zero-Config Local Wi-Fi Discovery Service using UDP Broadcast Beacons + USB Tunnel Detection
class SyncDiscoveryService {
  static const int broadcastPort = 8488;
  RawDatagramSocket? _socket;
  Timer? _beaconTimer;
  Timer? _cleanupTimer;
  int _tickCount = 0;

  String? _myIp;
  String _deviceName = 'Device';
  int _port = 8484;
  String _pin = '';
  int _noteCount = 0;

  final Map<String, DiscoveredPeer> _peers = {};
  final StreamController<List<DiscoveredPeer>> _peersController =
      StreamController<List<DiscoveredPeer>>.broadcast();

  Stream<List<DiscoveredPeer>> get peersStream => _peersController.stream;
  List<DiscoveredPeer> get peers => _peers.values.toList();

  bool get isRunning => _socket != null;

  /// Resolves the absolute path to adb.exe on Windows
  static String getAdbPath() {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null) {
        final candidate = '$localAppData\\Android\\Sdk\\platform-tools\\adb.exe';
        if (File(candidate).existsSync()) {
          return candidate;
        }
      }
    }
    return 'adb';
  }

  /// Automatically establishes clean ADB USB port forwarding on Windows (Port 8485 -> Phone 8484)
  static Future<void> setupAdbForwarding() async {
    if (!Platform.isWindows) return;
    try {
      final adbPath = getAdbPath();

      // Clean up any stale circular rules on 8484 that cause infinite loopbacks
      await Process.run(adbPath, ['forward', '--remove', 'tcp:8484'])
          .catchError((_) => ProcessResult(0, 0, '', ''));
      await Process.run(adbPath, ['reverse', '--remove', 'tcp:8484'])
          .catchError((_) => ProcessResult(0, 0, '', ''));

      // Establish dedicated port 8485 tunnel: PC:8485 -> Phone:8484
      await Process.run(adbPath, ['forward', 'tcp:8485', 'tcp:8484'])
          .catchError((_) => ProcessResult(0, 0, '', ''));
    } catch (_) {}
  }

  /// Wakes the phone screen and brings WZNotes to the foreground to unfreeze sockets
  static Future<void> wakePhoneApp() async {
    if (!Platform.isWindows) return;
    try {
      final adbPath = getAdbPath();
      await Process.run(adbPath, [
        'shell',
        'am',
        'start',
        '-n',
        'dev.opennotes.app/.MainActivity',
      ]).catchError((_) => ProcessResult(0, 0, '', ''));
    } catch (_) {}
  }

  /// Starts advertising this device and listening for nearby peers on local network
  Future<void> start({
    required String deviceName,
    required int port,
    required String pin,
    required int noteCount,
  }) async {
    await stop();

    _deviceName = deviceName;
    _port = port;
    _pin = pin;
    _noteCount = noteCount;
    _myIp = await NetworkHelper.getLocalIpAddress();

    // Auto setup ADB tunnel if on Windows
    if (Platform.isWindows) {
      unawaited(setupAdbForwarding());
    }

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        broadcastPort,
        reuseAddress: true,
      );
      _socket?.broadcastEnabled = true;

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _handleIncomingPacket(datagram);
          }
        }
      });

      // Send initial announcement immediately
      _broadcastBeacon();
      probeUsbPeer();

      // Recurring beacon every 1.5 seconds
      _beaconTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        _tickCount++;
        _broadcastBeacon();
        if (_tickCount % 2 == 0) {
          probeUsbPeer();
        }
      });

      // Prune inactive peers every 3 seconds
      _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _pruneStalePeers();
      });
    } catch (_) {
      // In case UDP broadcast binding fails (e.g. firewall restriction), fail gracefully
    }
  }

  void updateInfo({int? noteCount, int? port, String? pin}) {
    if (noteCount != null) _noteCount = noteCount;
    if (port != null) _port = port;
    if (pin != null) _pin = pin;
    _broadcastBeacon();
  }

  void _broadcastBeacon() {
    if (_socket == null || _myIp == null) return;

    try {
      final payload = json.encode({
        'protocol': 'wznotes-beacon',
        'deviceName': _deviceName,
        'ip': _myIp,
        'port': _port,
        'pin': _pin,
        'noteCount': _noteCount,
      });

      final bytes = utf8.encode(payload);
      // 1. General broadcast (255.255.255.255)
      _socket?.send(bytes, InternetAddress('255.255.255.255'), broadcastPort);

      // 2. Subnet directed broadcast (e.g. 192.168.1.255) to cross LAN-Wi-Fi bridges on routers
      final parts = _myIp!.split('.');
      if (parts.length == 4) {
        final subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
        _socket?.send(bytes, InternetAddress(subnetBroadcast), broadcastPort);
      }
    } catch (_) {}
  }

  /// Probes for a connected USB phone/device via local loopback port 8485
  Future<void> probeUsbPeer() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 800);
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:8485/api/status'));
      final resp = await req.close().timeout(const Duration(milliseconds: 1200));
      if (resp.statusCode == 200) {
        final bodyStr = await resp.transform(utf8.decoder).join();
        final data = json.decode(bodyStr) as Map<String, dynamic>;
        final rawName = (data['deviceName'] as String?) ?? 'Phone';
        final peerCount = (data['noteCount'] as int?) ?? 0;
        final peerPin = (data['pin'] as String?) ?? '';

        final peer = DiscoveredPeer(
          deviceName: '$rawName (USB Cable ⚡)',
          ip: '127.0.0.1',
          port: 8485,
          pin: peerPin,
          noteCount: peerCount,
          lastSeen: DateTime.now(),
        );

        _peers['127.0.0.1:8485'] = peer;
        _peersController.add(_peers.values.toList());
      }
      client.close();
    } catch (_) {}
  }

  /// Probes an IP directly via HTTP (ideal for LAN cable, USB tethering, or when UDP broadcast is blocked by router)
  Future<void> probeDirectPeer(String ip, [int port = 8484]) async {
    if (ip == _myIp) return;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1400);
      final req = await client.getUrl(Uri.parse('http://$ip:$port/api/status'));
      final resp = await req.close().timeout(const Duration(milliseconds: 2000));
      if (resp.statusCode == 200) {
        final bodyStr = await resp.transform(utf8.decoder).join();
        final data = json.decode(bodyStr) as Map<String, dynamic>;
        final peerName = (data['deviceName'] as String?) ?? 'Paired Device';

        if (ip == '127.0.0.1' && peerName.toLowerCase() == _deviceName.toLowerCase()) {
          client.close();
          return;
        }

        final peerCount = (data['noteCount'] as int?) ?? 0;
        final peerPin = (data['pin'] as String?) ?? '';

        final peer = DiscoveredPeer(
          deviceName: ip == '127.0.0.1' ? '$peerName (USB Cable ⚡)' : peerName,
          ip: ip,
          port: port,
          pin: peerPin,
          noteCount: peerCount,
          lastSeen: DateTime.now(),
        );

        _peers['$ip:$port'] = peer;
        _peersController.add(_peers.values.toList());
      }
      client.close();
    } catch (_) {}
  }

  void _handleIncomingPacket(Datagram datagram) {
    try {
      final rawStr = utf8.decode(datagram.data);
      final data = json.decode(rawStr) as Map<String, dynamic>;

      if (data['protocol'] != 'wznotes-beacon') return;

      final peerIp = (data['ip'] as String?) ?? datagram.address.address;
      // Ignore self-announcements
      if (peerIp == _myIp) return;

      final peerName = (data['deviceName'] as String?) ?? 'Nearby Device';
      final peerPort = (data['port'] as int?) ?? 8484;
      final peerPin = (data['pin'] as String?) ?? '';
      final peerCount = (data['noteCount'] as int?) ?? 0;

      final peer = DiscoveredPeer(
        deviceName: peerName,
        ip: peerIp,
        port: peerPort,
        pin: peerPin,
        noteCount: peerCount,
        lastSeen: DateTime.now(),
      );

      _peers['$peerIp:$peerPort'] = peer;
      _peersController.add(_peers.values.toList());
    } catch (_) {}
  }

  void _pruneStalePeers() {
    final now = DateTime.now();
    bool changed = false;

    _peers.removeWhere((key, peer) {
      if (now.difference(peer.lastSeen).inSeconds > 6) {
        changed = true;
        return true;
      }
      return false;
    });

    if (changed) {
      _peersController.add(_peers.values.toList());
    }
  }

  Future<void> stop() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _socket?.close();
    _socket = null;
    _peers.clear();
    _peersController.add([]);
  }

  void dispose() {
    stop();
    _peersController.close();
  }
}
