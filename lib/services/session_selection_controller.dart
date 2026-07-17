import 'package:flutter/foundation.dart';

/// Shared cross-tab selection state so recordings (Home tab) and scanned
/// documents (Documents tab) can be combined into a single session report.
class SessionSelectionController extends ChangeNotifier {
  bool selectionMode = false;
  final Set<String> selectedRecordingIds = {};
  final Set<String> selectedDocumentIds = {};

  int get count => selectedRecordingIds.length + selectedDocumentIds.length;

  void enterSelectionMode() {
    selectionMode = true;
    notifyListeners();
  }

  void exitSelectionMode() {
    selectionMode = false;
    selectedRecordingIds.clear();
    selectedDocumentIds.clear();
    notifyListeners();
  }

  void toggleRecording(String id) {
    selectionMode = true;
    if (!selectedRecordingIds.remove(id)) {
      selectedRecordingIds.add(id);
    }
    notifyListeners();
  }

  void toggleDocument(String id) {
    selectionMode = true;
    if (!selectedDocumentIds.remove(id)) {
      selectedDocumentIds.add(id);
    }
    notifyListeners();
  }
}
