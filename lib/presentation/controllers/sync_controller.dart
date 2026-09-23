import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/sync/local_sync_client.dart';
import '../../infrastructure/sync/local_sync_server.dart';
import '../../infrastructure/sync/models/sync_models.dart';
import '../../infrastructure/sync/network_helper.dart';
import '../../infrastructure/sync/sync_discovery_service.dart';
import '../../infrastructure/sync/vault_backup_service.dart';
import 'notes_library_controller.dart';

enum SyncStatus {
  idle,
  hosting,
  connecting,
  syncing,
  success,
  error,
}

class SyncState {
  final SyncStatus status;
  final bool isHost;
  final String? localIp;
  final int port;
  final String pin;
  final String? peerAddress;
  final String progressMessage;
  final double progressPercent;
  final SyncResult? lastResult;
  final String? errorMessage;
  final List<DiscoveredPeer> discoveredPeers;
  final bool isDiscovering;

  const SyncState({
    this.status = SyncStatus.idle,
    this.isHost = false,
    this.localIp,
    this.port = 8484,
    this.pin = '',
    this.peerAddress,
    this.progressMessage = '',
    this.progressPercent = 0.0,
    this.lastResult,
    this.errorMessage,
    this.discoveredPeers = const [],
    this.isDiscovering = false,
  });

  String get qrPayload => 'opennotes://sync?ip=${localIp ?? ""}&port=$port&pin=$pin';

  SyncState copyWith({
    SyncStatus? status,
    bool? isHost,
    String? localIp,
    int? port,
    String? pin,
    String? peerAddress,
    String? progressMessage,
    double? progressPercent,
    SyncResult? lastResult,
    String? errorMessage,
    List<DiscoveredPeer>? discoveredPeers,
    bool? isDiscovering,
  }) {
    return SyncState(
      status: status ?? this.status,
      isHost: isHost ?? this.isHost,
      localIp: localIp ?? this.localIp,
      port: port ?? this.port,
      pin: pin ?? this.pin,
      peerAddress: peerAddress ?? this.peerAddress,
      progressMessage: progressMessage ?? this.progressMessage,
      progressPercent: progressPercent ?? this.progressPercent,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: errorMessage ?? this.errorMessage,
      discoveredPeers: discoveredPeers ?? this.discoveredPeers,
      isDiscovering: isDiscovering ?? this.isDiscovering,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  LocalSyncServer? _server;
  final SyncDiscoveryService _discoveryService = SyncDiscoveryService();
  StreamSubscription<List<DiscoveredPeer>>? _discoverySubscription;

  SyncNotifier(this._ref) : super(const SyncState()) {
    _initDefaults();
  }

  void _initDefaults() {
    final randomPin = (1000 + Random().nextInt(9000)).toString();
    state = state.copyWith(pin: randomPin);
  }

  String get _deviceName {
    if (Platform.isWindows) return 'Windows PC';
    if (Platform.isAndroid) return 'Android Phone';
    if (Platform.isIOS) return 'iPhone';
    if (Platform.isMacOS) return 'Mac';
    if (Platform.isLinux) return 'Linux PC';
    return 'OpenNotes Device';
  }

  /// Starts zero-config local Wi-Fi auto-discovery and readies the device for 1-tap sync
  Future<void> startAutoDiscovery() async {
    try {
      // 1. Start host server in background if not already started
      if (_server == null) {
        await startHostServer();
      }

      final notes = _ref.read(notesLibraryProvider).notes;
      await _discoveryService.start(
        deviceName: _deviceName,
        port: state.port,
        pin: state.pin,
        noteCount: notes.length,
      );

      _discoverySubscription?.cancel();
      _discoverySubscription = _discoveryService.peersStream.listen((peers) {
        state = state.copyWith(discoveredPeers: peers);
      });

      state = state.copyWith(
        isDiscovering: true,
        discoveredPeers: _discoveryService.peers,
      );

      // Probe USB connection (when phone is plugged into laptop via USB)
      _discoveryService.probeUsbPeer();

      // Probe last known peer IP directly (bypasses router LAN-Wi-Fi isolation)
      if (_lastKnownPeerIp != null) {
        _discoveryService.probeDirectPeer(_lastKnownPeerIp!, _lastKnownPeerPort);
      }
    } catch (_) {}
  }

  /// Instantly synchronizes notes over high-speed USB cable
  Future<void> syncViaUsb() async {
    if (Platform.isWindows) {
      await SyncDiscoveryService.setupAdbForwarding();
    }
    String targetPort = '8485';
    try {
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 500);
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:8485/api/status'));
      final resp = await req.close().timeout(const Duration(milliseconds: 800));
      if (resp.statusCode != 200) {
        targetPort = '8484';
      }
      client.close();
    } catch (_) {
      targetPort = '8484';
    }

    await syncWithPeer(
      peerIp: '127.0.0.1',
      peerPort: targetPort,
      pin: '',
    );
  }

  String? _lastKnownPeerIp;
  int _lastKnownPeerPort = 8484;

  /// Probes a specific IP directly (e.g. PC on Ethernet LAN cable)
  Future<void> probeCustomIp(String ip, [int port = 8484]) async {
    _lastKnownPeerIp = ip;
    _lastKnownPeerPort = port;
    await _discoveryService.probeDirectPeer(ip, port);
  }

  /// Stops zero-config auto-discovery
  Future<void> stopAutoDiscovery() async {
    await _discoveryService.stop();
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    state = state.copyWith(isDiscovering: false, discoveredPeers: []);
  }

  /// Performs effortless 1-tap sync with an auto-discovered peer device
  Future<void> syncWithDiscoveredPeer(DiscoveredPeer peer) async {
    await syncWithPeer(
      peerIp: peer.ip,
      peerPort: peer.port.toString(),
      pin: peer.pin,
    );
  }

  /// Exports all notes as a single .wzbackup file for offline/cloud/USB sync
  Future<VaultBackupResult> exportVault() async {
    final notes = _ref.read(notesLibraryProvider).notes;
    return await VaultBackupService.exportVault(
      notes: notes,
      deviceName: _deviceName,
    );
  }

  /// Imports and merges notes from a .wzbackup archive file
  Future<int> importVault(File file) async {
    final docs = await VaultBackupService.importVaultFromFile(file);
    if (docs.isNotEmpty) {
      _ref.read(notesLibraryProvider.notifier).importSyncedNotes(docs);
    }
    return docs.length;
  }

  /// Starts the local Wi-Fi sync server (Host Mode)
  Future<void> startHostServer() async {
    try {
      state = state.copyWith(
        status: SyncStatus.hosting,
        isHost: true,
        progressMessage: 'Initializing local sync server...',
      );

      final ip = await NetworkHelper.getLocalIpAddress();

      _server = LocalSyncServer(
        port: state.port,
        pin: state.pin,
        deviceName: _deviceName,
        onGetManifest: () {
          return _ref.read(notesLibraryProvider.notifier).getSyncManifest(
                deviceName: _deviceName,
              );
        },
        onGetNotes: (ids) {
          return _ref.read(notesLibraryProvider.notifier).getNotesByIds(ids);
        },
        onSaveNotes: (incoming) {
          _ref.read(notesLibraryProvider.notifier).importSyncedNotes(incoming);
        },
        onDeleteNotes: (ids) {
          _ref.read(notesLibraryProvider.notifier).batchDeleteNotes(ids);
        },
      );

      final actualPort = await _server!.start();

      state = state.copyWith(
        localIp: ip ?? '127.0.0.1',
        port: actualPort,
        status: SyncStatus.hosting,
        progressMessage: 'Waiting for device to connect...',
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: 'Failed to start host server: $e',
      );
    }
  }

  /// Stops the local host server
  Future<void> stopHostServer() async {
    if (_server != null) {
      await _server!.stop();
      _server = null;
    }
    state = state.copyWith(
      status: SyncStatus.idle,
      isHost: false,
      progressMessage: '',
      progressPercent: 0.0,
    );
  }

  /// Connects to a peer host server and executes bidirectional sync
  Future<void> syncWithPeer({
    required String peerIp,
    required String peerPort,
    required String pin,
  }) async {
    try {
      state = state.copyWith(
        status: SyncStatus.connecting,
        progressMessage: 'Connecting to $peerIp:$peerPort...',
        progressPercent: 0.1,
        errorMessage: null,
      );

      final client = LocalSyncClient(
        serverAddress: '$peerIp:$peerPort',
        pin: pin,
      );

      final localManifest = _ref.read(notesLibraryProvider.notifier).getSyncManifest(
            deviceName: _deviceName,
          );

      state = state.copyWith(
        status: SyncStatus.syncing,
      );

      final result = await client.performSync(
        localManifest: localManifest,
        getLocalNotes: (ids) => _ref.read(notesLibraryProvider.notifier).getNotesByIds(ids),
        onSaveIncomingNotes: (incoming) =>
            _ref.read(notesLibraryProvider.notifier).importSyncedNotes(incoming),
        onDeleteLocalNotes: (ids) =>
            _ref.read(notesLibraryProvider.notifier).batchDeleteNotes(ids),
        onProgress: (msg, pct) {
          state = state.copyWith(
            progressMessage: msg,
            progressPercent: pct,
          );
        },
      );

      if (result.success) {
        _lastKnownPeerIp = peerIp;
        _lastKnownPeerPort = int.tryParse(peerPort) ?? 8484;
        state = state.copyWith(
          status: SyncStatus.success,
          lastResult: result,
          progressMessage:
              'Sync successful! Uploaded: ${result.notesUploaded}, Downloaded: ${result.notesDownloaded}',
          progressPercent: 1.0,
        );
      } else {
        state = state.copyWith(
          status: SyncStatus.error,
          errorMessage: result.errorMessage ?? 'Sync failed',
          progressPercent: 0.0,
        );
      }
    } catch (e) {
      final err = e.toString();
      String friendlyMessage = err;
      if (err.contains('TimeoutException') || err.contains('OS Error') || err.contains('Failed host lookup')) {
        friendlyMessage = 'Connection timed out connecting to $peerIp:$peerPort.\n\n'
            'Your Wi-Fi router is blocking direct traffic between the PC (Ethernet cable) and Phone (Wi-Fi).\n\n'
            'Quick solutions:\n'
            '• Plug phone into PC via USB cable and tap "⚡ Sync via USB"\n'
            '• Connect PC to Wi-Fi instead of Ethernet cable\n'
            '• Keep WZNotes open on your phone\n'
            '• Use 1-click "Export Vault" to transfer offline';
      }
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: friendlyMessage,
        progressPercent: 0.0,
      );
    }
  }

  /// Parses a scanned QR payload (e.g. opennotes://sync?ip=192.168.1.5&port=8484&pin=1234)
  Map<String, String>? parseQrPayload(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme == 'opennotes' && uri.host == 'sync') {
        return {
          'ip': uri.queryParameters['ip'] ?? '',
          'port': uri.queryParameters['port'] ?? '8484',
          'pin': uri.queryParameters['pin'] ?? '',
        };
      }
    } catch (_) {}
    return null;
  }

  void resetStatus() {
    state = state.copyWith(
      status: SyncStatus.idle,
      errorMessage: null,
      progressMessage: '',
      progressPercent: 0.0,
    );
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _discoveryService.dispose();
    _server?.stop();
    super.dispose();
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});
