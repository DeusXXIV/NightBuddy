import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/filter_models.dart';

class BedtimeReminderService {
  static const int _baseNotificationId = 4100;
  static const int _checkInNotificationId = 4200;
  static const int _screenOffStartId = 4300;
  static const int _screenOffEndId = 4301;
  static const int _previewBedtimeId = 4400;
  static const int _previewCheckInId = 4401;
  static const int _previewScreenOffId = 4402;
  static const String _channelId = 'nightbuddy_bedtime_reminder';
  static const String _checkInChannelId = 'nightbuddy_checkin_reminder';
  static const String _screenOffChannelId = 'nightbuddy_screen_off';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
    await _plugin.initialize(settings);
    await _requestPermissions();
    await _configureLocalTimeZone();
    _initialized = true;
  }

  Future<void> updateReminders({
    required ScheduleConfig schedule,
    required bool enabled,
    required int leadMinutes,
  }) async {
    await initialize();
    await _cancelBedtimeReminders();

    if (!enabled || schedule.mode != FilterMode.scheduled) return;
    final weekdayStart = schedule.startTime;
    if (weekdayStart == null) return;

    final weekendStart = schedule.weekendDifferent
        ? (schedule.weekendStartTime ?? schedule.startTime)
        : schedule.startTime;

    for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
      final startTime = _isWeekend(day) ? weekendStart : weekdayStart;
      if (startTime == null) continue;
      final target = _reminderTarget(day, startTime, leadMinutes);
      final scheduled = _nextInstanceOfWeekdayTime(
        target.dayOfWeek,
        target.hour,
        target.minute,
      );
      final id = _baseNotificationId + day;
      await _plugin.zonedSchedule(
        id,
        'NightBuddy bedtime reminder',
        'Time to wind down for sleep.',
        scheduled,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> updateCheckInReminder({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    await initialize();
    await _plugin.cancel(_checkInNotificationId);
    if (!enabled) return;

    final scheduled = _nextInstanceOfTime(time.hour, time.minute);
    await _plugin.zonedSchedule(
      _checkInNotificationId,
      'NightBuddy sleep check-in',
      'How did you sleep? Log it in your journal.',
      scheduled,
      _checkInNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleScreenOffNotifications(DateTime until) async {
    await initialize();
    await cancelScreenOffNotifications();

    await _plugin.show(
      _screenOffStartId,
      'Screen-off goal',
      'No-phone window started. Put your phone away and relax.',
      _screenOffNotificationDetails(),
    );

    final scheduled = tz.TZDateTime.from(until, tz.local);
    await _plugin.zonedSchedule(
      _screenOffEndId,
      'Screen-off goal',
      'Your no-phone window is complete.',
      scheduled,
      _screenOffNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showPreview(NotificationPreview type) async {
    await initialize();
    switch (type) {
      case NotificationPreview.bedtime:
        await _plugin.show(
          _previewBedtimeId,
          'NightBuddy bedtime reminder',
          'Preview: time to wind down for sleep.',
          _notificationDetails(),
        );
        break;
      case NotificationPreview.checkIn:
        await _plugin.show(
          _previewCheckInId,
          'NightBuddy sleep check-in',
          'Preview: log how you slept.',
          _checkInNotificationDetails(),
        );
        break;
      case NotificationPreview.screenOff:
        await _plugin.show(
          _previewScreenOffId,
          'Screen-off goal',
          'Preview: no-phone window reminder.',
          _screenOffNotificationDetails(),
        );
        break;
    }
  }

  Future<void> cancelScreenOffNotifications() async {
    await initialize();
    await _plugin.cancel(_screenOffStartId);
    await _plugin.cancel(_screenOffEndId);
  }

  Future<void> _cancelBedtimeReminders() async {
    for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
      await _plugin.cancel(_baseNotificationId + day);
    }
  }

  NotificationDetails _notificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'Bedtime reminders',
      channelDescription: 'NightBuddy bedtime reminders tied to your schedule.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const darwinDetails = DarwinNotificationDetails();
    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
  }

  NotificationDetails _checkInNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      _checkInChannelId,
      'Sleep check-ins',
      channelDescription: 'Morning reminders to log your sleep quality.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const darwinDetails = DarwinNotificationDetails();
    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
  }

  NotificationDetails _screenOffNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      _screenOffChannelId,
      'Screen-off goal',
      channelDescription: 'No-phone window reminders.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const darwinDetails = DarwinNotificationDetails();
    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
  }

  Future<void> _requestPermissions() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  }

  bool _isWeekend(int weekday) =>
      weekday == DateTime.saturday || weekday == DateTime.sunday;

  _ReminderTarget _reminderTarget(
    int dayOfWeek,
    TimeOfDay startTime,
    int leadMinutes,
  ) {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    var reminderMinutes = startMinutes - leadMinutes;
    var adjustedDay = dayOfWeek;

    while (reminderMinutes < 0) {
      reminderMinutes += _minutesPerDay;
      adjustedDay = _shiftDay(adjustedDay, -1);
    }

    while (reminderMinutes >= _minutesPerDay) {
      reminderMinutes -= _minutesPerDay;
      adjustedDay = _shiftDay(adjustedDay, 1);
    }

    final hour = reminderMinutes ~/ 60;
    final minute = reminderMinutes % 60;
    return _ReminderTarget(
      dayOfWeek: adjustedDay,
      hour: hour,
      minute: minute,
    );
  }

  int _shiftDay(int day, int offset) {
    var value = day + offset;
    while (value < DateTime.monday) {
      value += 7;
    }
    while (value > DateTime.sunday) {
      value -= 7;
    }
    return value;
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(
    int weekday,
    int hour,
    int minute,
  ) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static const int _minutesPerDay = 24 * 60;
}

enum NotificationPreview {
  bedtime,
  checkIn,
  screenOff,
}

class _ReminderTarget {
  const _ReminderTarget({
    required this.dayOfWeek,
    required this.hour,
    required this.minute,
  });

  final int dayOfWeek;
  final int hour;
  final int minute;
}
