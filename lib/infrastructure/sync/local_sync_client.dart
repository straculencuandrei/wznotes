import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/note_document.dart';
import '../sync/models/sync_models.dart';
import '../sync/sync_engine.dart';

class LocalSyncClient {
  final String serverAddress; // e.g. "192.168.1.50:8484"
  final String pin;

  LocalSyncClient({
    required this.serverAddress,
    required this.pin,
  });

  String get _baseUrl {
    if (serverAddress.startsWith('http://') || serverAddress.startsWith('https://')) {
      return serverAddress;
    }
    return 'http://$serverAddress';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Sync-Pin': pin,
      };

  /// Tests connection to server and retrieves status
  Future<Map<String, dynamic>> checkStatus() async {
    final uri = Uri.parse('$_baseUrl/api/status');
    final res = await http.get(uri).timeout(const Duration(seconds: 4));
    if (res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception('Server returned status ${res.statusCode}');
    }
  }

  /// Probes USB loopback endpoints to see if a phone is connected via ADB tunnel
  Future<String?> _detectUsbFallbackUrl() async {
    for (final port in [8485, 8484]) {
      try {
        final uri = Uri.parse('http://127.0.0.1:$port/api/status');
        final res = await http.get(uri).timeout(const Duration(milliseconds: 1000));
        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          final name = ((data['deviceName'] as String?) ?? '').toLowerCase();
          // If port 8485 responded, or port 8484 isn't a Windows PC self-server
          if (port == 8485 || (!name.contains('windows') && !name.contains('desktop'))) {
            return 'http://127.0.0.1:$port';
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Runs full bidirectional synchronization against host
  Future<SyncResult> performSync({
    required SyncManifest localManifest,
    required List<NoteDocument> Function(List<String> ids) getLocalNotes,
    required void Function(List<NoteDocument> incoming) onSaveIncomingNotes,
    required void Function(List<String> deletedIds) onDeleteLocalNotes,
    void Function(String status, double progress)? onProgress,
  }) async {
    String activeBaseUrl = _baseUrl;
    try {
      onProgress?.call('Connecting to peer...', 0.1);

      // Step 1: Exchange manifests with snappy 3.5s timeout
      http.Response? manifestRes;
      try {
        final manifestUri = Uri.parse('$activeBaseUrl/api/manifest');
        manifestRes = await http
            .post(
              manifestUri,
              headers: _headers,
              body: json.encode(localManifest.toJson()),
            )
            .timeout(const Duration(milliseconds: 3500));
      } catch (e) {
        // If Wi-Fi failed, check if USB loopback is online
        if (!activeBaseUrl.contains('127.0.0.1')) {
          final usbUrl = await _detectUsbFallbackUrl();
          if (usbUrl != null) {
            onProgress?.call('Switching to fast USB connection...', 0.15);
            activeBaseUrl = usbUrl;
            try {
              manifestRes = await http
                  .post(
                    Uri.parse('$activeBaseUrl/api/manifest'),
                    headers: _headers,
                    body: json.encode(localManifest.toJson()),
                  )
                  .timeout(const Duration(seconds: 4));
            } catch (_) {}
          }
        }

        if (manifestRes == null) {
          return SyncResult.failure(
            'Connection timed out connecting to $serverAddress.\n\n'
            'Your Wi-Fi router is blocking direct traffic between the PC (Ethernet cable) and Phone (Wi-Fi).\n\n'
            'Quick solutions:\n'
            '• Plug phone into PC via USB cable and tap "⚡ Sync via USB"\n'
            '• Connect PC to Wi-Fi instead of Ethernet cable\n'
            '• Keep WZNotes open on the phone on the Sync screen\n'
            '• Use 1-click "Export Vault" to transfer offline',
          );
        }
      }

      if (manifestRes.statusCode != 200) {
        return SyncResult.failure('Failed to exchange manifests (${manifestRes.statusCode})');
      }

      final peerManifestJson = json.decode(manifestRes.body) as Map<String, dynamic>;
      final peerManifest = SyncManifest.fromJson(peerManifestJson);

      onProgress?.call('Computing changes...', 0.3);

      // Step 2: Calculate 2-way delta
      final delta = SyncEngine.calculateDelta(
        localManifest: localManifest,
        peerManifest: peerManifest,
      );

      int uploadedCount = 0;
      int downloadedCount = 0;
      int deletedCount = 0;

      // Step 3: Send notes needed by peer (Push)
      if (delta.notesToSend.isNotEmpty) {
        onProgress?.call('Uploading ${delta.notesToSend.length} notes...', 0.5);
        final notesToSendDocs = getLocalNotes(delta.notesToSend);
        final pushUri = Uri.parse('$activeBaseUrl/api/push');
        final pushRes = await http
            .post(
              pushUri,
              headers: _headers,
              body: json.encode({
                'notes': notesToSendDocs.map((n) => n.toJson()).toList(),
              }),
            )
            .timeout(const Duration(seconds: 15));
        if (pushRes.statusCode == 200) {
          uploadedCount = notesToSendDocs.length;
        }
      }

      // Step 4: Fetch notes needed locally (Pull)
      if (delta.notesToFetch.isNotEmpty) {
        onProgress?.call('Downloading ${delta.notesToFetch.length} notes...', 0.7);
        final pullUri = Uri.parse('$activeBaseUrl/api/pull');
        final pullRes = await http
            .post(
              pullUri,
              headers: _headers,
              body: json.encode({'ids': delta.notesToFetch}),
            )
            .timeout(const Duration(seconds: 15));
        if (pullRes.statusCode == 200) {
          final data = json.decode(pullRes.body) as Map<String, dynamic>;
          final incomingRaw = data['notes'] as List<dynamic>? ?? [];
          final List<NoteDocument> incomingDocs = [];
          for (final raw in incomingRaw) {
            try {
              incomingDocs.add(NoteDocument.fromJson(raw as Map<String, dynamic>));
            } catch (_) {}
          }
          onSaveIncomingNotes(incomingDocs);
          downloadedCount = incomingDocs.length;
        }
      }

      // Step 5: Delete locally if deleted on peer
      if (delta.notesToDeleteLocally.isNotEmpty) {
        onProgress?.call('Applying deletions...', 0.85);
        onDeleteLocalNotes(delta.notesToDeleteLocally);
        deletedCount += delta.notesToDeleteLocally.length;
      }

      // Step 6: Send local tombstones to peer
      if (delta.tombstonesToSend.isNotEmpty) {
        final tombUri = Uri.parse('$activeBaseUrl/api/tombstones');
        await http
            .post(
              tombUri,
              headers: _headers,
              body: json.encode({'ids': delta.tombstonesToSend}),
            )
            .timeout(const Duration(seconds: 10));
      }

      onProgress?.call('Sync complete!', 1.0);

      return SyncResult(
        success: true,
        notesUploaded: uploadedCount,
        notesDownloaded: downloadedCount,
        notesDeleted: deletedCount,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('TimeoutException') || msg.contains('OS Error') || msg.contains('Failed host lookup')) {
        return SyncResult.failure(
          'Connection timed out connecting to $serverAddress.\n\n'
          'Your Wi-Fi router is blocking direct traffic between the PC (Ethernet) and Phone (Wi-Fi).\n\n'
          'Quick solutions:\n'
          '• Plug phone into PC via USB cable and tap "⚡ Sync via USB"\n'
          '• Connect PC to Wi-Fi instead of Ethernet cable\n'
          '• Keep WZNotes open on your phone\n'
          '• Use 1-click "Export Vault" to transfer offline',
        );
      }
      return SyncResult.failure(msg);
    }
  }
}
