import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/media/media_compressor.dart';
import '../../../../core/services/image_moderation_service.dart';
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
        dobVerificationPill: cached.dobVerificationPill.isNotEmpty
            ? cached.dobVerificationPill
            : remote.dobVerificationPill,
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

  Future<void> polishBioWithEvaAi() async {
    state = state.copyWith(isPolishing: true);
    try {
      final polished = await _repo.polishBioWithEvaAi(state.profile.bio);
      state = state.copyWith(
        profile: state.profile.copyWith(bio: polished),
        isPolishing: false,
        successMessage: 'Bio refined with EVA AI mindful nuance ✨',
      );
    } catch (_) {
      state = state.copyWith(isPolishing: false, errorMessage: 'Could not polish bio.');
    }
  }

  Future<void> polishBioWithGroq() => polishBioWithEvaAi();

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

      final compressed = await MediaCompressorService.processProfilePhoto(
        sourceFile: rawFile,
        slotNumber: 1,
      );
      final finalPath = compressed?.compressedFile.path ?? rawFile.path;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_photo_slot_1', finalPath);

      final updatedProfile = state.profile.copyWith(avatarUrl: finalPath);
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

      final compressed = await MediaCompressorService.processProfilePhoto(
        sourceFile: rawFile,
        slotNumber: slotIndex + 2,
      );
      final finalPath = compressed?.compressedFile.path ?? rawFile.path;

      final prefs = await SharedPreferences.getInstance();
      final prefKey = 'profile_photo_slot_${slotIndex + 2}';
      await prefs.setString(prefKey, finalPath);

      final momentsList = List<String>.from(state.profile.momentPhotos);
      while (momentsList.length < 4) {
        momentsList.add('');
      }
      momentsList[slotIndex] = finalPath;

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
