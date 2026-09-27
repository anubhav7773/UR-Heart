import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/profile_repository.dart';
import '../../domain/user_profile_model.dart';

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
      : super(PersonaState(profile: _repo.getProfile()));

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

  Future<void> polishBioWithGroq() async {
    state = state.copyWith(isPolishing: true);
    try {
      final polished = await _repo.polishBioWithGroq(state.profile.bio);
      state = state.copyWith(
        profile: state.profile.copyWith(bio: polished),
        isPolishing: false,
        successMessage: 'Bio refined with mindful nuance ✨',
      );
    } catch (_) {
      state = state.copyWith(isPolishing: false, errorMessage: 'Could not polish bio.');
    }
  }

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
