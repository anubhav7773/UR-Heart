import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ConsentManager {
  ConsentManager._internal();
  static final ConsentManager instance = ConsentManager._internal();

  bool _isMobileAdsInitialized = false;

  /// Requests Google UMP consent info update and presents the consent form if required.
  Future<void> gatherConsent({
    required VoidCallback onConsentGathered,
  }) async {
    final ConsentRequestParameters params = ConsentRequestParameters(
      // In development/test mode, uncomment to test European Economic Area (EEA) / GDPR simulation
      // consentDebugSettings: ConsentDebugSettings(
      //   debugGeography: DebugGeography.debugGeographyEea,
      //   testIdentifiers: ['YOUR_TEST_DEVICE_ID'],
      // ),
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        // Check if consent form is required
        ConsentForm.loadAndShowConsentFormIfRequired(
          (formError) async {
            if (formError != null) {
              debugPrint("⚠️ [UMP Consent] Form error: ${formError.message}");
            }
            await _initializeAdsIfPermitted();
            onConsentGathered();
          },
        );
      },
      (formError) async {
        debugPrint("⚠️ [UMP Consent] Info update failed: ${formError.message}");
        await _initializeAdsIfPermitted();
        onConsentGathered();
      },
    );
  }

  /// Initializes MobileAds SDK only after user consent is verified
  Future<void> _initializeAdsIfPermitted() async {
    final canRequest = await ConsentInformation.instance.canRequestAds();
    if (canRequest && !_isMobileAdsInitialized) {
      await MobileAds.instance.initialize();
      _isMobileAdsInitialized = true;
      debugPrint("✓ [AdMob] MobileAds initialized following Google UMP consent approval.");
    } else {
      debugPrint("ℹ️ [AdMob] Ads not requested or initialization deferred (canRequestAds: $canRequest).");
    }
  }

  /// Checks whether ads can be requested currently
  Future<bool> canRequestAds() async {
    return await ConsentInformation.instance.canRequestAds();
  }

  /// Allows user to modify or revoke consent from Profile Settings
  Future<void> showPrivacyOptionsForm(BuildContext context) async {
    ConsentForm.showPrivacyOptionsForm((formError) {
      if (formError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unable to open consent settings: ${formError.message}"),
            backgroundColor: const Color(0xFFFF334B),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✓ Ad preferences updated successfully."),
            backgroundColor: Color(0xFF06D6A0),
          ),
        );
      }
    });
  }
}
