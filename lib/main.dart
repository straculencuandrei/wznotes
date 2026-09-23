import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'infrastructure/update/update_service.dart';
import 'presentation/controllers/sync_controller.dart';
import 'presentation/controllers/theme_controller.dart';
import 'presentation/screens/notes_library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UpdateService.init();
  runApp(
    const ProviderScope(
      child: WzNotesApp(),
    ),
  );
}

class WzNotesApp extends ConsumerStatefulWidget {
  const WzNotesApp({super.key});

  @override
  ConsumerState<WzNotesApp> createState() => _WzNotesAppState();
}

class _WzNotesAppState extends ConsumerState<WzNotesApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Background-ready: start sync listener and auto-discovery as soon as app opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncProvider.notifier).startAutoDiscovery();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncProvider.notifier).startAutoDiscovery();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'wznotes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const NotesLibraryScreen(),
    );
  }
}
