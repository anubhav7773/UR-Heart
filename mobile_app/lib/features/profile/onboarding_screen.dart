import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/security/storage_manager.dart';
import '../feed/feed_screen.dart';
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

  final TextEditingController _nameController = TextEditingController(text: 'Rahul Singh');
  final TextEditingController _bioController = TextEditingController(
      text: 'Simple guy from Ayodhya. Love tea, photography, and late night talks.');
  final TextEditingController _areaController = TextEditingController(text: 'Sohawal, Ayodhya');
  final TextEditingController _pinController = TextEditingController(text: '224189');

  final DateTime _selectedDob = DateTime(2002, 3, 26);
  final String _gender = 'male';
  final String _interestedIn = 'female';
  String _intent = 'serious';
  bool _isSubmitting = false;

  final List<String?> _photoPaths = [
    'https://r2.ruralheart.com/p1.webp',
    'https://r2.ruralheart.com/p2.webp',
    'https://r2.ruralheart.com/p3.webp',
    'https://r2.ruralheart.com/p4.webp',
    'https://r2.ruralheart.com/p5.webp',
  ];

  Future<void> _pickImageForSlot(int index) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
      );

      if (pickedFile != null) {
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

    final filledPhotos = _photoPaths.where((p) => p != null && p.isNotEmpty).toList();
    if (filledPhotos.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select/upload photos for all 5 slots.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'full_name': _nameController.text.trim(),
        'dob': _selectedDob.toIso8601String().split('T').first,
        'gender': _gender,
        'interested_in': _interestedIn,
        'intent': _intent,
        'bio': _bioController.text.trim(),
        'area_name': _areaController.text.trim(),
        'village_pin_code': _pinController.text.trim(),
        'latitude': 26.7880,
        'longitude': 82.1300,
        'photos': List.generate(5, (index) {
          final path = _photoPaths[index]!;
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
          MaterialPageRoute(builder: (context) => const FeedScreen()),
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
