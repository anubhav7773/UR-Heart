import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/location_service.dart';
import '../data/profile_repository.dart';
import '../../kyc/presentation/photo_upload_screen.dart';
import '../../onboarding/presentation/widgets/gender_selector_bottom_sheet.dart';

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

  String _selectedState = "Uttar Pradesh";
  String? _selectedCity;
  Map<String, List<String>> _locationCatalog = {
    "Uttar Pradesh": ["Lucknow", "Ayodhya", "Kanpur", "Varanasi", "Prayagraj", "Noida", "Agra"],
    "Delhi NCR": ["New Delhi", "Gurugram"],
    "Maharashtra": ["Mumbai", "Pune"],
  };

  bool _isLocating = false;
  bool _isSubmitting = false;
  final ProfileRepository _profileRepo = ProfileRepository();

  @override
  void initState() {
    super.initState();
    _loadLocationCatalog();
  }

  Future<void> _loadLocationCatalog() async {
    try {
      final dio = createApiClient();
      final res = await dio.get('/api/v1/location/catalog');
      if (res.statusCode == 200 && res.data is Map && mounted) {
        final Map<String, dynamic> rawMap = res.data;
        final Map<String, List<String>> catalog = {};
        rawMap.forEach((k, v) {
          if (v is List) {
            catalog[k] = v.map((e) => e.toString()).toList();
          }
        });
        setState(() {
          _locationCatalog = catalog;
        });
      }
    } catch (_) {}
  }

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

    if ((_selectedCity == null || _selectedCity!.trim().isEmpty) && _cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select your city from the verified list."),
          backgroundColor: Color(0xFFFF334B),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String rawPhone = _whatsappController.text.trim();
      final String fullWhatsApp = rawPhone.startsWith("+91") ? rawPhone : "+91$rawPhone";
      final String resolvedCity = _selectedCity ?? _cityController.text.trim();

      await _profileRepo.submitProfileSetup(
        fullName: _nameController.text.trim(),
        whatsappNumber: fullWhatsApp,
        gender: _selectedGender!,
        city: resolvedCity,
        bio: _bioController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        detectedLocality: _detectedLocality,
      );

      if (mounted) {
        // Navigate forward to 5-Photo Upload & Video KYC Screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PhotoUploadScreen()),
          (route) => false,
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

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: canvasBg,
        appBar: AppBar(
          backgroundColor: canvasBg,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
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

                // 3. Gender Identity (Comprehensive Spectrum Selector)
                const Text("Gender Identity / लिंग पहचान", style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final selected = await GenderSelectorBottomSheet.show(context, _selectedGender ?? '');
                    if (selected != null) {
                      setState(() => _selectedGender = selected.key);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedGender != null ? brandPrimary.withValues(alpha: 0.6) : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_alt_outlined, color: brandPrimary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedGender != null
                                ? kGenderSpectrum.firstWhere(
                                    (g) => g.key == _selectedGender,
                                    orElse: () => GenderOption(key: _selectedGender!, label: _selectedGender!, category: '', description: ''),
                                  ).label
                                : "Select your gender identity...",
                            style: TextStyle(
                              color: _selectedGender != null ? Colors.white : const Color(0xFF636375),
                              fontSize: 14,
                              fontWeight: _selectedGender != null ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFA0A0B2), size: 22),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Verified City/State Selection (Anti-Spoofing)
                const Text("Verified State & City / राज्य और शहर", style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),

                // Location selection using dropdowns instead of raw text fields or manual coordinates
                DropdownButtonFormField<String>(
                  value: _selectedState,
                  dropdownColor: const Color(0xFF16161D),
                  decoration: InputDecoration(
                    labelText: "State / राज्य",
                    labelStyle: const TextStyle(color: Color(0xFFA0A0B2)),
                    filled: true,
                    fillColor: const Color(0xFF22222C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: (_locationCatalog.keys.isNotEmpty ? _locationCatalog.keys.toList() : ["Uttar Pradesh", "Delhi NCR", "Maharashtra"])
                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (val) => setState(() {
                    _selectedState = val ?? "Uttar Pradesh";
                    _selectedCity = null;
                  }),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedCity,
                  dropdownColor: const Color(0xFF16161D),
                  decoration: InputDecoration(
                    labelText: "City / शहर",
                    labelStyle: const TextStyle(color: Color(0xFFA0A0B2)),
                    filled: true,
                    fillColor: const Color(0xFF22222C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: (_locationCatalog[_selectedState] ?? ["Lucknow", "Ayodhya", "Kanpur"])
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (val) => setState(() {
                    _selectedCity = val;
                    _cityController.text = val ?? "";
                  }),
                ),
                const SizedBox(height: 8),

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
    ),
  );
}
}
