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

/// Zero-Config Local Wi-Fi Discovery Service using UDP Broadcast Beacons
class SyncDiscoveryService {
  static const int broadcastPort = 8488;
  RawDatagramSocket? _socket;
  Timer? _beaconTimer;
  Timer? _cleanupTimer;

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

      // Recurring beacon every 1.5 seconds
      _beaconTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        _broadcastBeacon();
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
      _socket?.send(bytes, InternetAddress('255.255.255.255'), broadcastPort);
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

      _peers[peerIp] = peer;
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
