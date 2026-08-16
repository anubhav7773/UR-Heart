import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class UpdateService {
  UpdateService._internal();
  static final UpdateService instance = UpdateService._internal();
  factory UpdateService() => instance;

  static const String _repo = 'anubhav7773/UR-Heart';
  static const String _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';

  bool _isChecking = false;

  /// Check for new OTA updates from GitHub Releases API
  Future<void> checkForUpdates(BuildContext context, {bool silent = true}) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'UR-Heart-Mobile-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        if (!silent && context.mounted) {
          _showSnackBar(context, 'No updates found or repository is private.');
        }
        return;
      }

      final Map<String, dynamic> release = jsonDecode(response.body);
      final String rawTag = release['tag_name'] ?? '';
      final String latestVersion = _cleanVersion(rawTag);
      final String releaseNotes = release['body'] ?? 'Performance improvements and bug fixes.';
      
      // Find direct APK download url
      final List<dynamic> assets = release['assets'] ?? [];
      String? apkUrl;
      for (final asset in assets) {
        final name = (asset['name'] as String?)?.toLowerCase() ?? '';
        final url = asset['browser_download_url'] as String?;
        if (name.endsWith('.apk') && url != null) {
          apkUrl = url;
          break;
        }
      }

      if (apkUrl == null && assets.isNotEmpty) {
        apkUrl = assets.first['browser_download_url'] as String?;
      }

      // Check current package info
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = _cleanVersion(packageInfo.version);

      if (_isNewerVersion(latestVersion, currentVersion)) {
        if (context.mounted && apkUrl != null) {
          _showUpdateDialog(
            context,
            latestVersion: latestVersion,
            releaseNotes: releaseNotes,
            apkUrl: apkUrl,
          );
        }
      } else if (!silent && context.mounted) {
        _showSnackBar(context, 'You are on the latest version ($currentVersion).');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Update check failed: $e');
      }
      if (!silent && context.mounted) {
        _showSnackBar(context, 'Failed to check for updates.');
      }
    } finally {
      _isChecking = false;
    }
  }

  /// Clean semantic tag e.g. "v1.2.0" -> "1.2.0"
  String _cleanVersion(String v) {
    var cleaned = v.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }
    final plusIndex = cleaned.indexOf('+');
    if (plusIndex != -1) {
      cleaned = cleaned.substring(0, plusIndex);
    }
    return cleaned;
  }

  /// Compares semantic versions (e.g. 1.0.1 > 1.0.0)
  bool _isNewerVersion(String latest, String current) {
    if (latest.isEmpty) return false;
    if (current.isEmpty) return true;

    final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (latestParts.length < 3) {
      latestParts.add(0);
    }
    while (currentParts.length < 3) {
      currentParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  /// Display modern themed Update Dialog
  void _showUpdateDialog(
    BuildContext context, {
    required String latestVersion,
    required String releaseNotes,
    required String apkUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _UpdateDialogContent(
          latestVersion: latestVersion,
          releaseNotes: releaseNotes,
          apkUrl: apkUrl,
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.cardColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _UpdateDialogContent extends StatefulWidget {
  final String latestVersion;
  final String releaseNotes;
  final String apkUrl;

  const _UpdateDialogContent({
    required this.latestVersion,
    required this.releaseNotes,
    required this.apkUrl,
  });

  @override
  State<_UpdateDialogContent> createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<_UpdateDialogContent> {
  bool _isDownloading = false;
  int _downloadProgress = 0;
  String _statusText = '';

  Future<void> _startOtaUpdate() async {
    if (kIsWeb) {
      _fallbackToBrowser();
      return;
    }

    setState(() {
      _isDownloading = true;
      _statusText = 'Starting download...';
      _downloadProgress = 0;
    });

    try {
      OtaUpdate()
          .execute(
            widget.apkUrl,
            destinationFilename: 'ur-heart-update.apk',
          )
          .listen(
        (OtaEvent event) {
          if (!mounted) return;
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final int progress = int.tryParse(event.value ?? '0') ?? 0;
              setState(() {
                _downloadProgress = progress;
                _statusText = 'Downloading update... $progress%';
              });
              break;
            case OtaStatus.INSTALLING:
              setState(() {
                _statusText = 'Installing update...';
              });
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              setState(() {
                _statusText = 'Update already in progress.';
              });
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
              setState(() {
                _statusText = 'Direct install failed. Opening browser...';
              });
              _fallbackToBrowser();
              break;
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _statusText = 'Update error. Opening browser...';
            });
            _fallbackToBrowser();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        _fallbackToBrowser();
      }
    }
  }

  Future<void> _fallbackToBrowser() async {
    final uri = Uri.parse(widget.apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF161B22),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update Available 🚀',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'v${widget.latestVersion}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'What\'s New:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.releaseNotes,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress / 100.0 : null,
                color: AppTheme.primaryColor,
                backgroundColor: Colors.white10,
                borderRadius: BorderRadius.circular(8),
                minHeight: 6,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _statusText,
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isDownloading)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Later',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isDownloading ? null : _startOtaUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  child: Text(
                    _isDownloading ? 'Updating...' : 'Update Now',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
