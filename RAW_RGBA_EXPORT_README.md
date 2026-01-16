# Raw RGBA Export для Flutter

Реализация захвата виджета через `RenderRepaintBoundary` и экспорт изображения в формате `ui.ImageByteFormat.rawRgba`.

## Возможности

- ✅ Захват виджета через `RepaintBoundary`
- ✅ Экспорт в raw RGBA формат (сырые байты)
- ✅ Структура данных с `Uint8List pixels`, `int width`, `int height`
- ✅ Подробное логирование всех операций
- ✅ Готово для отправки на backend
- ✅ Python скрипт для декодирования

## Использование

### 1. Базовое использование

```dart
import 'package:screen_recorder/src/raw_rgba_export.dart';

// Создаем экспортер
final exporter = RawRgbaExporter(
  pixelRatio: 1.0,      // 1.0 = оригинальный размер
  enableLogging: true,  // Включить логирование
);

// Оборачиваем виджет в RepaintBoundary
Widget buildCaptureWidget(Widget child) {
  return exporter.buildCaptureWidget(child);
}

// Захватываем виджет
final result = await exporter.captureFromRepaintBoundary(
  exporter.repaintBoundaryKey,
);

if (result != null) {
  print('Размер: ${result.width}x${result.height}');
  print('Данные: ${result.pixels.length} байт');
  print('Пикселей: ${result.pixelCount}');
  
  // Отправка на backend
  await sendToBackend(
    result.pixels,
    result.width,
    result.height,
  );
}
```

### 2. Использование с существующим RepaintBoundary

```dart
final GlobalKey repaintBoundaryKey = GlobalKey();

Widget build(BuildContext context) {
  return RepaintBoundary(
    key: repaintBoundaryKey,
    child: YourWidget(),
  );
}

// Захват
final exporter = RawRgbaExporter();
final result = await exporter.captureFromRepaintBoundary(repaintBoundaryKey);
```

### 3. Структура данных RawRgbaImage

```dart
class RawRgbaImage {
  final Uint8List pixels;  // Сырые RGBA байты (R, G, B, A для каждого пикселя)
  final int width;         // Ширина в пикселях
  final int height;        // Высота в пикселях
  
  int get sizeInBytes;     // Размер данных в байтах
  int get pixelCount;      // Количество пикселей
  bool get isValid;        // Проверка корректности данных
}
```

### 4. Формат данных

Данные хранятся в формате **raw RGBA**:
- Каждый пиксель = 4 байта: `R`, `G`, `B`, `A`
- Порядок байтов: строка за строкой, слева направо, сверху вниз
- Размер данных = `width * height * 4` байт

Пример для изображения 2x2:
```
Пиксель (0,0): R G B A
Пиксель (1,0): R G B A
Пиксель (0,1): R G B A
Пиксель (1,1): R G B A
```

## Логирование

При `enableLogging: true` выводятся следующие сообщения:

```
[RawRgbaExporter] Начало захвата виджета
[RawRgbaExporter] Размер: 400x600, pixelRatio: 1.0
[RawRgbaExporter] RenderRepaintBoundary найден
[RawRgbaExporter] Изображение захвачено: 400x600 за 15ms
[RawRgbaExporter] Начало экспорта в raw RGBA: 400x600
[RawRgbaExporter] ByteData получен за 8ms: 960000 байт
[RawRgbaExporter] Конвертация в Uint8List за 250μs
[RawRgbaExporter] Размер данных: 960000 байт (937.50 KB)
[RawRgbaExporter] Ожидаемый размер: 960000 байт
[RawRgbaExporter] RawRgbaImage создан успешно
[RawRgbaExporter] Данные готовы для отправки на backend: 240000 пикселей, 960000 байт
[RawRgbaExporter] Экспорт завершен за 10ms
[RawRgbaExporter] Результат: RawRgbaImage(width: 400, height: 600, pixels: 960000 bytes, size: 937.50 KB)
[RawRgbaExporter] Общее время: 33ms
```

## Отправка на Backend

### Пример с HTTP

```dart
import 'package:http/http.dart' as http;

Future<void> sendToBackend(
  Uint8List pixels,
  int width,
  int height,
) async {
  final response = await http.post(
    Uri.parse('https://your-backend.com/api/image'),
    headers: {
      'Content-Type': 'application/octet-stream',
      'X-Image-Width': width.toString(),
      'X-Image-Height': height.toString(),
    },
    body: pixels,
  );
  
  if (response.statusCode == 200) {
    print('Изображение успешно отправлено');
  }
}
```

### Пример с multipart/form-data

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendToBackend(
  Uint8List pixels,
  int width,
  int height,
) async {
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('https://your-backend.com/api/image'),
  );
  
  request.fields['width'] = width.toString();
  request.fields['height'] = height.toString();
  request.files.add(
    http.MultipartFile.fromBytes(
      'image',
      pixels,
      filename: 'image.raw',
    ),
  );
  
  final response = await request.send();
  if (response.statusCode == 200) {
    print('Изображение успешно отправлено');
  }
}
```

## Декодирование на Python

### Установка зависимостей

```bash
pip3 install Pillow numpy
```

### Использование скрипта

```bash
# Базовое использование
python3 decode_raw_rgba.py image.raw 800 600

# С указанием выходного файла
python3 decode_raw_rgba.py image.raw 800 600 output.png

# Из stdin (для pipe)
cat image.raw | python3 decode_raw_rgba.py - 800 600 output.png
```

### Пример сохранения из Flutter и декодирования

```dart
// В Flutter
final result = await exporter.captureFromRepaintBoundary(key);
if (result != null) {
  // Сохраняем в файл (для тестирования)
  final file = File('image.raw');
  await file.writeAsBytes(result.pixels);
  print('Сохранено: image.raw (${result.width}x${result.height})');
}
```

```bash
# На Mac
python3 decode_raw_rgba.py image.raw 800 600 image.png
```

### Структура скрипта

Скрипт `decode_raw_rgba.py`:
- Читает raw RGBA файл
- Проверяет размер данных
- Конвертирует в numpy array
- Создает PIL Image
- Сохраняет в PNG

## Параметры

### RawRgbaExporter

- `pixelRatio` (double, по умолчанию: 1.0)
  - Коэффициент масштабирования
  - 1.0 = оригинальный размер
  - 0.5 = половина размера
  - 2.0 = двойной размер

- `enableLogging` (bool, по умолчанию: true)
  - Включить/выключить подробное логирование

## Производительность

Примерные времена выполнения (на среднем устройстве):
- Захват изображения: 10-30ms
- Конвертация в ByteData: 5-15ms
- Конвертация в Uint8List: <1ms
- **Общее время: 15-50ms**

Размер данных:
- 400x600 пикселей = 960,000 байт (~937 KB)
- 800x1200 пикселей = 3,840,000 байт (~3.66 MB)
- 1920x1080 пикселей = 8,294,400 байт (~7.91 MB)

## Обработка ошибок

Все методы возвращают `null` в случае ошибки:

```dart
final result = await exporter.captureFromRepaintBoundary(key);
if (result == null) {
  print('Ошибка при захвате');
  return;
}
// Используем result
```

Ошибки логируются в консоль с префиксом `[RawRgbaExporter] ОШИБКА:`.

## Примеры

Полный пример использования см. в `lib/screenrecorder/src/raw_rgba_example.dart`.
