import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

import 'views/home_page_mobile.dart';
import 'views/home_page_desktop.dart';
import 'services/player_provider.dart';
import 'services/audio_service_manager.dart';
import 'services/cache/cache_system.dart';
import 'services/bilibili/download_manager.dart';
import 'services/bilibili/download_service.dart';
import 'services/bilibili/cookie_manager.dart';
import 'services/bilibili/api_client.dart';
import 'services/bilibili/stream_service.dart';
import 'services/playlist_service.dart';
import 'database/database.dart';
import './services/theme_provider.dart';
import 'platform/desktop_manager.dart';
import 'platform/mobile_manager.dart';
import 'widgets/keyboard_handler.dart';
import './utils/platform_utils.dart';
import './utils/theme_utils.dart';
import './utils/common_utils.dart';
import './router/route_observer.dart';
import './router/router.dart';
import './contants/app_contants.dart' show PlayerPage;
import './widgets/expandable_player.dart';
import './widgets/expandable_player_content.dart';
import './widgets/global_top_bar.dart';

/// 全局播放器管理器（用于跨页面访问播放器状态）
class GlobalPlayerManager {
  static GlobalKey<ExpandablePlayerState>? _playerKey;
  
  static GlobalKey<ExpandablePlayerState>? get playerKey => _playerKey;
  
  static void setPlayerKey(GlobalKey<ExpandablePlayerState> key) {
    _playerKey = key;
  }
  
  static void clearPlayerKey() {
    _playerKey = null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (PlatformUtils.isDesktop) {
      await DesktopManager.initialize();
    } else if (PlatformUtils.isMobile) {
      await MobileManager.initialize();
    }

    final audioHandler = await AudioServiceManager.ensureInitialized();

    final themeProvider = AppThemeProvider();
    await themeProvider.init();
    final musicDatabase = MusicDatabase.initialize();

    // ⭐ 初始化缓存系统
    await CacheSystem.init();

    // ⭐ 初始化系统播放列表
    final playlistService = PlaylistService(musicDatabase);
    await playlistService.initSystemPlaylists();
    debugPrint('✅ 系统播放列表已初始化');

    // 创建 PlayerProvider 实例
    final playerProvider = PlayerProvider();
    debugPrint('🎵 PlayerProvider 已创建');
    
    debugPrint('🔗 正在将 AudioHandler 注入到 PlayerProvider...');
    await playerProvider.initWithAudioHandler(audioHandler);
    debugPrint('✅ AudioHandler 已成功注入到 PlayerProvider');

    // ⭐ 创建下载管理器（需要先创建依赖服务）
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    final streamService = BilibiliStreamService(apiClient);
    final downloadService = BilibiliDownloadService(
      musicDatabase,
      streamService,
      cookieManager,
    );
    final downloadManager = DownloadManager(musicDatabase, downloadService);
    debugPrint('✅ DownloadManager 已创建');

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<PlayerProvider>.value(value: playerProvider),
          ChangeNotifierProvider<DownloadManager>.value(value: downloadManager),
          Provider<MusicDatabase>.value(value: musicDatabase),
        ],
        child: const MainApp(),
      ),
    );

    if (PlatformUtils.isDesktop) {
      await DesktopManager.postInitialize();
    }
  } catch (e) {
    debugPrint('应用初始化失败: $e');
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with DesktopWindowMixin {
  @override
  void initState() {
    super.initState();
    if (PlatformUtils.isDesktop) {
      DesktopManager.initializeListeners(this);
    }
  }

  @override
  void dispose() {
    if (PlatformUtils.isDesktop) {
      DesktopManager.disposeListeners();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppThemeProvider>(
      builder: (context, themeProvider, child) {
        return MyKeyboardHandler(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            color: Colors.transparent,
            title: 'Motto Music',
            theme: themeProvider.buildLightTheme(),
            darkTheme: themeProvider.buildDarkTheme(),
            themeMode: themeProvider.themeMode,
            home: const HomePageWrapper(),
            navigatorObservers: [routeObserver],
            builder: (context, child) {
              if (PlatformUtils.isDesktopNotMac) {
                return DesktopManager.buildWithTitleBar(child);
              }
              return child ?? const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  
}

class HomePageWrapper extends StatefulWidget {
  const HomePageWrapper({super.key});

  @override
  State<HomePageWrapper> createState() => _HomePageWrapperState();
}

class _HomePageWrapperState extends State<HomePageWrapper> {
  final GlobalKey<ExpandablePlayerState> _playerKey = GlobalKey();
  final menuManager = MenuManager();
  OverlayEntry? _playerOverlay;
  OverlayEntry? _navBarOverlay;
  OverlayEntry? _topBarOverlay;
  
  // 使用 ValueNotifier 替代 setState + markNeedsBuild
  late final ValueNotifier<double> _playerBottomNotifier;

  @override
  void initState() {
    super.initState();
    menuManager.init(navigatorKey: GlobalKey<NavigatorState>());
    _playerBottomNotifier = ValueNotifier(0.0);
    // 注册全局播放器 Key
    GlobalPlayerManager.setPlayerKey(_playerKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 移动平台：在 Overlay 中插入全局播放器和导航栏
    if (PlatformUtils.isMobile && _playerOverlay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _insertOverlays();
      });
    }
  }

  void _insertOverlays() {
    // 获取根 Navigator 的 Overlay（与菜单使用同一个 Overlay）
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final overlay = rootNavigator.overlay!;
    
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final navBarHeight = 44 + bottomPadding; // 导航栏总高度（包括安全区域，44 内容高度）
    
    // 初始化播放器底部偏移量（迷你模式时在导航栏上方）
    _playerBottomNotifier.value = 0.0; // 改为0，导航栏的偏移由自身控制
    
    // 插入底部导航栏（最底层，使用 ValueListenableBuilder 实现动态偏移）
    _navBarOverlay = OverlayEntry(
      builder: (context) {
        return ValueListenableBuilder<double>(
          valueListenable: _playerBottomNotifier,
          builder: (context, percentage, child) {
            // 计算导航栏的垂直偏移量
            // 0-20%: 从 0 下降到 navBarHeight（完全推下）
            // 20-100%: 保持在 navBarHeight（不可见）
            // 收起时反向
            final navBarOffset = _calculateNavBarOffset(percentage, navBarHeight);
            
            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Transform.translate(
                offset: Offset(0, navBarOffset),
                child: child!,
              ),
            );
          },
          child: Material(
            type: MaterialType.transparency,
            child: _GlobalBottomNavBar(menuManager: menuManager),
          ),
        );
      },
    );
    overlay.insert(_navBarOverlay!);
    
    // 插入统一顶栏（位于页面上方，但在播放器之下）
    _topBarOverlay = OverlayEntry(
      builder: (context) {
        return GlobalTopBar(controller: GlobalTopBarController.instance);
      },
    );
    overlay.insert(_topBarOverlay!);

    // 插入全局播放器（在导航栏上方，动态调整底部偏移）
    _playerOverlay = OverlayEntry(
      builder: (context) {
        return ValueListenableBuilder<double>(
          valueListenable: _playerBottomNotifier,
          builder: (context, percentage, child) {
            // 播放器底部位置：始终跟随导航栏下降
            // percentage = 0: bottom = navBarHeight（在导航栏上方）
            // percentage = 1: bottom = 0（贴底）
            final playerBottom = navBarHeight * (1.0 - percentage);
            
            return Positioned(
              left: 0,
              right: 0,
              bottom: playerBottom,
              child: child!,
            );
          },
          child: Material(
            type: MaterialType.transparency,
            child: ExpandablePlayer(
              key: _playerKey,
              minHeight: 84,
              maxHeight: MediaQuery.of(context).size.height,
              bgColor: Colors.transparent,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutExpo,
              onHeightChange: (percentage) {
                // 更新百分比，触发播放器和导航栏位置更新
                _playerBottomNotifier.value = percentage;
              },
              builder: (height, percentage) {
                return ExpandablePlayerContent(
                  height: height,
                  percentage: percentage,
                  minHeight: 84,
                  maxHeight: MediaQuery.of(context).size.height,
                  onRequestClose: () {
                    // 播放器内容请求关闭，缩小播放器
                    _playerKey.currentState?.animateToState(false);
                  },
                );
              },
            ),
          ),
        );
      },
    );
    overlay.insert(_playerOverlay!);
    debugPrint('========== 插入 Overlay 完成 ==========\n');
  }
  
  /// 计算导航栏的垂直偏移量
  /// 展开动画（0 → 1）：
  ///   0-20%: 从 0 下降到 navBarHeight
  ///   20-100%: 保持在 navBarHeight（完全不可见）
  /// 收起动画（1 → 0）：
  ///   20-100%: 保持在 navBarHeight
  ///   20-5%: 从 navBarHeight 上升到 0
  ///   5-0%: 保持在 0
  double _calculateNavBarOffset(double percentage, double navBarHeight) {
    if (percentage <= 0.20) {
      // 0-20% 线性下降/上升
      return navBarHeight * (percentage / 0.20);
    } else {
      // 20-100% 保持完全推下
      return navBarHeight;
    }
  }

  @override
  void dispose() {
    _playerOverlay?.remove();
    _playerOverlay = null;
    _navBarOverlay?.remove();
    _navBarOverlay = null;
    _topBarOverlay?.remove();
    _topBarOverlay = null;
    _playerBottomNotifier.dispose();
    GlobalPlayerManager.clearPlayerKey(); // 清理全局引用
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isMobileWidth(context)) {
      return HomePageMobile(
        menuManager: menuManager,
        playerKey: _playerKey,
      );
    } else {
      return const HomePageDesktop();
    }
  }
}

/// 全局底部导航栏组件
class _GlobalBottomNavBar extends StatelessWidget {
  final MenuManager menuManager;

  const _GlobalBottomNavBar({required this.menuManager});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return ValueListenableBuilder<PlayerPage>(
      valueListenable: menuManager.currentPage,
      builder: (context, currentPage, _) {
        final theme = Theme.of(context);
        final primary = Colors.red;
        final isDark = theme.brightness == Brightness.dark;
        final defaultTextColor = isDark ? Colors.white : Colors.black;

        final navBgColor = ThemeUtils.backgroundColor(context).withValues(alpha: 0.8);
        final borderColor = CommonUtils.select(
          isDark,
          t: const Color.fromRGBO(255, 255, 255, 0.05),
          f: const Color.fromRGBO(0, 0, 0, 0.05),
        );

        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.only(bottom: bottomPadding), // 底部安全区域
              decoration: BoxDecoration(
                color: navBgColor,
                border: Border(
                  top: BorderSide(
                    color: borderColor,
                    width: 1.0,
                  ),
                ),
              ),
              child: SizedBox(
                height: 44, // 导航栏高度调整为 44，给更大的图标留空间
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    menuManager.navBarItems.length,
                    (index) {
                      final item = menuManager.navBarItems[index];
                      final isSelected = item.key == currentPage;

                      final iconColor = isSelected 
                          ? primary 
                          : defaultTextColor.withValues(alpha: 0.6);
                      final textColor = isSelected 
                          ? primary 
                          : defaultTextColor.withValues(alpha: 0.6);

                      return Expanded(
                        child: InkWell(
                          onTap: () => menuManager.setPage(
                            item.key,
                            context: context,
                          ),
                          child: Container(
                            // 向下明显偏移（约 10 像素视觉效果），
                            // 同时保留足够空间避免溢出
                            padding: const EdgeInsets.only(top: 8),
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.icon,
                                  color: iconColor,
                                  size: 26, // 保持当前位置不变
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 7,
                                    height: 0.9, // 略压缩行高，避免底部溢出
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
