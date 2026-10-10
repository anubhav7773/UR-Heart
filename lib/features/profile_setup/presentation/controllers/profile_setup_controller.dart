import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/media/media_compressor.dart';
import '../../../../core/media/supabase_media_uploader.dart';
import '../../../../core/services/activity_logger_service.dart';
import '../../../../core/services/image_moderation_service.dart';
import '../../../../core/services/real_gps_location_service.dart';
import '../../../../core/storage/secure_session_storage.dart';
import '../../data/profile_repository.dart';
import '../../../profile/data/profile_repository.dart' as main_profile;

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
  final bool isGpsServiceDisabled;
  final bool isGpsPermissionDeniedForever;
  final String? voiceSparkUrl;
  final String? voiceSparkPrompt;
  final double voiceSparkDuration;
  final bool isPhotoVeiled;

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
    this.isGpsServiceDisabled = false,
    this.isGpsPermissionDeniedForever = false,
    this.voiceSparkUrl,
    this.voiceSparkPrompt,
    this.voiceSparkDuration = 0.0,
    this.isPhotoVeiled = false,
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
    bool? isGpsServiceDisabled,
    bool? isGpsPermissionDeniedForever,
    String? voiceSparkUrl,
    String? voiceSparkPrompt,
    double? voiceSparkDuration,
    bool? isPhotoVeiled,
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
      isGpsServiceDisabled: isGpsServiceDisabled ?? this.isGpsServiceDisabled,
      isGpsPermissionDeniedForever:
          isGpsPermissionDeniedForever ?? this.isGpsPermissionDeniedForever,
      voiceSparkUrl: voiceSparkUrl ?? this.voiceSparkUrl,
      voiceSparkPrompt: voiceSparkPrompt ?? this.voiceSparkPrompt,
      voiceSparkDuration: voiceSparkDuration ?? this.voiceSparkDuration,
      isPhotoVeiled: isPhotoVeiled ?? this.isPhotoVeiled,
    );
  }
}

class ProfileSetupController extends StateNotifier<ProfileSetupState> {
  final ProfileRepository _repository;

  ProfileSetupController(this._repository) : super(const ProfileSetupState()) {
    loadSavedProfile();
  }

  /// Completely resets ProfileSetupState to clean defaults
  void reset() {
    state = const ProfileSetupState();
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

      final secureUserId = await SecureSessionStorage.instance.getUserId();
      final currentUserId = secureUserId ?? prefs.getString('ur_heart_user_id');
      final storedProfileUserId = prefs.getString('profile_user_id');

      // Restore existing photos ONLY if authenticated user matches stored profile
      final bool isSameUser = (currentUserId != null &&
          currentUserId.isNotEmpty &&
          storedProfileUserId != null &&
          storedProfileUserId == currentUserId);

      final Map<int, String> restoredSlots = {};
      if (isSameUser) {
        for (int i = 1; i <= 5; i++) {
          final path = prefs.getString('profile_photo_slot_$i');
          if (path != null && path.trim().isNotEmpty) {
            restoredSlots[i] = path;
          }
        }
      } else if (storedProfileUserId != null && currentUserId != null) {
        // Defensive purge of lingering previous user's photo slots
        for (int i = 1; i <= 5; i++) {
          await prefs.remove('profile_photo_slot_$i');
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
        photoSlots: restoredSlots,
      );

      // Auto-trigger GPS acquisition if not yet verified
      if (!isGps) {
        fetchRealGpsLocation();
      }
    } catch (_) {}
  }

  /// Acquires authentic GPS coordinates with Patal-Lok subterranean resilience
  Future<String> fetchRealGpsLocation() async {
    if (state.isAcquiringGps) return state.location;

    state = state.copyWith(
      isAcquiringGps: true,
      gpsError: null,
      isGpsServiceDisabled: false,
      isGpsPermissionDeniedForever: false,
    );
    final result = await RealGpsLocationService.acquireRealHardwareGps();
    if (result.isSuccess) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_location', result.formattedLocation);
      await prefs.setDouble('profile_gps_latitude', result.latitude);
      await prefs.setDouble('profile_gps_longitude', result.longitude);
      await prefs.setDouble('profile_gps_accuracy', result.accuracyMeters);
      await prefs.setBool('profile_gps_verified', true);

      state = state.copyWith(
        location: result.formattedLocation,
        isGpsVerified: true,
        isAcquiringGps: false,
        gpsError: null,
        isGpsServiceDisabled: false,
        isGpsPermissionDeniedForever: false,
      );
      return result.formattedLocation;
    } else {
      state = state.copyWith(
        isGpsVerified: false,
        isAcquiringGps: false,
        gpsError: result.errorMessage ?? 'Unable to acquire genuine GPS',
        isGpsServiceDisabled: result.isServiceDisabled,
        isGpsPermissionDeniedForever: result.isPermissionDeniedForever,
      );
      return result.errorMessage ?? 'Unable to acquire genuine GPS';
    }
  }

  /// Direct link to device location settings if GPS is switched off
  Future<void> openLocationSettings() async {
    await RealGpsLocationService.openLocationSettings();
  }

  /// Direct link to app permission settings if location permission was permanently denied
  Future<void> openAppSettings() async {
    await RealGpsLocationService.openAppSettings();
  }

  Future<bool> processAndUploadBytes({
    required int slotNumber,
    required Uint8List rawBytes,
    String? localFallbackPath,
    String userId = 'demo_user_1',
  }) async {
    state = state.copyWith(isUploadingPhoto: true, lastModerationError: null);

    // 1. Strict Multi-Layer Content Moderation Gatekeeper
    final moderation = await ImageModerationService.inspectBytes(
      rawBytes,
      slotNumber: slotNumber,
    );

    if (!moderation.isSafe) {
      state = state.copyWith(
        isUploadingPhoto: false,
        lastModerationError: moderation.rejectionReason ??
            'Photo rejected: Contact information, phone numbers, or policy violations are strictly prohibited.',
      );
      return false;
    }

    try {
      final processed = await MediaCompressor.processPortraitBytes(rawBytes);
      final prefs = await SharedPreferences.getInstance();
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      final secureEmail = await SecureSessionStorage.instance.getUserEmail();
      final userEmail = prefs.getString('ur_heart_user_email') ?? secureEmail ?? (authUid != null ? 'uid_$authUid' : userId);
      final safeUserUuid = (authUid != null && authUid.isNotEmpty)
          ? authUid
          : userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      String finalUrl = localFallbackPath ?? '';
      if (processed != null) {
        try {
          final cloudUrl = await SupabaseMediaUploader.uploadProfileSlot(
            userUuid: safeUserUuid,
            slotNumber: slotNumber,
            webpBytes: processed.webpBytes,
            userName: state.fullName.isNotEmpty ? state.fullName : prefs.getString('profile_full_name'),
          );
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            finalUrl = cloudUrl;
          }
        } catch (_) {}
      }

      if (finalUrl.isNotEmpty) {
        await prefs.setString('profile_photo_slot_$slotNumber', finalUrl);
        final currentUid = await SecureSessionStorage.instance.getUserId() ??
            prefs.getString('ur_heart_user_id') ??
            authUid;
        if (currentUid != null && currentUid.isNotEmpty) {
          await prefs.setString('profile_user_id', currentUid);
        }

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
      }

      state = state.copyWith(isUploadingPhoto: false);
      return false;
    } catch (e) {
      state = state.copyWith(isUploadingPhoto: false);
      return false;
    }
  }

  Future<bool> processAndUploadPhoto({
    required int slotNumber,
    required dynamic rawFile,
    String userId = 'demo_user_1',
  }) async {
    try {
      final Uint8List bytes;
      final String localPath;
      if (rawFile is XFile) {
        bytes = await rawFile.readAsBytes();
        localPath = rawFile.path;
      } else if (rawFile is Uint8List) {
        bytes = rawFile;
        localPath = 'memory_slot_$slotNumber.jpg';
      } else {
        bytes = await (rawFile as dynamic).readAsBytes() as Uint8List;
        localPath = (rawFile as dynamic).path as String? ?? 'slot_$slotNumber.jpg';
      }
      return await processAndUploadBytes(
        slotNumber: slotNumber,
        rawBytes: bytes,
        localFallbackPath: localPath,
        userId: userId,
      );
    } catch (_) {
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

  /// Sets a single interested_in preference (radio-style single-select)
  void setInterestedIn(String option) {
    state = state.copyWith(interestedIn: {option});
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('profile_interested_in', option);
    });
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

  /// Live Photo Pose Selfie evaluated by EVA AI (Tinder/Bumble Industry Standard)
  Future<KycVerificationResult> executeSelfieKyc({
    required String selfieBase64,
    String? anchorPhotoB64,
    List<String>? profilePhotosB64,
    List<String>? profilePhotoUrls,
    String? expectedPose,
    String userId = 'me',
  }) async {
    final result = await _repository.submitSelfieKyc(
      userId: userId,
      selfieBase64: selfieBase64,
      anchorPhotoB64: anchorPhotoB64,
      profilePhotosB64: profilePhotosB64,
      profilePhotoUrls: profilePhotoUrls,
      expectedPose: expectedPose,
    );
    state = state.copyWith(
      isKycVerified: result.isApproved,
      isKycPendingReview: result.isPendingReview,
      kycStatusMessage: result.message,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_is_kyc_verified', result.isApproved);
    return result;
  }

  void setVoiceSpark({required String url, required String prompt, required double duration}) {
    state = state.copyWith(
      voiceSparkUrl: url,
      voiceSparkPrompt: prompt,
      voiceSparkDuration: duration,
    );
  }

  void clearVoiceSpark() {
    state = state.copyWith(
      voiceSparkUrl: '',
      voiceSparkPrompt: '',
      voiceSparkDuration: 0.0,
    );
  }

  void setPhotoVeil(bool val) {
    state = state.copyWith(isPhotoVeiled: val);
  }

  Future<bool> completeSetup() async {
    if (!state.canCompleteSetup) return false;
    state = state.copyWith(isSubmitting: true);

    final prefs = await SharedPreferences.getInstance();
    final interestedInStr = state.interestedIn.isNotEmpty
        ? state.interestedIn.first
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
    await prefs.setBool('profile_is_photo_veiled', state.isPhotoVeiled);
    if (state.voiceSparkUrl != null && state.voiceSparkUrl!.isNotEmpty) {
      await prefs.setString('profile_voice_spark_url', state.voiceSparkUrl!);
      await prefs.setString('profile_voice_spark_prompt', state.voiceSparkPrompt ?? '');
      await prefs.setDouble('profile_voice_spark_duration', state.voiceSparkDuration);
    }

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
        'is_photo_veiled': state.isPhotoVeiled,
        'has_voice_spark': state.voiceSparkUrl != null && state.voiceSparkUrl!.isNotEmpty,
      },
    );

    final savedAge = prefs.getInt('profile_age') ?? prefs.getInt('ur_heart_user_age');
    final success = await _repository.saveUserProfile({
      'full_name': state.fullName,
      'gender': state.gender,
      'dob': state.dobString,
      'birth_date': state.dobString,
      'date_of_birth': state.dobString,
      if (savedAge != null && savedAge > 0) 'age': savedAge,
      'interested_in': interestedInStr,
      'looking_for': interestedInStr,
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
      'bridge_platform': state.contactBridgePlatform,
      'contact_bridge_handle': state.contactBridgeHandle,
      'bridge_value': state.contactBridgeHandle,
      'is_kyc_verified': state.isKycVerified,
      'is_kyc': state.isKycVerified,
      'is_photo_veiled': state.isPhotoVeiled,
      'voice_spark_url': state.voiceSparkUrl,
      'voice_spark_prompt': state.voiceSparkPrompt,
      'voice_spark_duration': state.voiceSparkDuration,
      'is_voice_verified': state.voiceSparkUrl != null && state.voiceSparkUrl!.isNotEmpty,
      'photo_slots_count': state.photoSlots.length,
      'photos': [
        state.photoSlots[2] ?? '',
        state.photoSlots[3] ?? '',
        state.photoSlots[4] ?? '',
        state.photoSlots[5] ?? '',
      ],
      'avatar_url': state.photoSlots[1] ?? (state.photoSlots.values.isNotEmpty ? state.photoSlots.values.first : ''),
      'email': email,
    });

    if (success) {
      await prefs.setBool('ur_heart_profile_setup_completed', true);
      await prefs.setBool('ur_heart_has_entered_sanctuary', true);
      main_profile.ProfileRepository.prewarmStatic(prefs);
    } else {
      await prefs.setBool('ur_heart_profile_setup_completed', false);
    }

    state = state.copyWith(isSubmitting: false);
    return success;
  }
}

final profileSetupControllerProvider =
    StateNotifierProvider<ProfileSetupController, ProfileSetupState>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return ProfileSetupController(repo);
});
