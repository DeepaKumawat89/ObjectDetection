import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:image/image.dart';
import 'package:tensorflow_demo/values/app_constants.dart';

// ImageUtils
class ImageUtils {
  /// Letterboxes [image] into target dimensions maintaining aspect ratio.
  static ({
    Image letterboxedImage,
    double scale,
    int padX,
    int padY,
  }) letterboxImage(
    Image image, {
    int targetWidth = AppConstants.ssdCompatibleImageWidth,
    int targetHeight = AppConstants.ssdCompatibleImageHeight,
  }) {
    final scale = min(
      targetWidth / image.width,
      targetHeight / image.height,
    );

    final scaledWidth = (image.width * scale).round().clamp(1, targetWidth);
    final scaledHeight = (image.height * scale).round().clamp(1, targetHeight);

    final resized = copyResize(
      image,
      width: scaledWidth,
      height: scaledHeight,
    );

    final padX = (targetWidth - scaledWidth) ~/ 2;
    final padY = (targetHeight - scaledHeight) ~/ 2;

    final letterboxed = Image(
      width: targetWidth,
      height: targetHeight,
    );
    letterboxed.clear(ColorRgb8(128, 128, 128));

    compositeImage(
      letterboxed,
      resized,
      dstX: padX,
      dstY: padY,
    );

    return (
      letterboxedImage: letterboxed,
      scale: scale,
      padX: padX,
      padY: padY,
    );
  }

  /// Transforms a raw normalized bounding box ([yMin, xMin, yMax, xMax])
  /// from letterboxed model space back to original image pixel coordinates.
  static Rect unletterboxRect({
    required List<num> raw,
    required double scale,
    required int padX,
    required int padY,
    required int srcWidth,
    required int srcHeight,
    int targetWidth = AppConstants.ssdCompatibleImageWidth,
    int targetHeight = AppConstants.ssdCompatibleImageHeight,
  }) {
    final rawYMin = raw[0];
    final rawXMin = raw[1];
    final rawYMax = raw[2];
    final rawXMax = raw[3];

    // Model space pixel coordinates
    final modelXMin = rawXMin * targetWidth;
    final modelYMin = rawYMin * targetHeight;
    final modelXMax = rawXMax * targetWidth;
    final modelYMax = rawYMax * targetHeight;

    // Remove letterbox padding and un-scale to original dimensions
    final xMin = ((modelXMin - padX) / scale).clamp(0.0, srcWidth.toDouble());
    final yMin = ((modelYMin - padY) / scale).clamp(0.0, srcHeight.toDouble());
    final xMax = ((modelXMax - padX) / scale).clamp(0.0, srcWidth.toDouble());
    final yMax = ((modelYMax - padY) / scale).clamp(0.0, srcHeight.toDouble());

    return Rect.fromLTRB(xMin, yMin, xMax, yMax);
  }

  /// Crops the region specified by [boundingBox] from [imageBytes].
  /// Supports normalized [0..1] or pixel coordinates, adds a padding margin
  /// to prevent cutting off text at character edges, and optionally applies
  /// grayscale/contrast preprocessing for OCR.
  static Uint8List? cropImageRegion(
    Uint8List imageBytes,
    Rect boundingBox, {
    double paddingRatio = 0.10,
    bool preprocessForOcr = true,
  }) {
    var decoded = decodeImage(imageBytes);
    if (decoded == null) return null;
    decoded = bakeOrientation(decoded);

    final isNormalized = boundingBox.left <= 1.0 &&
        boundingBox.top <= 1.0 &&
        boundingBox.right <= 1.0 &&
        boundingBox.bottom <= 1.0;

    final left = isNormalized ? boundingBox.left * decoded.width : boundingBox.left;
    final top = isNormalized ? boundingBox.top * decoded.height : boundingBox.top;
    final right = isNormalized ? boundingBox.right * decoded.width : boundingBox.right;
    final bottom = isNormalized ? boundingBox.bottom * decoded.height : boundingBox.bottom;

    final width = right - left;
    final height = bottom - top;
    final padX = width * paddingRatio;
    final padY = height * paddingRatio;

    final cropX = (left - padX).toInt().clamp(0, decoded.width - 1);
    final cropY = (top - padY).toInt().clamp(0, decoded.height - 1);
    final cropWidth = (width + 2 * padX).toInt().clamp(1, decoded.width - cropX);
    final cropHeight = (height + 2 * padY).toInt().clamp(1, decoded.height - cropY);

    var cropped = copyCrop(
      decoded,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    if (preprocessForOcr) {
      cropped = grayscale(cropped);
      cropped = contrast(cropped, contrast: 130);
    }

    return encodeJpg(cropped, quality: 95);
  }

  /// Preprocesses full [imageBytes] for optimal OCR recognition:
  /// Converts to grayscale and enhances contrast.
  static Uint8List preprocessImageForOcr(Uint8List imageBytes) {
    var decoded = decodeImage(imageBytes);
    if (decoded == null) return imageBytes;
    decoded = bakeOrientation(decoded);

    var processed = grayscale(decoded);
    processed = contrast(processed, contrast: 130);

    return encodeJpg(processed, quality: 95);
  }

  static Image? convertCameraImageToImage(CameraImage cameraImage) {
    return switch (cameraImage.format.group) {
      ImageFormatGroup.yuv420 => _convertYUV420ToRGBImage(cameraImage),
      ImageFormatGroup.bgra8888 => _convertBGRA8888ToRGBImage(cameraImage),
      ImageFormatGroup.jpeg => _convertJPEGToImage(cameraImage),
      ImageFormatGroup.nv21 => _convertNV21ToRGBImage(cameraImage),
      ImageFormatGroup.unknown => null,
    };
  }

  static Image? _convertJPEGToImage(CameraImage cameraImage) {
    // Extract the bytes from the CameraImage
    // first plane is responsible for holding all the image data
    final bytes = cameraImage.planes[0].bytes;

    // Create a new Image instance from the JPEG bytes
    var image = decodeImage(bytes);
    if (image != null) {
      image = bakeOrientation(image);
    }

    return image;
  }

  static Image _convertNV21ToRGBImage(CameraImage cameraImage) {
    // Extract the bytes from the CameraImage
    final yuvBytes = cameraImage.planes[0].bytes;
    final vuBytes = cameraImage.planes[1].bytes;

    // Create a new Image instance
    final image = Image(
      width: cameraImage.width,
      height: cameraImage.height,
    );

    // Convert NV21 to RGB
    _convertNV21ToRGB(
      yuvBytes,
      vuBytes,
      cameraImage.width,
      cameraImage.height,
      image,
    );

    return image;
  }

  static void _convertNV21ToRGB(
    Uint8List yuvBytes,
    Uint8List vuBytes,
    int width,
    int height,
    Image image,
  ) {
    // Conversion logic from NV21 to RGB
    // ...

    // Example conversion logic using the `imageLib` package
    // This is just a placeholder and may not be the most efficient method
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yIndex = y * width + x;
        final uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

        final yValue = yuvBytes[yIndex];
        final uValue = vuBytes[uvIndex * 2];
        final vValue = vuBytes[uvIndex * 2 + 1];

        // Convert YUV to RGB
        final r = yValue + 1.402 * (vValue - 128);
        final g =
            yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128);
        final b = yValue + 1.772 * (uValue - 128);

        // Set the RGB pixel values in the Image instance
        image.setPixelRgba(x, y, r.toInt(), g.toInt(), b.toInt(), 255);
      }
    }
  }

  // Converts a [CameraImage] in BGRA888 format to [imageLib.Image] in RGB format
  static Image _convertBGRA8888ToRGBImage(CameraImage cameraImage) {
    final firstPlane = cameraImage.planes[0];
    return Image.fromBytes(
      width: firstPlane.width!,
      height: firstPlane.height!,
      bytes: firstPlane.bytes.buffer,
      order: ChannelOrder.bgra,
    );
  }

  static Image _convertYUV420ToRGBImage(CameraImage cameraImage) {
    final imageWidth = cameraImage.width;
    final imageHeight = cameraImage.height;

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel!;

    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel!;

    final image = Image(width: imageWidth, height: imageHeight);

    for (int h = 0; h < imageHeight; h++) {
      int uvh = (h / 2).floor();

      for (int w = 0; w < imageWidth; w++) {
        int uvw = (w / 2).floor();

        final yIndex = (h * yRowStride) + (w * yPixelStride);

        // Y plane should have positive values belonging to [0...255]
        final int y = yBuffer[yIndex];

        // U/V Values are subsampled i.e. each pixel in U/V chanel in a
        // YUV_420 image act as chroma value for 4 neighbouring pixels
        final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

        // U/V values ideally fall under [-0.5, 0.5] range. To fit them into
        // [0, 255] range they are scaled up and centered to 128.
        // Operation below brings U/V values to [-128, 127].
        final int u = uBuffer[uvIndex];
        final int v = vBuffer[uvIndex];

        // Compute RGB values per formula above.
        int r = (y + v * 1436 / 1024 - 179).round();
        int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
        int b = (y + u * 1814 / 1024 - 227).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        image.setPixelRgb(w, h, r, g, b);
      }
    }
    return image;
  }
}
