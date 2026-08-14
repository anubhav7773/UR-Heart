import 'package:flutter/material.dart';

class ProfileViewDialog extends StatefulWidget {
  final String name;
  final int age;
  final String distanceLabel;
  final List<String> photos;
  final bool isVerified;

  const ProfileViewDialog({
    super.key,
    required this.name,
    required this.age,
    required this.distanceLabel,
    required this.photos,
    this.isVerified = false,
  });

  @override
  State<ProfileViewDialog> createState() => _ProfileViewDialogState();
}

class _ProfileViewDialogState extends State<ProfileViewDialog> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                child: Image.network(
                  photos[index],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
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
                        '${widget.name}, ${widget.age}',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      if (widget.isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: Colors.blueAccent, size: 22),
                      ],
                    ],
                  ),
                  Text(widget.distanceLabel, style: const TextStyle(color: Colors.white70)),
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
                  child: Center(child: Image.network(widget.photos[index], fit: BoxFit.contain)),
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
