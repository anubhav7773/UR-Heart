// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../data/admin_repository.dart';

class AdminKycDashboardScreen extends StatefulWidget {
  const AdminKycDashboardScreen({super.key});

  @override
  State<AdminKycDashboardScreen> createState() => _AdminKycDashboardScreenState();
}

class _AdminKycDashboardScreenState extends State<AdminKycDashboardScreen> {
  static const MethodChannel _securityChannel = MethodChannel('com.urheart.app/security');
  final AdminRepository _repo = AdminRepository();
  bool _isLoading = true;
  KycStatsModel? _stats;
  List<KycCandidateModel> _queue = [];

  @override
  void initState() {
    super.initState();
    _ensureScreenshotsAllowed();
    _loadDashboardData();
  }

  Future<void> _ensureScreenshotsAllowed() async {
    try {
      await _securityChannel.invokeMethod('disableSecure');
    } catch (_) {}
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final statsFuture = _repo.fetchStats();
      final queueFuture = _repo.fetchQueue();
      final results = await Future.wait([statsFuture, queueFuture]);

      setState(() {
        _stats = results[0] as KycStatsModel;
        _queue = results[1] as List<KycCandidateModel>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading admin data: ${e.toString()}"),
            backgroundColor: const Color(0xFFFF334B),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDecision(KycCandidateModel candidate, String decision, {String? reason}) async {
    try {
      await _repo.submitDecision(
        queueId: candidate.queueId,
        userId: candidate.userId,
        decision: decision,
        rejectionReason: reason,
      );

      setState(() {
        _queue.removeWhere((item) => item.queueId == candidate.queueId);
        if (_stats != null) {
          _stats = KycStatsModel(
            pending: (_stats!.pending - 1).clamp(0, 99999),
            verified: decision == "approve" ? _stats!.verified + 1 : _stats!.verified,
            rejected: decision == "reject" ? _stats!.rejected + 1 : _stats!.rejected,
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == "approve"
                  ? "✓ User Approved. Video permanently purged from cloud storage."
                  : "✗ User Rejected. Video purged from storage.",
            ),
            backgroundColor: decision == "approve" ? const Color(0xFF06D6A0) : const Color(0xFFFF334B),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed action: $e"), backgroundColor: const Color(0xFFFF334B)),
        );
      }
    }
  }

  void _showRejectionDialog(KycCandidateModel candidate) {
    String selectedReason = "Face does not match profile photos";
    final List<String> reasons = [
      "Face does not match profile photos",
      "Audio inaudible / name mismatch",
      "Lighting too dark / face blurred",
      "Third party / non-human subject detected",
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16161D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Reject KYC Verification", style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((r) {
              return RadioListTile<String>(
                value: r,
                groupValue: selectedReason,
                title: Text(r, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                activeColor: const Color(0xFFFF334B),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedReason = val);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF334B)),
              onPressed: () {
                Navigator.pop(ctx);
                _handleDecision(candidate, "reject", reason: selectedReason);
              },
              child: const Text("Confirm Rejection", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color canvasBg = Color(0xFF0A0A0D);

    return Scaffold(
      backgroundColor: canvasBg,
      appBar: AppBar(
        backgroundColor: canvasBg,
        elevation: 0,
        title: const Text(
          "Master KYC Review Hub",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFFD166)),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD166)))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: const Color(0xFFFFD166),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Top Stats Counters
                  if (_stats != null) _buildStatsRow(_stats!),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Pending Review Queue",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "${_queue.length} Candidates",
                        style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_queue.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(Icons.verified_user_outlined, size: 48, color: Color(0xFF06D6A0)),
                          SizedBox(height: 12),
                          Text("All caught up!", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text("No pending candidate submissions in review queue.", style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    ..._queue.map((candidate) => _CandidateReviewCard(
                          candidate: candidate,
                          onApprove: () => _handleDecision(candidate, "approve"),
                          onReject: () => _showRejectionDialog(candidate),
                        )),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsRow(KycStatsModel stats) {
    return Row(
      children: [
        _buildStatCard("Pending", stats.pending.toString(), const Color(0xFFFFD166)),
        const SizedBox(width: 8),
        _buildStatCard("Verified", stats.verified.toString(), const Color(0xFF06D6A0)),
        const SizedBox(width: 8),
        _buildStatCard("Rejected", stats.rejected.toString(), const Color(0xFFFF334B)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF16161D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: accentColor, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _CandidateReviewCard extends StatefulWidget {
  final KycCandidateModel candidate;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _CandidateReviewCard({
    required this.candidate,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_CandidateReviewCard> createState() => _CandidateReviewCardState();
}

class _CandidateReviewCardState extends State<_CandidateReviewCard> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    final url = widget.candidate.videoPlaybackUrl.trim();
    if (url.isEmpty) {
      debugPrint('[_CandidateReviewCard] videoPlaybackUrl is empty for candidate ${widget.candidate.registeredName}');
      setState(() {
        _isLoading = false;
        _errorMessage = "Video stream URL unavailable";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[_CandidateReviewCard] Initializing VideoPlayer for ${widget.candidate.registeredName}: $url');
      _videoController?.dispose();
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));

      _videoController!
          .initialize()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception("Video stream initialization timed out (15s)");
            },
          )
          .then((_) {
        if (mounted) {
          debugPrint('[_CandidateReviewCard] Video initialized successfully for ${widget.candidate.registeredName}');
          setState(() {
            _isVideoInitialized = true;
            _isLoading = false;
          });
          _videoController?.setLooping(true);
          _videoController?.play();
        }
      }).catchError((error) {
        debugPrint('[_CandidateReviewCard] VideoPlayerController initialization error: $error (URL: $url)');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isVideoInitialized = false;
            _errorMessage = "Failed to stream video: ${error.toString().replaceAll('Exception: ', '')}";
          });
        }
      });
    } catch (e) {
      debugPrint('[_CandidateReviewCard] URI parse / controller create failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isVideoInitialized = false;
          _errorMessage = "Invalid video playback stream: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    const Color cardSurface = Color(0xFF16161D);
    const Color surfaceRaised = Color(0xFF22222C);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & City
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.registeredName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text("📍 ${candidate.registeredCity}", style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: candidate.confidenceScore >= 0.70
                      ? const Color(0xFF06D6A0).withValues(alpha: 0.2)
                      : const Color(0xFFFFD166).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "AI Score: ${(candidate.confidenceScore * 100).toInt()}%",
                  style: TextStyle(
                    color: candidate.confidenceScore >= 0.70 ? const Color(0xFF06D6A0) : const Color(0xFFFFD166),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5-Second Video Player Preview
          if (_isVideoInitialized && _videoController != null && _videoController!.value.isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio > 0
                    ? _videoController!.value.aspectRatio
                    : (16 / 9),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_videoController!),
                    VideoProgressIndicator(
                      _videoController!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFFFFD166),
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.black38,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    ),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _videoController!.value.isPlaying
                                ? _videoController!.pause()
                                : _videoController!.play();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _videoController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(color: surfaceRaised, borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam_off_outlined, color: Color(0xFFFF334B), size: 30),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _initializeVideo,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 14, color: Color(0xFFFFD166)),
                          SizedBox(width: 4),
                          Text("Retry stream", style: TextStyle(color: Color(0xFFFFD166), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_isLoading || !_isVideoInitialized)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(color: surfaceRaised, borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(color: Color(0xFFFFD166), strokeWidth: 2.5),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Buffering video stream...",
                    style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Transcript & AI Flags
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: surfaceRaised, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Spoken Audio Transcript:", style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  '"${candidate.transcript}"',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontStyle: FontStyle.italic),
                ),
                if (candidate.flags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: candidate.flags.map((flag) {
                      return Chip(
                        label: Text(flag, style: const TextStyle(color: Color(0xFFFF334B), fontSize: 10)),
                        backgroundColor: const Color(0xFFFF334B).withValues(alpha: 0.12),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Reject vs Approve
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onReject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF334B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Reject / अस्वीकार", style: TextStyle(color: Color(0xFFFF334B), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06D6A0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Approve / स्वीकृत", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
