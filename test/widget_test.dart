import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:tensorflow_demo/models/detected_object/detected_object_dm.dart';

void main() {
  test('DetectedObjectDm heightInCm and widthInCm calculation test for vertical object', () {
    const object = DetectedObjectDm(
      label: 'Bottle',
      score: 0.95,
      location: Rect.fromLTRB(0.1, 0.2, 0.36, 0.9), // height = 0.7, width = 0.26
      imageWidth: 1000,
      imageHeight: 1000,
    );

    // Bounding box height normalized: 0.9 - 0.2 = 0.7
    expect(object.height, closeTo(0.7, 0.001));

    // Bounding box width normalized: 0.36 - 0.1 = 0.26
    expect(object.width, closeTo(0.26, 0.001));

    // Height in cm = 0.7 * 30.0 = 21.0 cm
    expect(object.heightInCm, closeTo(21.0, 0.001));

    // Width in cm = 0.26 * 30.0 = 7.8 cm
    expect(object.widthInCm, closeTo(7.8, 0.001));
  });

  test('DetectedObjectDm heightInCm and widthInCm calculation test for horizontal object', () {
    const object = DetectedObjectDm(
      label: 'Bottle',
      score: 0.95,
      location: Rect.fromLTRB(0.1, 0.2, 0.9, 0.46), // height = 0.26, width = 0.8
      imageWidth: 1000,
      imageHeight: 1000,
    );

    // Naturally tall object lying horizontally retains primary axis length as Height
    // Height in cm = max(0.26, 0.8) * 30.0 = 24.0 cm
    expect(object.heightInCm, closeTo(24.0, 0.001));

    // Width in cm = min(0.26, 0.8) * 30.0 = 7.8 cm
    expect(object.widthInCm, closeTo(7.8, 0.001));
  });
}
