import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/sync_controller.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '8484');
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);
    final syncNotifier = ref.read(syncProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.amoledBlack,
      appBar: AppBar(
        backgroundColor: AppColors.amoledBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () {
            if (syncState.isHost) {
              syncNotifier.stopHostServer();
            }
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Wi-Fi Device Sync',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.samsungOrange,
          indicatorWeight: 3,
          labelColor: AppColors.samsungOrange,
          unselectedLabelColor: AppColors.amoledTextSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_2), text: 'Host on this Device'),
            Tab(icon: Icon(Icons.sync_alt), text: 'Connect & Sync'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHostTab(syncState, syncNotifier),
          _buildConnectTab(syncState, syncNotifier),
        ],
      ),
    );
  }

  Widget _buildHostTab(SyncState state, SyncNotifier notifier) {
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.amoledSurface,
            borderRadius: BorderRadius.all(Radius.circular(16)),
            border: Border.fromBorderSide(BorderSide(color: AppColors.amoledBorder)),
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_tethering, color: AppColors.samsungOrange, size: 28),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direct Local Wi-Fi Sync',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Free & private peer-to-peer sync. Both devices must be on the same Wi-Fi.',
                      style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (!state.isHost) ...[
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.samsungOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: const Text(
                'Start Sync Server',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () => notifier.startHostServer(),
            ),
          ),
        ] else ...[
          // Host Active Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.amoledSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.samsungOrange.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.accentEmerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Server Online & Ready',
                      style: TextStyle(color: AppColors.accentEmerald, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // QR Code
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: state.qrPayload,
                    version: QrVersions.auto,
                    size: 180.0,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // IP & PIN Details
                _buildInfoRow('Local IP Address', state.localIp ?? 'Discovering...'),
                _buildInfoRow('Port', '${state.port}'),
                _buildInfoRow('Security PIN', state.pin, isHighlight: true),

                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop Server'),
                  onPressed: () => notifier.stopHostServer(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConnectTab(SyncState state, SyncNotifier notifier) {
    final isBusy = state.status == SyncStatus.connecting || state.status == SyncStatus.syncing;

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.amoledSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.amoledBorder),
          ),
          child: const Text(
            'Enter the IP Address and PIN shown on your other device to synchronize your notes library.',
            style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 20),

        // IP Input
        TextField(
          controller: _ipController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Peer IP Address (e.g. 192.168.1.50)',
            labelStyle: const TextStyle(color: AppColors.amoledTextSecondary),
            prefixIcon: const Icon(Icons.computer, color: AppColors.samsungOrange),
            filled: true,
            fillColor: AppColors.amoledSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _portController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Port',
                  labelStyle: const TextStyle(color: AppColors.amoledTextSecondary),
                  prefixIcon: const Icon(Icons.numbers, color: AppColors.samsungOrange),
                  filled: true,
                  fillColor: AppColors.amoledSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _pinController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: '4-Digit PIN',
                  counterText: '',
                  labelStyle: const TextStyle(color: AppColors.amoledTextSecondary),
                  prefixIcon: const Icon(Icons.lock, color: AppColors.samsungOrange),
                  filled: true,
                  fillColor: AppColors.amoledSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Progress & Status UI
        if (state.status != SyncStatus.idle) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.amoledSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: state.status == SyncStatus.error
                    ? Colors.redAccent
                    : (state.status == SyncStatus.success ? AppColors.accentEmerald : AppColors.samsungOrange),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isBusy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.samsungOrange),
                      )
                    else if (state.status == SyncStatus.success)
                      const Icon(Icons.check_circle, color: AppColors.accentEmerald, size: 20)
                    else if (state.status == SyncStatus.error)
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.errorMessage ?? state.progressMessage,
                        style: TextStyle(
                          color: state.status == SyncStatus.error ? Colors.redAccent : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isBusy) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: state.progressPercent > 0 ? state.progressPercent : null,
                    backgroundColor: AppColors.amoledBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.samsungOrange),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Sync Now Button
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.samsungOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(
              isBusy ? 'Syncing...' : 'Sync Now',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: isBusy
                ? null
                : () {
                    final ip = _ipController.text.trim();
                    final port = _portController.text.trim();
                    final pin = _pinController.text.trim();

                    if (ip.isEmpty || pin.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter Peer IP and PIN')),
                      );
                      return;
                    }

                    notifier.syncWithPeer(
                      peerIp: ip,
                      peerPort: port.isNotEmpty ? port : '8484',
                      pin: pin,
                    );
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.amoledTextSecondary, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? AppColors.samsungOrange : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
