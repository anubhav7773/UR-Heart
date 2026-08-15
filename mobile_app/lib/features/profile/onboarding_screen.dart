import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/security/storage_manager.dart';
import '../../core/services/image_guard_service.dart';
import '../home/home_screen.dart';
import 'profile_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final ProfileService _profileService = ProfileService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  DateTime _selectedDob = DateTime(2001, 1, 1);
  String _gender = 'male';
  String _interestedIn = 'female';
  String _intent = 'casual';
  bool _isSubmitting = false;

  int get _computedAge {
    final now = DateTime.now();
    int age = now.year - _selectedDob.year;
    if (now.month < _selectedDob.month || (now.month == _selectedDob.month && now.day < _selectedDob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year - 18, now.month, now.day);
    final firstDate = DateTime(1940);
    final initialDate = _selectedDob.isAfter(lastDate) ? lastDate : _selectedDob;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select Date of Birth (18+ only)',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE91E63),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  final List<String?> _photoPaths = [
    null,
    null,
    null,
    null,
    null,
  ];

  Future<void> _pickImageForSlot(int index) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
      );

      if (pickedFile != null) {
        // On-Device OCR Text Guard Check
        final isClean = await ImageGuardService.validateProfilePhoto(pickedFile.path);
        if (!isClean) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.redAccent,
                content: Text(
                  "⚠️ Photo me phone number, Insta ID, ya text likhna mana hai. Kripya apni real photo upload karein.",
                ),
              ),
            );
          }
          return;
        }

        setState(() => _isSubmitting = true);
        final File imageFile = File(pickedFile.path);
        final String? uploadedUrl = await _profileService.uploadProfilePhoto(imageFile);

        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          setState(() {
            _photoPaths[index] = uploadedUrl;
          });
        } else {
          setState(() {
            _photoPaths[index] = pickedFile.path;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      String errDetail = e.toString();
      if (e is DioException && e.response != null) {
        errDetail = e.response!.data.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo upload notice: $errDetail'),
          backgroundColor: Colors.amber[800],
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    if (_computedAge < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be at least 18 years old to join UR Heart.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final filledPhotos = _photoPaths.where((p) => p != null && p.isNotEmpty).toList();
    if (filledPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select/upload at least 1 profile photo.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dobStr = _selectedDob.toIso8601String().split('T').first;
      final payload = {
        'full_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        'dob': dobStr,
        'date_of_birth': dobStr,
        'gender': _gender,
        'interested_in': _interestedIn,
        'intent': _intent,
        'bio': _bioController.text.trim(),
        'area_name': _areaController.text.trim(),
        'village_pin_code': _pinController.text.trim(),
        'photos': List.generate(filledPhotos.length, (index) {
          final path = filledPhotos[index]!;
          return {
            'photo_url': path,
            'is_first_impression': index == 0,
            'display_order': index + 1,
          };
        }),
      };

      final response = await _profileService.updateProfile(payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await StorageManager.instance.setProfileComplete(true);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainHomeScreen()),
        );
      } else {
        final errText = response.data != null ? response.data.toString() : 'HTTP ${response.statusCode}';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile error: $errText'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String errText = e.toString();
      if (e is DioException && e.response != null) {
        errText = e.response!.data.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Onboarding Error: $errText'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildPhotoSlotImage(String path) {
    if (path.startsWith('http://') || path.startsWith('https://') || kIsWeb) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[900],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } else {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Complete Your Profile', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add 5 Photos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your 1st photo will be your First Impression card.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    final path = _photoPaths[index];
                    return GestureDetector(
                      onTap: () => _pickImageForSlot(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: index == 0 ? const Color(0xFFE91E63) : Colors.grey[800]!,
                            width: index == 0 ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Stack(
                            children: [
                              if (path != null && path.isNotEmpty)
                                _buildPhotoSlotImage(path)
                              else
                                const Center(
                                  child: Icon(Icons.add_a_photo, color: Colors.grey, size: 28),
                                ),
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: index == 0 ? const Color(0xFFE91E63) : Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    index == 0 ? 'Main' : '#${index + 1}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'WhatsApp / Mobile Number',
                    hintText: 'e.g. 9876543210 (for 🔒 Safe Share)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    prefixIcon: const Icon(Icons.chat, color: Colors.greenAccent, size: 20),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDateOfBirth,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date of Birth (18+ only)',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_selectedDob.day.toString().padLeft(2, '0')}/${_selectedDob.month.toString().padLeft(2, '0')}/${_selectedDob.year}  (Age: $_computedAge)',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Icon(Icons.calendar_month, color: Color(0xFFE91E63)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'I am',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('👨 Male'),
                      selected: _gender == 'male',
                      selectedColor: const Color(0xFFE91E63),
                      onSelected: (sel) => setState(() => _gender = 'male'),
                    ),
                    ChoiceChip(
                      label: const Text('👩 Female'),
                      selected: _gender == 'female',
                      selectedColor: const Color(0xFFE91E63),
                      onSelected: (sel) => setState(() => _gender = 'female'),
                    ),
                    ChoiceChip(
                      label: const Text('✨ Other'),
                      selected: _gender == 'other',
                      selectedColor: const Color(0xFFE91E63),
                      onSelected: (sel) => setState(() => _gender = 'other'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Looking for',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('👩 Women'),
                      selected: _interestedIn == 'female',
                      selectedColor: const Color(0xFFE91E63),
                      onSelected: (sel) => setState(() => _interestedIn = 'female'),
                    ),
                    ChoiceChip(
                      label: const Text('👨 Men'),
                      selected: _interestedIn == 'male',
                      selectedColor: const Color(0xFFE91E63),
                      onSelected: (sel) => setState(() => _interestedIn = 'male'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Bio / About You',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _areaController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Landmark / Area',
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'PIN Code',
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Intent / Relationship Goal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('☕ Casual Chai'),
                      selected: _intent == 'casual',
                      selectedColor: const Color(0xFFE91E63),
                      onSelected: (sel) => setState(() => _intent = 'casual'),
                    ),
                    ChoiceChip(
                      label: const Text('💍 Serious Marriage'),
                      selected: _intent == 'serious',
                      selectedColor: const Color(0xFFE91E63),
                      onSelected: (sel) => setState(() => _intent = 'serious'),
                    ),
                    ChoiceChip(
                      label: const Text('🤝 Friendship'),
                      selected: _intent == 'friendship',
                      selectedColor: const Color(0xFFE91E63),
                      onSelected: (sel) => setState(() => _intent = 'friendship'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitOnboarding,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save & Start Matching', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
