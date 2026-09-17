import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/location_service.dart';
import '../data/profile_repository.dart';
import '../../kyc/presentation/photo_upload_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();

  String? _selectedGender; // 'male', 'female', 'lgbtq+'
  double? _latitude;
  double? _longitude;
  String? _detectedLocality;

  bool _isLocating = false;
  bool _isSubmitting = false;
  final ProfileRepository _profileRepo = ProfileRepository();

  // Tier-2/3 Indian Cities Fallback List
  final List<String> _quickCities = [
    "Lucknow", "Ayodhya", "Varanasi", "Kanpur", 
    "Prayagraj", "Gorakhpur", "Agra", "Meerut", "Patna", "Indore"
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleGpsLocation() async {
    setState(() => _isLocating = true);
    try {
      final UserLocationResult result = await LocationService.fetchCurrentLocation();
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _cityController.text = result.city;
        _detectedLocality = result.locality;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("📍 Detected: ${result.city}"),
            backgroundColor: const Color(0xFF06D6A0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not detect GPS: ${e.toString().replaceAll('Exception: ', '')}"),
            backgroundColor: const Color(0xFFFF334B),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select your gender identity."),
          backgroundColor: Color(0xFFFF334B),
        ),
      );
      return;
    }

    if (_cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select or detect your city."),
          backgroundColor: Color(0xFFFF334B),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String rawPhone = _whatsappController.text.trim();
      final String fullWhatsApp = rawPhone.startsWith("+91") ? rawPhone : "+91$rawPhone";

      await _profileRepo.submitProfileSetup(
        fullName: _nameController.text.trim(),
        whatsappNumber: fullWhatsApp,
        gender: _selectedGender!,
        city: _cityController.text.trim(),
        bio: _bioController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        detectedLocality: _detectedLocality,
      );

      if (mounted) {
        // Navigate forward to 5-Photo Upload & Video KYC Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PhotoUploadScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFFF334B),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color canvasBg = Color(0xFF0A0A0D);
    const Color cardSurface = Color(0xFF16161D);
    const Color surfaceRaised = Color(0xFF22222C);
    const Color brandPrimary = Color(0xFFFF2E63);
    const Color brandCyan = Color(0xFF08D9D6);
    const Color textPrimary = Color(0xFFFFFFFF);
    const Color textSecondary = Color(0xFFA0A0B2);

    return Scaffold(
      backgroundColor: canvasBg,
      appBar: AppBar(
        backgroundColor: canvasBg,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Complete Profile / प्रोफ़ाइल भरें",
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Counter & Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: surfaceRaised,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    "STEP 1 OF 2: BASIC DETAILS",
                    style: TextStyle(color: brandCyan, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Tell us about yourself\nअपने बारे में बताएं",
                  style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 24),

                // 1. Full Name Input
                const Text("Legal Full Name / पूरा नाम", style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: textPrimary, fontSize: 15),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: "Enter your full name",
                    hintStyle: const TextStyle(color: Color(0xFF636375)),
                    filled: true,
                    fillColor: cardSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 2) return "Enter at least 2 characters.";
                    if (!RegExp(r"^[a-zA-Z\s.'-]+$").hasMatch(val.trim())) return "Only alphabetic characters allowed.";
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // 2. WhatsApp Number (+91) with Privacy Disclaimer
                const Text("WhatsApp Number / व्हाट्सएप नंबर", style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  style: const TextStyle(color: textPrimary, fontSize: 15, letterSpacing: 1.2),
                  decoration: InputDecoration(
                    prefixIcon: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Text("+91", style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    hintText: "9876543210",
                    hintStyle: const TextStyle(color: Color(0xFF636375)),
                    filled: true,
                    fillColor: cardSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length != 10) return "Enter valid 10-digit mobile number.";
                    if (!RegExp(r"^[6-9]\d{9}$").hasMatch(val.trim())) return "Must begin with 6, 7, 8, or 9.";
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: surfaceRaised.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFFFFD166), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Private: Only revealed when both matches mutually agree and watch 3 video ads.",
                          style: TextStyle(color: Color(0xFFFFD166), fontSize: 11, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Gender Identity (High Contrast Inclusive Chips)
                const Text("Gender Identity / लिंग पहचान", style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildGenderChip("male", "♂️ Male", "पुरुष"),
                    const SizedBox(width: 10),
                    _buildGenderChip("female", "♀️ Female", "महिला"),
                    const SizedBox(width: 10),
                    _buildGenderChip("lgbtq+", "🏳️🌈 LGBTQ+", "अन्य"),
                  ],
                ),
                const SizedBox(height: 24),

                // 4. City Selection & GPS Detection
                const Text("City & Discovery Area / शहर", style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        style: const TextStyle(color: textPrimary, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: "Your City (e.g. Lucknow)",
                          hintStyle: const TextStyle(color: Color(0xFF636375)),
                          filled: true,
                          fillColor: cardSurface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isLocating ? null : _handleGpsLocation,
                        icon: _isLocating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.my_location, size: 18, color: Colors.black),
                        label: const Text("GPS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandCyan,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Quick City Select Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickCities.map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(c, style: const TextStyle(color: textSecondary, fontSize: 12)),
                          backgroundColor: surfaceRaised,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onPressed: () => setState(() => _cityController.text = c),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),

                // Geospatial Privacy Microcopy Notice
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: brandCyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: brandCyan.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, color: brandCyan, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "🔒 Exact coordinates are never shared. Discovery profiles only display your city and an approximate distance badge (e.g. Nearby 10 km).",
                          style: TextStyle(color: brandCyan, fontSize: 11, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Short Bio Input
                const Text("Bio / परिचय (Optional)", style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  maxLength: 250,
                  style: const TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Share a hobby, interest, or what brings you here...",
                    hintStyle: const TextStyle(color: Color(0xFF636375)),
                    filled: true,
                    fillColor: cardSurface,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      elevation: 4,
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                        : const Text(
                            "Continue to Photos & KYC / आगे बढ़ें →",
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderChip(String value, String labelEn, String labelHi) {
    final bool isSelected = _selectedGender == value;
    const Color brandPrimary = Color(0xFFFF2E63);
    const Color cardSurface = Color(0xFF16161D);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? brandPrimary.withValues(alpha: 0.18) : cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? brandPrimary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labelEn,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFA0A0B2),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                labelHi,
                style: TextStyle(
                  color: isSelected ? Colors.white70 : const Color(0xFF636375),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
