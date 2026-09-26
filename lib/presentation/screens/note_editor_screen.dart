import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_themes.dart';
import '../../domain/models/note_document.dart';
import '../../infrastructure/export/markdown_exporter.dart';
import '../../infrastructure/export/svg_exporter.dart';
import '../widgets/export_dialog.dart';
import '../widgets/infinite_rich_text_layer.dart';
import '../controllers/document_controller.dart';
import '../controllers/notes_library_controller.dart';
import '../controllers/inking_controller.dart';
import '../controllers/settings_controller.dart';
import '../widgets/top_island_toast.dart';
import '../canvas/infinite_canvas_viewport.dart';
import '../widgets/text_formatting_toolbar.dart';
import '../widgets/floating_pen_dock.dart';
import '../../core/diagnostics/performance_benchmark.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  bool _isDeleting = false;
  Timer? _autoSaveDebouncer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveDebouncer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      if (!_isDeleting) {
        _flushAndSave();
      }
    }
  }

  void _flushAndSave() {
    if (_isDeleting) return;
    InfiniteRichTextLayer.flushActive();
    final currentDoc = ref.read(documentProvider);
    ref.read(notesLibraryProvider.notifier).saveNote(currentDoc);
  }

  void _saveAndPop() {
    if (!_isDeleting) {
      _flushAndSave();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PerformanceBenchmarkService.measure('note_editor_build', () {
      final inkingState = ref.watch(inkingProvider);
      final activeTheme = ref.watch(appThemeProvider);

      // Auto-save: When document content updates, debounce save to disk within 2s
      ref.listen<NoteDocument>(documentProvider, (previous, next) {
        if (_isDeleting) return;
        _autoSaveDebouncer?.cancel();
        _autoSaveDebouncer = Timer(const Duration(milliseconds: 2000), () {
          if (mounted && !_isDeleting) {
            ref.read(notesLibraryProvider.notifier).saveNote(next);
          }
        });
      });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_isDeleting) {
          _flushAndSave();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: activeTheme.background,
          gradient: activeTheme.backgroundGradient,
        ),
        child: _KeyboardStableMediaQuery(
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, size: 22, color: activeTheme.textPrimary),
                tooltip: 'Back to Notes',
                onPressed: _saveAndPop,
              ),
              title: Consumer(
                builder: (context, ref, _) {
                  final showWordCount = ref.watch(settingsProvider.select((s) => s.showWordCount));
                if (!showWordCount) return const SizedBox.shrink();
                final wordCount = ref.watch(documentProvider.select((d) => d.metadata.wordCount));
                return Text(
                  wordCount > 0 ? '$wordCount words' : '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: activeTheme.textSecondary,
                  ),
                );
              },
            ),
            centerTitle: false,
            actions: [
              // Quick direct delete button inside note header
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 22, color: AppColors.accentRose),
                tooltip: 'Move to Trash',
                onPressed: () {
                  final currentDoc = ref.read(documentProvider);
                  _confirmDelete(context, currentDoc);
                },
              ),

              // Export & Options Menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 24, color: activeTheme.textPrimary),
                tooltip: 'Note Options',
                color: activeTheme.surfaceElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: activeTheme.border),
                ),
                onSelected: (action) {
                  InfiniteRichTextLayer.flushActive();
                  final currentDoc = ref.read(documentProvider);
                  if (action == 'delete') {
                    _confirmDelete(context, currentDoc);
                  } else {
                    ref.read(notesLibraryProvider.notifier).saveNote(currentDoc);
                    _handleExport(context, action, currentDoc);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'txt',
                    child: Row(
                      children: [
                        const Icon(Icons.article_outlined, color: Colors.blueAccent, size: 18),
                        const SizedBox(width: 8),
                        Text('Export to Plain Text (.txt)', style: TextStyle(color: activeTheme.textPrimary, fontSize: 14)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, color: AppColors.accentRose, size: 18),
                        const SizedBox(width: 8),
                        Text('Export to Vector PDF (.pdf)', style: TextStyle(color: activeTheme.textPrimary, fontSize: 14)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'markdown',
                    child: Row(
                      children: [
                        Icon(Icons.code_rounded, color: activeTheme.textSecondary, size: 18),
                        const SizedBox(width: 8),
                        Text('Export to Markdown (.md)', style: TextStyle(color: activeTheme.textPrimary, fontSize: 14)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'svg',
                    child: Row(
                      children: [
                        Icon(Icons.draw_outlined, color: activeTheme.accent, size: 18),
                        const SizedBox(width: 8),
                        Text('Export to SVG Vector', style: TextStyle(color: activeTheme.textPrimary, fontSize: 14)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: AppColors.accentRose, size: 20),
                        SizedBox(width: 8),
                        Text('Delete note', style: TextStyle(color: AppColors.accentRose, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Listener(
            onPointerDown: (event) {
              PerformanceBenchmarkService.instance.onUserTapScreen(event.localPosition);
            },
            child: Stack(
            children: [
              // 1. Full Keyboard Writing Viewport extending edge-to-edge behind floating toolbars
              Positioned.fill(
                child: RepaintBoundary(
                  child: InfiniteCanvasViewport(scrollController: _scrollController),
                ),
              ),

              // 2. Floating Stylus Tool Dock & Formatting Toolbar smoothly glued above keyboard
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _KeyboardDockIsland(
                  child: RepaintBoundary(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (inkingState.isInkingMode)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: FloatingPenDock(),
                          ),
                        TextFormattingToolbar(scrollController: _scrollController),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Writing Performance Diagnostic HUD (collapsible live latency & stress test runner)
              if (kDebugMode)
                Positioned(
                  top: 8,
                  right: 12,
                  child: SafeArea(
                    child: BenchmarkHudOverlay(ref: ref),
                  ),
                ),
            ],
          ),
          ),
        ),
        ),
      ),
    );
    });
  }

  void _confirmDelete(BuildContext context, NoteDocument doc) {
    final activeTheme = ref.read(appThemeProvider);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: activeTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: activeTheme.border),
        ),
        title: Text('Move to Trash?', style: TextStyle(color: activeTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'This note will be moved to the Trash bin. You can restore it anytime within 30 days before it is permanently deleted.',
          style: TextStyle(color: activeTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Cancel', style: TextStyle(color: activeTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              _isDeleting = true;
              _autoSaveDebouncer?.cancel();
              ref.read(notesLibraryProvider.notifier).deleteNote(doc.metadata.id);
              Navigator.of(dialogCtx).pop(); // dismiss dialog
              Navigator.of(context).pop(); // exit editor
              TopIslandToast.show(
                context,
                message: 'Note moved to Trash',
                icon: Icons.delete_outline_rounded,
                color: AppColors.accentRose,
              );
            },
            child: const Text('Move to Trash', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, String format, NoteDocument doc) async {
    if (format == 'txt') {
      await NoteExportService.exportSingleNote(context, doc, format: ExportFormat.txt);
    } else if (format == 'pdf') {
      await NoteExportService.exportSingleNote(context, doc, format: ExportFormat.pdf);
    } else if (format == 'markdown') {
      final md = MarkdownExporter.exportToMarkdown(doc);
      _showExportPreview(context, 'Markdown Export', md);
    } else if (format == 'svg') {
      final svg = SvgExporter.exportToSvg(doc);
      _showExportPreview(context, 'SVG Vector Export', svg);
    }
  }

  void _showExportPreview(BuildContext context, String title, String content) {
    final activeTheme = ref.read(appThemeProvider);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: activeTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: activeTheme.border),
        ),
        title: Text(title, style: TextStyle(color: activeTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: activeTheme.textPrimary.withValues(alpha: 0.9)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: activeTheme.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Isolates keyboard inset updates so the floating island glides in exact 120 FPS lockstep
/// with Android's WindowInsets via hardware VSYNC interpolation and GPU matrix translation,
/// completely eliminating stair-step stutter, CPU layout thrashing, and fighting with the OS keyboard.
class _KeyboardDockIsland extends StatefulWidget {
  final Widget child;
  const _KeyboardDockIsland({required this.child});

  @override
  State<_KeyboardDockIsland> createState() => _KeyboardDockIslandState();
}

class _KeyboardDockIslandState extends State<_KeyboardDockIsland>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _keyboardChannel = MethodChannel('dev.opennotes.app/keyboard');

  final ValueNotifier<double> _visualInsetNotifier = ValueNotifier<double>(0.0);
  double _targetInset = 0.0;
  double _visualInset = 0.0;
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// Cached last known physical keyboard height for zero-delay predictive motion
  double _cachedKeyboardHeight = 0.0;

  /// Hysteresis guard: prevents transient OS zero-crossings (keyboard cycling)
  /// from causing wild dock oscillation during the 304→0→304→0→304 pattern
  Timer? _closeGuardTimer;

  /// Whether native keyboard channel has delivered at least one event
  bool _nativeChannelActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);

    // Register predictive glide callbacks with the benchmark service
    final bench = PerformanceBenchmarkService.instance;
    bench.onKeyboardLikelyOpening = _onPredictiveOpen;
    bench.onKeyboardLikelyClosing = _onPredictiveClose;

    // Listen to native keyboard height (bypasses Flutter engine entirely)
    _keyboardChannel.setMethodCallHandler(_onNativeKeyboardEvent);
  }

  /// Receives keyboard height from Android's WindowInsetsAnimation.Callback
  /// via MethodChannel — zero Flutter engine overhead, no handleMetricsChanged()
  Future<dynamic> _onNativeKeyboardEvent(MethodCall call) async {
    if (call.method == 'keyboardHeight') {
      _nativeChannelActive = true;
      final double height = (call.arguments as num).toDouble();
      _onKeyboardHeight(height);
    }
    return null;
  }

  /// Unified keyboard height handler — used by both native channel and fallback path
  void _onKeyboardHeight(double logicalHeight) {
    if (!mounted) return;

    // Feed the flight recorder
    PerformanceBenchmarkService.instance.recordKeyboardInsetEvent(
      logicalHeight, logicalHeight * (View.of(context).devicePixelRatio));

    // Cache the keyboard height for future zero-delay predictive motion
    if (logicalHeight > 10.0) {
      _cachedKeyboardHeight = logicalHeight;
      _closeGuardTimer?.cancel();
      _closeGuardTimer = null;
    }

    // Hysteresis: when dock is UP and OS sends a transient zero, wait 150ms
    if (logicalHeight < 1.0 && _targetInset > 10.0) {
      _closeGuardTimer ??= Timer(const Duration(milliseconds: 150), () {
        _closeGuardTimer = null;
        if (!mounted) return;
        _targetInset = 0.0;
        if (!_ticker.isActive) {
          _lastTick = Duration.zero;
          _ticker.start();
        }
      });
      return;
    }

    if ((logicalHeight - _targetInset).abs() > 0.5) {
      _targetInset = logicalHeight;
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    }
  }

  /// Called at T+0ms when text focus is acquired — starts gliding immediately
  void _onPredictiveOpen(double estimatedHeight) {
    if (!mounted) return;
    final height = _cachedKeyboardHeight > 10.0 ? _cachedKeyboardHeight : estimatedHeight;
    if ((height - _targetInset).abs() > 0.5) {
      _targetInset = height;
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    }
  }

  /// Called when text focus is lost — starts gliding back to zero immediately
  void _onPredictiveClose() {
    if (!mounted) return;
    if (_targetInset > 0.5) {
      _targetInset = 0.0;
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final double deltaSeconds = ((elapsed - _lastTick).inMicroseconds / 1000000.0).clamp(0.001, 0.05);
    _lastTick = elapsed;

    final double diff = _targetInset - _visualInset;
    if (diff.abs() < 0.25) {
      _visualInset = _targetInset;
      _visualInsetNotifier.value = _visualInset;
      _ticker.stop();
      _lastTick = Duration.zero;
      return;
    }

    final double step = diff * (1.0 - math.exp(-32.0 * deltaSeconds));
    _visualInset += step;
    _visualInsetNotifier.value = _visualInset;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateInsetFallback();
  }

  @override
  void didChangeMetrics() {
    _updateInsetFallback();
  }

  /// Fallback path: only used when native MethodChannel hasn't delivered events.
  /// With native interception active, viewInsets.bottom is always 0 from Flutter's
  /// perspective, so this method becomes a no-op.
  void _updateInsetFallback() {
    if (_nativeChannelActive || !mounted) return;
    try {
      final view = View.of(context);
      final physicalInset = view.viewInsets.bottom;
      if (physicalInset < 1.0 && _targetInset < 1.0) return;
      final dpr = view.devicePixelRatio > 0 ? view.devicePixelRatio : 1.0;
      final logicalInset = physicalInset / dpr;
      _onKeyboardHeight(logicalInset);
    } catch (_) {}
  }

  @override
  void dispose() {
    _closeGuardTimer?.cancel();
    _keyboardChannel.setMethodCallHandler(null);
    // Unregister predictive glide callbacks
    final bench = PerformanceBenchmarkService.instance;
    if (bench.onKeyboardLikelyOpening == _onPredictiveOpen) {
      bench.onKeyboardLikelyOpening = null;
    }
    if (bench.onKeyboardLikelyClosing == _onPredictiveClose) {
      bench.onKeyboardLikelyClosing = null;
    }
    _ticker.dispose();
    _visualInsetNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PerformanceBenchmarkService.measure('keyboard_dock_build', () {
      return ValueListenableBuilder<double>(
        valueListenable: _visualInsetNotifier,
        builder: (context, inset, child) {
          return Transform.translate(
            offset: Offset(0, -inset),
            child: child,
          );
        },
        child: RepaintBoundary(
          child: PerformanceProbeWidget(
            tag: 'keyboard_dock',
            child: widget.child,
          ),
        ),
      );
    });
  }
}

/// Prevents keyboard inset changes from propagating through the widget tree.
///
/// Problem: `MediaQuery.removeViewInsets` re-reads `MediaQuery.of(context)` on every frame,
/// creating an unconditional dependency. When the keyboard animates (22+ OS events over 1.5s),
/// every event triggers a full subtree rebuild (148ms per frame from TextField IME reconnects).
///
/// Solution: Cache the non-keyboard MediaQuery data and only update children when structurally
/// relevant fields change (screen size, system padding, device pixel ratio). The keyboard
/// inset is always stripped to 0 — the floating dock island handles positioning independently
/// via `View.of(context).viewInsets.bottom` + GPU `Transform.translate`.
class _KeyboardStableMediaQuery extends StatefulWidget {
  final Widget child;
  const _KeyboardStableMediaQuery({required this.child});

  @override
  State<_KeyboardStableMediaQuery> createState() => _KeyboardStableMediaQueryState();
}

class _KeyboardStableMediaQueryState extends State<_KeyboardStableMediaQuery> with WidgetsBindingObserver {
  MediaQueryData? _stableData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Only rebuild if NON-keyboard metrics changed (screen rotation, display cutouts, etc.)
    if (!mounted) return;
    final parentData = MediaQuery.maybeOf(context);
    if (parentData == null) return;
    final newStable = _stripKeyboardInsets(parentData);
    if (_stableData != null && _stableData == newStable) return;
    setState(() {
      _stableData = newStable;
    });
  }

  static MediaQueryData _stripKeyboardInsets(MediaQueryData data) {
    return data.copyWith(
      viewInsets: data.viewInsets.copyWith(bottom: 0),
      // Stabilize viewPadding.bottom to prevent keyboard-caused padding changes
      // from propagating (keep navigation bar padding, strip keyboard padding)
      viewPadding: data.viewPadding.copyWith(
        bottom: data.padding.bottom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentData = MediaQuery.of(context);
    _stableData ??= _stripKeyboardInsets(parentData);
    return MediaQuery(
      data: _stableData!,
      child: widget.child,
    );
  }
}
