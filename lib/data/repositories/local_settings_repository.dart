import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/app_database.dart';
import '../models/chat_models.dart';

abstract class SettingsRepository {
  Stream<AppSettingsModel> watchSettings();
  Future<void> saveSettings(AppSettingsModel settings);
}

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<AppSettingsModel> watchSettings() {
    return Stream.fromFuture(
      _database.ensureSeeded(),
    ).asyncExpand((_) => _database.watchSettings());
  }

  @override
  Future<void> saveSettings(AppSettingsModel settings) {
    return _database.ensureSeeded().then(
      (_) => _database.saveSettings(settings),
    );
  }
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final databaseReadyProvider = FutureProvider<void>((ref) async {
  final database = ref.watch(databaseProvider);
  await database.ensureSeeded();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  ref.watch(databaseReadyProvider);
  return LocalSettingsRepository(ref.watch(databaseProvider));
});

class SettingsController extends Notifier<AppSettingsModel> {
  @override
  AppSettingsModel build() {
    final repository = ref.watch(settingsRepositoryProvider);
    final subscription = repository.watchSettings().listen(
      (settings) => state = settings,
    );
    ref.onDispose(subscription.cancel);
    return AppSettingsModel.defaults;
  }

  Future<void> updateThemeMode(ThemeMode mode) {
    final next = state.copyWith(themeMode: mode);
    state = next;
    return ref.read(settingsRepositoryProvider).saveSettings(next);
  }

  Future<void> updateDynamicColor(bool value) {
    final next = state.copyWith(useDynamicColor: value);
    state = next;
    return ref.read(settingsRepositoryProvider).saveSettings(next);
  }

  Future<void> updateFontScale(double value) {
    final next = state.copyWith(fontScale: value);
    state = next;
    return ref.read(settingsRepositoryProvider).saveSettings(next);
  }

  Future<void> updateLineNumbers(bool value) {
    final next = state.copyWith(showLineNumbers: value);
    state = next;
    return ref.read(settingsRepositoryProvider).saveSettings(next);
  }

  Future<void> updateAnimations(bool value) {
    final next = state.copyWith(animationsEnabled: value);
    state = next;
    return ref.read(settingsRepositoryProvider).saveSettings(next);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettingsModel>(
      SettingsController.new,
    );
