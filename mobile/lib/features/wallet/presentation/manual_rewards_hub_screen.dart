import 'package:flutter/material.dart';
import '../data/wallet_repository.dart';
import '../../ads/services/ad_manager.dart';
import 'night_farmer_screen.dart';

class ManualRewardsHubScreen extends StatefulWidget {
  const ManualRewardsHubScreen({super.key});

  @override
  State<ManualRewardsHubScreen> createState() => _ManualRewardsHubScreenState();
}

class _ManualRewardsHubScreenState extends State<ManualRewardsHubScreen> {
  final WalletRepository _walletRepo = WalletRepository();
  bool _isLoading = true;
  bool _isClaiming = false;
  WalletBalanceModel? _wallet;

  // Selected reward choices per tier
  String _selectedTier10Choice = "dm_credit"; // 'dm_credit' or 'missed_bio_pass'
  String _selectedTier20Choice = "dm_credit"; // 'dm_credit' or 'streak_shield'
  String _selectedTier30Choice = "wa_reveal_token"; // 'wa_reveal_token' or 'dm_credit'

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  Future<void> _fetchBalance() async {
    setState(() => _isLoading = true);
    try {
      final balance = await _walletRepo.fetchBalance();
      setState(() => _wallet = balance);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchAdAndClaim(String adTier, String rewardChoice) async {
    setState(() => _isClaiming = true);

    try {
      await AdManager.instance.showTieredAd(
        context: context,
        adTier: adTier,
        rewardChoice: rewardChoice,
        onRewardSuccess: () async {
          try {
            await _walletRepo.claimReward(
              adTier: adTier,
              rewardChoice: rewardChoice,
            );
            await _fetchBalance();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("✓ Reward added to your wallet!"),
                  backgroundColor: Color(0xFF06D6A0),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Claim error: $e"), backgroundColor: const Color(0xFFFF334B)),
              );
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ad playback failed: $e"), backgroundColor: const Color(0xFFFF334B)),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color canvasBg = Color(0xFF0A0A0D);
    const Color brandPrimary = Color(0xFFFF2E63);

    return Scaffold(
      backgroundColor: canvasBg,
      appBar: AppBar(
        backgroundColor: canvasBg,
        elevation: 0,
        title: const Text(
          "Watch Ads & Earn Rewards",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFFD166)),
            onPressed: _fetchBalance,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandPrimary))
          : RefreshIndicator(
              onRefresh: _fetchBalance,
              color: brandPrimary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Top Live Wallet Balance Header Card
                  if (_wallet != null) _buildWalletHUD(_wallet!),

                  // Night Farmer Auto Sleep Stream Banner Card
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16161D),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF08D9D6).withValues(alpha: 0.35)),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF08D9D6).withValues(alpha: 0.1),
                          const Color(0xFF16161D),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.bedtime_outlined, color: Color(0xFF08D9D6), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "Night Farmer (Auto Sleep Stream)",
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF08D9D6).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text("AUTO", style: TextStyle(color: Color(0xFF08D9D6), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Going to sleep? Turn on Night Farmer. Your phone will auto-cycle ads with a 75-second cooling timer and wake you up with a full package of DMs, WA tokens & shields.",
                          style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 12, height: 1.3),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF08D9D6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.play_arrow, color: Colors.black, size: 20),
                            label: const Text(
                              "Start Overnight Sleep Farm (Max 18)",
                              style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const NightFarmerScreen()),
                              ).then((_) => _fetchBalance());
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "Choose Your Ad Tier / विज्ञापन का स्तर चुनें",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Select your preferred reward and watch a short ad to claim instantly.",
                    style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // TIER 1: 10s Quick Boost Card
                  _buildAdTierCard(
                    tier: "10s",
                    badgeText: "10 SECONDS • QUICK BOOST",
                    badgeColor: const Color(0xFF08D9D6),
                    icon: Icons.bolt,
                    options: [
                      {"value": "dm_credit", "title": "+1 Direct DM Credit", "sub": "Send instant DM without waiting for a match"},
                      {"value": "missed_bio_pass", "title": "+1 Missed Bio Pass", "sub": "Unlock bio of any passed profile for 24h"},
                    ],
                    selectedChoice: _selectedTier10Choice,
                    onChoiceChanged: (val) => setState(() => _selectedTier10Choice = val),
                    onWatchTap: () => _launchAdAndClaim("10s", _selectedTier10Choice),
                  ),
                  const SizedBox(height: 16),

                  // TIER 2: 20s Standard Boost Card
                  _buildAdTierCard(
                    tier: "20s",
                    badgeText: "20 SECONDS • STANDARD BOOST",
                    badgeColor: const Color(0xFFFFD166),
                    icon: Icons.shield,
                    options: [
                      {"value": "dm_credit", "title": "+2 Direct DM Credits", "sub": "Double direct message allowance"},
                      {"value": "streak_shield", "title": "+1 Streak Shield", "sub": "Protects your fire streak from resetting for 24h"},
                    ],
                    selectedChoice: _selectedTier20Choice,
                    onChoiceChanged: (val) => setState(() => _selectedTier20Choice = val),
                    onWatchTap: () => _launchAdAndClaim("20s", _selectedTier20Choice),
                  ),
                  const SizedBox(height: 16),

                  // TIER 3: 30s High-Value Power Card
                  _buildAdTierCard(
                    tier: "30s",
                    badgeText: "30 SECONDS • HIGH VALUE UNLOCK",
                    badgeColor: const Color(0xFFFF2E63),
                    icon: Icons.workspace_premium,
                    options: [
                      {"value": "wa_reveal_token", "title": "+1 WhatsApp Reveal Token", "sub": "Advance mutual WhatsApp unlock checkpoint (1/3)"},
                      {"value": "dm_credit", "title": "+4 Direct DM Credits", "sub": "Maximum direct message pack"},
                    ],
                    selectedChoice: _selectedTier30Choice,
                    onChoiceChanged: (val) => setState(() => _selectedTier30Choice = val),
                    onWatchTap: () => _launchAdAndClaim("30s", _selectedTier30Choice),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildWalletHUD(WalletBalanceModel wallet) {
    const Color cardSurface = Color(0xFF16161D);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Your Rewards Wallet", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFFFD166), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildWalletChip("🪙 DMs", "${wallet.dmCredits}", const Color(0xFFFFD166)),
              const SizedBox(width: 8),
              _buildWalletChip("💬 WA Tokens", "${wallet.waRevealTokens}", const Color(0xFF06D6A0)),
              const SizedBox(width: 8),
              _buildWalletChip("🛡️ Shields", "${wallet.streakShields}", const Color(0xFF08D9D6)),
              const SizedBox(width: 8),
              _buildWalletChip("👀 Bio Passes", "${wallet.missedBioPasses}", Colors.white70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF22222C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 10, fontWeight: FontWeight.w500), maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildAdTierCard({
    required String tier,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required List<Map<String, String>> options,
    required String selectedChoice,
    required ValueChanged<String> onChoiceChanged,
    required VoidCallback onWatchTap,
  }) {
    const Color cardSurface = Color(0xFF16161D);
    const Color surfaceRaised = Color(0xFF22222C);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier Header Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              Icon(icon, color: badgeColor, size: 20),
            ],
          ),
          const SizedBox(height: 14),

          // Radio Selection Rows
          ...options.map((opt) {
            final bool isSelected = selectedChoice == opt['value'];
            return GestureDetector(
              onTap: () => onChoiceChanged(opt['value']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? badgeColor.withOpacity(0.1) : surfaceRaised,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? badgeColor : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? badgeColor : const Color(0xFF636375),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt['title']!,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFFA0A0B2),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(opt['sub']!, style: const TextStyle(color: Color(0xFF636375), fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),

          // Launch CTA Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: badgeColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isClaiming ? null : onWatchTap,
              child: _isClaiming
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : Text(
                      "Watch $tier Ad & Claim Reward",
                      style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
