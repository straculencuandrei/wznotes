import 'dart:async';

enum AudioSessionState {
  idle,
  recording,
  playing,
  paused,
}

/// Service managing audio-to-ink recording timecodes and synchronized playback
class AudioSyncService {
  AudioSessionState _state = AudioSessionState.idle;
  int _recordingStartTimestampMs = 0;
  Timer? _recordingTimer;
  Timer? _playbackTimer;
  int _currentRecordingElapsedMs = 0;
  int _currentPlaybackElapsedMs = 0;

  final StreamController<int> _timecodeStreamController = StreamController<int>.broadcast();
  final StreamController<AudioSessionState> _stateStreamController = StreamController<AudioSessionState>.broadcast();

  Stream<int> get timecodeStream => _timecodeStreamController.stream;
  Stream<AudioSessionState> get stateStream => _stateStreamController.stream;
  AudioSessionState get state => _state;
  int get currentElapsedMs => _state == AudioSessionState.recording
      ? _currentRecordingElapsedMs
      : (_state == AudioSessionState.playing ? _currentPlaybackElapsedMs : 0);

  /// Starts recording session and broadcasting live millisecond timecode
  Future<void> startRecording(String filePath) async {
    _state = AudioSessionState.recording;
    _recordingStartTimestampMs = DateTime.now().millisecondsSinceEpoch;
    _currentRecordingElapsedMs = 0;
    _stateStreamController.add(_state);

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _currentRecordingElapsedMs = DateTime.now().millisecondsSinceEpoch - _recordingStartTimestampMs;
      _timecodeStreamController.add(_currentRecordingElapsedMs);
    });
  }

  /// Stops audio recording session
  Future<String?> stopRecording() async {
    _recordingTimer?.cancel();
    _state = AudioSessionState.idle;
    _stateStreamController.add(_state);
    _timecodeStreamController.add(-1);
    return null;
  }

  /// Plays recorded audio and synchronizes stroke highlights
  Future<void> play(String filePath) async {
    _state = AudioSessionState.playing;
    _stateStreamController.add(_state);
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _currentPlaybackElapsedMs += 50;
      _timecodeStreamController.add(_currentPlaybackElapsedMs);
    });
  }

  /// Pauses audio playback
  Future<void> pause() async {
    _playbackTimer?.cancel();
    _state = AudioSessionState.paused;
    _stateStreamController.add(_state);
  }

  /// Seeks playback to a specific millisecond offset
  Future<void> seek(int positionMs) async {
    _currentPlaybackElapsedMs = positionMs;
    _timecodeStreamController.add(positionMs);
  }

  /// Disposes resources
  void dispose() {
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    _timecodeStreamController.close();
    _stateStreamController.close();
  }
}
