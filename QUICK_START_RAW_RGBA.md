# Быстрый старт: Raw RGBA Export

## 1. Использование в Flutter

```dart
import 'package:screen_recorder/src/raw_rgba_export.dart';
import 'dart:io';

// Создаем экспортер
final exporter = RawRgbaExporter(
  pixelRatio: 1.0,
  enableLogging: true,
);

// В вашем виджете
Widget build(BuildContext context) {
  return exporter.buildCaptureWidget(
    YourWidget(),
  );
}

// Захватываем
final result = await exporter.captureFromRepaintBoundary(
  exporter.repaintBoundaryKey,
);

if (result != null) {
  // Сохраняем для тестирования (опционально)
  final file = File('test_image.raw');
  await file.writeAsBytes(result.pixels);
  
  print('Сохранено: test_image.raw');
  print('Размер: ${result.width}x${result.height}');
  print('Размер данных: ${result.sizeInBytes} байт');
  
  // Или отправляем на backend
  // await sendToBackend(result.pixels, result.width, result.height);
}
```

## 2. Декодирование на Mac

```bash
# Установка зависимостей (один раз)
pip3 install Pillow numpy

# Декодирование
python3 decode_raw_rgba.py test_image.raw 800 600 test_image.png

# Или с автоматическим именем
python3 decode_raw_rgba.py test_image.raw 800 600
# Создаст test_image.png
```

## 3. Проверка результата

Откройте созданный PNG файл - вы должны увидеть захваченное изображение.

## Структура данных

```dart
RawRgbaImage {
  pixels: Uint8List,  // Сырые RGBA байты
  width: int,          // Ширина
  height: int,         // Высота
}
```

Формат: каждый пиксель = 4 байта (R, G, B, A)

## Отправка на Backend

```dart
// HTTP POST
final response = await http.post(
  Uri.parse('https://your-api.com/image'),
  headers: {
    'Content-Type': 'application/octet-stream',
    'X-Width': result.width.toString(),
    'X-Height': result.height.toString(),
  },
  body: result.pixels,
);
```

## Логи

Все операции логируются с префиксом `[RawRgbaExporter]`:
- Начало операций
- Время выполнения
- Размеры данных
- Ошибки (если есть)
