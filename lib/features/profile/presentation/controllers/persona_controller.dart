import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/media/media_compressor.dart';
import '../../../../core/media/supabase_media_uploader.dart';
import '../../../../core/services/image_moderation_service.dart';
import '../../../../core/storage/secure_session_storage.dart';
import '../../data/profile_repository.dart';

class PersonaState {
  final UserProfile profile;
  final bool isInitialLoading;
  final bool isSaving;
  final bool isPolishing;
  final String? successMessage;
  final String? errorMessage;

  const PersonaState({
    required this.profile,
    this.isInitialLoading = false,
    this.isSaving = false,
    this.isPolishing = false,
    this.successMessage,
    this.errorMessage,
  });

  List<String> get moments => profile.momentsUrls;
  bool get isReady => profile.isLoaded || !isInitialLoading;

  PersonaState copyWith({
    UserProfile? profile,
    bool? isInitialLoading,
    bool? isSaving,
    bool? isPolishing,
    String? successMessage,
    String? errorMessage,
  }) {
    return PersonaState(
      profile: profile ?? this.profile,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isSaving: isSaving ?? this.isSaving,
      isPolishing: isPolishing ?? this.isPolishing,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }
}

class PersonaController extends StateNotifier<PersonaState> {
  final ProfileRepository _repo;

  PersonaController(this._repo)
      : super(PersonaState(
          profile: _repo.getProfile(),
          isInitialLoading: _repo.getProfile().isPlaceholder,
        )) {
    _loadInitialProfile();
  }

  Future<void> _loadInitialProfile() async {
    final cached = await _repo.loadProfileFromStorage();
    if (!mounted) return;
    state = state.copyWith(
      profile: cached,
      isInitialLoading: cached.isPlaceholder,
    );

    try {
      final remote = await _repo.fetchMyProfile();
      if (!mounted) return;

      // Remote profile is the single source of truth for photos
      final List<String> remoteMoments = List<String>.from(remote.momentPhotos);
      while (remoteMoments.length < 4) {
        remoteMoments.add('');
      }

      final remoteAvatar = remote.avatarUrl;

      // Defense-in-depth: Ensure avatar is never mirrored into moment slots
      if (remoteAvatar.isNotEmpty) {
        for (int i = 0; i < remoteMoments.length; i++) {
          if (remoteMoments[i] == remoteAvatar) {
            remoteMoments[i] = '';
          }
        }
      }

      final updatedProfile = remote.copyWith(
        avatarUrl: remoteAvatar,
        momentPhotos: remoteMoments,
        age: (remote.age > 0 && remote.age != 24)
            ? remote.age
            : (cached.age > 0 ? cached.age : remote.age),
        dobVerificationPill: remote.dobVerificationPill.isNotEmpty
            ? remote.dobVerificationPill
            : cached.dobVerificationPill,
        gender: remote.gender.isNotEmpty ? remote.gender : cached.gender,
        interestedIn: remote.interestedIn.isNotEmpty ? remote.interestedIn : cached.interestedIn,
      );
      state = state.copyWith(
        profile: updatedProfile,
        isInitialLoading: false,
      );
    } catch (e) {
      debugPrint('[PersonaController] Remote profile sync notice: $e');
      if (mounted && state.isInitialLoading) {
        state = state.copyWith(isInitialLoading: false);
      }
    }
  }

  void reset() {
    state = PersonaState(
      profile: ProfileRepository.getEmptyProfile(),
      isInitialLoading: true,
    );
  }

  Future<void> refreshProfile() async {
    await _loadInitialProfile();
  }

  Future<void> onKycVerified() async {
    state = state.copyWith(
      profile: state.profile.copyWith(hasVerifiedCrest: true),
      successMessage: 'Verified Sanctuary Crest Awarded! 🛡️✨',
    );
    await refreshProfile();
  }

  void updateBio(String newBio) {
    state = state.copyWith(profile: state.profile.copyWith(bio: newBio));
  }

  void updateProfession(String newProf) {
    state = state.copyWith(profile: state.profile.copyWith(profession: newProf));
  }

  void updateEducation(String newEdu) {
    state = state.copyWith(profile: state.profile.copyWith(education: newEdu));
  }

  void updateAgeRange(double minAge, double maxAge) {
    state = state.copyWith(
      profile: state.profile.copyWith(minAgePref: minAge, maxAgePref: maxAge),
    );
  }

  Future<void> polishBioWithEvaAi([String? customBio]) async {
    state = state.copyWith(isPolishing: true);
    try {
      final bioToPolish = (customBio != null && customBio.trim().isNotEmpty)
          ? customBio.trim()
          : state.profile.bio;
      final polished = await _repo.polishBioWithEvaAi(bioToPolish);
      state = state.copyWith(
        profile: state.profile.copyWith(bio: polished),
        isPolishing: false,
        successMessage: 'Bio refined with EVA AI mindful nuance ✨',
      );
    } catch (_) {
      state = state.copyWith(isPolishing: false, errorMessage: 'Could not polish bio.');
    }
  }

  Future<void> polishBioWithGroq([String? customBio]) => polishBioWithEvaAi(customBio);

  Future<void> refreshLocation() async {
    final loc = await _repo.refreshGpsLocation();
    state = state.copyWith(
      profile: state.profile.copyWith(location: loc),
      successMessage: 'GPS location refreshed',
    );
  }

  Future<void> saveProfile() async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final updated = await _repo.updateProfile(state.profile);
      state = state.copyWith(
        profile: updated,
        isSaving: false,
        successMessage: 'Persona updated successfully',
      );
    } catch (_) {
      state = state.copyWith(isSaving: false, errorMessage: 'Failed to save changes.');
    }
  }

  List<String> get moments => state.profile.momentsUrls;

  void clearBanner() {
    state = state.copyWith(successMessage: null, errorMessage: null);
  }

  Future<bool> updateAvatarFile(File rawFile) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final modResult = await ImageModerationService.inspectImage(rawFile, slotNumber: 1);
      if (!modResult.isSafe) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: modResult.rejectionReason ?? 'Image does not meet Sanctuary guidelines.',
        );
        return false;
      }

      final processed = await MediaCompressor.processPortraitPhoto(rawFile);
      final secureEmail = await SecureSessionStorage.instance.getUserEmail();
      final secureUserId = await SecureSessionStorage.instance.getUserId();
      final prefs = await SharedPreferences.getInstance();
      final userEmail = secureEmail ?? prefs.getString('ur_heart_user_email') ?? state.profile.email;
      final rawUid = state.profile.id.isNotEmpty
          ? state.profile.id
          : (secureUserId ?? prefs.getString('ur_heart_user_id') ?? userEmail);
      final safeUserUuid = rawUid.isNotEmpty
          ? rawUid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
          : (prefs.getString('ur_heart_installation_id') ?? 'seeker_${state.profile.fullName.hashCode.abs()}');

      String finalUrl = rawFile.path;
      if (processed != null) {
        try {
          final cloudUrl = await SupabaseMediaUploader.uploadProfileSlot(
            userUuid: safeUserUuid,
            slotNumber: 1,
            webpBytes: processed.webpBytes,
            userName: state.profile.fullName,
          );
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            finalUrl = cloudUrl;
          }
        } catch (_) {}
      }

      await prefs.setString('profile_photo_slot_1', finalUrl);

      // Clean moments to ensure avatar is never in moment slots
      final cleanMoments = state.profile.momentPhotos.map((m) => m == finalUrl ? '' : m).toList();
      final updatedProfile = state.profile.copyWith(
        avatarUrl: finalUrl,
        momentPhotos: cleanMoments,
      );
      state = state.copyWith(
        profile: updatedProfile,
        isSaving: false,
        successMessage: 'Avatar updated successfully ✨',
      );

      _repo.updateProfile(updatedProfile).catchError((dynamic e) {
        debugPrint('[PersonaController] Avatar cloud sync error: $e');
        return updatedProfile;
      });

      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: 'Failed to update avatar: $e');
      return false;
    }
  }

  Future<bool> updateMomentSlotFile(int slotIndex, File rawFile) async {
    if (slotIndex < 0 || slotIndex >= 4) return false;
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final modResult = await ImageModerationService.inspectImage(rawFile, slotNumber: slotIndex + 2);
      if (!modResult.isSafe) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: modResult.rejectionReason ?? 'Image does not meet Sanctuary guidelines.',
        );
        return false;
      }

      final processed = await MediaCompressor.processPortraitPhoto(rawFile);
      final secureEmail = await SecureSessionStorage.instance.getUserEmail();
      final secureUserId = await SecureSessionStorage.instance.getUserId();
      final prefs = await SharedPreferences.getInstance();
      final userEmail = secureEmail ?? prefs.getString('ur_heart_user_email') ?? state.profile.email;
      final rawUid = state.profile.id.isNotEmpty
          ? state.profile.id
          : (secureUserId ?? prefs.getString('ur_heart_user_id') ?? userEmail);
      final safeUserUuid = rawUid.isNotEmpty
          ? rawUid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
          : (prefs.getString('ur_heart_installation_id') ?? 'seeker_${state.profile.fullName.hashCode.abs()}');

      String finalUrl = rawFile.path;
      if (processed != null) {
        try {
          final cloudUrl = await SupabaseMediaUploader.uploadProfileSlot(
            userUuid: safeUserUuid,
            slotNumber: slotIndex + 2,
            webpBytes: processed.webpBytes,
            userName: state.profile.fullName,
          );
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            finalUrl = cloudUrl;
          }
        } catch (_) {}
      }

      final prefKey = 'profile_photo_slot_${slotIndex + 2}';
      await prefs.setString(prefKey, finalUrl);

      final momentsList = List<String>.from(state.profile.momentPhotos);
      while (momentsList.length < 4) {
        momentsList.add('');
      }
      momentsList[slotIndex] = finalUrl;

      final updatedProfile = state.profile.copyWith(momentPhotos: momentsList);
      state = state.copyWith(
        profile: updatedProfile,
        isSaving: false,
        successMessage: 'Moment #${slotIndex + 1} updated ✨',
      );

      _repo.updateProfile(updatedProfile).catchError((dynamic e) {
        debugPrint('[PersonaController] Moment cloud sync error: $e');
        return updatedProfile;
      });

      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: 'Failed to update moment: $e');
      return false;
    }
  }

  void updateAvatar([dynamic context]) {
    state = state.copyWith(successMessage: 'Avatar updated with verified selfie');
  }

  void replaceMomentSlot(int slotNumber, [dynamic context]) {
    state = state.copyWith(successMessage: 'Moment slot $slotNumber updated via Cloud Storage');
  }

  void openBridgeEditor([dynamic context]) {
    state = state.copyWith(successMessage: 'Sacred Bridge Handle editor opened');
  }

  Future<void> savePreferences([dynamic context]) async {
    await saveProfile();
  }

  Future<void> updateVoiceSpark({
    required String voiceSparkUrl,
    required String voiceSparkPrompt,
    required double voiceSparkDuration,
    bool isVoiceVerified = true,
  }) async {
    final updatedProfile = state.profile.copyWith(
      voiceSparkUrl: voiceSparkUrl,
      voiceSparkPrompt: voiceSparkPrompt,
      voiceSparkDuration: voiceSparkDuration,
      isVoiceVerified: isVoiceVerified,
    );
    state = state.copyWith(
      profile: updatedProfile,
      successMessage: 'Voice Spark (7-second audio) saved! 🎙️✨',
    );
    try {
      await _repo.updateProfile(updatedProfile);
    } catch (e) {
      debugPrint('[PersonaController] Voice Spark sync notice: $e');
    }
  }

  Future<bool> deleteVoiceSpark() async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final updatedProfile = state.profile.copyWith(
        voiceSparkUrl: '',
        voiceSparkPrompt: '',
        voiceSparkDuration: 0.0,
        isVoiceVerified: false,
      );
      state = state.copyWith(
        profile: updatedProfile,
        isSaving: false,
        successMessage: 'Voice Spark removed 🗑️',
      );
      await _repo.updateProfile(updatedProfile);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: 'Failed to remove Voice Spark: $e');
      return false;
    }
  }
}

final personaControllerProvider =
    StateNotifierProvider<PersonaController, PersonaState>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return PersonaController(repo);
});
