import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/sync/local_sync_client.dart';
import '../../infrastructure/sync/local_sync_server.dart';
import '../../infrastructure/sync/models/sync_models.dart';
import '../../infrastructure/sync/network_helper.dart';
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
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  LocalSyncServer? _server;

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
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
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
    _server?.stop();
    super.dispose();
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});
