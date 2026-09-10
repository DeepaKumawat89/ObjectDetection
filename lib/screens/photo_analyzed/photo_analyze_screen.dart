import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tensorflow_demo/models/detected_object/detected_object_dm.dart';
import 'package:tensorflow_demo/screens/photo_analyzed/widgets/detected_object_tile.dart';
import 'package:tensorflow_demo/services/tensorflow_service.dart';
import 'package:tensorflow_demo/services/text_recognition_service.dart';
import 'package:tensorflow_demo/utils/error_handler.dart';
import 'package:tensorflow_demo/utils/image_utils.dart';
import 'package:tensorflow_demo/widgets/app_dialog.dart';

class PhotoAnalyzedScreen extends StatefulWidget {
  const PhotoAnalyzedScreen({required this.imageBytes, super.key});

  final Uint8List imageBytes;

  @override
  State<PhotoAnalyzedScreen> createState() => _PhotoAnalyzedScreenState();
}

class _PhotoAnalyzedScreenState extends State<PhotoAnalyzedScreen> {
  Uint8List? image;
  List<DetectedObjectDm> detectedObjectList = [];
  bool isAnalyzing = true;
  String? fullImageText;
  int analysisProgress = 0;
  String statusMessage = 'Preparing image...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyzeImage();
    });
  }

  void _updateProgress(int progress, String status) {
    if (mounted) {
      setState(() {
        analysisProgress = progress.clamp(0, 100);
        statusMessage = status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isAnalyzing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analysis Details'),
          elevation: 0,
          scrolledUnderElevation: 2,
          automaticallyImplyLeading: !isAnalyzing,
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: isAnalyzing
              ? _buildLoadingState(context)
              : _buildResultsView(context),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Center(
      key: const ValueKey('loading_view'),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(32.0, 16.0, 32.0, 16.0 + bottomInset),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: analysisProgress / 100.0,
                      strokeWidth: 8.0,
                      strokeCap: StrokeCap.round,
                      color: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  Text(
                    '$analysisProgress%',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 250,
                height: 8,
                child: LinearProgressIndicator(
                  value: analysisProgress / 100.0,
                  backgroundColor: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.3),
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyzing object boundaries, dimensions & text',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView(BuildContext context) {
    final theme = Theme.of(context);
    final displayBytes = image ?? widget.imageBytes;
    final topObject =
        detectedObjectList.isNotEmpty ? detectedObjectList.first : null;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 24;

    return ListView(
      key: const ValueKey('results_view'),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
      children: [
        // Main Image Display Card with Badge
        Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              displayBytes.isEmpty
                  ? const SizedBox(
                      height: 240,
                      child: Center(
                        child: Text('Invalid or empty image data'),
                      ),
                    )
                  : Image.memory(
                      key: ValueKey(image == null ? 'old_image' : 'new_image'),
                      displayBytes,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 240,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Text('Failed to load image'),
                          ),
                        );
                      },
                    ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.center_focus_strong_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'AI Analyzed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Stats Summary Row
        if (detectedObjectList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: 'Detected',
                    value:
                        '${detectedObjectList.length} ${detectedObjectList.length == 1 ? 'Object' : 'Objects'}',
                    icon: Icons.category_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                if (topObject != null)
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Confidence',
                      value: '${(topObject.score * 100).toInt()}% Match',
                      icon: Icons.verified_rounded,
                      color: Colors.green,
                    ),
                  ),
                if (topObject != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Estimated Height',
                      value: '${topObject.heightInCm.toStringAsFixed(1)} cm',
                      icon: Icons.straighten_rounded,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Detected Objects List
        if (detectedObjectList.isEmpty)
          (fullImageText != null && fullImageText!.isNotEmpty)
              ? _buildOverallTextCard(context)
              : const Card(
                  elevation: 0,
                  color: Colors.black12,
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No objects or text detected in this image.',
                        style: TextStyle(fontSize: 15, color: Colors.grey),
                      ),
                    ),
                  ),
                )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detected Objects',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${detectedObjectList.length} Found',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            detectedObjectList.length,
            (index) {
              final detectedObject = detectedObjectList[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DetectedObjectTile(
                  label: detectedObject.label,
                  value: detectedObject.score.toStringAsFixed(2),
                  heightValue:
                      '${detectedObject.heightInCm.toStringAsFixed(1)} cm',
                  extractedText: detectedObject.extractedText,
                ),
              );
            },
          ),
          if (fullImageText != null && fullImageText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildOverallTextCard(context),
          ],
        ],
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallTextCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.text_snippet_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Overall Extracted Text',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy all text',
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: fullImageText!),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied all extracted text'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                fullImageText!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _analyzeImage() {
    Future.delayed(
      const Duration(milliseconds: 150),
      () async {
        if (!mounted) return;

        try {
          if (widget.imageBytes.isEmpty) {
            if (mounted) {
              setState(() {
                isAnalyzing = false;
              });
              await showAppAlertDialog(
                context: context,
                title: 'Invalid Image',
                message: 'The uploaded image data is empty or invalid.',
              );
            }
            return;
          }

          // Step 1: Preprocessing & Decoding (15%)
          _updateProgress(15, 'Decoding image data...');
          await Future.delayed(const Duration(milliseconds: 120));

          // Step 2: Object Detection via TensorFlow (30% -> 55%)
          _updateProgress(30, 'Running object detection model...');
          final output = TensorflowService.ssdMobileNet.analyseImage(
            widget.imageBytes,
          );
          _updateProgress(55, 'Extracting object regions & dimensions...');
          await Future.delayed(const Duration(milliseconds: 120));

          // Step 3: Text Recognition on individual detected objects (55% -> 80%)
          final updatedList = <DetectedObjectDm>[];
          final totalObjects = output.detectedObjects.length;
          if (totalObjects > 0) {
            for (var i = 0; i < totalObjects; i++) {
              final obj = output.detectedObjects[i];
              String extractedText = '';
              try {
                final croppedBytes = ImageUtils.cropImageRegion(
                  widget.imageBytes,
                  obj.location,
                );
                if (croppedBytes != null && croppedBytes.isNotEmpty) {
                  extractedText = await TextRecognitionService.instance
                      .processImageBytes(croppedBytes);
                }
              } catch (e) {
                debugPrint('Error extracting text from object region: $e');
              }
              updatedList.add(obj.copyWith(extractedText: extractedText));

              final progressStep =
                  55 + (((i + 1) / totalObjects) * 25).toInt();
              _updateProgress(
                progressStep,
                'Processing object ${i + 1} of $totalObjects...',
              );
            }
          } else {
            _updateProgress(75, 'Processing object regions...');
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // Step 4: Text Recognition on overall image (85% -> 95%)
          _updateProgress(85, 'Extracting overall text...');
          String overallText = '';
          try {
            overallText = await TextRecognitionService.instance
                .processImageBytes(
                  widget.imageBytes,
                  applyPreprocessing: true,
                );
          } catch (e) {
            debugPrint('Error extracting overall text: $e');
          }

          // Step 5: Completion (100%)
          _updateProgress(100, 'Analysis complete!');
          await Future.delayed(const Duration(milliseconds: 250));

          if (mounted) {
            setState(() {
              image = output.imageBytes;
              detectedObjectList = updatedList;
              fullImageText = overallText;
              isAnalyzing = false;
            });
          }
        } catch (e, stack) {
          debugPrint('Error analyzing image: $e\n$stack');
          final errorMsg = ErrorHandler.getErrorMessage(e);
          if (mounted) {
            setState(() {
              isAnalyzing = false;
            });
            await showAppAlertDialog(
              context: context,
              title: 'Analysis Failed',
              message: errorMsg,
            );
          }
        }
      },
    );
  }
}
