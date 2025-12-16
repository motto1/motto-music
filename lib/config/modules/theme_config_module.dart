import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config_module.dart';
import '../../services/theme_provider.dart';

class ThemeConfigModule extends ConfigModule {
  @override
  String get id => 'theme';

  @override
  String get name => '外观与主题';

  @override
  String get description => '主题模式、透明度、侧边栏状态等';

  @override
  int get version => 1;

  @override
  Future<Map<String, dynamic>> exportData({bool includeSensitive = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};

    final themeMode = prefs.getInt(ThemePrefsKeys.themeMode);
    if (themeMode != null) data['themeMode'] = themeMode;

    final seedColor = prefs.getInt(ThemePrefsKeys.seedColor);
    if (seedColor != null) data['seedColor'] = seedColor;

    final seedAlpha = prefs.getDouble(ThemePrefsKeys.seedAlpha);
    if (seedAlpha != null) data['seedAlpha'] = seedAlpha;

    final opacityTarget = prefs.getString(ThemePrefsKeys.opacityTarget);
    if (opacityTarget != null) data['opacityTarget'] = opacityTarget;

    final sidebarIsExtended =
        prefs.getBool(ThemePrefsKeys.sidebarIsExtended);
    if (sidebarIsExtended != null) {
      data['sidebarIsExtended'] = sidebarIsExtended;
    }

    return data;
  }

  @override
  Future<void> importData(Map<String, dynamic> data,
      {required bool merge}) async {
    final prefs = await SharedPreferences.getInstance();

    if (data.containsKey('themeMode')) {
      final raw = data['themeMode'];
      final index = raw is int ? raw : int.tryParse(raw.toString());
      if (index != null &&
          index >= 0 &&
          index < ThemeMode.values.length) {
        await prefs.setInt(ThemePrefsKeys.themeMode, index);
      }
    }

    if (data.containsKey('seedColor')) {
      final raw = data['seedColor'];
      final value = raw is int ? raw : int.tryParse(raw.toString());
      if (value != null) {
        await prefs.setInt(ThemePrefsKeys.seedColor, value);
      }
    }

    if (data.containsKey('seedAlpha')) {
      final raw = data['seedAlpha'];
      final value =
          raw is double ? raw : double.tryParse(raw.toString());
      if (value != null) {
        await prefs.setDouble(ThemePrefsKeys.seedAlpha, value);
      }
    }

    if (data.containsKey('opacityTarget')) {
      final raw = data['opacityTarget'];
      if (raw != null) {
        await prefs.setString(
            ThemePrefsKeys.opacityTarget, raw.toString());
      }
    }

    if (data.containsKey('sidebarIsExtended')) {
      final raw = data['sidebarIsExtended'];
      final value =
          raw is bool ? raw : raw.toString().toLowerCase() == 'true';
      await prefs.setBool(ThemePrefsKeys.sidebarIsExtended, value);
    }
  }
}

