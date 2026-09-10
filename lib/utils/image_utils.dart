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
      targetWidth / max(1, image.width),
      targetHeight / max(1, image.height),
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

    final safeScale = scale <= 0 ? 1.0 : scale;

    // Remove letterbox padding and un-scale to original dimensions
    final xMin = ((modelXMin - padX) / safeScale).clamp(0.0, srcWidth.toDouble());
    final yMin = ((modelYMin - padY) / safeScale).clamp(0.0, srcHeight.toDouble());
    final xMax = ((modelXMax - padX) / safeScale).clamp(0.0, srcWidth.toDouble());
    final yMax = ((modelYMax - padY) / safeScale).clamp(0.0, srcHeight.toDouble());

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
    if (imageBytes.isEmpty) return null;
    var decoded = decodeImage(imageBytes);
    if (decoded == null) return null;
    decoded = bakeOrientation(decoded);

    if (decoded.width <= 0 || decoded.height <= 0) return null;

    final isNormalized = boundingBox.left <= 1.0 &&
        boundingBox.top <= 1.0 &&
        boundingBox.right <= 1.0 &&
        boundingBox.bottom <= 1.0;

    final left = isNormalized ? boundingBox.left * decoded.width : boundingBox.left;
    final top = isNormalized ? boundingBox.top * decoded.height : boundingBox.top;
    final right = isNormalized ? boundingBox.right * decoded.width : boundingBox.right;
    final bottom = isNormalized ? boundingBox.bottom * decoded.height : boundingBox.bottom;

    final width = max(1.0, right - left);
    final height = max(1.0, bottom - top);
    final padX = width * paddingRatio;
    final padY = height * paddingRatio;

    final int cropX = (left - padX).toInt().clamp(0, max(0, decoded.width - 1)).toInt();
    final int cropY = (top - padY).toInt().clamp(0, max(0, decoded.height - 1)).toInt();
    final int maxCropW = max(1, decoded.width - cropX);
    final int maxCropH = max(1, decoded.height - cropY);
    final int cropWidth = (width + 2 * padX).toInt().clamp(1, maxCropW).toInt();
    final int cropHeight = (height + 2 * padY).toInt().clamp(1, maxCropH).toInt();

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
    if (imageBytes.isEmpty) return imageBytes;
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
    if (cameraImage.planes.isEmpty) return null;
    final bytes = cameraImage.planes[0].bytes;
    if (bytes.isEmpty) return null;

    var image = decodeImage(bytes);
    if (image != null) {
      image = bakeOrientation(image);
    }

    return image;
  }

  static Image? _convertNV21ToRGBImage(CameraImage cameraImage) {
    if (cameraImage.planes.length < 2) return null;
    final yuvBytes = cameraImage.planes[0].bytes;
    final vuBytes = cameraImage.planes[1].bytes;

    final image = Image(
      width: cameraImage.width,
      height: cameraImage.height,
    );

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
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yIndex = y * width + x;
        final uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

        if (yIndex >= yuvBytes.length || (uvIndex * 2 + 1) >= vuBytes.length) {
          continue;
        }

        final yValue = yuvBytes[yIndex];
        final uValue = vuBytes[uvIndex * 2];
        final vValue = vuBytes[uvIndex * 2 + 1];

        final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255);
        final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).clamp(0, 255);
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255);

        image.setPixelRgba(x, y, r.toInt(), g.toInt(), b.toInt(), 255);
      }
    }
  }

  static Image? _convertBGRA8888ToRGBImage(CameraImage cameraImage) {
    if (cameraImage.planes.isEmpty) return null;
    final firstPlane = cameraImage.planes[0];
    if (firstPlane.width == null || firstPlane.height == null) return null;

    return Image.fromBytes(
      width: firstPlane.width!,
      height: firstPlane.height!,
      bytes: firstPlane.bytes.buffer,
      order: ChannelOrder.bgra,
    );
  }

  static Image? _convertYUV420ToRGBImage(CameraImage cameraImage) {
    if (cameraImage.planes.length < 3) return null;
    final imageWidth = cameraImage.width;
    final imageHeight = cameraImage.height;

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel ?? 1;

    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final image = Image(width: imageWidth, height: imageHeight);

    for (int h = 0; h < imageHeight; h++) {
      int uvh = (h / 2).floor();

      for (int w = 0; w < imageWidth; w++) {
        int uvw = (w / 2).floor();

        final yIndex = (h * yRowStride) + (w * yPixelStride);
        final uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

        if (yIndex >= yBuffer.length || uvIndex >= uBuffer.length || uvIndex >= vBuffer.length) {
          continue;
        }

        final int y = yBuffer[yIndex];
        final int u = uBuffer[uvIndex];
        final int v = vBuffer[uvIndex];

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
