import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../constants/app_links.dart';
import '../../state/app_notifier.dart';
import '../../services/overlay_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    return appState.when(
      data: (state) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          children: [
            SwitchListTile(
              title: const Text('Show notification shortcut'),
              subtitle: const Text('Quick toggle to disable or enable filter'),
              value: state.notificationShortcutEnabled,
              onChanged: (value) {
                ref
                    .read(appStateProvider.notifier)
                    .toggleNotificationShortcut(value);
              },
            ),
            SwitchListTile(
              title: const Text('Start on boot reminder'),
              subtitle: const Text(
                'Show reminder to enable overlay after reboot',
              ),
              value: state.startOnBootReminder,
              onChanged: (value) {
                ref
                    .read(appStateProvider.notifier)
                    .toggleStartOnBootReminder(value);
              },
            ),
            _OverlayPermissionRow(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.star_border),
              title: const Text('Rate this app'),
              onTap: () {
                _launchUrl(
                  'market://details?id=$kAndroidPackageId',
                  context,
                  fallback:
                      'https://play.google.com/store/apps/details?id=$kAndroidPackageId',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              onTap: () => _handleLegalTap(
                context,
                url: kPrivacyPolicyUrl,
                fallbackTitle: 'Privacy Policy',
                fallbackBody:
                    'NightBuddy stores your preferences (presets, schedule, premium flag) locally on your device only. No personal data is sent to our servers. '
                    'Ads and in-app purchases may collect diagnostics per their respective SDK policies. You can clear app data to reset stored preferences.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Terms of Service'),
              onTap: () => _handleLegalTap(
                context,
                url: kTermsOfServiceUrl,
                fallbackTitle: 'Terms of Service',
                fallbackBody:
                    'Use NightBuddy at your own discretion. The app provides a screen tint overlay to reduce blue light. We do not guarantee medical outcomes. '
                    'By using the app, you agree not to misuse overlays (e.g., to obscure critical system dialogs) and to comply with Play Store policies. '
                    'Premium unlock is non-transferable and subject to Play Store billing terms.',
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'NightBuddy reduces blue light by tinting your screen with a warm overlay. '
                'Use it at night to help your eyes relax.',
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 24),
              child: Text('Version 0.1.0'),
            ),
          ],
        ),
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}

Future<void> _handleLegalTap(
  BuildContext context, {
  required String url,
  required String fallbackTitle,
  required String fallbackBody,
}) async {
  if (url.isNotEmpty) {
    await _launchUrl(url, context);
    return;
  }
  _showLegal(context, title: fallbackTitle, body: fallbackBody);
}

Future<void> _launchUrl(String url, BuildContext context,
    {String? fallback}) async {
  final can = await canLaunchUrlString(url);
  if (can) {
    await launchUrlString(url, mode: LaunchMode.externalApplication);
    return;
  }
  if (fallback != null && await canLaunchUrlString(fallback)) {
    await launchUrlString(fallback, mode: LaunchMode.externalApplication);
    return;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open link')),
    );
  }
}

void _showLegal(BuildContext context,
    {required String title, required String body}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  body,
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OverlayPermissionRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.layers),
      title: const Text('Overlay permission'),
      subtitle: const Text('Open system settings to allow overlay'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final overlayService = ref.read(overlayServiceProvider);
        final hasPermission = await overlayService.hasPermission();
        if (!hasPermission) {
          await overlayService.requestPermission();
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Overlay permission already granted'),
            ),
          );
        }
      },
    );
  }
}
