import 'package:flutter/material.dart';
import '../contants/app_contants.dart';
import '../views/home_view.dart';
import '../views/favorites_view.dart';
import '../views/bilibili/favorites_page.dart';
import '../views/bilibili/global_search_page.dart';
import '../storage/player_state_storage.dart';
import '../widgets/show_aware_page.dart';
import '../views/settings/settings_page.dart';
import '../views/settings/storage_setting_page.dart';
import '../views/settings/config_management_page.dart';
import '../animations/page_transitions.dart';
import '../widgets/global_top_bar.dart';

/// 单个菜单项
class MenuItem {
  final IconData icon;
  final double iconSize;
  final String label;
  final PlayerPage key;
  final GlobalKey pageKey;
  // builder 函数保持不变
  final Widget Function(GlobalKey key) builder;

  const MenuItem({
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.key,
    required this.pageKey,
    required this.builder,
  });

  Widget buildPage() => builder(pageKey);
}

/// 菜单子项数据模型
class MenuSubItem {
  final String routeName;
  final String title;
  final Widget Function() builder; // 改为 builder 函数避免预创建
  final IconData? icon;

  const MenuSubItem({
    required this.routeName,
    required this.title,
    required this.builder,
    this.icon,
  });

  Widget buildPage() => builder();
}

/// 菜单和页面统一管理器
class MenuManager {
  MenuManager._();

  static final MenuManager _instance = MenuManager._();

  factory MenuManager() => _instance;

  /// 当前页面
  final ValueNotifier<PlayerPage> currentPage = ValueNotifier(
    PlayerPage.home,
  );

  /// 当前 hover 的菜单项
  final ValueNotifier<int> hoverIndex = ValueNotifier(-1);

  /// 页面实例缓存
  late final List<Widget> pages = items.map((item) => item.buildPage()).toList();

  /// 导航器 Key（供需要嵌套导航的页面使用）
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// 所有菜单项（底部导航栏的核心页面）
  late final List<MenuItem> items = [
    MenuItem(
      icon: Icons.home_rounded,
      iconSize: 22.0,
      label: '主页',
      key: PlayerPage.home,
      pageKey: GlobalKey<HomeViewState>(),
      builder: (key) => HomeView(key: key),
    ),
    MenuItem(
      icon: Icons.video_library_rounded,
      iconSize: 22.0,
      label: 'Bilibili',
      key: PlayerPage.bilibili,
      pageKey: GlobalKey(),
      builder: (key) => BilibiliFavoritesPage(key: key),
    ),
    MenuItem(
      icon: Icons.search_rounded,
      iconSize: 22.0,
      label: '智能搜索',
      key: PlayerPage.globalSearch,
      pageKey: GlobalKey(),
      builder: (key) => GlobalSearchPage(key: key),
    ),
    MenuItem(
      icon: Icons.favorite_rounded,
      iconSize: 22.0,
      label: '喜欢',
      key: PlayerPage.favorite,
      pageKey: GlobalKey<FavoritesViewState>(),
      builder: (key) => FavoritesView(key: key),
    ),
    MenuItem(
      icon: Icons.settings_rounded,
      iconSize: 22.0,
      label: '设置',
      key: PlayerPage.settings,
      pageKey: GlobalKey<NestedNavigatorWrapperState>(),
      builder: (key) => NestedNavigatorWrapper(
        key: key,
        navigatorKey: navigatorKey,
        initialRoute: '/',
        subItems: subItems,
      ),
    ),
  ];

  /// 底部导航栏显示的菜单项（与 items 相同）
  late final List<MenuItem> navBarItems = items;

  /// 二级菜单项配置
  late final List<MenuSubItem> subItems = _getDefaultSubItems();

  /// 初始化（必须调用一次）
  Future<void> init({
    required GlobalKey<NavigatorState> navigatorKey,
    List<MenuSubItem>? subMenuItems, // 可选参数，允许从外部传入
  }) async {


    final playerState = await PlayerStateStorage.getInstance();
    currentPage.value = playerState.currentPage;
    GlobalTopBarController.instance
        .setActiveBaseSource(_topBarSourceForPage(currentPage.value));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final itemIndex = items.indexWhere((item) => item.key == currentPage.value);
      if (itemIndex != -1) {
        _notifyPageShow(items[itemIndex].pageKey);
      }
    });
  }

  /// 获取默认的二级菜单项配置
  List<MenuSubItem> _getDefaultSubItems() {
    return [
      MenuSubItem(
        routeName: '/',
        title: '设置首页',
        builder: () => SettingsPage(key: GlobalKey<SettingsPageState>()),
        icon: Icons.settings,
      ),
      MenuSubItem(
        routeName: '/settings/storage',
        title: '存储设置',
        builder: () => const StorageSettingPage(),
        icon: Icons.storage,
      ),
      MenuSubItem(
        routeName: '/settings/config',
        title: '配置管理',
        builder: () => const ConfigManagementPage(),
        icon: Icons.backup_rounded,
      ),
    ];
  }

  /// 根据路由名称查找对应的页面
  Widget? getPageByRoute(String routeName) {
    try {
      return subItems
          .firstWhere((item) => item.routeName == routeName)
          .buildPage();
    } catch (e) {
      return null;
    }
  }

  /// 获取所有路由名称
  List<String> getAllRoutes() {
    return subItems.map((item) => item.routeName).toList();
  }

  String _topBarSourceForPage(PlayerPage page) {
    switch (page) {
      case PlayerPage.home:
        return 'home';
      case PlayerPage.bilibili:
        return 'bilibili-library';
      case PlayerPage.globalSearch:
        return 'global-search';
      case PlayerPage.favorite:
        return 'favorites';
      case PlayerPage.settings:
        return 'settings';
      default:
        // 非底部 tab 页面：交由 push/pop 栈（详情页）处理。
        return 'hidden';
    }
  }

  void notifyCurrentPageShow() {
    final itemIndex = items.indexWhere((item) => item.key == currentPage.value);
    if (itemIndex == -1) return;
    _notifyPageShow(items[itemIndex].pageKey);
  }

  void setPage(PlayerPage page, {BuildContext? context}) {
    if (page == currentPage.value) return;
    final oldPage = currentPage.value;
    currentPage.value = page;

    // 工业级：切换 tab 不强制 hide 顶栏，避免出现“空白/闪烁/偶发不显示”。
    // 由新页面的 onPageShow 主动设置顶栏样式。
    GlobalTopBarController.instance.setActiveBaseSource(_topBarSourceForPage(page));

    PlayerStateStorage.getInstance().then((s) => s.setCurrentPage(page));

    if (context != null) {
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
    }

    // 根据key查找旧页面项
    final oldItemIndex = items.indexWhere((item) => item.key == oldPage);
    if (oldItemIndex != -1) {
      final oldItem = items[oldItemIndex];
      if (oldItem.pageKey.currentState is NestedNavigatorWrapperState) {
        (oldItem.pageKey.currentState as NestedNavigatorWrapperState)
            .navigatorKey
            .currentState
            ?.popUntil((r) => r.isFirst);
      }
    }

    // 根据key查找新页面项
    final newItemIndex = items.indexWhere((item) => item.key == page);
    if (newItemIndex != -1) {
      // 尽量立即触发一次（若 state 还未挂载则由 postFrame 再兜底一次）。
      _notifyPageShow(items[newItemIndex].pageKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyPageShow(items[newItemIndex].pageKey);
      });
    }
  }

  void _notifyPageShow(GlobalKey key) {
    final state = key.currentState;
    if (state == null) return;
    if (state is ShowAwarePage) {
      state.onPageShow();
    }
  }
}

class NestedNavigatorWrapper extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final String initialRoute;
  final List<MenuSubItem> subItems; // 接收二级菜单配置

  const NestedNavigatorWrapper({
    super.key,
    required this.navigatorKey,
    required this.initialRoute,
    required this.subItems,
  });

  @override
  NestedNavigatorWrapperState createState() => NestedNavigatorWrapperState();
}

class NestedNavigatorWrapperState extends State<NestedNavigatorWrapper>
    with ShowAwarePage {
  GlobalKey<NavigatorState> get navigatorKey => widget.navigatorKey;

  @override
  void onPageShow() {
    print('NestedNavigatorWrapper onPageShow');

    // 直接调用第一个子路由的 onPageShow
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyFirstSubPageShow();
    });
  }

  /// 通知第一个子页面显示
  void _notifyFirstSubPageShow() {
    // 直接通过navigator context查找ShowAwarePage
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _findAndNotifyShowAwarePage(navigator.context);
    }
  }

  /// 通知页面显示
  void _notifyPageShow(MenuSubItem subItem) {
    // 直接通过navigator context查找ShowAwarePage
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      _findAndNotifyShowAwarePage(navigator.context);
    }
  }

  /// 在Widget树中查找并通知ShowAwarePage
  void _findAndNotifyShowAwarePage(BuildContext context) {
    void visitor(Element element) {
      final widget = element.widget;
      final state = element is StatefulElement ? element.state : null;

      if (state is ShowAwarePage) {
        state.onPageShow();
        return; // 找到第一个就停止
      }

      element.visitChildren(visitor);
    }

    try {
      context.visitChildElements(visitor);
    } catch (e) {
      print('查找ShowAwarePage时出错: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: widget.navigatorKey,
      initialRoute: widget.initialRoute,
      onGenerateRoute: (settings) {
        Widget page;
        try {
          final subItem = widget.subItems.firstWhere(
            (item) => item.routeName == settings.name,
          );
          page = subItem.buildPage();
        } catch (e) {
          page = Scaffold(body: Center(child: Text('未知路由: ${settings.name}')));
        }

        // 使用 Namida 风格的滑动动画
        // 前进时从右往左滑入，返回时自动反向（从左往右）
        return NamidaPageRoute(
          page: page,
          type: PageTransitionType.slideLeft,
        );
      },
    );
  }
}

// 导航助手类
class NestedNavigationHelper {
  static void push(BuildContext context, String routeName) {
    Navigator.of(context, rootNavigator: false).pushNamed(routeName);
  }

  static void pop(BuildContext context) {
    Navigator.of(context, rootNavigator: false).pop();
  }

  // 根据菜单项导航
  static void pushByMenuItem(BuildContext context, MenuSubItem menuItem) {
    Navigator.of(context, rootNavigator: false).pushNamed(menuItem.routeName);
  }
}
