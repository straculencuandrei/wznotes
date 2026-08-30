import 'dart:io';

class NetworkHelper {
  /// Discovers the most suitable local IPv4 address (e.g. 192.168.x.x, 10.x.x.x)
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // Prioritize Wi-Fi and Ethernet interfaces
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        final isLikelyPrimary = name.contains('wi-fi') ||
            name.contains('wlan') ||
            name.contains('eth') ||
            name.contains('en0') ||
            name.contains('ethernet');

        for (final addr in interface.addresses) {
          if (!addr.isLoopback &&
              addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('169.254')) {
            if (isLikelyPrimary) {
              return addr.address;
            }
          }
        }
      }

      // Fallback: return first non-loopback IPv4
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback &&
              addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('169.254')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
