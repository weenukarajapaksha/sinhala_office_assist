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
  bool _isPaused = false;
  bool _isLoading = true;
  bool _busy = false;
  double _level = 0;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;
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
    _amplitudeSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_busy) return;
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
    if (!await _recorder.hasPermission()) {
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
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.opus),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _elapsed = Duration.zero;
        _startedAt = DateTime.now();
        _currentRecordingId = id;
      });

      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      });

      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 200))
          .listen((amplitude) {
            if (!mounted) return;
            setState(() => _level = ((amplitude.current + 60) / 60).clamp(0.0, 1.0));
          });
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('පටිගත කිරීම ආරම්භ කළ නොහැක: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    try {
      final recordedPath = await _recorder.stop();

      if (recordedPath != null && _currentRecordingId != null) {
        final recording = await _repository.finalize(
          id: _currentRecordingId!,
          recordedPath: recordedPath,
          recordedAt: _startedAt!,
          duration: _elapsed,
        );
        _recordings.insert(0, recording);
        await _repository.save(_recordings);
      }
    } catch (e) {
      debugPrint('Failed to stop/save recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('පටිගත කිරීම සුරැකිය නොහැක: $e')),
        );
      }
    }

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _currentRecordingId = null;
      _level = 0;
    });
  }

  Future<void> _togglePause() async {
    if (_busy) return;
    _busy = true;
    try {
      if (_isPaused) {
        await _recorder.resume();
        _startedAt = DateTime.now().subtract(_elapsed);
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => _elapsed = DateTime.now().difference(_startedAt!));
        });
        setState(() => _isPaused = false);
      } else {
        _ticker?.cancel();
        await _recorder.pause();
        setState(() => _isPaused = true);
      }
    } catch (e) {
      debugPrint('Failed to toggle pause: $e');
    } finally {
      _busy = false;
    }
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

  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('පටිගත කිරීම මකන්නද?'),
        content: const Text(
          'මෙම පටිගත කිරීම මකා දැමීමට ඔබට විශ්වාසද? මෙය අවලංගු කළ නොහැක.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('අවලංගු කරන්න'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'මකන්න',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteRecording(Recording recording) async {
    if (_playingId == recording.id) {
      await _player.stop();
      _playingId = null;
    }
    setState(() => _recordings.removeWhere((r) => r.id == recording.id));
    await _repository.save(_recordings);
    await _repository.delete(recording);
  }

  Future<void> _renameRecording(Recording recording) async {
    final controller = TextEditingController(
      text: recording.title ?? _formatDuration(recording.duration),
    );
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename recording'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Recording name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newTitle == null || newTitle.isEmpty) return;

    final index = _recordings.indexWhere((r) => r.id == recording.id);
    if (index == -1) return;
    setState(() {
      _recordings[index] = recording.copyWith(title: newTitle);
    });
    await _repository.save(_recordings);
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
              if (_isRecording) ...[
                Row(
                  children: [
                    Icon(
                      Icons.fiber_manual_record_rounded,
                      size: 14,
                      color: _isPaused
                          ? AppTheme.textSecondary
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isPaused
                          ? 'විරාමයි • ${_formatDuration(_elapsed)}'
                          : 'පටිගත කරමින් • ${_formatDuration(_elapsed)}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _isPaused ? 0 : _level,
                    minHeight: 6,
                    backgroundColor: AppTheme.divider,
                    valueColor: const AlwaysStoppedAnimation(
                      AppTheme.accentTeal,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _togglePause,
                        icon: Icon(
                          _isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                        label: Text(_isPaused ? 'දිගටම කරගෙන යන්න' : 'විරාමය'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _toggleRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('නවත්වන්න'),
                      ),
                    ),
                  ],
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _toggleRecording,
                    icon: const Icon(Icons.mic_none_rounded),
                    label: const Text('නව පටිගත කිරීමක්'),
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
                              title: Text(
                                recording.title ??
                                    _formatDuration(recording.duration),
                              ),
                              subtitle: Text(
                                '${recording.recordedAt.year}-${recording.recordedAt.month.toString().padLeft(2, '0')}-${recording.recordedAt.day.toString().padLeft(2, '0')} '
                                '${recording.recordedAt.hour.toString().padLeft(2, '0')}:${recording.recordedAt.minute.toString().padLeft(2, '0')}'
                                '${recording.title != null ? ' • ${_formatDuration(recording.duration)}' : ''}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    color: AppTheme.textSecondary,
                                    tooltip: 'Rename',
                                    onPressed: () => _renameRecording(recording),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    color: AppTheme.textSecondary,
                                    tooltip: 'මකන්න',
                                    onPressed: () async {
                                      if (await _confirmDelete()) {
                                        await _deleteRecording(recording);
                                      }
                                    },
                                  ),
                                ],
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
