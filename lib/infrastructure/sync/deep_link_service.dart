import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../presentation/controllers/sync_controller.dart';
import '../../presentation/screens/sync_screen.dart';
import '../../presentation/widgets/top_island_toast.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('dev.opennotes.app/deep_link');
  static final StreamController<Map<String, String>> _syncPayloadController =
      StreamController<Map<String, String>>.broadcast();

  static Stream<Map<String, String>> get syncPayloadStream => _syncPayloadController.stream;

  static bool _initialized = false;
  static bool isSyncScreenActive = false;

  /// Initializes deep link listening on Android/iOS
  static Future<void> init(SyncNotifier syncNotifier) async {
    if (_initialized) return;
    _initialized = true;

    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final link = call.arguments as String?;
        if (link != null && link.isNotEmpty) {
          _handleIncomingLink(link, syncNotifier);
        }
      }
    });

    // Check if app was cold-started from a deep link
    try {
      final initialLink = await _channel.invokeMethod<String>('getInitialLink');
      if (initialLink != null && initialLink.isNotEmpty) {
        _handleIncomingLink(initialLink, syncNotifier);
      }
    } catch (_) {}
  }

  static void _handleIncomingLink(String link, SyncNotifier syncNotifier) {
    final payload = syncNotifier.parseQrPayload(link);
    if (payload == null) return;

    final ip = payload['ip'] ?? '';
    final port = payload['port'] ?? '8484';
    final pin = payload['pin'] ?? '';

    if (ip.isEmpty) return;

    // Notify any active listener (e.g. SyncScreen)
    _syncPayloadController.add(payload);

    // If SyncScreen is not currently open, navigate to it automatically
    if (!isSyncScreenActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navState = rootNavigatorKey.currentState;
        final context = rootNavigatorKey.currentContext;
        if (navState != null) {
          navState.push<void>(
            MaterialPageRoute(
              builder: (_) => SyncScreen(
                initialPeerIp: ip,
                initialPeerPort: port,
                initialPeerPin: pin,
                autoConnect: true,
              ),
            ),
          );

          if (context != null) {
            TopIslandToast.show(
              context,
              message: 'Scanned PC QR: $ip (PIN $pin)',
              icon: Icons.qr_code_scanner_rounded,
            );
          }
        }
      });
    }
  }

  /// Manually dispatch a parsed payload (e.g. from in-app camera scanner)
  static void dispatchPayload(Map<String, String> payload) {
    _syncPayloadController.add(payload);
  }
}
