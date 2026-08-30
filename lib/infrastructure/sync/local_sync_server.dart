import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../domain/models/note_document.dart';
import '../sync/models/sync_models.dart';

typedef GetLocalManifestCallback = SyncManifest Function();
typedef GetNotesByIdsCallback = List<NoteDocument> Function(List<String> ids);
typedef SaveIncomingNotesCallback = void Function(List<NoteDocument> notes);
typedef DeleteNotesCallback = void Function(List<String> ids);

class LocalSyncServer {
  HttpServer? _server;
  final int port;
  final String pin;
  final String deviceName;

  final GetLocalManifestCallback onGetManifest;
  final GetNotesByIdsCallback onGetNotes;
  final SaveIncomingNotesCallback onSaveNotes;
  final DeleteNotesCallback onDeleteNotes;

  bool get isRunning => _server != null;

  LocalSyncServer({
    this.port = 8484,
    required this.pin,
    required this.deviceName,
    required this.onGetManifest,
    required this.onGetNotes,
    required this.onSaveNotes,
    required this.onDeleteNotes,
  });

  Future<int> start() async {
    await stop();
    // Try requested port or any available port if busy
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    } catch (_) {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }

    _server!.listen(_handleRequest);
    return _server!.port;
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Add CORS headers for flexibility
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, X-Sync-Pin');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    // PIN Authentication check (except for public status info)
    final providedPin = request.headers.value('X-Sync-Pin');
    if (path != '/api/status' && providedPin != pin) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.write(json.encode({'error': 'Invalid PIN'}));
      await request.response.close();
      return;
    }

    try {
      if (path == '/api/status' && request.method == 'GET') {
        _respondJson(request, {
          'status': 'online',
          'deviceName': deviceName,
          'version': '1.0.0',
        });
      } else if (path == '/api/manifest' && request.method == 'POST') {
        final bodyStr = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> jsonMap = json.decode(bodyStr) as Map<String, dynamic>;
        final _ = SyncManifest.fromJson(jsonMap);

        final localManifest = onGetManifest();
        _respondJson(request, localManifest.toJson());
      } else if (path == '/api/pull' && request.method == 'POST') {
        final bodyStr = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> jsonMap = json.decode(bodyStr) as Map<String, dynamic>;
        final requestedIds = (jsonMap['ids'] as List<dynamic>?)?.cast<String>() ?? [];

        final notes = onGetNotes(requestedIds);
        _respondJson(request, {
          'notes': notes.map((n) => n.toJson()).toList(),
        });
      } else if (path == '/api/push' && request.method == 'POST') {
        final bodyStr = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> jsonMap = json.decode(bodyStr) as Map<String, dynamic>;
        final incomingRaw = jsonMap['notes'] as List<dynamic>? ?? [];

        final List<NoteDocument> incomingDocs = [];
        for (final raw in incomingRaw) {
          try {
            incomingDocs.add(NoteDocument.fromJson(raw as Map<String, dynamic>));
          } catch (_) {}
        }

        onSaveNotes(incomingDocs);
        _respondJson(request, {'success': true, 'saved': incomingDocs.length});
      } else if (path == '/api/tombstones' && request.method == 'POST') {
        final bodyStr = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> jsonMap = json.decode(bodyStr) as Map<String, dynamic>;
        final deleteIds = (jsonMap['ids'] as List<dynamic>?)?.cast<String>() ?? [];

        onDeleteNotes(deleteIds);
        _respondJson(request, {'success': true, 'deleted': deleteIds.length});
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(json.encode({'error': 'Endpoint not found'}));
        await request.response.close();
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(json.encode({'error': e.toString()}));
      await request.response.close();
    }
  }

  void _respondJson(HttpRequest request, Map<String, dynamic> data) {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(json.encode(data));
    request.response.close();
  }
}
