import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motto_music/utils/platform_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/theme_utils.dart';

class MobileManager {
  static Future<void> initialize() async {
    if (!PlatformUtils.isMobile) return;

    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
      );

      if (Platform.isIOS) {
        await _initializeIOS();
      }

      if (Platform.isAndroid) {
        await _initializeAndroid();
      }
    } catch (e) {
      debugPrint('移动端初始化失败: $e');
    }
  }

  static Future<void> _initializeIOS() async {
    try {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
          statusBarColor: Colors.transparent,
        ),
      );
    } catch (e) {
      debugPrint('iOS 初始化失败: $e');
    }
  }

  static Future<void> _initializeAndroid() async {
    try {
      // Android 端仅允许竖屏（正向），与 Manifest 中的
      // android:screenOrientation="portrait" 保持一致，避免手动旋转导致布局抖动
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      await _ensureNotificationPermission();
    } catch (e) {
      debugPrint('Android 初始化失败: $e');
    }
  }

  static Future<void> _ensureNotificationPermission() async {
    if (!PlatformUtils.isMobile || !Platform.isAndroid) return;

    var status = await Permission.notification.status;
    if (status.isGranted || status.isLimited) {
      return;
    }

    if (status.isDenied) {
      status = await Permission.notification.request();
    }

    if (status.isPermanentlyDenied) {
      debugPrint('⚠️ 通知权限被永久拒绝，将无法显示音乐控制通知。');
      final shouldOpenSettings =
          await Permission.notification.shouldShowRequestRationale;
      if (!shouldOpenSettings) {
        // 用户选择“不要再询问”，引导至设置页面
        await openAppSettings();
      }
      return;
    }

    if (!status.isGranted && !status.isLimited) {
      debugPrint('⚠️ 通知权限被拒绝，将无法显示音乐控制通知。');
    }
  }

  static void setStatusBarStyle({required bool isDarkTheme}) {
    if (!PlatformUtils.isMobile) return;

    try {
      if (Platform.isIOS) {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarBrightness: isDarkTheme ? Brightness.dark : Brightness.light,
            statusBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
            statusBarColor: Colors.transparent,
          ),
        );
      } else if (Platform.isAndroid) {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            statusBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
          ),
        );
      }
    } catch (e) {
      debugPrint('状态栏样式设置失败: $e');
    }
  }
}
