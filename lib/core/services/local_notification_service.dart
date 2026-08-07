import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smart_reminder/features/settings/domain/entities/notification_sound_option.dart';
import 'package:smart_reminder/features/settings/domain/services/notification_sound_preference_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final class ReminderNotificationAction {
  const ReminderNotificationAction({
    required this.actionId,
    required this.taskId,
    this.notificationId,
  });
  final String actionId;
  final String taskId;
  final int? notificationId;
}

/// Android notification gateway used by reminder application services.
final class LocalNotificationService {
  LocalNotificationService({
    required NotificationSoundPreferenceService soundPreferences,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _soundPreferences = soundPreferences,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const completeAction = 'complete';
  static const snoozeAction = 'snooze';
  static const openAction = 'open';
  static const _channelName = 'Reminders';
  static const _channelDescription = 'Task and reminder notifications';
  static const _demoNotificationId = 0x534D50;
  static const _engagementNotificationId = 0x535452;

  final NotificationSoundPreferenceService _soundPreferences;
  final FlutterLocalNotificationsPlugin _plugin;
  final _actions = StreamController<ReminderNotificationAction>.broadcast();
  Future<void>? _initialization;

  Stream<ReminderNotificationAction> get actions => _actions.stream;

  Future<void> initialize() => _initialization ??= _initializePlugin();

  Future<void> _initializePlugin() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleResponse,
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      _handleResponse(launchResponse);
    }
  }

  void _handleResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final taskId = data['taskId'] as String?;
      if (taskId != null)
        _actions.add(
          ReminderNotificationAction(
            actionId: response.actionId?.isNotEmpty == true
                ? response.actionId!
                : openAction,
            taskId: taskId,
            notificationId: response.id,
          ),
        );
    } catch (_) {}
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<bool> showReminder({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    if (!await requestPermission()) return false;
    final sound = await _soundPreferences.load();
    await _ensureAndroidChannel(sound);
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetailsFor(sound),
      payload: payload,
    );
    return true;
  }

  Future<bool> scheduleReminder({
    required int id,
    required String taskId,
    required String title,
    required String body,
    required DateTime scheduledFor,
  }) async {
    await initialize();
    if (scheduledFor.isBefore(DateTime.now())) return false;
    if (!await requestPermission()) return false;
    final sound = await _soundPreferences.load();
    await _ensureAndroidChannel(sound);
    var mode = AndroidScheduleMode.inexactAllowWhileIdle;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      if (await android?.requestExactAlarmsPermission() ?? false)
        mode = AndroidScheduleMode.exactAllowWhileIdle;
    } catch (_) {}
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledFor.toUtc(), tz.UTC),
      notificationDetails: notificationDetailsFor(sound),
      payload: jsonEncode({'taskId': taskId}),
      androidScheduleMode: mode,
    );
    return true;
  }

  /// Sends one real notification through the same channel as reminders.
  /// Reusing the id replaces the previous demo instead of creating a stack.
  Future<bool> showDemoNotification() => showReminder(
    id: _demoNotificationId,
    title: 'Smart Planner demo',
    body: 'Your reminder notification sound is working.',
  );

  Future<bool> showEngagementNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    if (!await requestPermission()) return false;
    final sound = await _soundPreferences.load();
    await _ensureAndroidChannel(sound);
    await _plugin.show(
      id: _engagementNotificationId,
      title: title,
      body: body,
      notificationDetails: _engagementDetailsFor(sound),
      payload: jsonEncode({'engagement': true}),
    );
    return true;
  }

  Future<bool> scheduleEngagementNotification({
    required String title,
    required String body,
    required DateTime scheduledFor,
  }) async {
    await initialize();
    if (scheduledFor.isBefore(DateTime.now())) return false;
    if (!await requestPermission()) return false;
    final sound = await _soundPreferences.load();
    await _ensureAndroidChannel(sound);
    await _plugin.zonedSchedule(
      id: _engagementNotificationId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledFor.toUtc(), tz.UTC),
      notificationDetails: _engagementDetailsFor(sound),
      payload: jsonEncode({'engagement': true}),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return true;
  }

  Future<void> cancelEngagementNotification() async {
    await initialize();
    await _plugin.cancel(id: _engagementNotificationId);
  }

  Future<void> _ensureAndroidChannel(NotificationSoundOption sound) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        sound.androidChannelId,
        '$_channelName - ${sound.label}',
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        sound: sound.isSystemDefault
            ? null
            : RawResourceAndroidNotificationSound(sound.androidResourceName!),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.notification,
      ),
    );
  }

  Future<void> snooze({
    required String taskId,
    required String title,
    int minutes = 15,
  }) async {
    await scheduleReminder(
      id: DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff),
      taskId: taskId,
      title: title,
      body: 'Snoozed reminder',
      scheduledFor: DateTime.now().add(Duration(minutes: minutes)),
    );
  }

  Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id: id);
  }

  Future<void> cancelForTask(String taskId) async {
    await initialize();
    for (final request in await _plugin.pendingNotificationRequests()) {
      if (request.payload?.contains('"taskId":"$taskId"') ?? false)
        await _plugin.cancel(id: request.id);
    }
  }

  Future<List<PendingNotificationRequest>> pending() async {
    await initialize();
    return _plugin.pendingNotificationRequests();
  }

  NotificationDetails notificationDetailsFor(NotificationSoundOption sound) =>
      NotificationDetails(android: androidDetailsFor(sound));

  NotificationDetails _engagementDetailsFor(NotificationSoundOption sound) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          sound.androidChannelId,
          '$_channelName - ${sound.label}',
          channelDescription: _channelDescription,
          icon: 'ic_notification',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.notification,
          sound: sound.isSystemDefault
              ? null
              : RawResourceAndroidNotificationSound(sound.androidResourceName!),
        ),
      );
  AndroidNotificationDetails androidDetailsFor(NotificationSoundOption sound) =>
      AndroidNotificationDetails(
        sound.androidChannelId,
        '$_channelName - ${sound.label}',
        channelDescription: _channelDescription,
        icon: 'ic_notification',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.notification,
        sound: sound.isSystemDefault
            ? null
            : RawResourceAndroidNotificationSound(sound.androidResourceName!),
        actions: const [
          AndroidNotificationAction(
            completeAction,
            'Complete',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            snoozeAction,
            'Snooze 15m',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            openAction,
            'Open',
            showsUserInterface: true,
          ),
        ],
      );

  Future<void> dispose() async {
    await _actions.close();
  }
}
