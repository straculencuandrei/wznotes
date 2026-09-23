import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../infrastructure/sync/sync_discovery_service.dart';
import '../controllers/sync_controller.dart';
import '../widgets/top_island_toast.dart';

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

  List<File> _availableBackups = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Automatically start local network discovery upon entering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncProvider.notifier).startAutoDiscovery();
      _scanLocalVaultBackups();
    });
  }

  @override
  void dispose() {
    // Stop discovery
    ref.read(syncProvider.notifier).stopAutoDiscovery();
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _scanLocalVaultBackups() async {
    try {
      Directory? outDir;
      if (Platform.isAndroid) {
        outDir = Directory('/storage/emulated/0/Documents/WZNotes');
        if (!outDir.existsSync()) {
          outDir = await getExternalStorageDirectory();
        }
      } else {
        outDir = await getApplicationDocumentsDirectory();
      }

      if (outDir != null && outDir.existsSync()) {
        final files = outDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.wzbackup'))
            .toList();
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        if (mounted) {
          setState(() {
            _availableBackups = files;
          });
        }
      }
    } catch (_) {}
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
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          tabs: const [
            Tab(icon: Icon(Icons.flash_on_rounded), text: '1-Tap Nearby & Vault'),
            Tab(icon: Icon(Icons.settings_input_antenna_rounded), text: 'Manual Wi-Fi Sync'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuickSyncTab(syncState, syncNotifier),
          _buildManualSyncTab(syncState, syncNotifier),
        ],
      ),
    );
  }

  // --- TAB 1: 1-TAP NEARBY & VAULT SYNC ---
  Widget _buildQuickSyncTab(SyncState state, SyncNotifier notifier) {
    final isBusy = state.status == SyncStatus.syncing || state.status == SyncStatus.connecting;

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        // 0. High-Speed USB Cable Sync Card
        _buildUsbQuickSyncCard(state, notifier, isBusy),

        // 1. Nearby Devices Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.amoledSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.amoledBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.samsungOrange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.radar_rounded, color: AppColors.samsungOrange, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nearby Devices on Wi-Fi',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'Zero-config auto-discovery. No IP or PIN typing required.',
                          style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (state.discoveredPeers.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF262626)),
                  ),
                  child: const Column(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.samsungOrange),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Scanning Wi-Fi for nearby devices...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Open WZNotes on your phone or PC on the same Wi-Fi.\nDevices will appear here automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ...state.discoveredPeers.map((peer) => _buildDiscoveredPeerCard(peer, notifier, isBusy)),
              ],

              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.amoledTextSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: const Icon(Icons.lan_outlined, size: 16, color: AppColors.samsungOrange),
                  label: const Text(
                    'PC on Ethernet LAN cable? Tap to pair directly',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _showFindLanDeviceDialog(context, notifier),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 2. Cloud & USB Vault Backup Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.amoledSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.amoledBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: AppColors.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cloud & File Vault Backup',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'Sync via Google Drive, OneDrive, USB, or Quick Share in 1 file.',
                          style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  // Export Vault Button
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF222222),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF383838)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 18, color: AppColors.samsungOrange),
                      label: const Text('Export Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () async {
                        final res = await notifier.exportVault();
                        if (mounted) {
                          TopIslandToast.show(
                            context,
                            message: res.message,
                            icon: res.success ? Icons.check_circle_rounded : Icons.error_outline,
                            color: res.success ? AppColors.accentEmerald : Colors.redAccent,
                          );
                          _scanLocalVaultBackups();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Open Folder Button
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: AppColors.amoledBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.folder_open_rounded, size: 18, color: Colors.white70),
                      label: const Text('Open Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () async {
                        try {
                          Directory? outDir;
                          if (Platform.isAndroid) {
                            outDir = Directory('/storage/emulated/0/Documents/WZNotes');
                          } else {
                            outDir = await getApplicationDocumentsDirectory();
                          }
                          if (outDir.existsSync()) {
                            await OpenFilex.open(outDir.path);
                          }
                        } catch (_) {}
                      },
                    ),
                  ),
                ],
              ),

              if (_availableBackups.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Available Vault Backups to Restore:',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ..._availableBackups.take(3).map((f) {
                  final name = p.basename(f.path);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF282828)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: AppColors.samsungOrange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final count = await notifier.importVault(f);
                            if (mounted) {
                              TopIslandToast.show(
                                context,
                                message: 'Restored & merged $count notes!',
                                icon: Icons.check_circle_rounded,
                                color: AppColors.accentEmerald,
                              );
                            }
                          },
                          child: const Text('Merge', style: TextStyle(color: AppColors.samsungOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 3. Progress Card
        if (state.progressMessage.isNotEmpty || state.errorMessage != null)
          _buildProgressCard(state, notifier, isBusy),
      ],
    );
  }

  Widget _buildUsbQuickSyncCard(SyncState state, SyncNotifier notifier, bool isBusy) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.samsungOrange.withValues(alpha: 0.16),
            const Color(0xFF1A1A1A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.samsungOrange.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.samsungOrange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.usb_rounded, color: AppColors.samsungOrange, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '1-Tap USB Cable Sync',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '⚡ Instant',
                      style: TextStyle(color: AppColors.samsungOrange, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  'Bypasses Wi-Fi router isolation. Plug phone to PC via USB.',
                  style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.samsungOrange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: isBusy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.bolt_rounded, size: 16, color: Colors.black),
            label: Text(
              isBusy ? 'Syncing...' : 'Sync USB',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.black),
            ),
            onPressed: isBusy ? null : () => notifier.syncViaUsb(),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredPeerCard(DiscoveredPeer peer, SyncNotifier notifier, bool isBusy) {
    final isUsb = peer.ip == '127.0.0.1' || peer.deviceName.contains('USB');
    final isMobile = !isUsb && (peer.deviceName.toLowerCase().contains('phone') || peer.deviceName.toLowerCase().contains('android'));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUsb ? AppColors.accentEmerald.withValues(alpha: 0.6) : AppColors.samsungOrange.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUsb ? AppColors.accentEmerald.withValues(alpha: 0.15) : AppColors.samsungOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isUsb
                  ? Icons.usb_rounded
                  : (isMobile ? Icons.phone_android_rounded : Icons.laptop_windows_rounded),
              color: isUsb ? AppColors.accentEmerald : AppColors.samsungOrange,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        peer.deviceName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUsb) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentEmerald.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('⚡ FAST', style: TextStyle(color: AppColors.accentEmerald, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isUsb ? 'USB Cable Loopback • ${peer.noteCount} notes' : '${peer.ip} • ${peer.noteCount} notes',
                  style: const TextStyle(color: AppColors.amoledTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isUsb ? AppColors.accentEmerald : AppColors.samsungOrange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : Icon(isUsb ? Icons.bolt_rounded : Icons.sync_rounded, size: 18, color: Colors.black),
            label: Text(
              isBusy ? 'Syncing...' : (isUsb ? '1-Tap USB' : '1-Tap Sync'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
            ),
            onPressed: isBusy ? null : () => notifier.syncWithDiscoveredPeer(peer),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: MANUAL WI-FI SYNC ---
  Widget _buildManualSyncTab(SyncState state, SyncNotifier notifier) {
    final isBusy = state.status == SyncStatus.syncing || state.status == SyncStatus.connecting;

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        // Host Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.amoledSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.amoledBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.wifi_tethering, color: AppColors.samsungOrange, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Direct Host Server Details',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInfoRow('Local IP Address', state.localIp ?? 'Detecting...'),
              _buildInfoRow('Server Port', '${state.port}'),
              _buildInfoRow('Pairing PIN', state.pin, isHighlight: true),
              const SizedBox(height: 14),
              if (state.localIp != null) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: state.qrPayload,
                      version: QrVersions.auto,
                      size: 160.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Connect Form
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.amoledSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.amoledBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect to IP Directly',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ipController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Peer IP Address',
                  labelStyle: const TextStyle(color: AppColors.amoledTextSecondary),
                  hintText: 'e.g. 192.168.1.100',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _portController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Port',
                        labelStyle: const TextStyle(color: AppColors.amoledTextSecondary),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _pinController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'PIN Code',
                        labelStyle: const TextStyle(color: AppColors.amoledTextSecondary),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.samsungOrange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.sync_rounded, color: Colors.black),
                  label: const Text('Connect & Sync', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  onPressed: isBusy
                      ? null
                      : () {
                          final ip = _ipController.text.trim();
                          final port = _portController.text.trim();
                          final pin = _pinController.text.trim();
                          if (ip.isEmpty || pin.isEmpty) return;
                          notifier.syncWithPeer(peerIp: ip, peerPort: port.isNotEmpty ? port : '8484', pin: pin);
                        },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        if (state.progressMessage.isNotEmpty || state.errorMessage != null)
          _buildProgressCard(state, notifier, isBusy),
      ],
    );
  }

  Widget _buildProgressCard(SyncState state, SyncNotifier notifier, bool isBusy) {
    final isError = state.status == SyncStatus.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amoledSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError ? Colors.redAccent.withValues(alpha: 0.8) : AppColors.amoledBorder,
          width: isError ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.samsungOrange),
                  ),
                )
              else if (state.status == SyncStatus.success)
                const Icon(Icons.check_circle, color: AppColors.accentEmerald, size: 20)
              else if (isError)
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.errorMessage ?? state.progressMessage,
                  style: TextStyle(
                    color: isError ? const Color(0xFFFF6B6B) : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
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
          if (isError) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.samsungOrange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.black),
                  label: const Text('Sync via USB Cable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => notifier.syncViaUsb(),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.amoledBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 16, color: AppColors.samsungOrange),
                  label: const Text('Export Vault', style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    final res = await notifier.exportVault();
                    if (mounted) {
                      TopIslandToast.show(
                        context,
                        message: res.message,
                        icon: res.success ? Icons.check_circle_rounded : Icons.error_outline,
                        color: res.success ? AppColors.accentEmerald : Colors.redAccent,
                      );
                      _scanLocalVaultBackups();
                    }
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onPressed: () => notifier.resetStatus(),
                  child: const Text('Dismiss', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
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

  void _showFindLanDeviceDialog(BuildContext context, SyncNotifier notifier) {
    final ipCtl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.amoledSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.amoledBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.lan_rounded, color: AppColors.samsungOrange, size: 22),
            SizedBox(width: 10),
            Text(
              'Connect to PC or Phone',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the direct IP address or tap a quick preset:',
              style: TextStyle(color: AppColors.amoledTextSecondary, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('⚡ USB (127.0.0.1)', style: TextStyle(fontSize: 11.5, color: AppColors.samsungOrange)),
                  backgroundColor: AppColors.samsungOrange.withValues(alpha: 0.15),
                  side: const BorderSide(color: AppColors.samsungOrange),
                  onPressed: () {
                    ipCtl.text = '127.0.0.1';
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipCtl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. 192.168.1.15 or 127.0.0.1',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF333333)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.samsungOrange,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final ip = ipCtl.text.trim();
              if (ip.isNotEmpty) {
                notifier.probeCustomIp(ip);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Find & Pair', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
