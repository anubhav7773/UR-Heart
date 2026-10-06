import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/feed/domain/candidate_profile.dart';
import 'package:ur_heart/features/feed/presentation/widgets/voice_spark_pill.dart';
import 'package:ur_heart/features/profile/domain/user_profile_model.dart';
import 'package:ur_heart/features/profile/presentation/widgets/voice_spark_recording_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Voice Spark Domain Model Integrity Tests', () {
    test('UserProfileModel retains voice spark fields in constructor and copyWith', () {
      const profile = UserProfile(
        id: 'user_voice_1',
        fullName: 'Aarav Sharma',
        email: 'aarav@urheart.app',
        age: 25,
        dobVerificationPill: '10 Jan 1999',
        gender: 'Man',
        interestedIn: 'Women',
        maskedWhatsApp: '',
        memberSinceText: 'Member',
        hasVerifiedCrest: true,
        location: 'Saket, New Delhi',
        bio: 'Mindful seeker',
        profession: 'Architect',
        education: 'B.Arch',
        minAgePref: 20,
        maxAgePref: 30,
        avatarUrl: 'https://cdn.example.com/avatar.webp',
        momentPhotos: [],
        voiceSparkUrl: 'https://supabase.co/storage/v1/voice/aarav.m4a',
        voiceSparkPrompt: 'My favourite midnight snack...',
        voiceSparkDuration: 6.8,
        isVoiceVerified: true,
      );

      expect(profile.voiceSparkUrl, 'https://supabase.co/storage/v1/voice/aarav.m4a');
      expect(profile.voiceSparkPrompt, 'My favourite midnight snack...');
      expect(profile.voiceSparkDuration, 6.8);
      expect(profile.isVoiceVerified, true);

      final updated = profile.copyWith(
        voiceSparkPrompt: 'What brings me instant peace...',
        voiceSparkDuration: 7.0,
      );
      expect(updated.voiceSparkPrompt, 'What brings me instant peace...');
      expect(updated.voiceSparkDuration, 7.0);
      expect(updated.voiceSparkUrl, 'https://supabase.co/storage/v1/voice/aarav.m4a');
    });

    test('UserProfileModel.fromJson and toJson round-trip preserves voice spark fields', () {
      final json = {
        'id': 'user_voice_2',
        'full_name': 'Meera Sen',
        'email': 'meera@urheart.app',
        'voice_spark_url': 'https://supabase.co/storage/v1/voice/meera.m4a',
        'voice_spark_prompt': 'A song that describes my energy...',
        'voice_spark_duration': 6.5,
        'is_voice_verified': true,
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.voiceSparkUrl, 'https://supabase.co/storage/v1/voice/meera.m4a');
      expect(profile.voiceSparkPrompt, 'A song that describes my energy...');
      expect(profile.voiceSparkDuration, 6.5);
      expect(profile.isVoiceVerified, true);

      final serialized = profile.toJson();
      expect(serialized['voice_spark_url'], 'https://supabase.co/storage/v1/voice/meera.m4a');
      expect(serialized['voice_spark_prompt'], 'A song that describes my energy...');
      expect(serialized['voice_spark_duration'], 6.5);
      expect(serialized['is_voice_verified'], true);
    });

    test('CandidateProfile retains voice spark fields and serializes cleanly', () {
      const candidate = CandidateProfile(
        id: 'candidate_voice_1',
        fullName: 'Rohan Mehra',
        age: 26,
        gender: 'Man',
        lookingFor: 'Women',
        locationName: 'Bandra, Mumbai',
        distanceKm: 4.2,
        resonanceScore: 88,
        intentQuote: 'Analog coffee lover.',
        interests: ['Coffee', 'Design'],
        photoUrls: ['https://cdn.example.com/rohan1.webp'],
        blurHashes: ['L6PZfSi_.AyE_3t7t7R**0o#DgR4'],
        voiceSparkUrl: 'https://supabase.co/storage/v1/voice/rohan.m4a',
        voiceSparkPrompt: 'A question I love answering...',
        voiceSparkDuration: 7.0,
        isVoiceVerified: true,
      );

      expect(candidate.voiceSparkUrl, 'https://supabase.co/storage/v1/voice/rohan.m4a');
      expect(candidate.voiceSparkPrompt, 'A question I love answering...');
      expect(candidate.voiceSparkDuration, 7.0);
      expect(candidate.isVoiceVerified, true);

      final map = candidate.toMap();
      expect(map['voice_spark_url'], 'https://supabase.co/storage/v1/voice/rohan.m4a');
      expect(map['voice_spark_prompt'], 'A question I love answering...');
      expect(map['voice_spark_duration'], 7.0);
      expect(map['is_voice_verified'], true);

      final deserialized = CandidateProfile.fromJson(map);
      expect(deserialized.voiceSparkUrl, candidate.voiceSparkUrl);
      expect(deserialized.voiceSparkPrompt, candidate.voiceSparkPrompt);
      expect(deserialized.voiceSparkDuration, candidate.voiceSparkDuration);
      expect(deserialized.isVoiceVerified, true);
    });
  });

  group('VoiceSparkPill Widget Unit Tests', () {
    testWidgets('VoiceSparkPill displays prompt and formatted duration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceSparkPill(
              voiceUrl: 'https://supabase.co/storage/v1/voice/sample.m4a',
              prompt: 'My secret recipe for a bad day...',
              duration: 7.0,
              isDark: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('My secret recipe for a bad day...'), findsOneWidget);
      expect(find.text('7s'), findsOneWidget);
      expect(find.text('VOICE SPARK'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });
  });

  group('VoiceSparkRecordingModal Widget Unit Tests', () {
    testWidgets('VoiceSparkRecordingModal renders prompts and handles prompt selection', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VoiceSparkRecordingModal(
                initialPrompt: 'Sunday morning par meri ideal vibe...',
                onRecorded: (file, duration, prompt) async {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('7-Second Voice Spark'), findsOneWidget);
      expect(find.text('Awaaz jhooth nahi bolti · Pure authenticity'), findsOneWidget);
      expect(find.text('CHOOSE A PROMPT TO ANSWER:'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.text('Tap to record (Max 7.0s)'), findsOneWidget);

      // Selected initial prompt is rendered in the prompt banner
      expect(find.text('Sunday morning par meri ideal vibe...'), findsWidgets);
    });
  });
}
