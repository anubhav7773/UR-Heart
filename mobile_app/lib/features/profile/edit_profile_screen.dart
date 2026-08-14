import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isVerified = false;
  String _verificationStatus = 'UNVERIFIED';
  bool _isUploadingVideo = false;

  final ImagePicker _picker = ImagePicker();
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.getProfile();
      if (response.data != null && response.data['data'] != null) {
        final data = response.data['data'];
        _nameController.text = data['full_name'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _areaController.text = data['area_name'] ?? '';
        _isVerified = data['is_verified'] == true;
        _verificationStatus = (data['verification_status'] ?? 'UNVERIFIED').toString().toUpperCase();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[EditProfileScreen] Error fetching profile: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recordVerificationVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 10),
        preferredCameraDevice: CameraDevice.front,
      );

      if (video != null) {
        setState(() => _isUploadingVideo = true);

        final res = await _profileService.uploadVerificationVideo(File(video.path));

        if (mounted) {
          setState(() {
            _verificationStatus = 'PENDING';
            _isVerified = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res?['message'] ?? 'Video Verification Submitted! Status is now PENDING review.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video verification notice: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingVideo = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ApiClient.instance.putProfile({
        'full_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'area_name': _areaController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Edit Profile & Verification', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check, color: Colors.greenAccent),
            onPressed: _isSaving ? null : _saveProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video Verification Badge Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isVerified
                              ? [Colors.blue.shade900.withValues(alpha: 0.5), Colors.blue.shade700.withValues(alpha: 0.3)]
                              : [AppTheme.surfaceColor, AppTheme.cardColor],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isVerified ? Colors.blueAccent : Colors.grey[800]!,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isVerified ? Icons.verified : Icons.verified_user_outlined,
                                color: _isVerified ? Colors.blueAccent : Colors.white70,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _isVerified
                                      ? 'Profile Verified ✓'
                                      : _verificationStatus == 'PENDING'
                                          ? 'Verification Under Review ⏳'
                                          : _verificationStatus == 'REJECTED'
                                              ? 'Verification Rejected ❌'
                                              : 'Get Verified Blue Tick',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _isVerified
                                        ? Colors.blueAccent
                                        : _verificationStatus == 'PENDING'
                                            ? Colors.amber
                                            : _verificationStatus == 'REJECTED'
                                                ? Colors.redAccent
                                                : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isVerified
                                ? 'Your identity is verified. Your Blue Tick badge is visible on your profile and discovery cards.'
                                : _verificationStatus == 'PENDING'
                                    ? 'Your selfie video has been submitted and is currently being reviewed by our moderation team (takes up to 24h).'
                                    : _verificationStatus == 'REJECTED'
                                        ? 'Your previous selfie video did not pass community quality guidelines. Please record a clearer video.'
                                        : 'Record a 5-second selfie video to unlock the official Verified Blue Tick badge.',
                            style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isUploadingVideo ? null : _recordVerificationVideo,
                              icon: _isUploadingVideo
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Icon(_isVerified ? Icons.videocam_outlined : Icons.camera_front, size: 20),
                              label: Text(_isVerified
                                  ? 'Re-record Verification Video'
                                  : _verificationStatus == 'PENDING'
                                      ? 'Re-upload Verification Video'
                                      : 'Record 5s Selfie Video 📹'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isVerified ? Colors.blue.shade800 : AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full Name Field
                    const Text('Full Name', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter your full name',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Name cannot be empty' : null,
                    ),
                    const SizedBox(height: 20),

                    // Bio Field
                    const Text('About Me (Bio)', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Share a little about yourself...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Area Name Field
                    const Text('Area / City Name', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _areaController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g. Ayodhya, Faizabad',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
