import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:tensorflow_demo/models/detected_object/detected_object_dm.dart';

void main() {
  test('DetectedObjectDm heightInCm calculation test', () {
    const object = DetectedObjectDm(
      label: 'Cup',
      score: 0.95,
      location: Rect.fromLTRB(0.1, 0.2, 0.5, 0.7),
    );

    // Bounding box height normalized: 0.7 - 0.2 = 0.5
    expect(object.height, closeTo(0.5, 0.001));

    // Height in cm = 0.5 * 30.0 = 15.0 cm
    expect(object.heightInCm, closeTo(15.0, 0.001));
  });
}
