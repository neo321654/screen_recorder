import 'package:flutter/material.dart';

/// Глобальное состояние приложения для передачи данных между экранами
class AppState extends ChangeNotifier {
  String? savedFilePath;
  String? fileSize;
  Duration? recordingDuration;
  String? estimatedSizePerMinute;
  bool showFileInfo = false;

  void updateFileInfo({
    required String filePath,
    required String size,
    required Duration duration,
    required String estimatedPerMinute,
  }) {
    savedFilePath = filePath;
    fileSize = size;
    recordingDuration = duration;
    estimatedSizePerMinute = estimatedPerMinute;
    showFileInfo = true;
    notifyListeners();
  }

  void clearFileInfo() {
    savedFilePath = null;
    fileSize = null;
    recordingDuration = null;
    estimatedSizePerMinute = null;
    showFileInfo = false;
    notifyListeners();
  }
}
