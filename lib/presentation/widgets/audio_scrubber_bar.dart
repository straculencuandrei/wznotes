import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../infrastructure/audio/audio_sync_service.dart';

class AudioSyncState {
  final AudioSessionState sessionState;
  final int currentPositionMs;
  final int totalDurationMs;

  const AudioSyncState({
    this.sessionState = AudioSessionState.idle,
    this.currentPositionMs = 0,
    this.totalDurationMs = 0,
  });

  AudioSyncState copyWith({
    AudioSessionState? sessionState,
    int? currentPositionMs,
    int? totalDurationMs,
  }) {
    return AudioSyncState(
      sessionState: sessionState ?? this.sessionState,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
    );
  }
}

class AudioSyncNotifier extends StateNotifier<AudioSyncState> {
  final AudioSyncService _service = AudioSyncService();

  AudioSyncNotifier() : super(const AudioSyncState()) {
    _service.stateStream.listen((s) {
      state = state.copyWith(sessionState: s);
    });
    _service.timecodeStream.listen((ms) {
      state = state.copyWith(currentPositionMs: ms);
    });
  }

  void toggleRecord(String path) async {
    if (state.sessionState == AudioSessionState.recording) {
      await _service.stopRecording();
    } else {
      await _service.startRecording(path);
    }
  }

  void seek(int ms) {
    _service.seek(ms);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

final audioSyncProvider = StateNotifierProvider<AudioSyncNotifier, AudioSyncState>((ref) {
  return AudioSyncNotifier();
});

/// Audio scrubber bar that synchronizes handwriting highlights with audio timecode
class AudioScrubberBar extends ConsumerWidget {
  const AudioScrubberBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioSyncProvider);
    final isRecording = audioState.sessionState == AudioSessionState.recording;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isRecording ? const Color(0xFFFEF2F2) : Colors.white,
        border: const Border(bottom: BorderSide(color: AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          // Record / Stop Button
          IconButton(
            icon: Icon(
              isRecording ? Icons.stop_circle : Icons.mic,
              color: isRecording ? AppColors.accentRose : AppColors.primaryBlue,
            ),
            onPressed: () {
              ref.read(audioSyncProvider.notifier).toggleRecord('/tmp/note_audio.m4a');
            },
          ),
          const SizedBox(width: 8),

          // Live Timecode Display
          Text(
            _formatTime(audioState.currentPositionMs),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isRecording ? AppColors.accentRose : AppColors.darkBg,
            ),
          ),
          const SizedBox(width: 16),

          // Scrubber Slider
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: isRecording ? AppColors.accentRose : AppColors.primaryBlue,
                inactiveTrackColor: Colors.black12,
                thumbColor: isRecording ? AppColors.accentRose : AppColors.primaryBlue,
              ),
              child: Slider(
                value: audioState.currentPositionMs.toDouble().clamp(0.0, 3600000.0),
                min: 0.0,
                max: (audioState.totalDurationMs > 0 ? audioState.totalDurationMs.toDouble() : 3600000.0),
                onChanged: (val) {
                  ref.read(audioSyncProvider.notifier).seek(val.toInt());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(int ms) {
    if (ms < 0) return '00:00';
    final int sec = (ms / 1000).floor();
    final int m = (sec / 60).floor();
    final int s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
