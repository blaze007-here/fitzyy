import 'package:camera/camera.dart';

/// Provides safe camera lifecycle management for a camera StatefulWidget.
class CameraService {
  CameraService({
    this.resolutionPreset = ResolutionPreset.high,
    this.enableAudio = false,
  });

  final ResolutionPreset resolutionPreset;
  final bool enableAudio;

  CameraController? _controller;
  Future<void>? _initializationFuture;
  Object? _error;
  StackTrace? _errorStackTrace;

  /// The controller to pass to a [CameraPreview] after initialization.
  CameraController? get controller => _controller;

  /// The in-flight or completed initialization future for a FutureBuilder.
  Future<void>? get initializationFuture => _initializationFuture;

  /// The most recent initialization or capture error, if any.
  Object? get error => _error;

  /// The stack trace associated with [error], when one is available.
  StackTrace? get errorStackTrace => _errorStackTrace;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Finds and initializes the rear camera once.
  Future<void> initialize() {
    final existingFuture = _initializationFuture;
    if (existingFuture != null) return existingFuture;

    _error = null;
    _errorStackTrace = null;
    final future = _initialize();
    _initializationFuture = future;
    return future;
  }

  Future<void> _initialize() async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setError(const CameraServiceException('No cameras are available.'));
        return;
      }

      CameraDescription? rearCamera;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          rearCamera = camera;
          break;
        }
      }
      if (rearCamera == null) {
        _setError(const CameraServiceException('No rear camera is available.'));
        return;
      }

      controller = CameraController(
        rearCamera,
        resolutionPreset,
        enableAudio: enableAudio,
      );
      await controller.initialize();
      _controller = controller;
    } on Object catch (error, stackTrace) {
      if (controller != null) {
        await _disposeQuietly(controller);
      }
      _setError(
        CameraServiceException(
          'Could not initialize the rear camera.',
          cause: error,
          stackTrace: stackTrace,
        ),
        stackTrace,
      );
    }
  }

  /// Captures a photo when the camera is ready; otherwise returns null.
  Future<XFile?> takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;

    try {
      return await controller.takePicture();
    } on Object catch (error, stackTrace) {
      _setError(error, stackTrace);
      return null;
    }
  }

  /// Waits for initialization, then releases the camera controller.
  Future<void> dispose() async {
    final initializationFuture = _initializationFuture;
    if (initializationFuture != null) {
      await initializationFuture;
    }

    final controller = _controller;
    _controller = null;
    _initializationFuture = null;
    if (controller != null) {
      await _disposeQuietly(controller);
    }
  }

  void _setError(Object error, [StackTrace? stackTrace]) {
    _error = error;
    _errorStackTrace = stackTrace;
  }

  Future<void> _disposeQuietly(CameraController controller) async {
    try {
      await controller.dispose();
    } on Object {
      // Camera cleanup should not turn a recoverable camera failure into a
      // widget exception.
    }
  }
}

class CameraServiceException implements Exception {
  const CameraServiceException(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'CameraServiceException: $message';
}
