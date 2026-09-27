import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/media/media_compressor.dart';
import '../../../../core/media/firebase_media_uploader.dart';
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

  const ProfileSetupState({
    this.photoSlots = const {},
    this.blurHashes = const {},
    this.fullName = '',
    this.dobString = '14 Oct 2002',
    this.gender = 'Woman',
    this.interestedIn = const {'Men'},
    this.location = 'Bandra West, Mumbai',
    this.bio = '',
    this.profession = 'Architect',
    this.education = 'National Institute of Design',
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
  });

  bool get isBioPolishing => isPolishingBio;
  bool get hasPrimaryAnchorPhoto => photoSlots.containsKey(1);
  bool get canCompleteSetup => hasPrimaryAnchorPhoto && fullName.trim().isNotEmpty;

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
      contactBridgePlatform: contactBridgePlatform ?? this.contactBridgePlatform,
      contactBridgeHandle: contactBridgeHandle ?? this.contactBridgeHandle,
      isKycVerified: isKycVerified ?? this.isKycVerified,
      isKycPendingReview: isKycPendingReview ?? this.isKycPendingReview,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      isPolishingBio: isPolishingBio ?? this.isPolishingBio,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      kycStatusMessage: kycStatusMessage ?? this.kycStatusMessage,
    );
  }
}

class ProfileSetupController extends StateNotifier<ProfileSetupState> {
  final ProfileRepository _repository;

  ProfileSetupController(this._repository) : super(const ProfileSetupState());

  Future<bool> processAndUploadPhoto({
    required int slotNumber,
    required File rawFile,
    String userId = 'demo_user_1',
  }) async {
    state = state.copyWith(isUploadingPhoto: true);

    final processed = await MediaCompressor.processPortraitPhoto(rawFile);
    if (processed == null) {
      state = state.copyWith(isUploadingPhoto: false);
      return false;
    }

    await FirebaseMediaUploader.uploadProfileSlot(
      userUuid: userId,
      slotNumber: slotNumber,
      webpBytes: processed.webpBytes,
    );

    final updatedSlots = Map<int, String>.from(state.photoSlots);
    updatedSlots[slotNumber] = rawFile.path;

    final updatedBlurHashes = Map<int, String>.from(state.blurHashes);
    updatedBlurHashes[slotNumber] = processed.blurHash;

    state = state.copyWith(
      photoSlots: updatedSlots,
      blurHashes: updatedBlurHashes,
      isUploadingPhoto: false,
    );
    return true;
  }

  void setFullName(String name) => state = state.copyWith(fullName: name);
  void setGender(String gender) => state = state.copyWith(gender: gender);
  void setBio(String bio) => state = state.copyWith(bio: bio);
  void updateBio(String bio) => setBio(bio);
  void updateLocation(String location) => state = state.copyWith(location: location);
  void setProfession(String prof) => state = state.copyWith(profession: prof);
  void setEducation(String edu) => state = state.copyWith(education: edu);
  void setAgeRange(RangeValues range) => state = state.copyWith(minAge: range.start, maxAge: range.end);

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
    state = state.copyWith(contactBridgePlatform: platform, contactBridgeHandle: handle);
  }

  Future<String?> polishBioWithGroq([String? rawText]) async {
    state = state.copyWith(isPolishingBio: true);
    final target = (rawText != null && rawText.isNotEmpty) ? rawText : state.bio;
    final polished = await _repository.polishBioWithGroq(target);
    state = state.copyWith(bio: polished, isPolishingBio: false);
    return polished;
  }

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
  }

  Future<bool> completeSetup() async {
    if (!state.canCompleteSetup) return false;
    state = state.copyWith(isSubmitting: true);
    final success = await _repository.saveUserProfile({
      'full_name': state.fullName,
      'gender': state.gender,
      'bio': state.bio,
      'profession': state.profession,
      'education': state.education,
      'location': state.location,
      'contact_bridge_type': state.contactBridgePlatform,
      'contact_bridge_handle': state.contactBridgeHandle,
      'is_kyc_verified': state.isKycVerified,
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
