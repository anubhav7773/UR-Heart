import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> sendFeedbackEmail({String? userId, String? appVersion}) async {
  String resolvedVersion = appVersion ?? '';
  if (resolvedVersion.isEmpty) {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      resolvedVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {
      resolvedVersion = 'v1.1.0';
    }
  }

  const String developerEmail = 'kshtriyaanubhav9120@gmail.com';
  const String subject = 'RuralHeart App — Feature Suggestion / Feedback';
  final String body = '''
Hi Anubhav,

Here is my feedback / suggestion for the app:
[Write your suggestion or issue here]

------------------------------
Device Info:
- App Version: $resolvedVersion
- User ID: ${userId ?? 'N/A'}
------------------------------
''';

  final Uri emailLaunchUri = Uri(
    scheme: 'mailto',
    path: developerEmail,
    queryParameters: {
      'subject': subject,
      'body': body,
    },
  );

  try {
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback direct url launch
      final fallbackUri = Uri.parse(
        'mailto:$developerEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    if (kDebugMode) {
      print('Could not launch email client: $e');
    }
  }
}
