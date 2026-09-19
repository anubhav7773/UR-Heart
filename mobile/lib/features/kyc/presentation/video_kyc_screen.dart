import 'package:flutter/material.dart';

class VideoKycScreen extends StatefulWidget {
  const VideoKycScreen({super.key});

  @override
  State<VideoKycScreen> createState() => _VideoKycScreenState();
}

class _VideoKycScreenState extends State<VideoKycScreen> {
  bool _hasConsentedToBiometrics = false;
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    const Color canvasBg = Color(0xFF0A0A0D);
    const Color cardSurface = Color(0xFF16161D);
    const Color brandCrimson = Color(0xFFFF2E63);

    return Scaffold(
      backgroundColor: canvasBg,
      appBar: AppBar(
        backgroundColor: canvasBg,
        elevation: 0,
        title: const Text(
          "Video KYC Verification",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF08D9D6).withOpacity(0.12),
                      ),
                      child: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFF08D9D6), size: 40),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Quick 3-Second Liveness Check",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "To prevent fake profiles and bots, record a brief 3-second video smiling at the camera.",
                    style: TextStyle(color: Color(0xFFA0A0B2), fontSize: 13, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Statutory DPDP Act 2023 Biometric Consent Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _hasConsentedToBiometrics ? const Color(0xFF06D6A0) : const Color(0xFFFFD166).withOpacity(0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _hasConsentedToBiometrics,
                              activeColor: const Color(0xFF06D6A0),
                              checkColor: Colors.black,
                              onChanged: (val) {
                                setState(() => _hasConsentedToBiometrics = val ?? false);
                              },
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _hasConsentedToBiometrics = !_hasConsentedToBiometrics),
                                child: const Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: Text(
                                    "I consent to providing a short video for identity verification. This video will be permanently deleted post-verification.",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "Compliant with Section 8 of the Digital Personal Data Protection (DPDP) Act 2023. Raw media is scrubbed from servers immediately upon approval.",
                            style: TextStyle(color: Color(0xFF636375), fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Start Recording CTA (Gated by Biometric Consent Checkbox)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasConsentedToBiometrics ? brandCrimson : const Color(0xFF22222C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: _hasConsentedToBiometrics ? 4 : 0,
                ),
                icon: Icon(
                  Icons.videocam_rounded,
                  color: _hasConsentedToBiometrics ? Colors.white : Colors.white24,
                ),
                label: Text(
                  "Record 3s Verification Video",
                  style: TextStyle(
                    color: _hasConsentedToBiometrics ? Colors.white : Colors.white24,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _hasConsentedToBiometrics && !_isUploading
                    ? () {
                        // Launch camera flow
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
