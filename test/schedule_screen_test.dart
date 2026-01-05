import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightbuddy/features/schedule/schedule_screen.dart';
import 'package:nightbuddy/models/filter_models.dart';
import 'package:nightbuddy/state/app_notifier.dart';
import 'package:nightbuddy/state/app_state.dart';

class TestAppStateNotifier extends AppStateNotifier {
  TestAppStateNotifier(this._state);

  final AppState _state;

  @override
  Future<AppState> build() async => _state;
}

void main() {
  testWidgets('Schedule screen shows preview for scheduled mode', (tester) async {
    final schedule = ScheduleConfig(
      mode: FilterMode.scheduled,
      startTime: const TimeOfDay(hour: 22, minute: 0),
      endTime: const TimeOfDay(hour: 6, minute: 0),
      windDownMinutes: 30,
      fadeOutMinutes: 15,
    );
    final state = AppState.initial().copyWith(schedule: schedule);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(() => TestAppStateNotifier(state)),
        ],
        child: const MaterialApp(home: ScheduleScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Schedule preview'), findsOneWidget);
    expect(find.text('Save schedule'), findsOneWidget);
  });
}
