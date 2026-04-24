import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// GitHub release-based auto-update checker for EveryTick
class UpdateService {
  static const _repo = 'Mr-Q526/EveryTick';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';

  /// Check for updates and show dialog if a newer version is available
  static Future<void> checkForUpdate(
    BuildContext context, {
    bool silent = true,
  }) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // e.g. "1.0.2"

      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('检查更新失败，请稍后再试')));
        }
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').replaceAll('v', '');
      final releaseName = data['name'] as String? ?? tagName;
      final releaseBody = data['body'] as String? ?? '';
      final htmlUrl = data['html_url'] as String? ?? '';

      // Find APK asset
      String apkUrl = '';
      final assets = data['assets'] as List? ?? [];
      for (var asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String? ?? '';
          break;
        }
      }

      if (tagName.isEmpty) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('当前已是最新版本 ✅')));
        }
        return;
      }

      final hasUpdate = _isNewer(tagName, currentVersion);

      if (!hasUpdate) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('当前已是最新版本 v$currentVersion ✅')),
          );
        }
        return;
      }

      if (!context.mounted) return;

      // Show update dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.system_update,
                  color: Color(0xFF3B82F6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '发现新版本',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(
                      'v$currentVersion',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    Text(
                      'v$tagName',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
              if (releaseName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  releaseName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (releaseBody.isNotEmpty) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      releaseBody,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                '稍后更新',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                final url = apkUrl.isNotEmpty ? apkUrl : htmlUrl;
                if (url.isNotEmpty) {
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text(
                '立即更新',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      // Network error or timeout — silent fail
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('网络错误: $e')));
      }
    }
  }

  /// Compare semver: returns true if remote > current
  static bool _isNewer(String remote, String current) {
    final rp = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final cp = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (rp.length < 3) {
      rp.add(0);
    }
    while (cp.length < 3) {
      cp.add(0);
    }
    for (int i = 0; i < 3; i++) {
      if (rp[i] > cp[i]) return true;
      if (rp[i] < cp[i]) return false;
    }
    return false;
  }
}
