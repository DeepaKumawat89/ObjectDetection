import 'dart:math';
import 'dart:ui';

import 'package:image/image.dart';
import 'package:tensorflow_demo/models/detected_object/detected_object_dm.dart';
import 'package:tensorflow_demo/utils/image_utils.dart';
import 'package:tensorflow_demo/values/extensions.dart';
import 'package:tensorflow_demo/values/typedefs.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TensorflowHelper {
  const TensorflowHelper._();

  static List<String> getClassification({
    required int numberOfDetections,
    required List<int> classes,
    required List<String>? labelList,
  }) {
    final labels = labelList ?? [];
    if (labels.isEmpty) return List.filled(numberOfDetections, '???');

    final classification = <String>[];

    for (var i = 0; i < numberOfDetections; i++) {
      final classIdx = classes[i];
      String label = '???';

      if (classIdx >= 0 && classIdx < labels.length) {
        label = labels[classIdx].trim();
      }

      // If mapped label is a placeholder or out of bounds, check 1-based indexing fallback
      if ((label == '???' || label == '??' || label.isEmpty) && classIdx > 0 && classIdx <= labels.length) {
        final altLabel = labels[classIdx - 1].trim();
        if (altLabel.isNotEmpty && altLabel != '???' && altLabel != '??') {
          label = altLabel;
        }
      }

      classification.add(label);
    }

    return classification;
  }

  static void drawOnImage({
    required Image imageInput,
    required Rect rect,
    required num score,
    String? classification,
    Color? color,
  }) {
    final drawColor = color ?? ColorRgb8(255, 255, 255);

    final top = rect.top.toInt();
    final left = rect.left.toInt();

    drawRect(
      imageInput,
      x1: left,
      y1: top,
      x2: rect.right.toInt(),
      y2: rect.bottom.toInt(),
      color: drawColor,
      thickness: 3,
    );

    if (classification == null) return;
    final normalizedHeight = imageInput.height > 0 ? rect.height / imageInput.height : 0.0;
    final heightInCm = normalizedHeight * 30.0;
    drawString(
      imageInput,
      '$classification (${heightInCm.toStringAsFixed(1)} cm)',
      font: arial14,
      x: left + 1,
      y: top + 1,
      color: drawColor,
    );
  }

  /// Performs Non-Maximum Suppression (NMS).
  /// When [classAgnostic] is true, heavily overlapping boxes (> [iouThreshold])
  /// are suppressed even across different classes to prevent duplicate/conflicting
  /// labels on the same physical object region.
  static List<DetectedObjectDm> applyNMS(
    List<DetectedObjectDm> detections, {
    double iouThreshold = 0.45,
    bool classAgnostic = true,
  }) {
    final sorted = List<DetectedObjectDm>.from(detections)
      ..sort((a, b) => b.score.compareTo(a.score));

    final result = <DetectedObjectDm>[];

    while (sorted.isNotEmpty) {
      final best = sorted.removeAt(0);
      result.add(best);

      sorted.removeWhere((item) {
        final iou = _calculateIoU(best.location, item.location);
        if (classAgnostic) {
          return iou > iouThreshold;
        } else {
          return item.label == best.label && iou > iouThreshold;
        }
      });
    }

    return result;
  }

  static double _calculateIoU(Rect a, Rect b) {
    final intersectionLeft = max(a.left, b.left);
    final intersectionTop = max(a.top, b.top);
    final intersectionRight = min(a.right, b.right);
    final intersectionBottom = min(a.bottom, b.bottom);

    if (intersectionRight <= intersectionLeft ||
        intersectionBottom <= intersectionTop) {
      return 0.0;
    }

    final intersectionArea =
        (intersectionRight - intersectionLeft) * (intersectionBottom - intersectionTop);
    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    final unionArea = areaA + areaB - intersectionArea;

    return unionArea <= 0 ? 0.0 : intersectionArea / unionArea;
  }

  static AnalyseImageCallback analyseImage(
    Image image, {
    required Interpreter interpreter,
    required List<String> label,
    bool returnDetectedImage = true,
    bool drawObjectOnImage = true,
    double scoreThreshold = 0.40,
  }) {
    final letterboxResult = ImageUtils.letterboxImage(image);
    final letterboxedImage = letterboxResult.letterboxedImage;

    final generatedOutput = _runInference(letterboxedImage, interpreter);

    final locationsRaw = generatedOutput[0].first as List<List<num>>;
    final classesRaw = generatedOutput[1].first as List<num>;
    final scores = generatedOutput[2].first as List<num>;
    final numberOfDetectionsRaw = generatedOutput[3].first as double;

    final classes = classesRaw.toIntList;
    final numberOfDetections = numberOfDetectionsRaw.toInt();

    final classifications = getClassification(
      numberOfDetections: numberOfDetections,
      classes: classes,
      labelList: label,
    );

    final rawDetectedObjects = <DetectedObjectDm>[];

    for (var i = 0; i < numberOfDetections; i++) {
      final score = scores[i];
      final detectedObjectName = classifications[i];

      if (score >= scoreThreshold && detectedObjectName != '???') {
        final rawLocation = locationsRaw[i];

        final pixelRect = ImageUtils.unletterboxRect(
          raw: rawLocation,
          scale: letterboxResult.scale,
          padX: letterboxResult.padX,
          padY: letterboxResult.padY,
          srcWidth: image.width,
          srcHeight: image.height,
        );

        final normalizedRect = Rect.fromLTRB(
          (pixelRect.left / image.width).clamp(0.0, 1.0),
          (pixelRect.top / image.height).clamp(0.0, 1.0),
          (pixelRect.right / image.width).clamp(0.0, 1.0),
          (pixelRect.bottom / image.height).clamp(0.0, 1.0),
        );

        rawDetectedObjects.add(
          DetectedObjectDm(
            label: detectedObjectName,
            score: score,
            location: normalizedRect,
          ),
        );
      }
    }

    final filteredDetectedObjects = applyNMS(rawDetectedObjects);

    final Image? annotatedImage = (returnDetectedImage || drawObjectOnImage)
        ? copyResize(image, width: image.width, height: image.height)
        : null;

    if (drawObjectOnImage && annotatedImage != null) {
      for (final obj in filteredDetectedObjects) {
        final pixelRect = Rect.fromLTRB(
          obj.location.left * annotatedImage.width,
          obj.location.top * annotatedImage.height,
          obj.location.right * annotatedImage.width,
          obj.location.bottom * annotatedImage.height,
        );
        drawOnImage(
          classification: obj.label,
          imageInput: annotatedImage,
          rect: pixelRect,
          score: obj.score,
        );
      }
    }

    final imageOutput = returnDetectedImage && annotatedImage != null
        ? encodeJpg(annotatedImage, quality: 90)
        : null;

    return (imageBytes: imageOutput, detectedObjects: filteredDetectedObjects);
  }

  static List<List<Object>> _runInference(
    Image image,
    Interpreter interpreter,
  ) {
    // Creating matrix representation [300, 300, 3] from the image
    final imageMatrix = List.generate(
      image.height,
      (y) => List.generate(
        image.width,
        (x) {
          final pixel = image.getPixel(x, y);
          return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        },
      ),
    );

    // Set input tensor [1, 300, 300, 3]
    final input = [imageMatrix];

    // Set output tensor
    // Locations: [1, 10, 4]
    // Classes: [1, 10],
    // Scores: [1, 10],
    // Number of detections: [1]
    final output = {
      0: [List<List<num>>.filled(10, List<num>.filled(4, 0))],
      1: [List<num>.filled(10, 0)],
      2: [List<num>.filled(10, 0)],
      3: [0.0],
    };

    interpreter.runForMultipleInputs([input], output);
    return output.values.toList();
  }
}
