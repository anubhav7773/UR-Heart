import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/network/api_client.dart';

/// Screen: Privacy & Blocked Users Center
/// Spec: FIX-11 — Discovery privacy toggles + blocked users management
class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({super.key});

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  bool _isLoading = true;
  bool _isIncognito = false;
  bool _hideDistance = false;
  List<dynamic> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadPrivacyData();
  }

  Future<void> _loadPrivacyData() async {
    setState(() => _isLoading = true);
    try {
      final dio = createApiClient();

      final results = await Future.wait([
        dio.get('/api/v1/users/profile'),
        dio.get('/api/v1/safety/blocked'),
      ]);

      if (!mounted) return;
      setState(() {
        _isIncognito = results[0].data['is_incognito'] ?? false;
        _hideDistance = results[0].data['hide_distance'] ?? false;
        _blockedUsers = results[1].data ?? [];
      });
    } catch (_) {
      // Graceful degradation — privacy data will be defaults
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePrivacyToggles() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dio = createApiClient();
      await dio.patch(
        '/api/v1/safety/privacy-settings',
        data: {
          "is_incognito": _isIncognito,
          "hide_distance": _hideDistance,
        },
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text("Failed to update settings: $e"),
          backgroundColor: const Color(0xFFFF334B),
        ),
      );
    }
  }

  Future<void> _unblockUser(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dio = createApiClient();
      await dio.delete('/api/v1/safety/unblock/$userId');

      if (!mounted) return;
      setState(() {
        _blockedUsers.removeWhere((u) => u['user_id'] == userId);
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text("✓ User unblocked."),
          backgroundColor: Color(0xFF06D6A0),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text("Unblock failed: $e"),
          backgroundColor: const Color(0xFFFF334B),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color canvasBg = Color(0xFF0A0A0D);
    const Color cardSurface = Color(0xFF16161D);
    const Color brandPrimary = Color(0xFFFF2E63);

    return Scaffold(
      backgroundColor: canvasBg,
      appBar: AppBar(
        backgroundColor: canvasBg,
        elevation: 0,
        title: const Text(
          "Privacy & Blocked Users",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: brandPrimary),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Privacy Controls Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              color: Color(0xFF08D9D6), size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Discovery Privacy Controls",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Incognito Switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF08D9D6),
                        title: const Text(
                          "Incognito Mode / प्रोफ़ाइल छुपाएं",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        subtitle: const Text(
                          "Temporarily hide your card from other users in the Discovery Feed.",
                          style: TextStyle(
                            color: Color(0xFFA0A0B2),
                            fontSize: 12,
                          ),
                        ),
                        value: _isIncognito,
                        onChanged: (val) {
                          setState(() => _isIncognito = val);
                          _updatePrivacyToggles();
                        },
                      ),
                      Divider(
                        color: Colors.white.withValues(alpha: 0.12),
                        height: 16,
                      ),

                      // Hide Distance Switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF08D9D6),
                        title: const Text(
                          "Hide Approximate Distance",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        subtitle: const Text(
                          "Hides 'Nearby X km' badge. Other users will only see your city name.",
                          style: TextStyle(
                            color: Color(0xFFA0A0B2),
                            fontSize: 12,
                          ),
                        ),
                        value: _hideDistance,
                        onChanged: (val) {
                          setState(() => _hideDistance = val);
                          _updatePrivacyToggles();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Blocked Users Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Blocked Profiles",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${_blockedUsers.length} Blocked",
                      style: const TextStyle(
                        color: Color(0xFFA0A0B2),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_blockedUsers.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: Color(0xFF06D6A0), size: 36),
                        SizedBox(height: 8),
                        Text(
                          "No Blocked Profiles",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Profiles you block from chat or feed will appear here.",
                          style: TextStyle(
                            color: Color(0xFFA0A0B2),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._blockedUsers.map((u) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF22222C),
                            backgroundImage: u['photo_url'] != null
                                ? CachedNetworkImageProvider(u['photo_url'])
                                : null,
                            child: u['photo_url'] == null
                                ? const Icon(Icons.person,
                                    color: Colors.grey, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u['full_name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "📍 ${u['city'] ?? ''}",
                                  style: const TextStyle(
                                    color: Color(0xFFA0A0B2),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _unblockUser(u['user_id']),
                            child: const Text(
                              "Unblock",
                              style: TextStyle(
                                color: Color(0xFFFF334B),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
