import 'dart:io' show Platform;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/security/flutter_windowmanager.dart';

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
    _audioPlayer.dispose();
    _disableScreenshotProtection();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _enableScreenshotProtection() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } catch (e) {
        if (kDebugMode) print('Could not enable FLAG_SECURE: $e');
      }
    }
  }

  Future<void> _disableScreenshotProtection() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      } catch (e) {
        if (kDebugMode) print('Could not clear FLAG_SECURE: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos.take(5).toList();
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
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
                    child: CircularProgressIndicator(color: Color(0xFFE91E63)),
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
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
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
                            color: index == _pageIndex ? Colors.white : Colors.white38,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.age > 0 ? '${widget.name}, ${widget.age}' : widget.name,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      if (widget.isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: Colors.blueAccent, size: 22),
                      ],
                    ],
                  ),
                  Text(widget.distanceLabel, style: const TextStyle(color: Colors.white70)),
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
                          gradient: LinearGradient(
                            colors: _isPlayingVoice
                                ? [Colors.purpleAccent.shade700, Colors.deepPurple]
                                : [Colors.purple.shade900.withValues(alpha: 0.8), Colors.black87],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.purpleAccent, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isPlayingVoice ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isPlayingVoice
                                  ? 'Playing Voice Intro 🎵'
                                  : '▶ Play Voice Intro (0:${widget.voiceBioDurationSeconds.toString().padLeft(2, '0')})',
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
