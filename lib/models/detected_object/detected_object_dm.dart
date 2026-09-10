import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:tensorflow_demo/models/screen_params.dart';

/// Represents the recognition output from the model
class DetectedObjectDm {
  const DetectedObjectDm({
    required this.label,
    required this.score,
    required this.location,
    this.extractedText,
    this.imageWidth,
    this.imageHeight,
  });

  /// Label of the result
  final String label;

  /// Confidence [0.0, 1.0]
  final num score;

  /// Location of bounding box rect
  ///
  /// The rectangle corresponds to the raw input image
  /// passed for inference
  final Rect location;

  /// Recognized text within this object's region (if any)
  final String? extractedText;

  /// Width of the source image in pixels (if available)
  final int? imageWidth;

  /// Height of the source image in pixels (if available)
  final int? imageHeight;

  /// Normalized height of the object relative to image height [0.0, 1.0]
  double get height => location.height;

  /// Normalized width of the object relative to image width [0.0, 1.0]
  double get width => location.width;

  /// Height of the object box in render/screen coordinates
  double get renderHeight => renderLocation.height;

  /// Width of the object box in render/screen coordinates
  double get renderWidth => renderLocation.width;

  /// Aspect ratio of the original image (width / height)
  double get imageAspectRatio {
    if (imageWidth != null && imageHeight != null && imageHeight! > 0) {
      return imageWidth! / imageHeight!;
    }
    return 1.0;
  }

  /// Raw vertical dimension span in cm
  double get rawDimYInCm => location.height * 30.0;

  /// Raw horizontal dimension span in cm, adjusted for image aspect ratio
  double get rawDimXInCm => location.width * 30.0 * imageAspectRatio;

  /// Set of labels that are naturally taller along their primary body axis
  static const Set<String> _naturallyTallLabels = {
    'bottle',
    'container',
    'cup',
    'box',
    'person',
    'vase',
    'wine glass',
    'cell phone',
    'toothbrush',
    'knife',
    'fork',
    'spoon',
    'tie',
    'umbrella',
    'banana',
    'carrot',
    'remote',
    'scissors',
    'hair drier',
  };

  bool get _isNaturallyTallObject {
    final l = label.toLowerCase();
    return _naturallyTallLabels.any((item) => l.contains(item));
  }

  /// Height of object in centimeters (cm)
  ///
  /// Calculates physical height accounting for frame scale (~30cm FOV),
  /// image aspect ratio, and object orientation.
  double get heightInCm {
    final dimY = rawDimYInCm;
    final dimX = rawDimXInCm;

    if (_isNaturallyTallObject) {
      return max(dimY, dimX);
    } else if (dimY >= dimX) {
      return dimY;
    } else {
      return dimX;
    }
  }

  /// Width of object in centimeters (cm)
  ///
  /// Calculates physical width accounting for frame scale (~30cm FOV),
  /// image aspect ratio, and object orientation.
  double get widthInCm {
    final dimY = rawDimYInCm;
    final dimX = rawDimXInCm;

    if (_isNaturallyTallObject) {
      return min(dimY, dimX);
    } else if (dimY >= dimX) {
      return dimX;
    } else {
      return dimY;
    }
  }

  /// Height of the object box in image pixel coordinates given image height
  double pixelHeight(int imgHeight) => location.height * imgHeight;

  /// Width of the object box in image pixel coordinates given image width
  double pixelWidth(int imgWidth) => location.width * imgWidth;

  DetectedObjectDm copyWith({
    String? label,
    num? score,
    Rect? location,
    String? extractedText,
    int? imageWidth,
    int? imageHeight,
  }) {
    return DetectedObjectDm(
      label: label ?? this.label,
      score: score ?? this.score,
      location: location ?? this.location,
      extractedText: extractedText ?? this.extractedText,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
    );
  }

  /// Returns bounding box rectangle corresponding to the
  /// displayed image on screen
  Rect get renderLocation {
    final previewSize = ScreenParams.screenPreviewSize;
    return Rect.fromLTRB(
      location.left * previewSize.width,
      location.top * previewSize.height,
      location.right * previewSize.width,
      location.bottom * previewSize.height,
    );
  }

  /// Returns pixel coordinates for a given source image width and height
  Rect pixelLocation(int imgWidth, int imgHeight) {
    return Rect.fromLTRB(
      location.left * imgWidth,
      location.top * imgHeight,
      location.right * imgWidth,
      location.bottom * imgHeight,
    );
  }

  @override
  String toString() {
    return 'DetectedObjectDm(label: $label, score: $score, location: $location, heightInCm: $heightInCm, widthInCm: $widthInCm, extractedText: $extractedText)';
  }
}
