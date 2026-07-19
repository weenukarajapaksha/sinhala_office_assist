import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../models/scanned_document.dart';
import '../services/documents_repository.dart';
import '../services/gemini_ocr_service.dart';
import '../services/gemini_summary_service.dart';
import '../services/gemini_translation_service.dart';
import '../services/recordings_repository.dart';
import '../services/session_report_service.dart';
import '../services/session_selection_controller.dart';
import '../services/settings_repository.dart';
import '../theme/app_theme.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({required this.selectionController, super.key});

  final SessionSelectionController selectionController;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final ImagePicker _picker = ImagePicker();
  final DocumentsRepository _repository = DocumentsRepository();
  final RecordingsRepository _recordingsRepository = RecordingsRepository();
  final SettingsRepository _settings = SettingsRepository();
  final GeminiOcrService _ocrService = GeminiOcrService();
  final GeminiTranslationService _translationService =
      GeminiTranslationService();
  final GeminiSummaryService _summaryService = GeminiSummaryService();
  final SessionReportService _reportService = SessionReportService();
  final List<ScannedDocument> _documents = [];
  final Set<String> _extractingIds = {};
  final Set<String> _translatingIds = {};
  final Set<String> _summarizingIds = {};

  bool _isLoading = true;
  bool _generatingReport = false;
  bool _searchMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _enterSearchMode() {
    setState(() => _searchMode = true);
  }

  void _exitSearchMode() {
    setState(() {
      _searchMode = false;
      _query = '';
      _searchController.clear();
    });
  }

  List<ScannedDocument> get _visibleDocuments {
    if (_query.isEmpty) return _documents;
    final query = _query.toLowerCase();
    return _documents.where((d) {
      return (d.title?.toLowerCase().contains(query) ?? false) ||
          (d.extractedText?.toLowerCase().contains(query) ?? false) ||
          (d.translatedText?.toLowerCase().contains(query) ?? false) ||
          (d.summaryText?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _loadDocuments() async {
    final documents = await _repository.load();
    if (!mounted) return;
    setState(() {
      _documents
        ..clear()
        ..addAll(documents);
      _isLoading = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final document = ScannedDocument(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      scannedAt: DateTime.now(),
      imageBytes: bytes,
    );

    setState(() => _documents.insert(0, document));
    await _repository.save(_documents);
    unawaited(_extractText(document, mimeType: file.mimeType ?? 'image/jpeg'));
  }

  Future<void> _showSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('කැමරාවෙන් ගන්න'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('ගැලරියෙන් තෝරන්න'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      await _pickImage(source);
    }
  }

  Future<void> _extractText(
    ScannedDocument document, {
    String mimeType = 'image/jpeg',
  }) async {
    final apiKey = await _settings.getGeminiApiKey();
    if (apiKey == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'පෙළ උපුටා ගැනීමට Gemini API key එකක් සකසන්න (රැස්කිරීම් තිරයේ 🔑)',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _extractingIds.add(document.id));
    try {
      final text = await _ocrService.extractText(
        apiKey: apiKey,
        imageBytes: document.imageBytes,
        mimeType: mimeType,
      );
      final index = _documents.indexWhere((d) => d.id == document.id);
      if (index != -1) {
        setState(() {
          _documents[index] = _documents[index].copyWith(extractedText: text);
        });
        await _repository.save(_documents);
      }
    } catch (e) {
      debugPrint('Failed to extract document text: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('පෙළ උපුටා ගැනීම අසාර්ථකයි: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _extractingIds.remove(document.id));
      }
    }
  }

  Future<void> _translateDocument(ScannedDocument document) async {
    final apiKey = await _settings.getGeminiApiKey();
    if (apiKey == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'පරිවර්තනය කිරීමට Gemini API key එකක් සකසන්න (රැස්කිරීම් තිරයේ 🔑)',
            ),
          ),
        );
      }
      return;
    }
    if (document.extractedText == null || document.extractedText!.isEmpty) {
      return;
    }

    setState(() => _translatingIds.add(document.id));
    try {
      final translated = await _translationService.translate(
        apiKey: apiKey,
        text: document.extractedText!,
      );
      final index = _documents.indexWhere((d) => d.id == document.id);
      if (index != -1) {
        setState(() {
          _documents[index] = _documents[index].copyWith(
            translatedText: translated,
          );
        });
        await _repository.save(_documents);
      }
    } catch (e) {
      debugPrint('Failed to translate document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('පරිවර්තනය අසාර්ථකයි: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _translatingIds.remove(document.id));
      }
    }
  }

  Future<void> _summarizeDocument(ScannedDocument document) async {
    final apiKey = await _settings.getGeminiApiKey();
    if (apiKey == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'සාරාංශ කිරීමට Gemini API key එකක් සකසන්න (රැස්කිරීම් තිරයේ 🔑)',
            ),
          ),
        );
      }
      return;
    }
    if (document.extractedText == null || document.extractedText!.isEmpty) {
      return;
    }

    setState(() => _summarizingIds.add(document.id));
    try {
      final summary = await _summaryService.summarize(
        apiKey: apiKey,
        text: document.extractedText!,
      );
      final index = _documents.indexWhere((d) => d.id == document.id);
      if (index != -1) {
        setState(() {
          _documents[index] = _documents[index].copyWith(
            summaryText: summary,
          );
        });
        await _repository.save(_documents);
      }
    } catch (e) {
      debugPrint('Failed to summarize document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('සාරාංශ කිරීම අසාර්ථකයි: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _summarizingIds.remove(document.id));
      }
    }
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('පිටපත් කරන ලදී')));
    }
  }

  Future<void> _exportDocument(ScannedDocument document) async {
    try {
      final bytes = await _reportService.buildSingleDocumentPdf(document);
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            '${document.title ?? document.id}-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      debugPrint('Failed to export document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF එක සකසීම අසාර්ථකයි: $e')),
        );
      }
    }
  }

  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ලේඛනය මකන්නද?'),
        content: const Text('මෙම ලේඛනය මකා දැමීමට ඔබට විශ්වාසද? මෙය අවලංගු කළ නොහැක.'),
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

  Future<void> _deleteDocument(ScannedDocument document) async {
    setState(() => _documents.removeWhere((d) => d.id == document.id));
    await _repository.save(_documents);
  }

  Future<void> _renameDocument(ScannedDocument document) async {
    final controller = TextEditingController(
      text: document.title ?? _formatDateTime(document.scannedAt),
    );
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Document name'),
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

    final index = _documents.indexWhere((d) => d.id == document.id);
    if (index == -1) return;
    setState(() {
      _documents[index] = document.copyWith(title: newTitle);
    });
    await _repository.save(_documents);
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

    final selectedDocuments =
        _documents
            .where(
              (d) =>
                  controller.selectedDocumentIds.contains(d.id) &&
                  d.extractedText != null &&
                  d.extractedText!.isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.scannedAt.compareTo(b.scannedAt));

    final allRecordings = await _recordingsRepository.load();
    final selectedRecordings =
        allRecordings
            .where(
              (r) =>
                  controller.selectedRecordingIds.contains(r.id) &&
                  r.transcript != null &&
                  r.transcript!.isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    if (selectedRecordings.isEmpty && selectedDocuments.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('තෝරාගත් අයිතමවල පෙළ නොමැත')),
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

  String _formatDateTime(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _buildDocumentCard(BuildContext context, ScannedDocument document) {
    final controller = widget.selectionController;
    final isSelected = controller.selectedDocumentIds.contains(document.id);
    final card = Card(
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
                      onChanged: (_) => controller.toggleDocument(document.id),
                    )
                  : ClipRRect(
                      key: const ValueKey('thumb'),
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        document.imageBytes,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            title: Text(
              document.title ?? _formatDateTime(document.scannedAt),
            ),
            subtitle: Text(_formatDateTime(document.scannedAt)),
            trailing: controller.selectionMode
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        color: AppTheme.textSecondary,
                        tooltip: 'Rename',
                        onPressed: () => _renameDocument(document),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: AppTheme.textSecondary,
                        tooltip: 'මකන්න',
                        onPressed: () async {
                          if (await _confirmDelete()) {
                            await _deleteDocument(document);
                          }
                        },
                      ),
                    ],
                  ),
            onTap: controller.selectionMode
                ? () => controller.toggleDocument(document.id)
                : null,
            onLongPress: controller.selectionMode
                ? null
                : () => controller.toggleDocument(document.id),
          ),
          AnimatedSize(
            duration: AppTheme.motionDuration,
            curve: AppTheme.motionCurve,
            alignment: Alignment.topCenter,
            child: _extractingIds.contains(document.id)
                ? const Padding(
                    key: ValueKey('extracting'),
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
                        Text('පෙළ උපුටා ගනිමින්...'),
                      ],
                    ),
                  )
                : document.extractedText != null
                ? Padding(
                    key: const ValueKey('extracted'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                document.extractedText!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 18,
                              ),
                              color: AppTheme.textSecondary,
                              tooltip: 'නැවත උපුටා ගන්න',
                              onPressed: () => _extractText(document),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.translate_rounded,
                                size: 18,
                              ),
                              color: AppTheme.textSecondary,
                              tooltip: 'පරිවර්තනය කරන්න',
                              onPressed: () => _translateDocument(document),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.summarize_outlined,
                                size: 18,
                              ),
                              color: AppTheme.textSecondary,
                              tooltip: 'සාරාංශ කරන්න',
                              onPressed: () => _summarizeDocument(document),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_outlined, size: 18),
                              color: AppTheme.textSecondary,
                              tooltip: 'පිටපත් කරන්න',
                              onPressed: () =>
                                  _copyText(document.extractedText!),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 18,
                              ),
                              color: AppTheme.textSecondary,
                              tooltip: 'PDF ලෙස බාගන්න',
                              onPressed: () => _exportDocument(document),
                            ),
                          ],
                        ),
                        AnimatedSize(
                          duration: AppTheme.motionDuration,
                          curve: AppTheme.motionCurve,
                          alignment: Alignment.topCenter,
                          child: _translatingIds.contains(document.id)
                              ? const Padding(
                                  key: ValueKey('translating'),
                                  padding: EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('පරිවර්තනය කරමින්...'),
                                    ],
                                  ),
                                )
                              : document.translatedText != null
                              ? Container(
                                  key: const ValueKey('translated'),
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.backgroundLight,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.borderRadius,
                                    ),
                                    border: Border.all(color: AppTheme.divider),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          document.translatedText!,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.copy_outlined,
                                          size: 16,
                                        ),
                                        color: AppTheme.textSecondary,
                                        tooltip: 'පිටපත් කරන්න',
                                        onPressed: () => _copyText(
                                          document.translatedText!,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('noTranslation'),
                                ),
                        ),
                        AnimatedSize(
                          duration: AppTheme.motionDuration,
                          curve: AppTheme.motionCurve,
                          alignment: Alignment.topCenter,
                          child: _summarizingIds.contains(document.id)
                              ? const Padding(
                                  key: ValueKey('summarizing'),
                                  padding: EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('සාරාංශ කරමින්...'),
                                    ],
                                  ),
                                )
                              : document.summaryText != null
                              ? Container(
                                  key: const ValueKey('summarized'),
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentTeal.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.borderRadius,
                                    ),
                                    border: Border.all(
                                      color: AppTheme.accentTeal.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          document.summaryText!,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.copy_outlined,
                                          size: 16,
                                        ),
                                        color: AppTheme.textSecondary,
                                        tooltip: 'පිටපත් කරන්න',
                                        onPressed: () =>
                                            _copyText(document.summaryText!),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('noSummary'),
                                ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    key: const ValueKey('unextracted'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _extractText(document),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('පෙළ උපුටා ගන්න'),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );

    return Dismissible(
      key: ValueKey(document.id),
      direction: controller.selectionMode
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(),
      onDismissed: (_) => _deleteDocument(document),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: TweenAnimationBuilder<double>(
        key: ValueKey('anim-${document.id}'),
        tween: Tween(begin: 0, end: 1),
        duration: AppTheme.motionDuration,
        curve: AppTheme.motionCurve,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        ),
        child: card,
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
              : _searchMode
              ? TextField(
                  key: const ValueKey('searchField'),
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    hintText: 'ලේඛන සොයන්න...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                )
              : const Text('ලේඛන', key: ValueKey('normalTitle')),
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
                : _searchMode
                ? Row(
                    key: const ValueKey('searchActions'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _exitSearchMode,
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('normalActions'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search_rounded),
                        tooltip: 'සොයන්න',
                        onPressed: _documents.isEmpty
                            ? null
                            : _enterSearchMode,
                      ),
                      IconButton(
                        icon: const Icon(Icons.checklist_rounded),
                        tooltip: 'වාර්තාවක් සකසන්න',
                        onPressed: _documents.isEmpty
                            ? null
                            : controller.enterSelectionMode,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: controller.selectionMode
          ? null
          : FloatingActionButton(
              onPressed: _showSourceSheet,
              child: const Icon(Icons.document_scanner_outlined),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Builder(
            builder: (context) {
              final visibleDocuments = _visibleDocuments;
              if (_isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_documents.isEmpty) {
                return const _EmptyDocumentsState();
              }
              if (visibleDocuments.isEmpty) {
                return Center(
                  child: Text(
                    'ගැලපෙන ලේඛන නොමැත',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: visibleDocuments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _buildDocumentCard(context, visibleDocuments[index]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyDocumentsState extends StatelessWidget {
  const _EmptyDocumentsState();

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
              Icons.document_scanner_outlined,
              size: 48,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'ලේඛන නොමැත',
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
