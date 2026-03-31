import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightbuddy/features/root/root_shell.dart';
import 'package:nightbuddy/services/overlay_service.dart';
import 'package:nightbuddy/state/app_notifier.dart';
import 'package:nightbuddy/state/app_state.dart';

class _TestAppStateNotifier extends AppStateNotifier {
  _TestAppStateNotifier(this._state);

  final AppState _state;

  @override
  Future<AppState> build() async => _state;
}

class _TestOverlayService extends OverlayService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool?> isOverlayEnabled() async => false;

  @override
  Future<bool> hasFlashlight() async => false;
}

void main() {
  testWidgets('Root shell uses Tonight, Journal, Audio, and Settings tabs', (
    tester,
  ) async {
    final state = AppState.initial().copyWith(onboardingComplete: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(() => _TestAppStateNotifier(state)),
          overlayServiceProvider.overrideWithValue(_TestOverlayService()),
        ],
        child: const MaterialApp(home: RootShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tonight'), findsOneWidget);
    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Premium'), findsNothing);

    await tester.tap(find.byIcon(Icons.auto_graph_outlined));
    await tester.pumpAndSettle();
    expect(find.text('At a glance'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Weekly summary'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Weekly summary'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.graphic_eq_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Now playing'), findsOneWidget);
    expect(find.text('Usual audio defaults'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Display & goals'), findsOneWidget);
  });
}
