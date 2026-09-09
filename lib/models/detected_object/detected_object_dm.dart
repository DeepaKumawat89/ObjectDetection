import 'package:flutter/cupertino.dart';
import 'package:tensorflow_demo/models/screen_params.dart';
import 'package:tensorflow_demo/values/app_constants.dart';

/// Represents the recognition output from the model
class DetectedObjectDm {
  const DetectedObjectDm({
    required this.label,
    required this.score,
    required this.location,
    this.extractedText,
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

  DetectedObjectDm copyWith({
    String? label,
    num? score,
    Rect? location,
    String? extractedText,
  }) {
    return DetectedObjectDm(
      label: label ?? this.label,
      score: score ?? this.score,
      location: location ?? this.location,
      extractedText: extractedText ?? this.extractedText,
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
    return 'DetectedObjectDm(label: $label, score: $score, location: $location, extractedText: $extractedText)';
  }
}
