import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightbuddy/features/audio/audio_screen.dart';
import 'package:nightbuddy/features/home/home_screen.dart';
import 'package:nightbuddy/features/home/widgets/tonight_flow_screen.dart';
import 'package:nightbuddy/features/journal/journal_screen.dart';
import 'package:nightbuddy/features/settings/settings_screen.dart';
import 'package:nightbuddy/models/filter_models.dart';
import 'package:nightbuddy/models/mind_unload_entry.dart';
import 'package:nightbuddy/models/sleep_journal.dart';
import 'package:nightbuddy/services/ads_service.dart';
import 'package:nightbuddy/services/bedtime_reminder_service.dart';
import 'package:nightbuddy/services/log_service.dart';
import 'package:nightbuddy/services/overlay_service.dart';
import 'package:nightbuddy/services/premium_service.dart';
import 'package:nightbuddy/services/sleep_audio_service.dart';
import 'package:nightbuddy/services/storage_service.dart';
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

class ActiveOverlayService extends OverlayService {
  ActiveOverlayService({this.nativeEnabled = true});

  bool? nativeEnabled;

  @override
  Future<void> initialize() async {}

  @override
  Stream<bool> get overlayStatusStream => const Stream<bool>.empty();

  @override
  Stream<void> get toggleRequests => const Stream<void>.empty();

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool?> isOverlayEnabled() async => nativeEnabled;

  @override
  Future<void> startOverlay({
    required FilterPreset preset,
    required bool showNotification,
  }) async {
    nativeEnabled = true;
  }

  @override
  Future<void> stopOverlay({required bool showNotification}) async {
    nativeEnabled = false;
  }

  @override
  Future<bool?> getFlashlightStatus() async => null;

  @override
  Future<bool> hasFlashlight() async => false;
}

class TestStorageService extends StorageService {
  AppState? storedState;

  @override
  Future<AppState?> loadState() async => storedState;

  @override
  Future<void> saveState(AppState state) async {
    storedState = state;
  }
}

class TestSleepAudioPlayer implements SleepAudioPlayer {
  @override
  Future<void> dispose() async {}

  @override
  Future<void> playBytes(Uint8List bytes) async {}

  @override
  Future<void> setLooping() async {}

  @override
  Future<void> stop() async {}
}

class TestPremiumService extends PremiumService {
  TestPremiumService({bool isPremium = false}) : _isPremium = isPremium;

  bool _isPremium;

  @override
  Future<void> initialize() async {}

  @override
  bool get isPremium => _isPremium;

  @override
  Future<void> setPremium(bool value) async {
    _isPremium = value;
  }
}

class TestAdsService extends AdsService {
  @override
  Future<void> initialize() async {}
}

class TestBedtimeReminderService extends BedtimeReminderService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> updateReminders({
    required ScheduleConfig schedule,
    required bool enabled,
    required int leadMinutes,
  }) async {}

  @override
  Future<void> updateCheckInReminder({
    required bool enabled,
    required TimeOfDay time,
  }) async {}
}

class TestLogService extends LogService {
  @override
  Stream<List<AppLogEntry>> get entries => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logEvent({
    required String type,
    required String message,
    Map<String, dynamic>? details,
  }) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('Journal screen shows weekly summary card', (tester) async {
    final now = DateTime.now();
    final entry = SleepJournalEntry(
      startedAt: now.subtract(const Duration(hours: 7)),
      endedAt: now,
      quality: 4,
      notes: '',
      tags: const [],
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
        child: const MaterialApp(home: JournalScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('At a glance'), findsOneWidget);
    expect(find.text('Tonight'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Weekly summary'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Weekly summary'), findsOneWidget);
    expect(find.text('Morning check-in'), findsOneWidget);
  });

  testWidgets('Journal screen opens sleep history as a full screen', (
    tester,
  ) async {
    final now = DateTime.now();
    final entry = SleepJournalEntry(
      startedAt: now.subtract(const Duration(hours: 7)),
      endedAt: now,
      quality: 4,
      notes: 'Fell asleep quickly.',
      tags: const ['Stress'],
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
        child: const MaterialApp(home: JournalScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final viewHistoryButton = find.widgetWithText(TextButton, 'View history');
    await tester.ensureVisible(viewHistoryButton);
    await tester.pump();
    await tester.tap(viewHistoryButton, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sleep history'), findsOneWidget);
    expect(find.textContaining('Quality 4/5'), findsOneWidget);
    expect(find.byIcon(Icons.notes_outlined), findsOneWidget);
  });

  testWidgets('Tonight flow shows mind unload status', (tester) async {
    final state = AppState.initial().copyWith(
      onboardingComplete: true,
      environmentChecklistDate: DateTime.now(),
      environmentChecklist: const {
        'lights': true,
        'temperature': true,
        'alarm': true,
        'bedside': true,
      },
      mindUnloadEntries: [
        MindUnloadEntry(
          id: 'mind_1',
          createdAt: DateTime.now(),
          text: 'Remember to set out clothes for tomorrow.',
          category: 'Reminder',
        ),
      ],
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
      find.widgetWithText(ElevatedButton, 'Continue with mind clear'),
      300,
      scrollable: verticalScrollable,
    );
    await tester.pump();

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Continue with mind clear'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Next: Clear your mind'), findsOneWidget);
    expect(find.text('Clear your mind'), findsOneWidget);
    expect(find.textContaining('1 pending'), findsOneWidget);
  });

  testWidgets('Tonight flow shows environment check progress', (tester) async {
    final state = AppState.initial().copyWith(
      onboardingComplete: true,
      environmentChecklistDate: DateTime.now(),
      environmentChecklist: const {'lights': true, 'alarm': true},
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
      find.widgetWithText(ElevatedButton, 'Continue with room check'),
      300,
      scrollable: verticalScrollable,
    );
    await tester.pump();

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Continue with room check'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Set the room'), findsOneWidget);
    expect(find.textContaining('2/4 done'), findsOneWidget);
  });

  testWidgets('Tonight flow opens from settle in card', (tester) async {
    final state = AppState.initial().copyWith(onboardingComplete: true);

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
      find.widgetWithText(ElevatedButton, 'Continue with room check'),
      300,
      scrollable: verticalScrollable,
    );
    await tester.pump();

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Continue with room check'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tonight'), findsOneWidget);
    expect(find.text('Do this now'), findsOneWidget);
    expect(find.text('Set the room'), findsOneWidget);
    expect(find.textContaining('Next: Set the room'), findsOneWidget);
    expect(find.text('Current focus'), findsWidgets);
  });

  testWidgets('Full filter preview opens from tune filter card', (
    tester,
  ) async {
    final state = AppState.initial().copyWith(onboardingComplete: true);

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
      find.text('Open full preview'),
      300,
      scrollable: verticalScrollable,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open full preview'));
    await tester.pumpAndSettle();

    expect(find.text('Filter preview'), findsOneWidget);
    expect(find.textContaining('mock phone'), findsOneWidget);
  });

  testWidgets('Empty routine shows starter templates on Home', (tester) async {
    final state = AppState.initial().copyWith(
      onboardingComplete: true,
      windDownItems: const [],
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
      find.text('Start with a template'),
      300,
      scrollable: verticalScrollable,
    );
    await tester.pump();

    expect(find.text('Start with a template'), findsOneWidget);
    expect(find.text('Quick reset'), findsOneWidget);
    expect(find.text('Gentle drift'), findsOneWidget);
    expect(find.text('Screen-off push'), findsOneWidget);
  });

  testWidgets('Usual night setup opens from settle in card', (tester) async {
    final state = AppState.initial().copyWith(onboardingComplete: true);

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
      find.text('Adjust setup'),
      300,
      scrollable: verticalScrollable,
    );
    final setupButton = find.text('Adjust setup').first;
    await tester.ensureVisible(setupButton);
    await tester.pump();
    await tester.tap(setupButton, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Usual night setup').last, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Usual night setup'), findsWidgets);
    expect(
      find.text('Choose what your usual night should start with.'),
      findsOneWidget,
    );
    expect(find.text('Bedtime preset'), findsOneWidget);
    expect(find.text('Sleep music'), findsOneWidget);
  });

  testWidgets('Routine editor opens from settle in card', (tester) async {
    final state = AppState.initial().copyWith(onboardingComplete: true);

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
      find.text('Adjust setup'),
      300,
      scrollable: verticalScrollable,
    );
    final editButton = find.text('Adjust setup').first;
    await tester.ensureVisible(editButton);
    await tester.pump();
    await tester.tap(editButton, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Edit routine').last, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Wind-down routine'), findsOneWidget);
    expect(find.text('Your steps'), findsOneWidget);
    expect(find.text('Add step'), findsOneWidget);
  });

  testWidgets('Audio screen shows live track when music is playing', (
    tester,
  ) async {
    final state = AppState.initial().copyWith(onboardingComplete: true);
    final container = ProviderContainer(
      overrides: [
        appStateProvider.overrideWith(() => TestAppStateNotifier(state)),
        overlayServiceProvider.overrideWithValue(TestOverlayService()),
        storageServiceProvider.overrideWithValue(TestStorageService()),
        sleepAudioPlayerFactoryProvider.overrideWithValue(
          () => TestSleepAudioPlayer(),
        ),
        sleepAudioAssetLoaderProvider.overrideWithValue(
          (asset) async => Uint8List.fromList([1, 2, 3]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appStateProvider.future);
    await container.read(sleepAudioControllerProvider).playTrack('drift');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AudioScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Now playing'), findsOneWidget);
    expect(find.text('Quick start'), findsOneWidget);
    expect(find.text('Usual audio defaults'), findsOneWidget);
    expect(
      find.textContaining('Rainbound Lullaby is playing now'),
      findsOneWidget,
    );
  });

  testWidgets('Settings screen shows setup hub entries', (tester) async {
    final state = AppState.initial().copyWith(onboardingComplete: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(() => TestAppStateNotifier(state)),
          overlayServiceProvider.overrideWithValue(TestOverlayService()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set things up once'), findsOneWidget);
    expect(find.text('Usual night defaults'), findsOneWidget);
    expect(find.text('Display & goals'), findsOneWidget);
    expect(find.text('Night prompts'), findsOneWidget);
    expect(find.text('Routine & bedtime'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Device & privacy'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Device & privacy'), findsOneWidget);
  });

  testWidgets('Settings screen opens usual night defaults', (tester) async {
    final state = AppState.initial().copyWith(onboardingComplete: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(() => TestAppStateNotifier(state)),
          overlayServiceProvider.overrideWithValue(TestOverlayService()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Usual night defaults'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Usual night setup'), findsOneWidget);
  });

  testWidgets(
    'Tonight flow shows stronger complete state when routine is done',
    (tester) async {
      final now = DateTime.now();
      final defaultItems = AppState.initial().windDownItems;
      final state = AppState.initial().copyWith(
        onboardingComplete: true,
        filterEnabled: true,
        environmentChecklistDate: now,
        environmentChecklist: const {
          'lights': true,
          'temperature': true,
          'alarm': true,
          'bedside': true,
        },
        windDownChecklistDate: now,
        windDownChecklist: {for (final item in defaultItems) item.id: true},
        screenOffUntil: now.add(const Duration(minutes: 45)),
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
        find.widgetWithText(ElevatedButton, 'Review tonight'),
        300,
        scrollable: verticalScrollable,
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Review tonight'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tonight routine complete'), findsOneWidget);
      expect(find.text('Everything is set for tonight.'), findsOneWidget);
      expect(find.text('Tonight is fully ready'), findsOneWidget);
    },
  );

  testWidgets('Tonight flow can open the dedicated routine editor', (
    tester,
  ) async {
    final now = DateTime.now();
    final state = AppState.initial().copyWith(
      onboardingComplete: true,
      environmentChecklistDate: now,
      environmentChecklist: const {
        'lights': true,
        'temperature': true,
        'alarm': true,
        'bedside': true,
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(() => TestAppStateNotifier(state)),
          overlayServiceProvider.overrideWithValue(TestOverlayService()),
        ],
        child: const MaterialApp(home: TonightFlowScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final tonightScrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Edit routine'),
      300,
      scrollable: tonightScrollable,
    );
    final editRoutineButton = find.widgetWithText(TextButton, 'Edit routine');
    await tester.ensureVisible(editRoutineButton);
    await tester.pump();
    await tester.tap(editRoutineButton, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Wind-down routine'), findsOneWidget);
    expect(find.text('Your steps'), findsOneWidget);
  });

  testWidgets('Start usual night summarizes already-active states', (
    tester,
  ) async {
    final now = DateTime.now();
    final storedState = AppState.initial().copyWith(
      onboardingComplete: true,
      filterEnabled: true,
      screenOffUntil: now.add(const Duration(minutes: 45)),
    );
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(
          TestStorageService()..storedState = storedState,
        ),
        overlayServiceProvider.overrideWithValue(ActiveOverlayService()),
        premiumServiceProvider.overrideWithValue(TestPremiumService()),
        adsServiceProvider.overrideWithValue(TestAdsService()),
        bedtimeReminderServiceProvider.overrideWithValue(
          TestBedtimeReminderService(),
        ),
        logServiceProvider.overrideWithValue(TestLogService()),
        sleepAudioPlayerFactoryProvider.overrideWithValue(
          () => TestSleepAudioPlayer(),
        ),
        sleepAudioAssetLoaderProvider.overrideWithValue(
          (asset) async => Uint8List.fromList([1, 2, 3]),
        ),
      ],
    );
    await container.read(appStateProvider.future);
    final audio = container.read(sleepAudioControllerProvider);
    await audio.playTrack('drift');
    await audio.startTimer(const Duration(minutes: 30));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Start usual night'),
      300,
      scrollable: verticalScrollable,
    );
    final usualNightButton = find.widgetWithText(
      FilledButton,
      'Start usual night',
    );
    await tester.ensureVisible(usualNightButton);
    await tester.pump();
    await tester.tap(usualNightButton, warnIfMissed: false);
    await tester.pump();

    expect(find.textContaining('wind-down already active'), findsOneWidget);
    expect(
      find.textContaining('favorite music already playing'),
      findsOneWidget,
    );
    expect(find.textContaining('phone-down already active'), findsOneWidget);

    await audio.stop();
    container.dispose();
  });

  testWidgets('Home shows mind unload carry-over from a previous day', (
    tester,
  ) async {
    final state = AppState.initial().copyWith(
      onboardingComplete: true,
      mindUnloadEntries: [
        MindUnloadEntry(
          id: 'carry_1',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          text: 'Follow up on the overdue email.',
          category: 'Reminder',
        ),
      ],
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
      find.text('Carry into today'),
      300,
      scrollable: verticalScrollable,
    );
    await tester.pump();

    expect(find.text('Carry into today'), findsOneWidget);
    expect(find.text('Follow up on the overdue email.'), findsOneWidget);
    expect(find.text('Mark done'), findsOneWidget);
  });

  testWidgets('Home shows quieter supporting state when tonight is ready', (
    tester,
  ) async {
    final now = DateTime.now();
    final state = AppState.initial().copyWith(
      onboardingComplete: true,
      filterEnabled: true,
      environmentChecklistDate: now,
      environmentChecklist: const {
        'lights': true,
        'temperature': true,
        'alarm': true,
        'bedside': true,
      },
      screenOffUntil: now.add(const Duration(minutes: 30)),
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
      find.text(
        'You are set for tonight. These sections stay here for quick review or small changes.',
      ),
      300,
      scrollable: verticalScrollable,
    );
    await tester.pump();

    expect(find.textContaining('You are set for tonight.'), findsWidgets);
    expect(
      find.text(
        'You are set for tonight. These sections stay here for quick review or small changes.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Home hides debug tools unless explicitly enabled', (
    tester,
  ) async {
    final state = AppState.initial().copyWith(onboardingComplete: true);

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

    expect(find.text('Debug: Overlay service'), findsNothing);
  });

  testWidgets('Home shows debug tools when the setting is enabled', (
    tester,
  ) async {
    final state = AppState.initial().copyWith(
      onboardingComplete: true,
      showDebugTools: true,
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

    expect(find.text('Debug: Overlay service'), findsOneWidget);
  });
}
