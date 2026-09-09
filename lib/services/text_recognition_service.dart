import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tensorflow_demo/utils/image_utils.dart';

class TextRecognitionService {
  TextRecognitionService._();

  static final TextRecognitionService instance = TextRecognitionService._();

  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Recognizes text from image bytes with optional OCR preprocessing
  Future<String> processImageBytes(
    Uint8List bytes, {
    bool applyPreprocessing = false,
  }) async {
    try {
      final inputBytes = applyPreprocessing
          ? ImageUtils.preprocessImageForOcr(bytes)
          : bytes;

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/temp_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(inputBytes);

      final inputImage = InputImage.fromFile(tempFile);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return recognizedText.text.trim();
    } catch (e) {
      debugPrint('TextRecognitionService error: $e');
      return '';
    }
  }

  /// Disposes the text recognizer
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
