import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../models/recording.dart';
import '../services/recordings_repository.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final RecordingsRepository _repository = RecordingsRepository();
  final List<Recording> _recordings = [];

  bool _isRecording = false;
  bool _isLoading = true;
  bool _busy = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  DateTime? _startedAt;
  String? _currentRecordingId;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    final recordings = await _repository.load();
    if (!mounted) return;
    setState(() {
      _recordings
        ..clear()
        ..addAll(recordings);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_busy) {
      debugPrint('Ignoring tap: already busy');
      return;
    }
    _busy = true;
    try {
      if (_isRecording) {
        await _stopRecording();
      } else {
        await _startRecording();
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _startRecording() async {
    debugPrint('Requesting mic permission...');
    final granted = await _recorder.hasPermission();
    debugPrint('Permission granted: $granted');
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('මයික්‍රෆෝන් අවසරය අවශ්‍යයි')),
        );
      }
      return;
    }

    try {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final path = await _repository.pathForNewRecording('$id.webm');
      debugPrint('Starting recorder at path: $path');
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.opus),
        path: path,
      );
      debugPrint(
        'Recorder.start() returned. isRecording=${await _recorder.isRecording()}',
      );

      setState(() {
        _isRecording = true;
        _elapsed = Duration.zero;
        _startedAt = DateTime.now();
        _currentRecordingId = id;
      });

      _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
        final stillRecording = await _recorder.isRecording();
        debugPrint(
          'Tick at ${DateTime.now().difference(_startedAt!)}: isRecording=$stillRecording',
        );
        if (!mounted) return;
        setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      });
    } catch (e, st) {
      debugPrint('Failed to start recording: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('පටිගත කිරීම ආරම්භ කළ නොහැක: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    try {
      debugPrint(
        'Stopping recorder. isRecording=${await _recorder.isRecording()}',
      );
      final recordedPath = await _recorder.stop();
      debugPrint('Recorder stopped, path: $recordedPath');

      if (recordedPath != null && _currentRecordingId != null) {
        final recording = await _repository.finalize(
          id: _currentRecordingId!,
          recordedPath: recordedPath,
          recordedAt: _startedAt!,
          duration: _elapsed,
        );
        _recordings.insert(0, recording);
        await _repository.save(_recordings);
        debugPrint('Saved recording, total count: ${_recordings.length}');
      }
    } catch (e, st) {
      debugPrint('Failed to stop/save recording: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('පටිගත කිරීම සුරැකිය නොහැක: $e')),
        );
      }
    }

    setState(() {
      _isRecording = false;
      _currentRecordingId = null;
    });
  }

  Future<void> _playRecording(Recording recording) async {
    if (_playingId == recording.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }

    final source = recording.bytes != null
        ? BytesSource(recording.bytes!)
        : DeviceFileSource(recording.filePath!);
    await _player.play(source);
    setState(() => _playingId = recording.id);
    _player.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('සිංහල කාර්යාල සහායක'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _toggleRecording,
                  style: _isRecording
                      ? ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        )
                      : null,
                  icon: Icon(
                    _isRecording
                        ? Icons.stop_rounded
                        : Icons.mic_none_rounded,
                  ),
                  label: Text(
                    _isRecording
                        ? 'පටිගත කරමින් • ${_formatDuration(_elapsed)}'
                        : 'නව පටිගත කිරීමක්',
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'පෙර පටිගත කිරීම්',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _recordings.isEmpty
                    ? const _EmptyRecordingsState()
                    : ListView.separated(
                        itemCount: _recordings.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final recording = _recordings[index];
                          final isPlaying = _playingId == recording.id;
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                                color: AppTheme.accentTeal,
                                size: 32,
                              ),
                              title: Text(_formatDuration(recording.duration)),
                              subtitle: Text(
                                '${recording.recordedAt.year}-${recording.recordedAt.month.toString().padLeft(2, '0')}-${recording.recordedAt.day.toString().padLeft(2, '0')} '
                                '${recording.recordedAt.hour.toString().padLeft(2, '0')}:${recording.recordedAt.minute.toString().padLeft(2, '0')}',
                              ),
                              onTap: () => _playRecording(recording),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRecordingsState extends StatelessWidget {
  const _EmptyRecordingsState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 48,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'පටිගත කිරීම් නොමැත',
            style: textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
