import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsState {
  const AppSettingsState({
    required this.defaultHour,
    required this.defaultMinute,
  });
  final int defaultHour, defaultMinute;
  TimeOfDay get defaultTime =>
      TimeOfDay(hour: defaultHour, minute: defaultMinute);
}

class AppSettingsController extends AsyncNotifier<AppSettingsState> {
  static const _hour = 'default_hour', _minute = 'default_minute';
  @override
  FutureOr<AppSettingsState> build() async {
    try {
      final p = await SharedPreferences.getInstance();
      return AppSettingsState(
        defaultHour: p.getInt(_hour) ?? 9,
        defaultMinute: p.getInt(_minute) ?? 0,
      );
    } catch (_) {
      return const AppSettingsState(defaultHour: 9, defaultMinute: 0);
    }
  }

  Future<void> setDefaultTime(TimeOfDay time) async {
    final current = state.value;
    if (current == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_hour, time.hour);
    await p.setInt(_minute, time.minute);
    state = AsyncData(
      AppSettingsState(defaultHour: time.hour, defaultMinute: time.minute),
    );
  }
}

final appSettingsControllerProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettingsState>(
      AppSettingsController.new,
    );
