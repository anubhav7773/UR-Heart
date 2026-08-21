import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/security_service.dart';
import '../../core/theme/app_theme.dart';

class ProfileViewDialog extends StatefulWidget {
  final String name;
  final int age;
  final String distanceLabel;
  final List<String> photos;
  final bool isVerified;
  final String? voiceBioUrl;
  final int voiceBioDurationSeconds;

  const ProfileViewDialog({
    super.key,
    required this.name,
    required this.age,
    required this.distanceLabel,
    required this.photos,
    this.isVerified = false,
    this.voiceBioUrl,
    this.voiceBioDurationSeconds = 15,
  });

  @override
  State<ProfileViewDialog> createState() => _ProfileViewDialogState();
}

class _ProfileViewDialogState extends State<ProfileViewDialog> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;
  late final AudioPlayer _audioPlayer;
  bool _isPlayingVoice = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingVoice = false);
    });
    _enableScreenshotProtection();
  }

  @override
  void dispose() {
    try {
      _audioPlayer.stop();
    } catch (_) {}
    _audioPlayer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _enableScreenshotProtection() async {
    await WindowSecurityService.syncFromStorage();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos.take(5).toList();
    return Dialog.fullscreen(
      backgroundColor: AppTheme.backgroundColor,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: photos.length,
              onPageChanged: (index) => setState(() => _pageIndex = index),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _FullScreenImageViewer(
                      photos: photos,
                      initialIndex: index,
                    ),
                  ),
                ),
                child: CachedNetworkImage(
                  imageUrl: photos[index],
                  memCacheWidth: 600,
                  memCacheHeight: 800,
                  maxWidthDiskCache: 1000,
                  maxHeightDiskCache: 1200,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.person, color: Colors.white24, size: 96),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.cardBorderColor),
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.cardBorderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (photos.length > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          photos.length,
                          (index) => Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == _pageIndex ? AppTheme.primaryColor : Colors.white38,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.age > 0 ? '${widget.name}, ${widget.age}' : widget.name,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        if (widget.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: AppTheme.verifiedBlue, size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(widget.distanceLabel, style: const TextStyle(color: AppTheme.mutedTextColor, fontSize: 13)),
                    if (widget.voiceBioUrl != null && widget.voiceBioUrl!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          if (_isPlayingVoice) {
                            await _audioPlayer.stop();
                            setState(() => _isPlayingVoice = false);
                          } else {
                            await _audioPlayer.play(UrlSource(widget.voiceBioUrl!));
                            setState(() => _isPlayingVoice = true);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isPlayingVoice
                                ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                : AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _isPlayingVoice ? AppTheme.primaryColor : AppTheme.cardBorderColor,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isPlayingVoice ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isPlayingVoice
                                    ? 'Playing Voice Intro'
                                    : 'Voice Intro (0:${widget.voiceBioDurationSeconds.toString().padLeft(2, '0')})',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const _FullScreenImageViewer({required this.photos, required this.initialIndex});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.photos.length,
                itemBuilder: (_, index) => InteractiveViewer(
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.photos[index],
                      memCacheWidth: 800,
                      memCacheHeight: 1200,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.person, color: Colors.white24, size: 96),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
}
