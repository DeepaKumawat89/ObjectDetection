import 'dart:async';
import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tensorflow_demo/models/detected_object/detected_object_dm.dart';
import 'package:tensorflow_demo/models/screen_params.dart';
import 'package:tensorflow_demo/screens/live_object_detection/widgets/rounded_button.dart';
import 'package:tensorflow_demo/services/detector.dart';
import 'package:tensorflow_demo/services/navigation_service.dart';
import 'package:tensorflow_demo/services/snackbar_service.dart';
import 'package:tensorflow_demo/utils/error_handler.dart';
import 'package:tensorflow_demo/values/app_routes.dart';
import 'package:tensorflow_demo/widgets/app_dialog.dart';
import 'package:tensorflow_demo/widgets/box_widget.dart';

class LiveObjectDetectionScreen extends StatefulWidget {
  const LiveObjectDetectionScreen({super.key});

  @override
  State<LiveObjectDetectionScreen> createState() =>
      _LiveObjectDetectionScreenState();
}

class _LiveObjectDetectionScreenState
    extends State<LiveObjectDetectionScreen> {
  final _imagePicker = ImagePicker();

  String? message;
  bool _isProcessingAction = false;

  late final AppLifecycleListener _appLifecycleListener;

  /// List of available cameras
  List<CameraDescription> cameras = [];

  int cameraIndex = 0;

  /// Controller
  CameraController? _cameraController;

  /// Object Detector is running on a background [Isolate].
  Detector? _detector;

  StreamSubscription? _objectDetectorStream;

  /// Results to draw bounding boxes
  List<DetectedObjectDm>? detectedObjectList;

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      onResume: _init,
      onInactive: () {
        _cameraController?.stopImageStream().catchError((_) {});
        _objectDetectorStream?.cancel();
        _detector?.stop();
      },
    );
    _init();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    return Scaffold(
      appBar: AppBar(title: const Text('Live Object Detection')),
      body: controller == null || !controller.value.isInitialized
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message ?? 'Initializing camera...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _init,
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      ScreenParams.screenSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRect(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: controller.value.previewSize?.height ??
                                    constraints.maxWidth,
                                height: controller.value.previewSize?.width ??
                                    constraints.maxHeight,
                                child: CameraPreview(controller),
                              ),
                            ),
                          ),
                          // Bounding boxes
                          ...?detectedObjectList?.map(
                            (detectedObject) => Positioned.fromRect(
                              rect: detectedObject.renderLocation,
                              child:
                                  BoxWidget.fromDetectedObject(detectedObject),
                            ),
                          ),
                          if (_isProcessingAction)
                            Container(
                              color: Colors.black38,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                Container(
                  color: Colors.black,
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: 12,
                    bottom: 12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RoundedButton(
                            size: 48,
                            side: BorderSide.none,
                            color: Colors.white.withValues(alpha: 0.25),
                            onTap: _isProcessingAction
                                ? null
                                : _pickImageFromGallery,
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/vectors/gallery.svg',
                                width: 24,
                                height: 24,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Gallery',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RoundedButton(
                            size: 60,
                            padding: const EdgeInsets.all(3),
                            onTap: _isProcessingAction ? null : _takePicture,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Capture',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RoundedButton(
                            size: 48,
                            side: BorderSide.none,
                            color: Colors.white.withValues(alpha: 0.25),
                            onTap: _isProcessingAction ? null : _flipCamera,
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/vectors/repeate-music.svg',
                                width: 26,
                                height: 26,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Flip Camera',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _appLifecycleListener.dispose();
    _cameraController?.dispose();
    _objectDetectorStream?.cancel();
    _detector?.stop();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await _initializeCamera();
      await _initializeDetector();

      /// Listen to each frame from calling the image stream
      await _cameraController?.startImageStream(onLatestImageAvailable);

      final size = _cameraController?.value.previewSize;
      if (size != null) ScreenParams.previewSize = size;

      if (mounted) setState(() {});
    } catch (e) {
      log('Error during camera initialization: $e');
      if (mounted) {
        setState(() {
          message = ErrorHandler.getErrorMessage(e);
        });
      }
    }
  }

  /// Initializes the camera by setting [_cameraController]
  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            message = 'No camera is available on this device.';
          });
        }
        log('No Camera Available');
        return;
      }

      cameraIndex = 0;
      final camera = cameras[cameraIndex];
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController?.initialize();
      try {
        await _cameraController?.setFocusMode(FocusMode.auto);
      } catch (_) {
        // Focus mode setting may fail on devices without auto focus
      }
    } on CameraException catch (e) {
      log('CameraException initializing camera: $e');
      final errMsg = ErrorHandler.getErrorMessage(e);
      if (mounted) {
        setState(() {
          message = errMsg;
        });
        await showAppAlertDialog(
          context: context,
          title: 'Camera Error',
          message: errMsg,
        );
      }
    } catch (e) {
      log('Unexpected error initializing camera: $e');
      final errMsg = ErrorHandler.getErrorMessage(e);
      if (mounted) {
        setState(() {
          message = errMsg;
        });
      }
    }
  }

  Future<void> _initializeDetector() async {
    try {
      final detector = await Detector.start();
      if (mounted) {
        setState(() {
          _detector = detector;
          _objectDetectorStream =
              detector.resultsStream.listen((detectedObjects) {
            if (mounted) setState(() => detectedObjectList = detectedObjects);
          });
        });
      }
    } catch (e) {
      log('Error initializing Detector: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_isProcessingAction || cameras.length <= 1) return;

    setState(() {
      _isProcessingAction = true;
    });

    try {
      final newIndex = cameraIndex == 1 ? 0 : 1;
      cameraIndex = newIndex;
      await _cameraController?.stopImageStream().catchError((_) {});

      _cameraController = CameraController(
        cameras[newIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController?.initialize();
      try {
        await _cameraController?.setFocusMode(FocusMode.auto);
      } catch (_) {}

      await _cameraController?.startImageStream(onLatestImageAvailable);

      if (mounted) {
        setState(() {
          ScreenParams.previewSize =
              _cameraController?.value.previewSize ?? ScreenParams.previewSize;
        });
      }
    } catch (e) {
      log('Error flipping camera: $e');
      SnackBarService.showError('Failed to switch camera.');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _takePicture() async {
    if (_isProcessingAction || _cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isProcessingAction = true;
    });

    try {
      final capturedImage = await _cameraController?.takePicture();
      if (capturedImage == null) {
        SnackBarService.showError('Unable to capture photo.');
        return;
      }
      final decodedImage = await capturedImage.readAsBytes();
      if (decodedImage.isNotEmpty && mounted) {
        NavigationService.instance
          ..pop()
          ..pushNamed(AppRoutes.photoAnalyzedScreen, arguments: decodedImage);
      } else {
        SnackBarService.showError('Captured photo data is empty.');
      }
    } catch (e) {
      log('Error taking picture: $e');
      SnackBarService.showError('Failed to capture photo. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_isProcessingAction) return;

    setState(() {
      _isProcessingAction = true;
    });

    try {
      final result = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (result == null) return;
      final readAsBytesSync = await result.readAsBytes();
      if (readAsBytesSync.isNotEmpty && mounted) {
        NavigationService.instance
          ..pop()
          ..pushNamed(
            AppRoutes.photoAnalyzedScreen,
            arguments: readAsBytesSync,
          );
      } else {
        SnackBarService.showError('Selected gallery image is empty.');
      }
    } catch (e) {
      log('Error picking image from gallery: $e');
      final errorMsg = ErrorHandler.getErrorMessage(e);
      SnackBarService.showError('Failed to pick image: $errorMsg');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  /// Callback to receive each frame [CameraImage] perform inference on it
  void onLatestImageAvailable(CameraImage cameraImage) {
    _detector?.processFrame(cameraImage);
  }
}
