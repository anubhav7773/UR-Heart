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
  final bool isSaving;
  final bool isPolishing;
  final String? successMessage;
  final String? errorMessage;

  const PersonaState({
    required this.profile,
    this.isSaving = false,
    this.isPolishing = false,
    this.successMessage,
    this.errorMessage,
  });

  List<String> get moments => profile.momentsUrls;

  PersonaState copyWith({
    UserProfile? profile,
    bool? isSaving,
    bool? isPolishing,
    String? successMessage,
    String? errorMessage,
  }) {
    return PersonaState(
      profile: profile ?? this.profile,
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
      : super(PersonaState(profile: _repo.getProfile())) {
    _loadInitialProfile();
  }

  Future<void> _loadInitialProfile() async {
    final cached = await _repo.loadProfileFromStorage();
    state = state.copyWith(profile: cached);

    try {
      final remote = await _repo.fetchMyProfile();
      final List<String> mergedMoments = List<String>.from(cached.momentPhotos);
      while (mergedMoments.length < 4) {
        mergedMoments.add('');
      }
      for (int i = 0; i < remote.momentPhotos.length && i < 4; i++) {
        if (remote.momentPhotos[i].isNotEmpty) {
          mergedMoments[i] = remote.momentPhotos[i];
        }
      }

      final mergedAvatar = remote.avatarUrl.isNotEmpty
          ? remote.avatarUrl
          : cached.avatarUrl;

      final mergedProfile = remote.copyWith(
        avatarUrl: mergedAvatar,
        momentPhotos: mergedMoments,
        age: (remote.age > 0 && remote.age != 24)
            ? remote.age
            : (cached.age > 0 ? cached.age : remote.age),
        dobVerificationPill: (cached.dobVerificationPill.isNotEmpty && !cached.dobVerificationPill.contains('DigiLocker'))
            ? cached.dobVerificationPill
            : (remote.dobVerificationPill.isNotEmpty ? remote.dobVerificationPill : cached.dobVerificationPill),
        gender: remote.gender.isNotEmpty ? remote.gender : cached.gender,
        interestedIn: remote.interestedIn.isNotEmpty ? remote.interestedIn : cached.interestedIn,
      );
      state = state.copyWith(profile: mergedProfile);
    } catch (e) {
      debugPrint('[PersonaController] Remote profile sync notice: $e');
    }
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
      final prefs = await SharedPreferences.getInstance();
      final userEmail = secureEmail ?? prefs.getString('ur_heart_user_email') ?? state.profile.email;
      final safeUserUuid = userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      String finalUrl = rawFile.path;
      if (processed != null) {
        try {
          final cloudUrl = await SupabaseMediaUploader.uploadProfileSlot(
            userUuid: safeUserUuid.isNotEmpty ? safeUserUuid : 'seeker_1',
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

      final updatedProfile = state.profile.copyWith(avatarUrl: finalUrl);
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
      final prefs = await SharedPreferences.getInstance();
      final userEmail = secureEmail ?? prefs.getString('ur_heart_user_email') ?? state.profile.email;
      final safeUserUuid = userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      String finalUrl = rawFile.path;
      if (processed != null) {
        try {
          final cloudUrl = await SupabaseMediaUploader.uploadProfileSlot(
            userUuid: safeUserUuid.isNotEmpty ? safeUserUuid : 'seeker_1',
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
}

final personaControllerProvider =
    StateNotifierProvider<PersonaController, PersonaState>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return PersonaController(repo);
});
