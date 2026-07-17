import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';

import '../models/scanned_document.dart';
import '../services/documents_repository.dart';
import '../services/gemini_ocr_service.dart';
import '../services/settings_repository.dart';
import '../theme/app_theme.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final ImagePicker _picker = ImagePicker();
  final DocumentsRepository _repository = DocumentsRepository();
  final SettingsRepository _settings = SettingsRepository();
  final GeminiOcrService _ocrService = GeminiOcrService();
  final List<ScannedDocument> _documents = [];
  final Set<String> _extractingIds = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
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

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('පිටපත් කරන ලදී')));
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

  String _formatDateTime(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ලේඛන')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSourceSheet,
        child: const Icon(Icons.document_scanner_outlined),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _documents.isEmpty
              ? const _EmptyDocumentsState()
              : ListView.separated(
                  itemCount: _documents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final document = _documents[index];
                    return Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(
                                document.imageBytes,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(
                              document.title ??
                                  _formatDateTime(document.scannedAt),
                            ),
                            subtitle: Text(_formatDateTime(document.scannedAt)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  color: AppTheme.textSecondary,
                                  tooltip: 'Rename',
                                  onPressed: () => _renameDocument(document),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
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
                          ),
                          if (_extractingIds.contains(document.id))
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                                  Text('පෙළ උපුටා ගනිමින්...'),
                                ],
                              ),
                            )
                          else if (document.extractedText != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      document.extractedText!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
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
                                      Icons.copy_outlined,
                                      size: 18,
                                    ),
                                    color: AppTheme.textSecondary,
                                    tooltip: 'පිටපත් කරන්න',
                                    onPressed: () =>
                                        _copyText(document.extractedText!),
                                  ),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => _extractText(document),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('පෙළ උපුටා ගන්න'),
                                ),
                              ),
                            ),
                        ],
                      ),
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
            style: textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
