import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageHelper {
  static Future<Directory> getScreenshotDirectory(String? directoryName) async {
    Directory? targetDir;

    try {
      final Directory? extStorage = await getExternalStorageDirectory();
      if (extStorage != null) {
        final String extPath = extStorage.path;
        final int androidIndex = extPath.indexOf('/Android/');
        if (androidIndex != -1) {
          final String publicPath = extPath.substring(0, androidIndex);
          targetDir = Directory('$publicPath/Pictures');
        } else {
          targetDir = Directory('${extStorage.parent.path}/Pictures');
        }
      }
    } catch (e) {
      // Fallback to app documents directory
    }

    if (targetDir == null) {
      targetDir = await getApplicationDocumentsDirectory();
    }

    final String finalDirName = directoryName ?? 'Screenshots';
    final Directory customDir = Directory('${targetDir.path}/$finalDirName');

    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }

    return customDir;
  }
}
