class ScreenshotController {
  Future<String> Function()? _captureFunction;

  void setCaptureFunction(Future<String> Function() function) {
    _captureFunction = function;
  }

  Future<String> capture() async {
    if (_captureFunction == null) {
      throw Exception('ScreenshotWrapper is not ready');
    }
    return await _captureFunction!();
  }
}
