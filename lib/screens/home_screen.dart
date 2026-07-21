import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:printing/printing.dart';
import 'package:record/record.dart';

import '../models/recording.dart';
import '../services/audio_storage.dart';
import '../services/background_recording_service.dart';
import '../services/documents_repository.dart';
import '../services/gemini_transcription_service.dart';
import '../services/recordings_repository.dart';
import '../services/session_report_service.dart';
import '../services/session_selection_controller.dart';
import '../services/settings_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_chip.dart';
import '../widgets/stat_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.selectionController, super.key});

  final SessionSelectionController selectionController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final RecordingsRepository _repository = RecordingsRepository();
  final DocumentsRepository _documentsRepository = DocumentsRepository();
  final SettingsRepository _settings = SettingsRepository();
  final GeminiTranscriptionService _transcriptionService =
      GeminiTranscriptionService();
  final SessionReportService _reportService = SessionReportService();
  final List<Recording> _recordings = [];
  final Set<String> _transcribingIds = {};
  final GlobalKey<AnimatedListState> _listKey =
      GlobalKey<AnimatedListState>();

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _pulseAnimation = CurvedAnimation(
    parent: _pulseController,
    curve: Curves.easeInOut,
  );

  bool _isRecording = false;
  bool _isPaused = false;
  bool _isLoading = true;
  bool _busy = false;
  bool _generatingReport = false;
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
    _pulseController.dispose();
    if (_isRecording) {
      unawaited(BackgroundRecordingService.stop());
    }
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
      unawaited(BackgroundRecordingService.start());

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
    unawaited(BackgroundRecordingService.stop());
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
        _listKey.currentState?.insertItem(
          0,
          duration: AppTheme.motionDuration,
        );
        await _repository.save(_recordings);
        unawaited(_transcribeRecording(recording));
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

  Future<void> _transcribeRecording(Recording recording) async {
    final apiKey = await _settings.getGeminiApiKey();
    if (apiKey == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'පෙළට හැරවීමට Gemini API key එකක් සකසන්න (සැකසුම්)',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _transcribingIds.add(recording.id));
    try {
      final audioBytes = await readAudioBytes(recording);
      final transcript = await _transcriptionService.transcribe(
        apiKey: apiKey,
        audioBytes: audioBytes,
      );
      final index = _recordings.indexWhere((r) => r.id == recording.id);
      if (index != -1) {
        setState(() {
          _recordings[index] = _recordings[index].copyWith(
            transcript: transcript,
          );
        });
        await _repository.save(_recordings);
      }
    } catch (e) {
      debugPrint('Failed to transcribe recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('පෙළට හැරවීම අසාර්ථකයි: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _transcribingIds.remove(recording.id));
      }
    }
  }

  Future<void> _showApiKeyDialog() async {
    final controller = TextEditingController(
      text: await _settings.getGeminiApiKey() ?? '',
    );
    if (!mounted) return;
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'API key'),
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

    if (saved == null || saved.isEmpty) return;
    await _settings.saveGeminiApiKey(saved);
  }

  Future<void> _copyTranscript(String transcript) async {
    await Clipboard.setData(ClipboardData(text: transcript));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('පිටපත් කරන ලදී')),
      );
    }
  }

  Future<void> _generateReport() async {
    final controller = widget.selectionController;
    final apiKey = await _settings.getGeminiApiKey();
    if (apiKey == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'වාර්තාවක් සකසන්න Gemini API key එකක් සකසන්න (සැකසුම්)',
            ),
          ),
        );
      }
      return;
    }

    final selectedRecordings =
        _recordings
            .where(
              (r) =>
                  controller.selectedRecordingIds.contains(r.id) &&
                  r.transcript != null &&
                  r.transcript!.isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    final allDocuments = await _documentsRepository.load();
    final selectedDocuments =
        allDocuments
            .where(
              (d) =>
                  controller.selectedDocumentIds.contains(d.id) &&
                  d.extractedText != null &&
                  d.extractedText!.isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.scannedAt.compareTo(b.scannedAt));

    if (selectedRecordings.isEmpty && selectedDocuments.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('තෝරාගත් අයිතමවල පෙළ නොමැත'),
          ),
        );
      }
      return;
    }

    setState(() => _generatingReport = true);
    try {
      final summary = await _reportService.generateSummary(
        apiKey: apiKey,
        recordings: selectedRecordings,
        documents: selectedDocuments,
      );
      final pdfBytes = await _reportService.buildPdf(
        summary: summary,
        recordings: selectedRecordings,
        documents: selectedDocuments,
      );
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'session-report-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      if (mounted) {
        controller.exitSelectionMode();
      }
    } catch (e) {
      debugPrint('Failed to generate report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('වාර්තාව සකසීම අසාර්ථකයි: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generatingReport = false);
      }
    }
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
    final index = _recordings.indexWhere((r) => r.id == recording.id);
    if (index == -1) return;
    final removed = _recordings.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _animatedItem(
        animation,
        _buildRecordingCard(context, removed),
      ),
      duration: AppTheme.motionDuration,
    );
    setState(() {});
    await _repository.save(_recordings);
    await _repository.delete(removed);
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

  Widget _animatedItem(Animation<double> animation, Widget child) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: animation,
        curve: AppTheme.motionCurve,
      ),
      alignment: const Alignment(-1.0, -1.0),
      child: FadeTransition(
        opacity: animation,
        child: Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
      ),
    );
  }

  Widget _buildRecordingCard(BuildContext context, Recording recording) {
    final controller = widget.selectionController;
    final isPlaying = _playingId == recording.id;
    final isSelected = controller.selectedRecordingIds.contains(recording.id);
    return Card(
      key: ValueKey(recording.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: AnimatedSwitcher(
              duration: AppTheme.motionDuration,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: controller.selectionMode
                  ? Checkbox(
                      key: const ValueKey('checkbox'),
                      value: isSelected,
                      onChanged: (_) =>
                          controller.toggleRecording(recording.id),
                    )
                  : Icon(
                      isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      key: const ValueKey('play'),
                      color: AppTheme.accentTeal,
                      size: 32,
                    ),
            ),
            title: Text(
              recording.title ?? _formatDuration(recording.duration),
            ),
            subtitle: Text(
              '${recording.recordedAt.year}-${recording.recordedAt.month.toString().padLeft(2, '0')}-${recording.recordedAt.day.toString().padLeft(2, '0')} '
              '${recording.recordedAt.hour.toString().padLeft(2, '0')}:${recording.recordedAt.minute.toString().padLeft(2, '0')}'
              '${recording.title != null ? ' • ${_formatDuration(recording.duration)}' : ''}',
            ),
            trailing: controller.selectionMode
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        color: AppTheme.textSecondary,
                        tooltip: 'Rename',
                        onPressed: () => _renameRecording(recording),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
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
            onTap: controller.selectionMode
                ? () => controller.toggleRecording(recording.id)
                : () => _playRecording(recording),
            onLongPress: controller.selectionMode
                ? null
                : () => controller.toggleRecording(recording.id),
          ),
          AnimatedSize(
            duration: AppTheme.motionDuration,
            curve: AppTheme.motionCurve,
            alignment: Alignment.topCenter,
            child: _transcribingIds.contains(recording.id)
                ? const Padding(
                    key: ValueKey('transcribing'),
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('පෙළට හරවමින්...'),
                      ],
                    ),
                  )
                : recording.transcript != null
                ? Padding(
                    key: const ValueKey('transcript'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            recording.transcript!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          color: AppTheme.textSecondary,
                          tooltip: 'නැවත පෙළට හරවන්න',
                          onPressed: () => _transcribeRecording(recording),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          color: AppTheme.textSecondary,
                          tooltip: 'පිටපත් කරන්න',
                          onPressed: () =>
                              _copyTranscript(recording.transcript!),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    key: const ValueKey('untranscribed'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _transcribeRecording(recording),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('පෙළට හරවන්න'),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.selectionController,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final controller = widget.selectionController;
    return Scaffold(
      appBar: AppBar(
        leading: controller.selectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _generatingReport
                    ? null
                    : controller.exitSelectionMode,
              )
            : null,
        title: AnimatedSwitcher(
          duration: AppTheme.motionDuration,
          child: controller.selectionMode
              ? Text(
                  '${controller.count} තෝරා ඇත',
                  key: const ValueKey('selTitle'),
                )
              : const Text(
                  'E-ලේකම්',
                  key: ValueKey('normalTitle'),
                ),
        ),
        actions: [
          AnimatedSwitcher(
            duration: AppTheme.motionDuration,
            child: controller.selectionMode
                ? Row(
                    key: const ValueKey('selActions'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_generatingReport)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          tooltip: 'වාර්තාව ලබාගන්න',
                          onPressed: controller.count == 0
                              ? null
                              : _generateReport,
                        ),
                    ],
                  )
                : Row(
                    key: const ValueKey('normalActions'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.checklist_rounded),
                        tooltip: 'වාර්තාවක් සකසන්න',
                        onPressed: _recordings.isEmpty
                            ? null
                            : controller.enterSelectionMode,
                      ),
                      IconButton(
                        icon: const Icon(Icons.key_outlined),
                        tooltip: 'Gemini API Key',
                        onPressed: _showApiKeyDialog,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSwitcher(
                duration: AppTheme.motionDuration,
                switchInCurve: AppTheme.motionCurve,
                child: _isRecording
                    ? Column(
                        key: const ValueKey('recordingPanel'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              FadeTransition(
                                opacity: _isPaused
                                    ? const AlwaysStoppedAnimation(1.0)
                                    : _pulseAnimation,
                                child: Icon(
                                  Icons.fiber_manual_record_rounded,
                                  size: 14,
                                  color: _isPaused
                                      ? AppTheme.textSecondary
                                      : Theme.of(context).colorScheme.error,
                                ),
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
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: _isPaused ? 0 : _level,
                            ),
                            duration: const Duration(milliseconds: 150),
                            builder: (context, value, _) => ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: value,
                                minHeight: 6,
                                backgroundColor: AppTheme.divider,
                                valueColor: const AlwaysStoppedAnimation(
                                  AppTheme.accentTeal,
                                ),
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
                                  label: Text(
                                    _isPaused ? 'දිගටම කරගෙන යන්න' : 'විරාමය',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _toggleRecording,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                  ),
                                  icon: const Icon(Icons.stop_rounded),
                                  label: const Text('නවත්වන්න'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : SizedBox(
                        key: const ValueKey('startButton'),
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _toggleRecording,
                          icon: const Icon(Icons.mic_none_rounded),
                          label: const Text('නව පටිගත කිරීමක්'),
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
                    : AnimatedList(
                        key: _listKey,
                        initialItemCount: _recordings.length,
                        itemBuilder: (context, index, animation) {
                          final recording = _recordings[index];
                          return _animatedItem(
                            animation,
                            _buildRecordingCard(context, recording),
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
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppTheme.motionDuration,
        builder: (context, value, child) =>
            Opacity(opacity: value, child: child),
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
      ),
    );
  }
}
