import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../contants/app_contants.dart' show PlayerPage;
import '../router/router.dart';
import '../widgets/expandable_player.dart';

class HomePageMobile extends StatefulWidget {
  final MenuManager menuManager;
  final GlobalKey<ExpandablePlayerState>? playerKey;
  
  const HomePageMobile({
    super.key,
    required this.menuManager,
    this.playerKey,
  });

  @override
  State<HomePageMobile> createState() => _HomePageMobileState();
}

class _HomePageMobileState extends State<HomePageMobile> {
  MenuManager get menuManager => widget.menuManager;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppThemeProvider>(
      builder: (context, themeProvider, child) {
        Color bodyBg = ThemeUtils.backgroundColor(context);

        return ValueListenableBuilder<PlayerPage>(
          valueListenable: menuManager.currentPage,
          builder: (context, currentPage, _) {
            return PopScope(
              key: ValueKey(currentPage),
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                debugPrint('========== 系统返回事件 ==========');
                debugPrint('[PopScope] didPop: $didPop');
                debugPrint('[PopScope] currentPage: $currentPage');
                
                if (!didPop) {
                  // 优先检查播放器是否全屏，如果全屏则缩小播放器
                  final playerState = widget.playerKey?.currentState;
                  final percentage = playerState?.percentage ?? -1;
                  
                  debugPrint('[PopScope] playerState: ${playerState != null ? "存在" : "null"}');
                  debugPrint('[PopScope] percentage: ${(percentage * 100).toStringAsFixed(1)}%');
                  debugPrint('[PopScope] 是否全屏 (>= 0.9): ${percentage >= 0.9}');
                  
                  if (playerState != null && percentage >= 0.9) {
                    debugPrint('[PopScope] ✓ 拦截返回，缩小播放器');
                    playerState.animateToState(false);
                    return;
                  }
                  
                  // 播放器不是全屏，执行原有的页面导航逻辑
                  debugPrint('[PopScope] 播放器非全屏，执行页面导航');
                  if (currentPage == PlayerPage.home) {
                    debugPrint('[PopScope] → 当前在主页，退出应用');
                    SystemNavigator.pop();
                  } else {
                    debugPrint('[PopScope] → 当前在 $currentPage，返回主页');
                    menuManager.setPage(
                      PlayerPage.home,
                      context: context,
                    );
                  }
                }
                debugPrint('====================================\n');
              },
              child: Scaffold(
                body: Container(
                  color: bodyBg,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: MediaQuery.of(context).padding.copyWith(
                            // 84(播放器最小高度) + 44(导航栏高度)
                            bottom: MediaQuery.of(context).padding.bottom + 128,
                          ),
                    ),
                    child: ValueListenableBuilder<PlayerPage>(
                      valueListenable: menuManager.currentPage,
                      builder: (context, currentPage, _) {
                        final pageIndex = menuManager.items.indexWhere((item) => item.key == currentPage);
                        if (pageIndex != -1) {
                          return menuManager.pages[pageIndex];
                        }
                        return menuManager.pages[0];
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
