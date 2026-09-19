import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/wallet_repository.dart';
import '../../ads/services/ad_manager.dart';

class NightFarmerScreen extends StatefulWidget {
  const NightFarmerScreen({super.key});

  @override
  State<NightFarmerScreen> createState() => _NightFarmerScreenState();
}

class _NightFarmerScreenState extends State<NightFarmerScreen> with SingleTickerProviderStateMixin {
  final WalletRepository _walletRepo = WalletRepository();

  // State variables
  bool _isRunning = true;
  bool _isPlayingAd = false;
  int _secondsUntilNextAd = 75;
  Timer? _countdownTimer;
  Timer? _clockTimer;
  String _currentTime = "";

  // Session Metrics
  int _sessionAdsWatched = 0;
  int _farmedDms = 0;
  int _farmedWaTokens = 0;
  int _farmedShields = 0;
  int _farmedBioPasses = 0;
  final int _dailyCap = 18;
  int _alreadyFarmedToday = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentTime = DateFormat('hh:mm a').format(DateTime.now());

    // Keep screen active overnight
    try {
      WakelockPlus.enable();
    } catch (_) {}

    // Subtle breathing pulse for OLED display
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateFormat('hh:mm a').format(DateTime.now());
        });
      }
    });

    _initFarmingSession();
  }

  @override
  void dispose() {
    try {
      WakelockPlus.disable();
    } catch (_) {}
    _countdownTimer?.cancel();
    _clockTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initFarmingSession() async {
    try {
      final balance = await _walletRepo.fetchBalance();
      _alreadyFarmedToday = balance.nightFarmAdsToday;

      if (!balance.canFarmTonight || _alreadyFarmedToday >= _dailyCap) {
        _stopFarmingWithAlert("Tonight's safety cap of 18 ads has already been reached!");
        return;
      }

      _startCoolingCountdown();
    } catch (e) {
      _stopFarmingWithAlert("Could not initialize wallet session: $e");
    }
  }

  void _startCoolingCountdown() {
    if (!_isRunning) return;

    setState(() {
      _secondsUntilNextAd = 75; // 75s anti-IVT cooling gap
      _isPlayingAd = false;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isRunning) {
        timer.cancel();
        return;
      }

      if (_secondsUntilNextAd > 1) {
        setState(() => _secondsUntilNextAd--);
      } else {
        timer.cancel();
        _triggerAutomatedAd();
      }
    });
  }

  String _selectNextReward() {
    // Weighted cycle: 50% DM, 25% WA token, 15% Shield, 10% Bio Pass
    final cycleIndex = _sessionAdsWatched % 10;
    if (cycleIndex < 5) return "dm_credit";
    if (cycleIndex < 8) return "wa_reveal_token";
    if (cycleIndex == 8) return "streak_shield";
    return "missed_bio_pass";
  }

  Future<void> _triggerAutomatedAd() async {
    if (!_isRunning) return;

    if ((_alreadyFarmedToday + _sessionAdsWatched) >= _dailyCap) {
      _finishNightSession(isCapReached: true);
      return;
    }

    setState(() => _isPlayingAd = true);

    final String selectedReward = _selectNextReward();
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "night_farm";

    Future<void> onReward() async {
      try {
        await _walletRepo.claimReward(
          adTier: "night_farm",
          rewardChoice: selectedReward,
        );

        if (mounted) {
          setState(() {
            _sessionAdsWatched++;
            if (selectedReward == "dm_credit") _farmedDms++;
            if (selectedReward == "wa_reveal_token") _farmedWaTokens++;
            if (selectedReward == "streak_shield") _farmedShields++;
            if (selectedReward == "missed_bio_pass") _farmedBioPasses++;
          });
        }
      } catch (_) {}

      // Schedule next cooling cycle
      if (mounted && _isRunning) {
        _startCoolingCountdown();
      }
    }

    final bool shown = AdManager.instance.showRewardedAd(
      userId: uid,
      adType: "night_farm_auto",
      targetId: selectedReward,
      onRewardGranted: onReward,
    );

    if (!shown) {
      // In dev or test environments when ad is not buffered, allow direct reward progression
      onReward();
    }
  }

  void _stopFarmingWithAlert(String message) {
    setState(() => _isRunning = false);
    _countdownTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161D),
        title: const Text("Night Farmer Notice", style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(message, style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 13)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2E63)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _finishNightSession({bool isCapReached = false}) {
    setState(() => _isRunning = false);
    _countdownTimer?.cancel();

    // Show Morning Celebratory Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Text("🌅", style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text("Wake-Up Care Package!", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCapReached
                  ? "Daily safety cap of 18 ads reached! Here is what you farmed overnight:"
                  : "Good morning! Here is what your phone collected while you slept:",
              style: const TextStyle(color: Color(0xFFA0A0B2), fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow("🪙 Direct DMs:", "+$_farmedDms", const Color(0xFFFFD166)),
            _buildSummaryRow("💬 WhatsApp Reveal Tokens:", "+$_farmedWaTokens", const Color(0xFF06D6A0)),
            _buildSummaryRow("🛡️ Fire Streak Shields:", "+$_farmedShields", const Color(0xFF08D9D6)),
            _buildSummaryRow("👀 Missed Bio Passes:", "+$_farmedBioPasses", Colors.white70),
            const Divider(color: Colors.white12, height: 20),
            Text(
              "Total Ads Processed: $_sessionAdsWatched",
              style: const TextStyle(color: Color(0xFF636375), fontSize: 11),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06D6A0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Exit back to profile
            },
            child: const Text("Claim All to Wallet", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(val, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pure AMOLED black background to minimize battery usage
    const Color amoledBlack = Color(0xFF000000);

    return Scaffold(
      backgroundColor: amoledBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top HUD: Digital Clock & Mode indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTime,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: Color(0xFF06D6A0), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "NIGHT FARMER ACTIVE",
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${_alreadyFarmedToday + _sessionAdsWatched}/$_dailyCap Ads",
                      style: const TextStyle(color: Color(0xFFFFD166), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              // Center Ambient Pulse: Low-brightness Crimson Heart
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2E63).withOpacity(0.12),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.favorite,
                          size: 64,
                          color: const Color(0xFFFF2E63).withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isPlayingAd
                        ? "Playing Ad Impression..."
                        : "Cooling pause: ${_secondsUntilNextAd}s",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Farmed Tonight: +$_farmedDms DMs • +$_farmedWaTokens WA • +$_farmedShields Shields",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

              // Bottom Dismiss Bar: Slide or tap to exit
              Column(
                children: [
                  Text(
                    "Keep phone plugged in on nightstand\nAnti-IVT cooling timer keeps account 100% policy safe",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _finishNightSession(isCapReached: false),
                      child: Text(
                        "Stop Farming & Collect Rewards",
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
