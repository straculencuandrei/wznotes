import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'infrastructure/update/update_service.dart';
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

class WzNotesApp extends ConsumerWidget {
  const WzNotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
