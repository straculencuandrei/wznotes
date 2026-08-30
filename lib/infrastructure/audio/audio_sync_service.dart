import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

enum AudioSessionState {
  idle,
  recording,
  playing,
  paused,
}

/// Service managing audio-to-ink recording timecodes and synchronized playback
class AudioSyncService {
  final AudioPlayer _player = AudioPlayer();

  AudioSessionState _state = AudioSessionState.idle;
  int _recordingStartTimestampMs = 0;
  Timer? _recordingTimer;
  int _currentRecordingElapsedMs = 0;

  final StreamController<int> _timecodeStreamController = StreamController<int>.broadcast();
  final StreamController<AudioSessionState> _stateStreamController = StreamController<AudioSessionState>.broadcast();

  Stream<int> get timecodeStream => _timecodeStreamController.stream;
  Stream<AudioSessionState> get stateStream => _stateStreamController.stream;
  AudioSessionState get state => _state;
  int get currentElapsedMs => _state == AudioSessionState.recording ? _currentRecordingElapsedMs : 0;

  AudioSyncService() {
    _player.onPositionChanged.listen((Duration p) {
      if (_state == AudioSessionState.playing) {
        _timecodeStreamController.add(p.inMilliseconds);
      }
    });

    _player.onPlayerStateChanged.listen((PlayerState ps) {
      if (ps == PlayerState.completed) {
        _state = AudioSessionState.idle;
        _stateStreamController.add(_state);
        _timecodeStreamController.add(-1);
      }
    });
  }

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
    await _player.play(DeviceFileSource(filePath));
    _state = AudioSessionState.playing;
    _stateStreamController.add(_state);
  }

  /// Pauses audio playback
  Future<void> pause() async {
    await _player.pause();
    _state = AudioSessionState.paused;
    _stateStreamController.add(_state);
  }

  /// Seeks playback to a specific millisecond offset
  Future<void> seek(int positionMs) async {
    await _player.seek(Duration(milliseconds: positionMs));
    _timecodeStreamController.add(positionMs);
  }

  /// Disposes resources
  void dispose() {
    _recordingTimer?.cancel();
    _player.dispose();
    _timecodeStreamController.close();
    _stateStreamController.close();
  }
}
