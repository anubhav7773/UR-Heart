import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  bool _isChecking = false;
  bool _dialogShown = false;

  /// Clean semantic version string (strip 'v' prefix, '+build', and '-suffix' like '-beta' or '-release')
  static String cleanVersion(String v) {
    var cleaned = v.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }
    // Strip build metadata '+' (e.g. 1.1.0+2 -> 1.1.0)
    final plusIndex = cleaned.indexOf('+');
    if (plusIndex != -1) {
      cleaned = cleaned.substring(0, plusIndex);
    }
    // Strip prerelease suffixes '-' (e.g. 1.1.0-beta -> 1.1.0)
    final dashIndex = cleaned.indexOf('-');
    if (dashIndex != -1) {
      cleaned = cleaned.substring(0, dashIndex);
    }
    return cleaned.trim();
  }

  /// Semantic version comparison helper ([major, minor, patch] + build number)
  /// Returns true only if serverVersion is strictly newer than installedVersion
  static bool isServerVersionNewer({
    required String installedVersion,
    required String latestVersion,
    int installedBuild = 0,
    int latestBuild = 0,
  }) {
    try {
      final cleanInstalled = cleanVersion(installedVersion);
      final cleanLatest = cleanVersion(latestVersion);

      if (cleanLatest.isEmpty) return false;
      if (cleanInstalled.isEmpty) return true;

      final v1Parts = cleanInstalled.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
      final v2Parts = cleanLatest.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();

      while (v1Parts.length < 3) {
        v1Parts.add(0);
      }
      while (v2Parts.length < 3) {
        v2Parts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (v2Parts[i] > v1Parts[i]) return true;
        if (v2Parts[i] < v1Parts[i]) return false;
      }

      // If semantic versions (major.minor.patch) are identical, compare build numbers if present
      if (latestBuild > 0 && installedBuild > 0) {
        return latestBuild > installedBuild;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Checks backend for latest APK release and prompts user with direct in-app download.
  /// When called automatically on launch (showNoUpdateToast = false), dialog is only shown if force_update == true.
  /// When called manually (showNoUpdateToast = true), dialog is shown for any newer version or green snackbar if up-to-date.
  Future<void> checkForUpdate(BuildContext context, {bool showNoUpdateToast = false}) async {
    if (_isChecking || _dialogShown) return;
    _isChecking = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final installedVersion = packageInfo.version;
      final installedBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      final res = await ApiClient.instance.getAppVersion();
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'] as Map<String, dynamic>?;
        if (data != null) {
          final latestVersion = (data['latest_version'] ?? installedVersion).toString();
          final latestBuild = (data['latest_build_number'] as num?)?.toInt() ?? 0;
          final apkUrl = (data['download_url'] ?? data['apk_url'] ?? '').toString();
          final releaseNotes = (data['release_notes'] ?? 'General performance enhancements & bug fixes.').toString();
          final isForceUpdate = (data['force_update'] == true || data['is_force_update'] == true);

          final hasUpdate = isServerVersionNewer(
            installedVersion: installedVersion,
            latestVersion: latestVersion,
            installedBuild: installedBuild,
            latestBuild: latestBuild,
          );

          final bool isValidApkUrl = apkUrl.isNotEmpty &&
              apkUrl.toLowerCase() != 'null' &&
              (apkUrl.startsWith('http://') || apkUrl.startsWith('https://'));

          final bool isManual = showNoUpdateToast;
          final bool shouldShowDialog = hasUpdate && isValidApkUrl && (isForceUpdate || isManual);

          if (shouldShowDialog && context.mounted) {
            _dialogShown = true;
            await showDialog(
              context: context,
              barrierDismissible: !isForceUpdate,
              builder: (ctx) => _AppUpdateDialog(
                latestVersion: latestVersion,
                releaseNotes: releaseNotes,
                apkUrl: apkUrl,
                isForceUpdate: isForceUpdate,
              ),
            );
            _dialogShown = false;
          } else if (isManual && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('UR-Heart is up to date (v$installedVersion)! ✨'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AppUpdateService Error] $e');
      }
    } finally {
      _isChecking = false;
    }
  }
}

class _AppUpdateDialog extends StatefulWidget {
  final String latestVersion;
  final String releaseNotes;
  final String apkUrl;
  final bool isForceUpdate;

  const _AppUpdateDialog({
    required this.latestVersion,
    required this.releaseNotes,
    required this.apkUrl,
    required this.isForceUpdate,
  });

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = 'Direct In-App APK Install';

  Future<void> _startDirectDownload() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = 'Connecting to server... ⏳';
    });

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/ur-heart-update.apk';

        await ApiClient.instance.dio.download(
          widget.apkUrl,
          filePath,
          onReceiveProgress: (received, total) {
            if (total > 0 && mounted) {
              final double p = (received / total).clamp(0.0, 1.0);
              setState(() {
                _progress = p;
                _statusText = 'Downloading: ${(p * 100).toInt()}%';
              });
            }
          },
        );

        if (mounted) {
          setState(() {
            _progress = 1.0;
            _statusText = 'Opening package installer... 🚀';
          });
        }

        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          if (mounted) {
            setState(() {
              _statusText = 'Opening in browser...';
            });
          }
          await _openInBrowser();
        }
      } catch (e) {
        if (kDebugMode) print('[Download Error] $e');
        if (mounted) {
          setState(() {
            _statusText = 'Download failed. Opening in browser...';
          });
        }
        await _openInBrowser();
      } finally {
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
        }
      }
    } else {
      await _openInBrowser();
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    try {
      final uri = Uri.parse(widget.apkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isForceUpdate && !_isDownloading,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFFFF4081)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE91E63).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                '🚀 Naya Update Aaya Hai!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              Text(
                'Version ${widget.latestVersion} Available',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),

              // Release Notes Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What\'s New ✨',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.releaseNotes,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Download Progress Bar (When Active)
              if (_isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 10,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE91E63)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText,
                  style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],

              // Action Buttons
              if (!_isDownloading) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _startDirectDownload,
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text(
                      'Update Now (Direct APK)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                if (!widget.isForceUpdate) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Later',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
