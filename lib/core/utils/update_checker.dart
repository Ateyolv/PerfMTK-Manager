import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:http/http.dart' as http;
import 'package:manager/core/utils/changelog_list.dart';
import 'package:manager/core/utils/version_utils.dart';
import 'package:manager/localization/app_locales.dart';
import 'package:manager/localization/app_languages.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  final String owner;
  final String repo;
  final String currentVersion;
  final String currentLanguage;

  UpdateChecker({
    required this.owner,
    required this.repo,
    required this.currentVersion,
    required this.currentLanguage,
  });

  Future<bool> checkForUpdates(BuildContext context) async {
    try {
      final response = await http
          .get(
            Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return false;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;

      final tag = decoded['tag_name'];
      if (tag is! String || !isVersionNewer(tag, currentVersion)) return false;

      Map<String, dynamic>? apkAsset;
      final assets = decoded['assets'];
      if (assets is List) {
        for (final asset in assets) {
          if (asset is Map<String, dynamic> &&
              asset['name'] is String &&
              (asset['name'] as String).toLowerCase().endsWith('.apk') &&
              asset['browser_download_url'] is String) {
            apkAsset = asset;
            break;
          }
        }
      }
      if (apkAsset == null || !context.mounted) return false;

      final latestVersion = tag.replaceFirst(RegExp(r'^[vV]'), '');
      await _showUpdateDialog(
        context,
        latestVersion,
        apkAsset['browser_download_url'] as String,
        decoded['body'] is String ? decoded['body'] as String : '',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  Widget processChangelogForTesting(String changelog) => _processChangelog(changelog);

  Widget _processChangelog(String changelog) {
    final lines = const LineSplitter().convert(changelog);
    final requestedLanguage = AppLanguages.resolve(currentLanguage);
    const headings = {
      '## English': 'en',
      '## Español': 'es',
      '## 简体中文': 'zh',
      '## 中文': 'zh',
      '## Chinese': 'zh',
    };
    final availableLanguages = lines
        .map((line) => headings[line.trim()])
        .whereType<String>()
        .toSet();
    final targetLanguage = availableLanguages.contains(requestedLanguage)
        ? requestedLanguage
        : availableLanguages.contains('en') ? 'en' : null;
    final hasLanguageSections = availableLanguages.isNotEmpty;
    var isInExpectedSection = !hasLanguageSections;
    final changes = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      final headingLanguage = headings[line];
      if (headingLanguage != null) {
        isInExpectedSection = headingLanguage == targetLanguage;
        continue;
      }
      if (line.startsWith('##') || line.startsWith('**Full')) {
        continue;
      }
      if (isInExpectedSection && line.isNotEmpty) {
        changes.add(ChangelogList(line.replaceFirst(RegExp(r'^[-*]\s+'), '')));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: changes,
    );
  }

  Future<void> _showUpdateDialog(
    BuildContext context,
    String newVersion,
    String downloadUrl,
    String changelog,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppLocale.updateMess.getString(dialogContext)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocale.updateAvailable.getString(dialogContext)
                      .replaceAll('{version}', newVersion),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocale.updateNew.getString(dialogContext),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                _processChangelog(changelog),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocale.updateCancel.getString(dialogContext)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                launchUrl(
                  Uri.parse(downloadUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Text(AppLocale.updateDown.getString(dialogContext)),
            ),
          ],
        );
      },
    );
  }
}
