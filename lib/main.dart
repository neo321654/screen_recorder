import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screen_recorder_wrapper.dart';
import 'screens/main_screen.dart';
import 'app_state.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Builder(
        builder: (context) {
          // Оборачиваем все приложение в ScreenRecorderWrapper
          // чтобы запись продолжалась при переходах между экранами
          return ScreenRecorderWrapper(
            pixelRatio: 1,
            skipFramesBetweenCaptures: 60,
            onFileSaved: (filePath, fileSize, duration, estimatedSizePerMinute) {
              // Обновляем состояние приложения
              Provider.of<AppState>(context, listen: false).updateFileInfo(
                filePath: filePath,
                size: fileSize,
                duration: duration,
                estimatedPerMinute: estimatedSizePerMinute,
              );
              
              // Показываем уведомление
              debugPrint('File saved: $filePath');
              debugPrint('Size: $fileSize');
              debugPrint('Duration: $duration');
              debugPrint('Estimated per minute: $estimatedSizePerMinute');
            },
            onError: (error) {
              debugPrint('Error: $error');
            },
            child: MaterialApp(
              title: 'Screen Recorder',
              theme: ThemeData(primarySwatch: Colors.blue),
              home: const MainScreen(),
            ),
          );
        },
      ),
    );
  }
}
