import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../models/recording.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final List<Recording> _recordings = [];

  bool _isRecording = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  DateTime? _startedAt;
  String? _playingId;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('මයික්‍රෆෝන් අවසරය අවශ්‍යයි')),
        );
      }
      return;
    }

    final path = '${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: path);

    setState(() {
      _isRecording = true;
      _elapsed = Duration.zero;
      _startedAt = DateTime.now();
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed = DateTime.now().difference(_startedAt!));
    });
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    final path = await _recorder.stop();

    setState(() {
      _isRecording = false;
      if (path != null) {
        _recordings.insert(
          0,
          Recording(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            path: path,
            recordedAt: DateTime.now(),
            duration: _elapsed,
          ),
        );
      }
    });
  }

  Future<void> _playRecording(Recording recording) async {
    if (_playingId == recording.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }

    await _player.play(UrlSource(recording.path));
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
                child: _recordings.isEmpty
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
