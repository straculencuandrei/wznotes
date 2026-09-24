import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wznotes/presentation/controllers/sync_controller.dart';

void main() {
  group('Sync QR Payload & Parser Tests', () {
    late ProviderContainer container;
    late SyncNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(syncProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('qrPayload generates standard https universal link format', () {
      const state = SyncState(
        localIp: '192.168.1.50',
        port: 8484,
        pin: '4321',
      );
      expect(state.qrPayload, 'https://wznotes.app/sync?ip=192.168.1.50&port=8484&pin=4321');
    });

    test('parseQrPayload parses universal https link accurately', () {
      final parsed = notifier.parseQrPayload('https://wznotes.app/sync?ip=192.168.1.50&port=8484&pin=4321');
      expect(parsed, isNotNull);
      expect(parsed!['ip'], '192.168.1.50');
      expect(parsed['port'], '8484');
      expect(parsed['pin'], '4321');
    });

    test('parseQrPayload parses legacy opennotes custom scheme', () {
      final parsed = notifier.parseQrPayload('opennotes://sync?ip=10.0.0.2&port=9090&pin=7777');
      expect(parsed, isNotNull);
      expect(parsed!['ip'], '10.0.0.2');
      expect(parsed['port'], '9090');
      expect(parsed['pin'], '7777');
    });

    test('parseQrPayload parses wznotes custom scheme', () {
      final parsed = notifier.parseQrPayload('wznotes://sync?ip=172.16.0.4&port=8484&pin=1122');
      expect(parsed, isNotNull);
      expect(parsed!['ip'], '172.16.0.4');
      expect(parsed['port'], '8484');
      expect(parsed['pin'], '1122');
    });

    test('parseQrPayload rejects invalid or empty strings', () {
      expect(notifier.parseQrPayload(''), isNull);
      expect(notifier.parseQrPayload('hello world'), isNull);
      expect(notifier.parseQrPayload('https://google.com'), isNull);
    });
  });
}
