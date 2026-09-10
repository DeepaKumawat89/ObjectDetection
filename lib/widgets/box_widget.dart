import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:tensorflow_demo/models/detected_object/detected_object_dm.dart';

class BoxWidget extends StatelessWidget {
  const BoxWidget({
    required this.label,
    required this.score,
    this.width,
    this.height,
    this.heightInCm,
    this.widthInCm,
    super.key,
  });

  final double? width;
  final double? height;
  final double? heightInCm;
  final double? widthInCm;
  final String label;
  final num score;

  BoxWidget.fromDetectedObject(DetectedObjectDm recognition, {super.key})
      : label = recognition.label,
        score = recognition.score,
        width = recognition.renderLocation.width,
        height = recognition.renderLocation.height,
        heightInCm = recognition.heightInCm,
        widthInCm = recognition.widthInCm;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topLeft,
      width: width,
      height: height,
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(
          BorderSide(color: Colors.white, width: 3),
        ),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          bottomRight: Radius.circular(12),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 4),
          child: Container(
            color: Colors.white54,
            padding: const EdgeInsets.symmetric(
              vertical: 6,
              horizontal: 12,
            ),
            child: FittedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (heightInCm != null || widthInCm != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(${heightInCm != null ? 'H: ${heightInCm!.toStringAsFixed(1)}' : ''}${heightInCm != null && widthInCm != null ? ', ' : ''}${widthInCm != null ? 'W: ${widthInCm!.toStringAsFixed(1)}' : ''} cm)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
