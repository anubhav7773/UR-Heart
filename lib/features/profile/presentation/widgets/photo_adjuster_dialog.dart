import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/dark_sanctuary_tokens.dart';
import '../../../../core/theme/light_sanctuary_tokens.dart';

/// Interactive Sanctuary Photo Adjuster Modal (< 260 lines)
/// Provides drag pan, pinch/slider zoom, 90-degree rotation, rule-of-thirds grid,
/// and high-quality bitmap crop using pure-dart package:image.
class SanctuaryPhotoAdjusterDialog extends StatefulWidget {
  final File initialFile;
  final bool isDark;
  final bool isAvatar;
  final double targetAspectRatio;

  const SanctuaryPhotoAdjusterDialog({
    super.key,
    required this.initialFile,
    required this.isDark,
    this.isAvatar = false,
    this.targetAspectRatio = 1.0,
  });

  static Future<File?> show(
    BuildContext context, {
    required File file,
    required bool isDark,
    bool isAvatar = false,
    double targetAspectRatio = 1.0,
  }) {
    return showDialog<File?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SanctuaryPhotoAdjusterDialog(
        initialFile: file,
        isDark: isDark,
        isAvatar: isAvatar,
        targetAspectRatio: targetAspectRatio,
      ),
    );
  }

  @override
  State<SanctuaryPhotoAdjusterDialog> createState() => _SanctuaryPhotoAdjusterDialogState();
}

class _SanctuaryPhotoAdjusterDialogState extends State<SanctuaryPhotoAdjusterDialog> {
  final TransformationController _transformController = TransformationController();
  final GlobalKey _viewportKey = GlobalKey();
  final GlobalKey _imageKey = GlobalKey();

  int _rotationQuarterTurns = 0; // 0, 1, 2, 3 -> 0, 90, 180, 270 degrees
  bool _isProcessing = false;
  double _zoomLevel = 1.0;
  bool _showGrid = true;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _zoomLevel).abs() > 0.05 && mounted) {
      setState(() {
        _zoomLevel = scale.clamp(1.0, 3.5);
      });
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _rotateClockwise() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
      _transformController.value = Matrix4.identity();
      _zoomLevel = 1.0;
    });
  }

  void _resetTransform() {
    setState(() {
      _transformController.value = Matrix4.identity();
      _zoomLevel = 1.0;
    });
  }

  void _setZoom(double value) {
    setState(() {
      _zoomLevel = value;
      final currentTranslation = _transformController.value.getTranslation();
      final matrix = Matrix4.identity()
        ..translate(currentTranslation.x, currentTranslation.y)
        ..scale(value);
      _transformController.value = matrix;
    });
  }

  Future<void> _applyCropAndSave() async {
    setState(() => _isProcessing = true);
    try {
      final rawBytes = await widget.initialFile.readAsBytes();
      var decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        throw Exception('Could not decode photo bytes');
      }

      // 1. Apply user rotation if any
      final angleDegrees = _rotationQuarterTurns * 90;
      if (angleDegrees > 0) {
        decoded = img.copyRotate(decoded, angle: angleDegrees);
      }

      // 2. Compute exact crop coordinates from viewport & rendered child
      final viewportBox = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      final imageBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;

      if (viewportBox != null &&
          imageBox != null &&
          viewportBox.hasSize &&
          imageBox.hasSize &&
          imageBox.size.width > 0 &&
          imageBox.size.height > 0) {
        final viewportSize = viewportBox.size;
        final renderedImageSize = imageBox.size;

        final matrix = _transformController.value;
        final scale = matrix.getMaxScaleOnAxis();
        final tx = matrix.getTranslation().x;
        final ty = matrix.getTranslation().y;

        // Coordinates in rendered child space
        final visX = (-tx) / scale;
        final visY = (-ty) / scale;
        final visW = viewportSize.width / scale;
        final visH = viewportSize.height / scale;

        // Map from rendered display pixels to full-resolution bitmap pixels
        final factorX = decoded.width / renderedImageSize.width;
        final factorY = decoded.height / renderedImageSize.height;

        final rawCropX = (visX * factorX).round();
        final rawCropY = (visY * factorY).round();
        final rawCropW = (visW * factorX).round();
        final rawCropH = (visH * factorY).round();

        final safeCropX = rawCropX.clamp(0, decoded.width - 1);
        final safeCropY = rawCropY.clamp(0, decoded.height - 1);
        final safeCropW = rawCropW.clamp(1, decoded.width - safeCropX);
        final safeCropH = rawCropH.clamp(1, decoded.height - safeCropY);

        decoded = img.copyCrop(
          decoded,
          x: safeCropX,
          y: safeCropY,
          width: safeCropW,
          height: safeCropH,
        );
      } else {
        // Fallback: center-crop decoded image to target aspect ratio
        final targetAspect = widget.targetAspectRatio;
        int cropW = decoded.width;
        int cropH = (cropW / targetAspect).round();
        if (cropH > decoded.height) {
          cropH = decoded.height;
          cropW = (cropH * targetAspect).round();
        }
        final cropX = ((decoded.width - cropW) / 2).round().clamp(0, decoded.width - 1);
        final cropY = ((decoded.height - cropH) / 2).round().clamp(0, decoded.height - 1);
        decoded = img.copyCrop(decoded, x: cropX, y: cropY, width: cropW, height: cropH);
      }

      // Write cropped high-res image to temp file
      final tempDir = Directory.systemTemp;
      final outPath = '${tempDir.path}/sanctuary_adjusted_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outFile = File(outPath);
      await outFile.writeAsBytes(img.encodeJpg(decoded, quality: 90));

      if (mounted) {
        Navigator.of(context).pop(outFile);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adjusting image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.isDark ? DarkSanctuaryTokens.surfaceCard : LightSanctuaryTokens.surfaceCard;
    final primaryText = widget.isDark ? DarkSanctuaryTokens.textHeadline : LightSanctuaryTokens.textHeadline;
    final subText = widget.isDark ? DarkSanctuaryTokens.textMuted : LightSanctuaryTokens.textMuted;
    final pine = widget.isDark ? DarkSanctuaryTokens.sanctuaryPine : LightSanctuaryTokens.sanctuaryPine;
    final gold = widget.isDark ? DarkSanctuaryTokens.goldAccent : LightSanctuaryTokens.goldAccent;

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    Icon(widget.isAvatar ? Icons.face_rounded : Icons.crop_rotate_rounded, color: gold, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isAvatar ? 'Adjust Sanctuary Avatar' : 'Adjust Moment Framing',
                            style: AppTypography.titleH2.copyWith(color: primaryText, fontSize: 16),
                          ),
                          Text(
                            'Drag & pinch so your face is clear and centered',
                            style: TextStyle(color: subText, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: subText),
                      onPressed: _isProcessing ? null : () => Navigator.of(context).pop(null),
                    ),
                  ],
                ),
              ),

              // Viewport Frame with AspectRatio & Guides
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: gold.withValues(alpha: 0.3), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15.0),
                  child: AspectRatio(
                    key: _viewportKey,
                    aspectRatio: widget.targetAspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Interactive Image
                        InteractiveViewer(
                          transformationController: _transformController,
                          boundaryMargin: const EdgeInsets.all(200.0),
                          minScale: 0.8,
                          maxScale: 3.5,
                          child: Center(
                            child: RotatedBox(
                              quarterTurns: _rotationQuarterTurns,
                              child: Image.file(
                                widget.initialFile,
                                key: _imageKey,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),

                        // Subtle Rule-of-Thirds Grid Overlay
                        if (_showGrid)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _RuleOfThirdsPainter(
                                lineColor: Colors.white.withValues(alpha: 0.25),
                                isCircle: widget.isAvatar,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Zoom slider & Tool controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    // Zoom Slider Row
                    Row(
                      children: [
                        Icon(Icons.zoom_out, size: 16, color: subText),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: gold,
                              inactiveTrackColor: gold.withValues(alpha: 0.2),
                              thumbColor: gold,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            ),
                            child: Slider(
                              value: _zoomLevel,
                              min: 1.0,
                              max: 3.5,
                              onChanged: _isProcessing ? null : _setZoom,
                            ),
                          ),
                        ),
                        Icon(Icons.zoom_in, size: 16, color: subText),
                      ],
                    ),

                    // Quick Action Buttons (Rotate, Reset, Toggle Grid)
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _isProcessing ? null : _rotateClockwise,
                            icon: const Icon(Icons.rotate_90_degrees_cw_rounded, size: 15),
                            label: const Text('Rotate', style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              foregroundColor: primaryText,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _isProcessing ? null : _resetTransform,
                            icon: const Icon(Icons.center_focus_strong_rounded, size: 15),
                            label: const Text('Reset', style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              foregroundColor: primaryText,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => setState(() => _showGrid = !_showGrid),
                            icon: Icon(_showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded, size: 15),
                            label: Text(_showGrid ? 'Grid On' : 'Grid Off', style: const TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              foregroundColor: subText,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Bottom Confirmation Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : () => Navigator.of(context).pop(null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: subText,
                          side: BorderSide(color: subText.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _applyCropAndSave,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                        label: Text(
                          _isProcessing ? 'Framing & Saving...' : 'Apply & Save',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pine,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for rule-of-thirds grid and optional avatar circle mask
class _RuleOfThirdsPainter extends CustomPainter {
  final Color lineColor;
  final bool isCircle;

  const _RuleOfThirdsPainter({required this.lineColor, required this.isCircle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Rule of thirds lines
    final w1 = size.width / 3;
    final w2 = size.width * 2 / 3;
    final h1 = size.height / 3;
    final h2 = size.height * 2 / 3;

    canvas.drawLine(Offset(w1, 0), Offset(w1, size.height), paint);
    canvas.drawLine(Offset(w2, 0), Offset(w2, size.height), paint);
    canvas.drawLine(Offset(0, h1), Offset(size.width, h1), paint);
    canvas.drawLine(Offset(0, h2), Offset(size.width, h2), paint);

    if (isCircle) {
      final circlePaint = Paint()
        ..color = lineColor.withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final center = Offset(size.width / 2, size.height / 2);
      final radius = math.min(size.width, size.height) / 2 - 4;
      canvas.drawCircle(center, radius, circlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RuleOfThirdsPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor || oldDelegate.isCircle != isCircle;
  }
}
