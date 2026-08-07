import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';
import 'package:smart_reminder/features/settings/domain/entities/notification_sound_option.dart';

final class NotificationSoundController
    extends AsyncNotifier<NotificationSoundOption> {
  @override
  FutureOr<NotificationSoundOption> build() {
    return ref.watch(notificationSoundPreferenceServiceProvider).load();
  }

  Future<NotificationSoundOption?> select(NotificationSoundOption sound) async {
    state = const AsyncLoading();
    try {
      final selected = await ref
          .read(notificationSoundPreferenceServiceProvider)
          .select(sound);
      state = AsyncData(selected);
      return selected;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }
}

final notificationSoundControllerProvider =
    AsyncNotifierProvider<NotificationSoundController, NotificationSoundOption>(
      NotificationSoundController.new,
    );
