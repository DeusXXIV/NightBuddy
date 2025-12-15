// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/filter_models.dart';
import '../../state/app_notifier.dart';
import '../../state/app_state.dart';
import '../../services/overlay_service.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;
  FilterMode _initialMode = FilterMode.scheduled;
  bool _requestingPermission = false;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OnboardingCard(
        title: 'Welcome to NightBuddy',
        description:
            'Reduce blue light and keep your eyes comfortable at night.',
        icon: Icons.nightlight_round,
      ),
      _OnboardingCard(
        title: 'Warmer light, less strain',
        description: 'Switch to a warm tint that is easier on your eyes.',
        icon: Icons.wb_twilight,
      ),
      _OnboardingCard(
        title: 'Overlay permission',
        description:
            'We need draw-over-apps permission to place a non-intrusive overlay on Android.',
        icon: Icons.shield_outlined,
      ),
      _modePicker(context),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (value) => setState(() => _index = value),
                itemCount: pages.length,
                itemBuilder: (_, i) => pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      pages.length,
                      (i) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index
                              ? Colors.orange
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      if (_index == 0) {
                        Navigator.of(context).maybePop();
                        return;
                      }
                      _controller.animateToPage(
                        (_index - 1).clamp(0, pages.length - 1),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _requestingPermission
                        ? null
                        : () async {
                            if (_index < pages.length - 1) {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                              return;
                            }
                            await _finishOnboarding();
                          },
                    child: Text(_index == pages.length - 1 ? 'Start' : 'Next'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _requestingPermission
                        ? null
                        : () async {
                            await _finishOnboarding(skipToEnd: true);
                          },
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modePicker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose how NightBuddy starts',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          RadioListTile<FilterMode>(
            value: FilterMode.alwaysOn,
            groupValue: _initialMode,
            onChanged: (value) => setState(() => _initialMode = value!),
            title: const Text('Always On'),
          ),
          RadioListTile<FilterMode>(
            value: FilterMode.scheduled,
            groupValue: _initialMode,
            onChanged: (value) => setState(() => _initialMode = value!),
            title: const Text('Night Schedule 22:00-06:00'),
          ),
          RadioListTile<FilterMode>(
            value: FilterMode.off,
            groupValue: _initialMode,
            onChanged: (value) => setState(() => _initialMode = value!),
            title: const Text("I'll set it later"),
          ),
        ],
      ),
    );
  }

  Future<void> _finishOnboarding({bool skipToEnd = false}) async {
    setState(() => _requestingPermission = true);
    final notifier = ref.read(appStateProvider.notifier);
    final current = ref.read(appStateProvider).value ?? AppState.initial();
    await notifier.updateSchedule(
      current.schedule.copyWith(mode: _initialMode),
    );
    await notifier.setOnboardingComplete();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final overlayService = ref.read(overlayServiceProvider);
      final hasPermission = await overlayService.hasPermission();
      if (!hasPermission && mounted) {
        final shouldOpen = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Allow overlay permission'),
            content: const Text(
              'NightBuddy needs permission to draw over other apps to tint the screen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Not now'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Allow'),
              ),
            ],
          ),
        );
        if (shouldOpen == true) {
          await overlayService.requestPermission();
        }
      } else {
        await notifier.toggleOverlay(true);
      }
    });

    if (!mounted) return;
    if (skipToEnd) {
      Navigator.of(context).maybePop();
    }
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
