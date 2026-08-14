import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/network/api_client.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() => _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingList = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPendingVerifications();
  }

  Future<void> _fetchPendingVerifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.instance.dio.get('/admin/verifications/pending');
      if (response.data != null && response.data['data'] != null) {
        final List<dynamic> data = response.data['data'];
        setState(() {
          _pendingList = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load verifications: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reviewUser(String userId, String status, int index) async {
    try {
      final response = await ApiClient.instance.dio.post(
        '/admin/verifications/$userId/review',
        data: {'status': status},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        final isApproved = status.toLowerCase() == 'approved';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isApproved
                  ? '✓ User verification APPROVED!'
                  : '✕ User verification REJECTED.',
            ),
            backgroundColor: isApproved ? Colors.green[700] : Colors.redAccent[700],
            duration: const Duration(seconds: 2),
          ),
        );

        setState(() {
          if (index < _pendingList.length) {
            _pendingList.removeAt(index);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[950],
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Color(0xFFE91E63)),
            SizedBox(width: 8),
            Text('Admin Video Verification', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchPendingVerifications,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPendingVerifications,
        color: const Color(0xFFE91E63),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchPendingVerifications,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63)),
                            child: const Text('Retry', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  )
                : _pendingList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_user, size: 64, color: Colors.greenAccent.withValues(alpha: 0.8)),
                            const SizedBox(height: 16),
                            const Text(
                              'All Caught Up! 🎉',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No pending selfie video verifications in queue.',
                              style: TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _pendingList.length,
                        itemBuilder: (context, index) {
                          final item = _pendingList[index];
                          return _VerificationItemCard(
                            key: ValueKey(item['id']),
                            item: item,
                            onApprove: () => _reviewUser(item['id'], 'approved', index),
                            onReject: () => _reviewUser(item['id'], 'rejected', index),
                          );
                        },
                      ),
      ),
    );
  }
}

class _VerificationItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _VerificationItemCard({
    super.key,
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_VerificationItemCard> createState() => _VerificationItemCardState();
}

class _VerificationItemCardState extends State<_VerificationItemCard> {
  VideoPlayerController? _controller;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    final videoUrl = widget.item['verification_video_url'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isVideoInitialized = true;
            });
            _controller?.setLooping(true);
            _controller?.play();
          }
        }).catchError((err) {
          if (mounted) {
            setState(() {
              _hasVideoError = true;
            });
          }
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name'] ?? 'User';
    final age = widget.item['age'];
    final email = widget.item['email'] ?? '';
    final area = widget.item['area_name'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Preview Container
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              height: 280,
              width: double.infinity,
              color: Colors.black,
              child: _isVideoInitialized && _controller != null
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: IconButton(
                            icon: Icon(
                              _controller!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: Colors.white,
                              size: 36,
                            ),
                            onPressed: () {
                              setState(() {
                                if (_controller!.value.isPlaying) {
                                  _controller!.pause();
                                } else {
                                  _controller!.play();
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    )
                  : _hasVideoError
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_off, color: Colors.redAccent, size: 40),
                              SizedBox(height: 8),
                              Text('Unable to preview video stream', style: TextStyle(color: Colors.white60)),
                            ],
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: Color(0xFFE91E63)),
                        ),
            ),
          ),

          // User Info Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      age != null ? '$name, $age' : name,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: const Text(
                        'PENDING',
                        style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ],
                if (area.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(area, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Action Buttons: Approve (Green) & Reject (Red)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onReject,
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onApprove,
                        icon: const Icon(Icons.check, color: Colors.white, size: 18),
                        label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
