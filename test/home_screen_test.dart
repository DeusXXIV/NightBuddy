import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightbuddy/features/home/home_screen.dart';
import 'package:nightbuddy/models/sleep_journal.dart';
import 'package:nightbuddy/services/overlay_service.dart';
import 'package:nightbuddy/state/app_notifier.dart';
import 'package:nightbuddy/state/app_state.dart';

class TestAppStateNotifier extends AppStateNotifier {
  TestAppStateNotifier(this._state);

  final AppState _state;

  @override
  Future<AppState> build() async => _state;
}

class TestOverlayService extends OverlayService {
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
  testWidgets('Home shows weekly summary card', (tester) async {
    final now = DateTime.now();
    final entry = SleepJournalEntry(
      startedAt: now.subtract(const Duration(hours: 7)),
      endedAt: now,
      quality: 4,
      notes: '',
    );
    final state = AppState.initial().copyWith(
      onboardingComplete: true,
      sleepJournalEntries: [entry],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(() => TestAppStateNotifier(state)),
          overlayServiceProvider.overrideWithValue(TestOverlayService()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('Weekly summary'),
      400,
      scrollable: verticalScrollable,
    );
    await tester.pump();

    expect(find.text('Weekly summary'), findsOneWidget);
    expect(find.text('Sleep journal'), findsOneWidget);
  });
}
