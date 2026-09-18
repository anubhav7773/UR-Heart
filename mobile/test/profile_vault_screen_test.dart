import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur_heart/features/profile/data/profile_repository.dart';
import 'package:ur_heart/features/profile/presentation/profile_vault_screen.dart';

void main() {
  group('UserProfileData & Photo Slot Models', () {
    test('Correctly deserializes user profile JSON with 5 photo slots', () {
      final json = {
        'id': 'u1-test-id-1234',
        'full_name': 'Aman Gupta',
        'phone_number': '+919876543210',
        'city': 'Lucknow',
        'bio': 'Software Engineer & Musician',
        'streak_count': 14,
        'reward_balance': 450,
        'kyc_status': true,
        'photos': [
          {
            'slot_index': 1,
            'photo_url': 'https://pzrsyxvjbmzqlzlehuxg.supabase.co/storage/v1/object/public/user-photos/u1/slot_1.webp',
            'blur_hash': 'LEHLh[WB2yk8pyoJadR*.7kCMdnj',
          },
          {
            'slot_index': 2,
            'photo_url': 'https://pzrsyxvjbmzqlzlehuxg.supabase.co/storage/v1/object/public/user-photos/u1/slot_2.webp',
            'blur_hash': 'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
          },
        ],
      };

      final profile = UserProfileData.fromJson(json);

      expect(profile.id, equals('u1-test-id-1234'));
      expect(profile.fullName, equals('Aman Gupta'));
      expect(profile.city, equals('Lucknow'));
      expect(profile.streakCount, equals(14));
      expect(profile.rewardBalance, equals(450));
      expect(profile.kycStatus, isTrue);
      expect(profile.photos.length, equals(2));
      expect(profile.photos[0].slotIndex, equals(1));
      expect(profile.photos[0].photoUrl, contains('slot_1.webp'));
      expect(profile.photos[0].blurHash, equals('LEHLh[WB2yk8pyoJadR*.7kCMdnj'));
      expect(profile.photos[1].slotIndex, equals(2));
    });
  });

  group('ProfileVaultScreen UI Widget Rendering', () {
    testWidgets('Renders profile screen, user details, and 5-slot photo grid', (WidgetTester tester) async {
      final mockProfile = UserProfileData(
        id: 'test-user-id-123',
        fullName: 'Aman Gupta',
        phoneNumber: '+919876543210',
        city: 'Lucknow',
        bio: 'Software Engineer',
        streakCount: 7,
        rewardBalance: 200,
        kycStatus: true,
        photos: [], // Empty photos to test default avatar and slot placeholders
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileVaultScreen(
            initialProfile: mockProfile,
          ),
        ),
      );

      expect(find.text('Profile & Security Vault'), findsOneWidget);
      expect(find.text('Aman Gupta'), findsOneWidget);
      expect(find.text('Lucknow'), findsOneWidget);
      expect(find.text('Edit Profile & 5 Photos'), findsOneWidget);
      expect(find.text('Photos & KYC Slots (0/5)'), findsOneWidget);
      expect(find.text('Hero'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('#5'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget); // KYC verified badge
    });
  });
}
