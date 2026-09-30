import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/media/media_compressor.dart';
import '../../../../core/media/supabase_media_uploader.dart';
import '../../../../core/services/activity_logger_service.dart';
import '../../../../core/services/image_moderation_service.dart';
import '../../../../core/services/real_gps_location_service.dart';
import '../../../../core/storage/secure_session_storage.dart';
import '../../data/profile_repository.dart';

class ProfileSetupState {
  final Map<int, String> photoSlots;
  final Map<int, String> blurHashes;
  final String fullName;
  final String dobString;
  final String gender;
  final Set<String> interestedIn;
  final String location;
  final String bio;
  final String profession;
  final String education;
  final double minAge;
  final double maxAge;
  final String contactBridgePlatform;
  final String contactBridgeHandle;
  final bool isKycVerified;
  final bool isKycPendingReview;
  final bool isUploadingPhoto;
  final bool isPolishingBio;
  final bool isSubmitting;
  final String? kycStatusMessage;
  final String? lastModerationError;
  final bool isGpsVerified;
  final bool isAcquiringGps;
  final String? gpsError;

  const ProfileSetupState({
    this.photoSlots = const {},
    this.blurHashes = const {},
    this.fullName = '',
    this.dobString = '',
    this.gender = 'Woman',
    this.interestedIn = const {'Men'},
    this.location = 'Acquiring GPS...',
    this.bio = '',
    this.profession = '',
    this.education = '',
    this.minAge = 18.0,
    this.maxAge = 35.0,
    this.contactBridgePlatform = 'whatsapp',
    this.contactBridgeHandle = '',
    this.isKycVerified = false,
    this.isKycPendingReview = false,
    this.isUploadingPhoto = false,
    this.isPolishingBio = false,
    this.isSubmitting = false,
    this.kycStatusMessage,
    this.lastModerationError,
    this.isGpsVerified = false,
    this.isAcquiringGps = false,
    this.gpsError,
  });

  bool get isBioPolishing => isPolishingBio;
  bool get hasPrimaryAnchorPhoto => photoSlots.containsKey(1);
  bool get canCompleteSetup =>
      hasPrimaryAnchorPhoto && fullName.trim().isNotEmpty && isGpsVerified;

  ProfileSetupState copyWith({
    Map<int, String>? photoSlots,
    Map<int, String>? blurHashes,
    String? fullName,
    String? dobString,
    String? gender,
    Set<String>? interestedIn,
    String? location,
    String? bio,
    String? profession,
    String? education,
    double? minAge,
    double? maxAge,
    String? contactBridgePlatform,
    String? contactBridgeHandle,
    bool? isKycVerified,
    bool? isKycPendingReview,
    bool? isUploadingPhoto,
    bool? isPolishingBio,
    bool? isSubmitting,
    String? kycStatusMessage,
    String? lastModerationError,
    bool? isGpsVerified,
    bool? isAcquiringGps,
    String? gpsError,
  }) {
    return ProfileSetupState(
      photoSlots: photoSlots ?? this.photoSlots,
      blurHashes: blurHashes ?? this.blurHashes,
      fullName: fullName ?? this.fullName,
      dobString: dobString ?? this.dobString,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      profession: profession ?? this.profession,
      education: education ?? this.education,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      contactBridgePlatform:
          contactBridgePlatform ?? this.contactBridgePlatform,
      contactBridgeHandle: contactBridgeHandle ?? this.contactBridgeHandle,
      isKycVerified: isKycVerified ?? this.isKycVerified,
      isKycPendingReview: isKycPendingReview ?? this.isKycPendingReview,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      isPolishingBio: isPolishingBio ?? this.isPolishingBio,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      kycStatusMessage: kycStatusMessage ?? this.kycStatusMessage,
      lastModerationError: lastModerationError,
      isGpsVerified: isGpsVerified ?? this.isGpsVerified,
      isAcquiringGps: isAcquiringGps ?? this.isAcquiringGps,
      gpsError: gpsError,
    );
  }
}

class ProfileSetupController extends StateNotifier<ProfileSetupState> {
  final ProfileRepository _repository;

  ProfileSetupController(this._repository) : super(const ProfileSetupState()) {
    loadSavedProfile();
  }

  /// Automatically restores user's authentic name, DOB, and stored profile from disk
  Future<void> loadSavedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedName = prefs.getString('profile_full_name') ??
          prefs.getString('ur_heart_user_name') ??
          '';

      final savedDob = prefs.getString('ur_heart_selected_dob') ??
          prefs.getString('profile_dob') ??
          state.dobString;

      final savedGender = prefs.getString('profile_gender') ?? state.gender;
      final isGps = prefs.getBool('profile_gps_verified') ?? false;
      final savedLocation = prefs.getString('profile_location') ??
          (isGps ? state.location : 'Acquiring GPS...');
      final savedBio = prefs.getString('profile_bio') ?? state.bio;
      final savedProfession = prefs.getString('profile_profession') ?? state.profession;
      final savedEducation = prefs.getString('profile_education') ?? state.education;
      final isKyc = prefs.getBool('profile_is_kyc_verified') ?? false;

      final savedBridgePlatform = prefs.getString('profile_contact_bridge_platform') ?? state.contactBridgePlatform;
      final savedBridgeHandle = prefs.getString('profile_contact_bridge_handle') ?? state.contactBridgeHandle;

      final savedMinAge = prefs.getDouble('profile_min_age') ?? state.minAge;
      final savedMaxAge = prefs.getDouble('profile_max_age') ?? state.maxAge;

      // Restore existing photos
      final Map<int, String> restoredSlots = {};
      for (int i = 1; i <= 5; i++) {
        final path = prefs.getString('profile_photo_slot_$i');
        if (path != null && File(path).existsSync()) {
          restoredSlots[i] = path;
        }
      }

      state = state.copyWith(
        fullName: savedName,
        dobString: savedDob,
        gender: savedGender,
        location: savedLocation,
        isGpsVerified: isGps,
        bio: savedBio,
        profession: savedProfession,
        education: savedEducation,
        isKycVerified: isKyc,
        contactBridgePlatform: savedBridgePlatform,
        contactBridgeHandle: savedBridgeHandle,
        minAge: savedMinAge,
        maxAge: savedMaxAge,
        photoSlots: restoredSlots.isNotEmpty ? restoredSlots : state.photoSlots,
      );

      // Auto-trigger GPS acquisition if not yet verified
      if (!isGps) {
        fetchRealGpsLocation();
      }
    } catch (_) {}
  }

  /// Acquires real hardware GPS coordinates and reverse-geocodes locality
  Future<String> fetchRealGpsLocation() async {
    state = state.copyWith(isAcquiringGps: true, gpsError: null);
    final result = await RealGpsLocationService.acquireRealHardwareGps();
    if (result.isSuccess) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_location', result.formattedLocation);
      await prefs.setDouble('profile_gps_latitude', result.latitude);
      await prefs.setDouble('profile_gps_longitude', result.longitude);
      await prefs.setBool('profile_gps_verified', true);

      state = state.copyWith(
        location: result.formattedLocation,
        isGpsVerified: true,
        isAcquiringGps: false,
        gpsError: null,
      );
      return result.formattedLocation;
    } else {
      state = state.copyWith(
        isGpsVerified: false,
        isAcquiringGps: false,
        gpsError: result.errorMessage ?? 'Unable to acquire genuine GPS',
      );
      return result.errorMessage ?? 'Unable to acquire genuine GPS';
    }
  }

  Future<bool> processAndUploadPhoto({
    required int slotNumber,
    required File rawFile,
    String userId = 'demo_user_1',
  }) async {
    state = state.copyWith(isUploadingPhoto: true, lastModerationError: null);

    // 1. Strict Multi-Layer Content Moderation Gatekeeper
    final moderation = await ImageModerationService.inspectImage(
      rawFile,
      slotNumber: slotNumber,
    );

    if (!moderation.isSafe) {
      state = state.copyWith(
        isUploadingPhoto: false,
        lastModerationError: moderation.rejectionReason ??
            'Photo rejected: Intimate, explicit, or abusive content is strictly prohibited.',
      );
      return false;
    }

    try {
      final processed = await MediaCompressor.processPortraitPhoto(rawFile);
      final prefs = await SharedPreferences.getInstance();
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      final secureEmail = await SecureSessionStorage.instance.getUserEmail();
      final userEmail = prefs.getString('ur_heart_user_email') ?? secureEmail ?? (authUid != null ? 'uid_$authUid' : userId);
      final safeUserUuid = (authUid != null && authUid.isNotEmpty)
          ? authUid
          : userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      String finalUrl = rawFile.path;
      if (processed != null) {
        try {
          final cloudUrl = await SupabaseMediaUploader.uploadProfileSlot(
            userUuid: safeUserUuid,
            slotNumber: slotNumber,
            webpBytes: processed.webpBytes,
          );
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            finalUrl = cloudUrl;
          }
        } catch (_) {}
      }

      await prefs.setString('profile_photo_slot_$slotNumber', finalUrl);

      final updatedSlots = Map<int, String>.from(state.photoSlots);
      updatedSlots[slotNumber] = finalUrl;

      final updatedBlurHashes = Map<int, String>.from(state.blurHashes);
      if (processed != null) {
        updatedBlurHashes[slotNumber] = processed.blurHash;
      }

      state = state.copyWith(
        photoSlots: updatedSlots,
        blurHashes: updatedBlurHashes,
        isUploadingPhoto: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isUploadingPhoto: false);
      return false;
    }
  }

  Future<void> removePhotoSlot(int slotNumber) async {
    final updatedSlots = Map<int, String>.from(state.photoSlots)..remove(slotNumber);
    final updatedBlurHashes = Map<int, String>.from(state.blurHashes)..remove(slotNumber);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_photo_slot_$slotNumber');

    state = state.copyWith(
      photoSlots: updatedSlots,
      blurHashes: updatedBlurHashes,
    );
  }

  void setFullName(String name) {
    state = state.copyWith(fullName: name);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('profile_full_name', name);
    });
  }

  void setDob(String dob, [int? age]) {
    state = state.copyWith(dobString: dob);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('profile_dob', dob);
      prefs.setString('ur_heart_selected_dob', dob);
      if (age != null && age > 0) {
        prefs.setInt('profile_age', age);
        prefs.setInt('ur_heart_user_age', age);
      }
    });
  }

  void setGender(String gender) {
    state = state.copyWith(gender: gender);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('profile_gender', gender);
    });
  }

  void setBio(String bio) {
    state = state.copyWith(bio: bio);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('profile_bio', bio);
    });
  }

  void updateBio(String bio) => setBio(bio);

  void updateLocation(String location) {
    state = state.copyWith(location: location);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('profile_location', location);
    });
  }

  void setProfession(String prof) {
    state = state.copyWith(profession: prof);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('profile_profession', prof);
    });
  }

  void setEducation(String edu) {
    state = state.copyWith(education: edu);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('profile_education', edu);
    });
  }

  void setAgeRange(RangeValues range) {
    state = state.copyWith(minAge: range.start, maxAge: range.end);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble('profile_min_age', range.start);
      prefs.setDouble('profile_max_age', range.end);
    });
  }

  void toggleInterestedIn(String option) {
    final updated = Set<String>.from(state.interestedIn);
    if (updated.contains(option)) {
      if (updated.length > 1) updated.remove(option);
    } else {
      updated.add(option);
    }
    state = state.copyWith(interestedIn: updated);
  }

  void updateContactBridge({required String platform, required String handle}) {
    state = state.copyWith(
      contactBridgePlatform: platform,
      contactBridgeHandle: handle,
    );
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('profile_contact_bridge_platform', platform);
      prefs.setString('profile_contact_bridge_handle', handle);
    });
  }

  /// EVA AI Mindful Bio Refinement
  Future<String?> polishBioWithEvaAi([String? rawText]) async {
    state = state.copyWith(isPolishingBio: true);
    final target = (rawText != null && rawText.isNotEmpty) ? rawText : state.bio;
    final polished = await _repository.polishBioWithEvaAi(target);
    state = state.copyWith(bio: polished, isPolishingBio: false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_bio', polished);

    return polished;
  }

  /// Backward-compatible alias for existing tests
  Future<String?> polishBioWithGroq([String? rawText]) => polishBioWithEvaAi(rawText);

  /// 3-Second Live Selfie Video / Camera reflection evaluated by EVA AI
  Future<void> executeVideoKyc({
    required List<int> videoBytes,
    String userId = 'demo_user_1',
  }) async {
    final result = await _repository.submitVideoKyc(userId: userId, videoBytes: videoBytes);
    state = state.copyWith(
      isKycVerified: result.isApproved,
      isKycPendingReview: result.isPendingReview,
      kycStatusMessage: result.message,
    );

    if (result.isApproved) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('profile_is_kyc_verified', true);
    }
  }

  Future<bool> completeSetup() async {
    if (!state.canCompleteSetup) return false;
    state = state.copyWith(isSubmitting: true);

    final prefs = await SharedPreferences.getInstance();
    final interestedInStr = state.interestedIn.isNotEmpty
        ? state.interestedIn.join(', ')
        : 'Everyone';
    await prefs.setString('profile_interested_in', interestedInStr);
    await prefs.setString('profile_full_name', state.fullName);
    await prefs.setString('profile_gender', state.gender);
    await prefs.setString('profile_bio', state.bio);
    await prefs.setString('profile_profession', state.profession);
    await prefs.setString('profile_education', state.education);
    await prefs.setString('profile_location', state.location);
    await prefs.setString('profile_contact_bridge_platform', state.contactBridgePlatform);
    await prefs.setString('profile_contact_bridge_handle', state.contactBridgeHandle);
    await prefs.setBool('ur_heart_profile_setup_completed', true);

    final email = prefs.getString('ur_heart_user_email') ?? '';
    final lat = prefs.getDouble('profile_gps_latitude');
    final lng = prefs.getDouble('profile_gps_longitude');

    await ActivityLogger.log(
      category: 'PROFILE',
      action: 'PROFILE_SETUP_COMPLETED',
      screen: 'ProfileSetupScreen',
      details: {
        'name': state.fullName,
        'is_kyc': state.isKycVerified,
        'location': state.location,
        'is_gps_verified': state.isGpsVerified,
      },
    );

    final savedAge = prefs.getInt('profile_age') ?? prefs.getInt('ur_heart_user_age');
    final success = await _repository.saveUserProfile({
      'full_name': state.fullName,
      'gender': state.gender,
      'dob': state.dobString,
      'birth_date': state.dobString,
      if (savedAge != null && savedAge > 0) 'age': savedAge,
      'interested_in': interestedInStr,
      'bio': state.bio,
      'profession': state.profession,
      'education': state.education,
      'location': state.location,
      'location_name': state.location,
      'latitude': lat,
      'longitude': lng,
      'preferred_age_min': state.minAge.toInt(),
      'preferred_age_max': state.maxAge.toInt(),
      'contact_bridge_type': state.contactBridgePlatform,
      'contact_bridge_handle': state.contactBridgeHandle,
      'is_kyc_verified': state.isKycVerified,
      'photo_slots_count': state.photoSlots.length,
      'photos': [
        state.photoSlots[2] ?? '',
        state.photoSlots[3] ?? '',
        state.photoSlots[4] ?? '',
        state.photoSlots[5] ?? '',
      ],
      'avatar_url': state.photoSlots[1] ?? '',
      'email': email,
    });

    state = state.copyWith(isSubmitting: false);
    return success;
  }
}

final profileSetupControllerProvider =
    StateNotifierProvider<ProfileSetupController, ProfileSetupState>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return ProfileSetupController(repo);
});
