import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tensorflow_demo/models/detected_object/detected_object_dm.dart';
import 'package:tensorflow_demo/services/snackbar_service.dart';
import 'package:tensorflow_demo/services/tensorflow_service.dart';
import 'package:tensorflow_demo/services/text_recognition_service.dart';
import 'package:tensorflow_demo/utils/image_utils.dart';
import 'package:tensorflow_demo/screens/photo_analyzed/widgets/detected_object_tile.dart';

class PhotoAnalyzedScreen extends StatefulWidget {
  const PhotoAnalyzedScreen({required this.imageBytes, super.key});

  final Uint8List imageBytes;

  @override
  State<PhotoAnalyzedScreen> createState() => _PhotoAnalyzedScreenState();
}

class _PhotoAnalyzedScreenState extends State<PhotoAnalyzedScreen> {
  Uint8List? image;
  List<DetectedObjectDm> detectedObjectList = [];
  bool isExtractingText = false;
  String? fullImageText;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SnackBarService.show('Finding Objects...');
      _analyzeImage();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
      ),
      body: ListView(
        children: [
          AnimatedSwitcher(
            switchInCurve: Curves.easeInOutQuart,
            switchOutCurve: Curves.easeInOutQuart,
            duration: const Duration(milliseconds: 600),
            child: image == null
                ? Image.memory(
                    key: const ValueKey('old_image'),
                    widget.imageBytes,
                  )
                : Image.memory(
                    key: const ValueKey('new_image'),
                    image ?? widget.imageBytes,
                  ),
          ),
          if (isExtractingText)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Extracting text from image & objects...'),
                ],
              ),
            ),
          AnimatedSwitcher(
            switchInCurve: Curves.easeInOutQuart,
            switchOutCurve: Curves.easeInOutQuart,
            duration: const Duration(milliseconds: 600),
            child: detectedObjectList.isEmpty
                ? (fullImageText != null && fullImageText!.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Extracted Text from Image:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SelectableText(fullImageText!),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Detected Objects:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ...List.generate(
                        detectedObjectList.length,
                        (index) {
                          final detectedObject = detectedObjectList[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DetectedObjectTile(
                              label: detectedObject.label,
                              value: detectedObject.score.toStringAsFixed(2),
                              extractedText: detectedObject.extractedText,
                            ),
                          );
                        },
                      ),
                      if (fullImageText != null && fullImageText!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Overall Image Text:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(12),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SelectableText(fullImageText!),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _analyzeImage() {
    Future.delayed(
      const Duration(milliseconds: 600),
      () async {
        final output = TensorflowService.ssdMobileNet.analyseImage(
          widget.imageBytes,
        );
        image = output.imageBytes;
        detectedObjectList = output.detectedObjects;
        SnackBarService.remove();
        if (mounted) {
          setState(() {
            isExtractingText = true;
          });
        }

        // Run Text Recognition on individual detected objects
        final updatedList = <DetectedObjectDm>[];
        for (final obj in detectedObjectList) {
          final croppedBytes = ImageUtils.cropImageRegion(
            widget.imageBytes,
            obj.location,
          );
          String extractedText = '';
          if (croppedBytes != null) {
            extractedText = await TextRecognitionService.instance
                .processImageBytes(croppedBytes);
          }
          updatedList.add(obj.copyWith(extractedText: extractedText));
        }

        // Also run Text Recognition on the full image with OCR preprocessing
        final overallText = await TextRecognitionService.instance
            .processImageBytes(
              widget.imageBytes,
              applyPreprocessing: true,
            );

        if (mounted) {
          setState(() {
            detectedObjectList = updatedList;
            fullImageText = overallText;
            isExtractingText = false;
          });
        }
      },
    );
  }
}
