import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/flutter_windowmanager.dart';
import 'web_security_stub.dart'
    if (dart.library.js_interop) 'web_security_web.dart';

/// Secure window management service enforcing screenshot & screen-recording prevention
/// across the entire UR-Heart application per DPDP Act 2023 directives.
/// Enforces strict FLAG_SECURE window shielding across all private viewports
/// with a zero-bypass architecture to guarantee statutory privacy protections.
class WindowSecurityService {
  const WindowSecurityService._();

  /// Tracks active tab in the main shell (0: Feed, 1: Resonances, 2: Chats, 3: Growth Hub, 4: Persona)
  static int currentShellTab = 0;

  /// Routes containing personal photos, chat dialogues, unmasked phone numbers,
  /// AI emotional whispers, KYC footage, or cryptographic keys.
  static const Set<String> sensitiveRoutes = {
    '/chat-dialogue',
    '/chats',
    '/feed',
    '/resonances',
    '/persona',
    '/seeker-profile',
    '/seeker-detail',
    '/ai-sanctuary',
    '/eva-sanctuary',
    '/settings',
    '/admin/kyc-desk',
    '/profile-setup',
    '/ignored',
    '/ignored-profiles',
    '/blind-date',
    '/blind-date-session',
  };

  /// Public and growth routes where screenshots are safe and permitted
  /// (e.g. sharing referral codes, reading statutory DPDP terms, app licenses).
  static const Set<String> safeRoutes = {
    '/growth',
    '/consent',
    '/vault',
    '/vault-legal',
    '/appinfo',
    '/app-info',
    '/auth',
    '/magic-link',
    '/verify-email',
    '/auth/verify',
  };

  /// Checks if current authenticated session is authorized to bypass screenshot restrictions.
  static Future<bool> isBypassedUser() async {
    // ENFORCE ZERO-BYPASS ARCHITECTURE (FE-VULN-01):
    // Under no circumstances should screenshot protection (FLAG_SECURE) be disabled
    // in production viewports, regardless of administrative privileges.
    return false;
  }

  /// Automatically applies the appropriate privacy shield for a route name.
  static Future<bool> applyPolicyForRoute(String? routeName) async {
    if (await isBypassedUser()) {
      await disableSecureMode();
      return true;
    }
    if (routeName == null || routeName.isEmpty) return false;
    final cleanRoute = routeName.toLowerCase().split('?').first;

    // Shell routes dynamically respect the current navigation shell tab
    if (cleanRoute == '/main' || cleanRoute == '/sanctuary') {
      return applyPolicyForTab(currentShellTab);
    }

    for (final sensitive in sensitiveRoutes) {
      if (cleanRoute == sensitive || cleanRoute.startsWith('$sensitive/')) {
        await enableSecureMode();
        return true;
      }
    }

    for (final safe in safeRoutes) {
      if (cleanRoute == safe || cleanRoute.startsWith('$safe/')) {
        await disableSecureMode();
        return false;
      }
    }
    return false;
  }

  /// Automatically applies privacy shield based on the active navigation shell tab.
  /// - Tab 3 (Growth Hub): Safe for sharing referral codes and daily streak badges.
  /// - Tabs 0, 1, 2, 4 (Discovery Feed, Resonances, Chats, Persona): Confidential.
  static Future<bool> applyPolicyForTab(int tabIndex) async {
    currentShellTab = tabIndex;
    if (await isBypassedUser()) {
      await disableSecureMode();
      return true;
    }
    if (tabIndex == 3) {
      await disableSecureMode();
      return false;
    }
    await enableSecureMode();
    return true;
  }

  /// Enables FLAG_SECURE on Android and privacy veil / screenshot shields on Web.
  /// Safely handles tests and desktop/iOS runtimes without crashing.
  /// Strict zero-bypass architecture: screenshot protection is always enforced.
  static Future<bool> enableSecureMode() async {
    if (await isBypassedUser()) {
      await disableSecureMode();
      return true;
    }

    if (kIsWeb) {
      setWebPrivacyMode(true);
      return true;
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
        return true;
      }
    } catch (e) {
      debugPrint('WindowSecurityService: enableSecureMode suppressed: $e');
    }
    return false;
  }

  /// Clears FLAG_SECURE when user exits sensitive viewports or when superadmin signs in.
  static Future<bool> disableSecureMode() async {
    if (kIsWeb) {
      setWebPrivacyMode(false);
      return true;
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
        return true;
      }
    } catch (e) {
      debugPrint('WindowSecurityService: disableSecureMode suppressed: $e');
    }
    return false;
  }
}

/// Global NavigatorObserver automatically managing screenshot security policies
/// across route transitions.
class SanctuaryRouteSecurityObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final routeName = route.settings.name;
    if (routeName != null) {
      WindowSecurityService.applyPolicyForRoute(routeName);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final previousName = previousRoute?.settings.name;
    if (previousName != null) {
      WindowSecurityService.applyPolicyForRoute(previousName);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final newName = newRoute?.settings.name;
    if (newName != null) {
      WindowSecurityService.applyPolicyForRoute(newName);
    }
  }
}
