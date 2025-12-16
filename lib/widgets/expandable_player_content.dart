import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:motto_music/database/database.dart';
import 'package:motto_music/services/player_provider.dart';
import 'package:motto_music/utils/common_utils.dart';
import 'package:motto_music/contants/app_contants.dart' show PlayMode;
import 'package:motto_music/widgets/slider_custom.dart';
import 'package:motto_music/widgets/scrolling_text.dart';
import 'package:motto_music/widgets/karaoke_lyrics_view.dart';
import 'package:motto_music/widgets/player_buttons.dart';
import 'package:motto_music/widgets/audio_quality_section.dart';
import 'package:motto_music/widgets/unified_cover_image.dart';
import 'package:motto_music/models/bilibili/audio_quality.dart';
import 'package:motto_music/services/bilibili/download_manager.dart';
import 'package:motto_music/services/bilibili/stream_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/api_service.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/services/bilibili/favorite_sync_notifier.dart';
import 'package:motto_music/utils/bilibili_song_utils.dart';
import 'package:motto_music/storage/player_state_storage.dart';
// 歌词服务和模型
import 'package:motto_music/services/lyrics/lyric_service.dart';
import 'package:motto_music/models/lyrics/lyric_models.dart';
import 'package:motto_music/utils/lyric_parser.dart';
// 页面跳转和导航
import 'package:motto_music/animations/page_transitions.dart';
import 'package:motto_music/views/bilibili/user_videos_page.dart';
// 移除旧的对话框导入,改为内嵌实现

/// 播放器叠加层类型枚举
enum PlayerOverlayType {
  none,              // 仅显示播放器
  playlist,          // 显示播放列表
  lyricsMenu,        // 显示歌词菜单
  playerMenu,        // 显示播放器菜单(三点窗口)
  searchLyrics,      // 显示手动搜索歌词
  editLyrics,        // 显示编辑歌词
  adjustLyricsOffset,// 显示调整歌词偏移量
  favoriteSelection, // 显示收藏夹选择
}

/// 可展开播放器的内容组件
/// 
/// 根据 percentage 参数动态显示不同层级的 UI：
/// - 0.0 - 0.3: 迷你模式（底部播放条）
/// - 0.3 - 0.7: 过渡阶段
/// - 0.7 - 1.0: 全屏模式
/// 
/// 内嵌叠加层：
/// - 播放列表（从右侧滑入）
/// - 歌词菜单（从底部滑入）
class ExpandablePlayerContent extends StatefulWidget {
  /// 当前容器高度
  final double height;
  
  /// 展开百分比 (0.0 = 迷你, 1.0 = 全屏)
  final double percentage;
  
  /// 最小高度
  final double minHeight;
  
  /// 最大高度
  final double maxHeight;
  
  /// 请求关闭回调（用于全屏时按返回键缩小播放器）
  final VoidCallback? onRequestClose;

  const ExpandablePlayerContent({
    super.key,
    required this.height,
    required this.percentage,
    required this.minHeight,
    required this.maxHeight,
    this.onRequestClose,
  });

  @override
  State<ExpandablePlayerContent> createState() => _ExpandablePlayerContentState();
}

class _ExpandablePlayerContentState extends State<ExpandablePlayerContent>
    with TickerProviderStateMixin {
  // ========== 播放器基础状态 ==========
  double _tempSliderValue = -1; // 进度条临时值
  bool _showLyrics = false; // 封面/歌词切换状态（默认显示大封面）
  bool _targetShowLyrics = false; // 切换动画的目标状态（用于平滑过渡）
  int? _lastSongId; // 上一首歌曲的 ID（用于检测歌曲变化）

  // ========== 动画方向判断 ==========
  double _previousPercentage = 0.0; // 上一帧的百分比
  bool _isExpanding = true; // 当前是否为展开动画

  // ========== 叠加层状态管理 ==========
  PlayerOverlayType _currentOverlay = PlayerOverlayType.none;

  // 临时存储当前歌曲和 Provider（用于对话框层）
  Song? _overlayCurrentSong;
  PlayerProvider? _overlayPlayerProvider;
  List<BilibiliFavorite>? _overlayFavorites; // 收藏夹列表

  // ========== 搜索歌词状态 ==========
  late TextEditingController _searchLyricsController;
  List<LyricSearchResult>? _searchResults;
  bool _isSearching = false;
  bool _isFetchingLyric = false;
  String? _searchErrorMessage;

  // ========== 编辑歌词状态 ==========
  late TextEditingController _editOriginalLyricsController;
  late TextEditingController _editTranslatedLyricsController;
  bool _isSavingLyrics = false;
  
  // ========== 调整偏移量状态 ==========
  double _currentLyricOffset = 0.0;
  bool _isSavingOffset = false;
  
  // ========== 动画控制器 ==========
  // 封面过渡动画
  late AnimationController _coverTransitionController;
  late Animation<double> _coverSizeAnimation;
  late Animation<double> _coverLeftAnimation;
  late Animation<double> _coverTopAnimation;
  late Animation<double> _coverRadiusAnimation;
  
  // 播放列表滑入动画
  late AnimationController _playlistController;
  late Animation<Offset> _playlistSlideAnimation;
  
  // 歌词菜单滑入动画
  late AnimationController _lyricsMenuController;
  late Animation<Offset> _lyricsMenuSlideAnimation;
  
  // 对话框类叠加层动画（缩放+淡入）
  late AnimationController _dialogOverlayController;
  late Animation<double> _dialogScaleAnimation;
  late Animation<double> _dialogOpacityAnimation;
  
  // 缓存容器尺寸，用于计算动画目标值
  double _containerWidth = 0;
  double _containerHeight = 0;
  
  @override
  void initState() {
    super.initState();
    
    // ========== 初始化文本控制器 ==========
    _searchLyricsController = TextEditingController();
    _editOriginalLyricsController = TextEditingController();
    _editTranslatedLyricsController = TextEditingController();
    
    // ========== 初始化封面过渡动画控制器 ==========
    _coverTransitionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..value = 1.0; // 初始状态为完成状态
    
    // 初始化封面动画（歌词模式的初始值）
    _coverSizeAnimation = Tween<double>(begin: 60.0, end: 60.0).animate(
      CurvedAnimation(
        parent: _coverTransitionController,
        curve: Curves.easeInOut,
      ),
    );
    _coverLeftAnimation = Tween<double>(begin: 20.0, end: 20.0).animate(
      CurvedAnimation(
        parent: _coverTransitionController,
        curve: Curves.easeInOut,
      ),
    );
    _coverTopAnimation = Tween<double>(begin: 85.0, end: 85.0).animate(
      CurvedAnimation(
        parent: _coverTransitionController,
        curve: Curves.easeInOut,
      ),
    );
    _coverRadiusAnimation = Tween<double>(begin: 12.0, end: 12.0).animate(
      CurvedAnimation(
        parent: _coverTransitionController,
        curve: Curves.easeInOut,
      ),
    );
    
    // ========== 初始化播放列表滑入动画 ==========
    _playlistController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _playlistSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0), // 从底部滑入
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _playlistController,
      curve: Curves.easeOutCubic,
    ));
    
    // ========== 初始化歌词菜单滑入动画 ==========
    _lyricsMenuController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _lyricsMenuSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0), // 从底部滑入
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _lyricsMenuController,
      curve: Curves.easeOutCubic,
    ));
    
    // ========== 初始化对话框类叠加层动画（缩放+淡入） ==========
    _dialogOverlayController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _dialogScaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dialogOverlayController,
      curve: Curves.easeOutCubic,
    ));
    _dialogOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dialogOverlayController,
      curve: Curves.easeOut,
    ));
    
    _loadUserPreference();
  }
  
  @override
  void dispose() {
    _searchLyricsController.dispose();
    _editOriginalLyricsController.dispose();
    _editTranslatedLyricsController.dispose();
    _coverTransitionController.dispose();
    _playlistController.dispose();
    _lyricsMenuController.dispose();
    _dialogOverlayController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(ExpandablePlayerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 当容器尺寸变化时，重新计算封面目标位置
    if (widget.maxHeight != oldWidget.maxHeight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncAnimationWithCurrentMode();
      });
    }
    
    // 当 percentage 变化时，触发 AnimatedBuilder 重建
    // 修复：下拉再打开后点击切换封面不动的bug
    if (widget.percentage != oldWidget.percentage) {
      setState(() {});
    }
  }
  
  /// 加载用户偏好设置（首次打开始终显示大封面）
  Future<void> _loadUserPreference() async {
    // 首次打开播放器时始终显示大封面模式
    // 不再从 SharedPreferences 加载上次的状态
    if (mounted) {
      setState(() {
        _showLyrics = false; // 始终默认大封面模式
        _targetShowLyrics = false; // 同步目标状态
      });
      // 加载完后，立即同步动画目标值
      _syncAnimationWithCurrentMode();
    }
  }
  
  /// 同步动画目标值与当前模式（避免首次打开时状态不一致）
  void _syncAnimationWithCurrentMode() {
    // 修复：如果切换动画正在进行，不要覆盖
    // 避免 postFrameCallback 在动画过程中覆盖正在进行的切换动画
    if (_coverTransitionController.isAnimating) {
      return;
    }
    
    if (!mounted || _containerWidth == 0 || _containerHeight == 0) {
      // 容器尺寸未初始化，等待下一帧
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncAnimationWithCurrentMode();
      });
      return;
    }
    
    final double targetSize;
    final double targetLeft;
    final double targetTop;
    final double targetBorderRadius;
    
    // 修复：使用 _targetShowLyrics 而不是 _showLyrics
    // 避免在动画过程中被触发时使用错误的状态，导致覆盖正在进行的动画
    if (_targetShowLyrics) {
      // 歌词模式：小封面
      targetSize = 60.0;
      targetLeft = 20.0;
      targetTop = _getLyricsModeCoverTop();
      targetBorderRadius = 12.0;
    } else {
      // 大封面模式：响应式计算（与 _buildCoverSpacerContent 保持一致）
      // 使用 widget.maxHeight 作为目标高度，保证在 ExpandablePlayer 高度动画过程中
      // 封面插值的终点保持稳定，路径为从迷你位置到最终全屏位置的直线
      final screenHeight = widget.maxHeight;
      
      // 🔧 响应式顶部预留
      final topReserved = screenHeight < 650 
          ? screenHeight * 0.10  // 极短屏：~60-65px
          : screenHeight < 750 
              ? screenHeight * 0.12  // 短屏：~78-90px
              : 100.0;  // 正常屏：100px
      
      // 🔧 响应式底部UI计算
      final coverBottomSpacing = screenHeight < 650 ? 8.0 : 12.0;
      const songInfoHeight = 60.0;
      const buttonRowHeight = 48.0;
      final progressBarHeight = screenHeight < 650 ? 32.0 : 40.0;
      final controlsHeight = screenHeight < 650 ? 64.0 : 80.0;
      const bottomButtonsHeight = 60.0;
      final totalSpacing = screenHeight < 650 ? 20.0 : 30.0;
      
      final calculatedBottom = coverBottomSpacing + songInfoHeight + 
                               buttonRowHeight + progressBarHeight + 
                               controlsHeight + bottomButtonsHeight + 
                               totalSpacing;
      
      final bottomReserved = calculatedBottom;
      final availableHeight = screenHeight - topReserved - bottomReserved;
      
      // 🔧 响应式最小尺寸
      final coverMinSize = screenHeight < 650 
          ? screenHeight * 0.26  // 极短屏：~156-169px
          : screenHeight < 750 
              ? screenHeight * 0.28  // 短屏：~182-210px
              : 200.0;  // 正常屏：200px
      
      final maxCoverSize = min(_containerWidth * 0.80, availableHeight)
          .clamp(coverMinSize, 400.0);
      
      targetSize = maxCoverSize;
      targetLeft = (_containerWidth - maxCoverSize) / 2;
      final topSpace = screenHeight - maxCoverSize - bottomReserved;
      targetTop = topSpace * 0.45 + topReserved * 0.5;
      targetBorderRadius = 20.0;
    }
    
    // 更新动画目标值（无动画，直接设置）
    _coverSizeAnimation = Tween<double>(
      begin: targetSize,
      end: targetSize,
    ).animate(CurvedAnimation(
      parent: _coverTransitionController,
      curve: Curves.easeInOut,
    ));
    
    _coverLeftAnimation = Tween<double>(
      begin: targetLeft,
      end: targetLeft,
    ).animate(CurvedAnimation(
      parent: _coverTransitionController,
      curve: Curves.easeInOut,
    ));
    
    _coverTopAnimation = Tween<double>(
      begin: targetTop,
      end: targetTop,
    ).animate(CurvedAnimation(
      parent: _coverTransitionController,
      curve: Curves.easeInOut,
    ));
    
    _coverRadiusAnimation = Tween<double>(
      begin: targetBorderRadius,
      end: targetBorderRadius,
    ).animate(CurvedAnimation(
      parent: _coverTransitionController,
      curve: Curves.easeInOut,
    ));
    
    // 确保动画控制器处于完成状态
    _coverTransitionController.value = 1.0;
  }
  
  /// 保存用户偏好设置（可选：如果想完全禁用持久化，可以删除此方法的调用）
  Future<void> _saveUserPreference() async {
    // 注意：此方法仍会保存偏好，但 _loadUserPreference 不会加载
    // 如果不需要保存任何状态，可以注释掉此方法的内容
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('now_playing_show_lyrics', _showLyrics);
    } catch (e) {
      debugPrint('保存偏好设置失败: $e');
    }
  }
  
  /// 获取歌词模式下封面的 top 位置（统一计算方法）
  double _getLyricsModeCoverTop() {
    final safeAreaTop = MediaQuery.of(context).padding.top;
    return safeAreaTop + 61.0; // SafeArea 下方 61px（在标准设备上约为105px）
  }
  
  /// 计算当前封面的实际显示尺寸（修复：确保动画起点正确）
  /// 与 _buildContinuousAnimatedCover 中的计算逻辑保持一致
  double _getCurrentCoverSize() {
    final targetSize = _coverSizeAnimation.value;
    if (widget.percentage < 0.5) {
      const miniSize = 60.0;
      final progress = widget.percentage / 0.5;
      return miniSize + (targetSize - miniSize) * progress;
    } else {
      return targetSize;
    }
  }
  
  /// 计算当前封面的实际显示左边距
  double _getCurrentCoverLeft() {
    final targetLeft = _coverLeftAnimation.value;
    if (widget.percentage < 0.5) {
      const miniLeft = 20.0;
      final progress = widget.percentage / 0.5;
      return miniLeft + (targetLeft - miniLeft) * progress;
    } else {
      return targetLeft;
    }
  }
  
  /// 计算当前封面的实际显示上边距
  double _getCurrentCoverTop() {
    final targetTop = _coverTopAnimation.value;
    if (widget.percentage < 0.5) {
      const miniTop = 10.0;
      final progress = widget.percentage / 0.5;
      return miniTop + (targetTop - miniTop) * progress;
    } else {
      return targetTop;
    }
  }
  
  /// 计算当前封面的实际显示圆角
  double _getCurrentCoverRadius() {
    final targetRadius = _coverRadiusAnimation.value;
    if (widget.percentage < 0.5) {
      const miniBorderRadius = 12.0;
      final progress = widget.percentage / 0.5;
      return miniBorderRadius + (targetRadius - miniBorderRadius) * progress;
    } else {
      return targetRadius;
    }
  }
  
  /// 切换封面/歌词显示（带持久化）
  void _toggleView() {
    // 修复：先读取当前动画值，再停止和重置控制器
    // 避免 reset() 导致读取到错误的起点值
    final currentSize = _getCurrentCoverSize();
    final currentLeft = _getCurrentCoverLeft();
    final currentTop = _getCurrentCoverTop();
    final currentRadius = _getCurrentCoverRadius();
    
    // 停止可能正在进行的动画，并重置控制器
    if (_coverTransitionController.isAnimating) {
      _coverTransitionController.stop();
    }
    _coverTransitionController.reset();
    
    // 在切换前计算新的目标值
    final double targetSize;
    final double targetLeft;
    final double targetTop;
    final double targetBorderRadius;
    
    if (!_targetShowLyrics) {
      // 当前目标是大封面模式，即将切换到歌词模式
      targetSize = 60.0;
      targetLeft = 20.0;
      targetTop = _getLyricsModeCoverTop(); // 使用统一的计算方法
      targetBorderRadius = 12.0;
    } else {
      // 当前目标是歌词模式，即将切换到封面模式
      // 大封面模式：响应式计算（与 _syncAnimationWithCurrentMode 保持一致）
      final screenHeight = _containerHeight;
      
      // 🔧 响应式顶部预留
      final topReserved = screenHeight < 650 
          ? screenHeight * 0.10  // 极短屏：~60-65px
          : screenHeight < 750 
              ? screenHeight * 0.12  // 短屏：~78-90px
              : 100.0;  // 正常屏：100px
      
      // 🔧 响应式底部UI计算
      final coverBottomSpacing = screenHeight < 650 ? 8.0 : 12.0;
      const songInfoHeight = 60.0;
      const buttonRowHeight = 48.0;
      final progressBarHeight = screenHeight < 650 ? 32.0 : 40.0;
      final controlsHeight = screenHeight < 650 ? 64.0 : 80.0;
      const bottomButtonsHeight = 60.0;
      final totalSpacing = screenHeight < 650 ? 20.0 : 30.0;
      
      final calculatedBottom = coverBottomSpacing + songInfoHeight + 
                               buttonRowHeight + progressBarHeight + 
                               controlsHeight + bottomButtonsHeight + 
                               totalSpacing;
      
      final bottomReserved = calculatedBottom;
      final availableHeight = screenHeight - topReserved - bottomReserved;
      
      // 🔧 响应式最小尺寸
      final coverMinSize = screenHeight < 650 
          ? screenHeight * 0.26  // 极短屏：~156-169px
          : screenHeight < 750 
              ? screenHeight * 0.28  // 短屏：~182-210px
              : 200.0;  // 正常屏：200px
      
      final maxCoverSize = min(_containerWidth * 0.80, availableHeight)
          .clamp(coverMinSize, 400.0);
      
      targetSize = maxCoverSize;
      targetLeft = (_containerWidth - maxCoverSize) / 2;
      final topSpace = screenHeight - maxCoverSize - bottomReserved;
      targetTop = topSpace * 0.45 + topReserved * 0.5;
      targetBorderRadius = 20.0;
    }
    
    // 更新动画 Tween
    _coverSizeAnimation = Tween<double>(
      begin: currentSize,
      end: targetSize,
    ).animate(CurvedAnimation(
      parent: _coverTransitionController,
      curve: Curves.easeInOut,
    ));
    
    _coverLeftAnimation = Tween<double>(
      begin: currentLeft,
      end: targetLeft,
    ).animate(CurvedAnimation(
      parent: _coverTransitionController,
      curve: Curves.easeInOut,
    ));
    
    _coverTopAnimation = Tween<double>(
      begin: currentTop,
      end: targetTop,
    ).animate(CurvedAnimation(
      parent: _coverTransitionController,
      curve: Curves.easeInOut,
    ));
    
    _coverRadiusAnimation = Tween<double>(
      begin: currentRadius,
      end: targetBorderRadius,
    ).animate(CurvedAnimation(
      parent: _coverTransitionController,
      curve: Curves.easeInOut,
    ));
    
    setState(() {
      // 切换目标状态
      _targetShowLyrics = !_targetShowLyrics;
    });
    
    // 启动封面过渡动画
    _coverTransitionController.forward(from: 0.0).then((_) {
      // 动画完成后，更新实际状态
      if (mounted) {
        setState(() {
          _showLyrics = _targetShowLyrics;
        });
        _saveUserPreference();
      }
    });
  }

  // ========== 叠加层控制方法 ==========
  
  /// 显示播放列表
  void _showPlaylist() {
    if (_currentOverlay == PlayerOverlayType.playlist) return;
    
    setState(() {
      _currentOverlay = PlayerOverlayType.playlist;
    });
    _playlistController.forward(from: 0.0);
  }
  
  /// 显示歌词菜单
  void _showLyricsMenu() {
    if (_currentOverlay == PlayerOverlayType.lyricsMenu) return;

    setState(() {
      _currentOverlay = PlayerOverlayType.lyricsMenu;
    });
    _lyricsMenuController.forward(from: 0.0);
  }

  /// 显示播放器菜单(三点窗口)
  void _showPlayerMenuOverlay(Song song, PlayerProvider playerProvider) {
    if (_currentOverlay == PlayerOverlayType.playerMenu) return;

    setState(() {
      _currentOverlay = PlayerOverlayType.playerMenu;
      _overlayCurrentSong = song;
      _overlayPlayerProvider = playerProvider;
    });
    _lyricsMenuController.forward(from: 0.0); // 复用歌词菜单的动画控制器
  }

  /// 显示手动搜索歌词
  void _showSearchLyrics(Song song, PlayerProvider playerProvider) {
    if (_currentOverlay == PlayerOverlayType.searchLyrics) return;
    
    setState(() {
      _currentOverlay = PlayerOverlayType.searchLyrics;
      _overlayCurrentSong = song;
      _overlayPlayerProvider = playerProvider;
      
      // 初始化搜索状态
      _searchLyricsController.text = song.title;
      _searchResults = null;
      _isSearching = false;
      _isFetchingLyric = false;
      _searchErrorMessage = null;
    });
    _dialogOverlayController.forward(from: 0.0);
  }
  
  /// 显示编辑歌词
  void _showEditLyrics(Song song, PlayerProvider playerProvider) {
    if (_currentOverlay == PlayerOverlayType.editLyrics) return;
    if (playerProvider.currentLyrics == null) return;
    
    setState(() {
      _currentOverlay = PlayerOverlayType.editLyrics;
      _overlayCurrentSong = song;
      _overlayPlayerProvider = playerProvider;
      
      // 初始化编辑状态
      _editOriginalLyricsController.text = playerProvider.currentLyrics!.rawOriginalLyrics;
      _editTranslatedLyricsController.text = playerProvider.currentLyrics!.rawTranslatedLyrics ?? '';
      _isSavingLyrics = false;
    });
    _dialogOverlayController.forward(from: 0.0);
  }
  
  /// 显示调整歌词偏移
  void _showAdjustOffset(Song song, PlayerProvider playerProvider) {
    if (_currentOverlay == PlayerOverlayType.adjustLyricsOffset) return;
    if (playerProvider.currentLyrics == null) return;

    setState(() {
      _currentOverlay = PlayerOverlayType.adjustLyricsOffset;
      _overlayCurrentSong = song;
      _overlayPlayerProvider = playerProvider;

      // 初始化偏移量状态，保存原始值用于取消时恢复
      _currentLyricOffset = playerProvider.currentLyrics!.offset.toDouble();
      _originalLyricOffset = _currentLyricOffset;
      _isSavingOffset = false;
    });
    _dialogOverlayController.forward(from: 0.0);
  }
  
  /// 隐藏当前叠加层
  Future<void> _hideOverlay() async {
    if (_currentOverlay == PlayerOverlayType.none) return;

    final overlayToHide = _currentOverlay;

    // 先执行退出动画
    if (overlayToHide == PlayerOverlayType.playlist) {
      await _playlistController.reverse();
    } else if (overlayToHide == PlayerOverlayType.lyricsMenu ||
               overlayToHide == PlayerOverlayType.playerMenu) {
      await _lyricsMenuController.reverse();
    } else if (overlayToHide == PlayerOverlayType.searchLyrics ||
               overlayToHide == PlayerOverlayType.editLyrics ||
               overlayToHide == PlayerOverlayType.adjustLyricsOffset) {
      await _dialogOverlayController.reverse();
    }

    // 动画完成后清除状态
    if (mounted) {
      setState(() {
        _currentOverlay = PlayerOverlayType.none;
        _overlayCurrentSong = null;
        _overlayPlayerProvider = null;
      });
    }
  }

  // ========== 分段动画计算函数 ==========
  
  /// 计算背景透明度（展开动画）
  /// 0-2%: 快速淡入 0.0 → 1.0
  /// 2-95%: 保持完全可见 1.0
  /// 95-100%: 保持可见（收起时才淡出）
  double _calculateBackgroundOpacity(double percentage) {
    if (percentage <= 0.02) {
      // 0-2% 快速淡入
      return (percentage / 0.02).clamp(0.0, 1.0);
    } else {
      // 2-100% 保持完全可见
      return 1.0;
    }
  }
  
  /// 计算背景透明度（收起动画）
  /// 5-100%: 保持可见 1.0
  /// 0-2%: 快速淡出 1.0 → 0.0
  double _calculateBackgroundOpacityReverse(double percentage) {
    if (percentage >= 0.02) {
      return 1.0;
    } else {
      // 2-0% 快速淡出
      return (percentage / 0.02).clamp(0.0, 1.0);
    }
  }
  
  /// 计算小播放器透明度（展开动画）
  /// 0-2%: 快速淡出 1.0 → 0.0
  /// 2-100%: 保持隐藏 0.0
  double _calculateMiniPlayerOpacity(double percentage) {
    if (percentage <= 0.02) {
      // 0-2% 快速淡出
      return (1.0 - (percentage / 0.02)).clamp(0.0, 1.0);
    } else {
      return 0.0;
    }
  }
  
  /// 计算小封面右侧内容的最终透明度
  /// 结合两个因素：
  /// 1. percentage（播放器展开度）：0.5-0.7 淡入淡出
  /// 2. _coverTransitionController（切换动画）：大小封面切换时的淡入淡出
  double _calculateSmallCoverContentFinalOpacity(double percentage) {
    // 基于 percentage 的透明度
    final percentageOpacity = _calculateSmallCoverContentOpacity(percentage);
    
    // 基于切换动画的透明度
    final transitionProgress = _coverTransitionController.value.clamp(0.0, 1.0);
    
    double transitionOpacity;
    if (_targetShowLyrics) {
      // 目标是歌词模式：切换时淡入（0 → 1）
      transitionOpacity = transitionProgress;
    } else {
      // 目标是封面模式：切换时淡出（1 → 0）
      transitionOpacity = 1.0 - transitionProgress;
    }
    
    // 最终透明度 = 两者的乘积
    return (percentageOpacity * transitionOpacity).clamp(0.0, 1.0);
  }
  
  /// 计算小封面右侧内容的透明度（歌名、艺术家、歌词按钮）
  /// 0.7-1.0: 完全显示 1.0
  /// 0.5-0.7: 线性淡出 1.0 → 0.0
  /// 0-0.5: 完全隐藏 0.0
  double _calculateSmallCoverContentOpacity(double percentage) {
    if (percentage >= 0.7) {
      // 0.7-1.0: 完全显示
      return 1.0;
    } else if (percentage >= 0.5) {
      // 0.5-0.7: 线性淡出
      return ((percentage - 0.5) / 0.2).clamp(0.0, 1.0);
    } else {
      // 0-0.5: 完全隐藏
      return 0.0;
    }
  }
  
  /// 计算大封面下方信息的透明度（歌名、艺术家、两个按钮）
  /// 当播放器下拉时在开始阶段快速淡出
  /// 0.95-1.0: 快速淡出 1.0 → 0.0
  /// 0-0.95: 完全隐藏 0.0
  double _calculateLargeCoverInfoOpacity(double percentage) {
    if (percentage >= 0.95) {
      // 0.95-1.0: 快速淡出，限制在 0.0-1.0 范围内
      return ((percentage - 0.95) / 0.05).clamp(0.0, 1.0);
    } else {
      // 0-0.95: 完全隐藏
      return 0.0;
    }
  }
  
  /// 计算小播放器透明度（收起动画）
  /// 5-100%: 保持隐藏 0.0
  /// 0-2%: 快速淡入 0.0 → 1.0
  double _calculateMiniPlayerOpacityReverse(double percentage) {
    if (percentage >= 0.02) {
      return 0.0;
    } else {
      // 2-0% 快速淡入
      return (1.0 - (percentage / 0.02)).clamp(0.0, 1.0);
    }
  }
  
  /// 计算UI块的垂直偏移量
  /// 展开动画：
  ///   0-20%: 保持在底部外
  ///   20-95%: 从底部推入
  ///   95-100%: 保持在正常位置
  /// 收起动画：
  ///   100-95%: 保持静止（关键特性）
  ///   95-20%: 快速向下推出
  ///   20-0%: 已完全退出
  double _calculateUIBlockOffset(double percentage) {
    if (_isExpanding) {
      // 展开动画
      if (percentage <= 0.20) {
        // 0-20% UI块保持在底部外
        return widget.maxHeight;
      } else if (percentage <= 0.95) {
        // 20-95% 从底部平滑推入
        double progress = (percentage - 0.20) / 0.75;
        return widget.maxHeight * (1.0 - Curves.easeOutCubic.transform(progress));
      } else {
        // 95-100% 保持在正常位置
        return 0.0;
      }
    } else {
      // 收起动画
      if (percentage >= 0.95) {
        // 100-95% 保持静止（这是收起动画的关键特性）
        return 0.0;
      } else if (percentage >= 0.20) {
        // 95-20% 快速向下推出
        double progress = (0.95 - percentage) / 0.75;
        return widget.maxHeight * Curves.easeInCubic.transform(progress);
      } else {
        // 20-0% 已完全退出
        return widget.maxHeight;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return PopScope(
      // 只在全屏模式且没有叠加层时拦截返回
      canPop: widget.percentage < 0.9 || _currentOverlay != PlayerOverlayType.none,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // 如果有叠加层，先关闭叠加层
          if (_currentOverlay != PlayerOverlayType.none) {
            _hideOverlay();
            return;
          }

          // 如果是全屏播放器，调用回调缩小播放器
          if (widget.percentage >= 0.9) {
            widget.onRequestClose?.call();
          }
        }
      },
      child: Consumer<PlayerProvider>(
        builder: (context, playerProvider, child) {
          final currentSong = playerProvider.currentSong;
          final isPlaying = playerProvider.isPlaying;

          // ⭐ 检测歌曲变化并自动加载歌词
          if (currentSong != null && currentSong.id != _lastSongId) {
            _lastSongId = currentSong.id;
            // 使用 post frame callback 避免在 build 过程中调用 setState
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                playerProvider.loadLyrics();
              }
            });
          }

          // ========== 动画方向判断 ==========
          // 通过比较当前百分比和上一帧百分比来判断动画方向
          if (widget.percentage > _previousPercentage) {
            _isExpanding = true;
          } else if (widget.percentage < _previousPercentage) {
            _isExpanding = false;
          }
          _previousPercentage = widget.percentage;

          return LayoutBuilder(
            builder: (context, constraints) {
              // 更新容器尺寸缓存，用于动画计算
              final widthChanged = _containerWidth != constraints.maxWidth;
              final heightChanged = _containerHeight != constraints.maxHeight;
              
              _containerWidth = constraints.maxWidth;
              _containerHeight = constraints.maxHeight;
              
              // 容器尺寸变化时，同步动画目标值
              if (widthChanged || heightChanged) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _syncAnimationWithCurrentMode();
                });
              }

              return Stack(
                children: [
                  // 背景层（从0%开始显示，但透明度从0渐变）
                  if (widget.percentage > 0.0) _buildBackground(currentSong),

                  // 迷你播放器层（percentage < 0.5 时显示）
                  if (widget.percentage < 0.5)
                    _buildMiniPlayerLayer(currentSong, playerProvider, isPlaying),

                  // ============ 封面动画层（始终渲染，z-index: 2） ============
                  _buildContinuousAnimatedCover(
                    currentSong,
                    isPlaying,
                    playerProvider,
                    constraints.maxWidth,
                    constraints.maxHeight,
                  ),

                  // ============ 全屏播放器层（z-index: 3，在封面上方） ============
                  if (widget.percentage > 0.20)
                    Positioned.fill(
                      child: _buildExpandedLayerWithCoverCalculation(
                        currentSong,
                        playerProvider,
                        isPlaying,
                        screenSize,
                      ),
                    ),

                  // ============ 播放列表叠加层(z-index: 4,从右侧滑入) ============
                  if (_currentOverlay == PlayerOverlayType.playlist && widget.percentage > 0.7)
                    _buildPlaylistOverlay(playerProvider),

                  // ============ 歌词菜单叠加层(z-index: 5,从底部滑入) ============
                  if (_currentOverlay == PlayerOverlayType.lyricsMenu && widget.percentage > 0.7)
                    _buildLyricsMenuOverlay(currentSong, playerProvider),

                  // ============ 播放器菜单叠加层(z-index: 6,从底部滑入,三点窗口) ============
                  if (_currentOverlay == PlayerOverlayType.playerMenu && widget.percentage > 0.7) ...[
                    Builder(
                      builder: (context) {
                        return _buildPlayerMenuOverlay();
                      },
                    ),
                  ] else if (_currentOverlay == PlayerOverlayType.playerMenu) ...[
                    Builder(
                      builder: (context) {
                        return const SizedBox.shrink();
                      },
                    ),
                  ],

                  // ============ 手动搜索歌词叠加层(z-index: 7,对话框样式) ============
                  if (_currentOverlay == PlayerOverlayType.searchLyrics && widget.percentage > 0.7)
                    _buildSearchLyricsOverlay(),

                  // ============ 编辑歌词叠加层(z-index: 8,对话框样式) ============
                  if (_currentOverlay == PlayerOverlayType.editLyrics && widget.percentage > 0.7)
                    _buildEditLyricsOverlay(),

                  // ============ 调整偏移量叠加层(z-index: 9,对话框样式) ============
                  if (_currentOverlay == PlayerOverlayType.adjustLyricsOffset && widget.percentage > 0.7)
                    _buildAdjustOffsetOverlay(),
                  
                  // ============ 收藏夹选择叠加层(z-index: 10,从底部滑入) ============
                  if (_currentOverlay == PlayerOverlayType.favoriteSelection && widget.percentage > 0.7)
                    _buildFavoriteSelectionOverlay(),
                ],
              );
            },
          );
        },
      ),
    );
  }
  
  /// 构建连续动画的封面（分段插值优化版）
  Widget _buildContinuousAnimatedCover(
    Song? currentSong,
    bool isPlaying,
    PlayerProvider playerProvider,
    double containerWidth,
    double containerHeight,
  ) {
    // ============ 基础参数 ============
    const miniSize = 60.0;
    const miniLeft = 20.0;
    const miniTop = 10.0; // 保持迷你模式的原始位置
    const miniBorderRadius = 12.0;
    
    // ============ 使用 AnimatedBuilder 监听动画 ============
    return AnimatedBuilder(
      animation: _coverTransitionController,
      builder: (context, child) {
        // 使用动画后的目标值
        final targetSize = _coverSizeAnimation.value;
        final targetLeft = _coverLeftAnimation.value;
        final targetTop = _coverTopAnimation.value;
        final targetBorderRadius = _coverRadiusAnimation.value;
        
        // ============ 连续插值计算 ============
        // 使用整个 0.0-1.0 区间的 percentage 进行插值
        // 为满足「直线运行、线性变大」的需求，这里使用线性进度，不再额外施加缓动曲线
        final double coverProgress = widget.percentage.clamp(0.0, 1.0);

        // 尺寸与位置插值（从迷你模式到当前模式的目标状态）
        double size = miniSize + (targetSize - miniSize) * coverProgress;
        double left = miniLeft + (targetLeft - miniLeft) * coverProgress;
        double top = miniTop + (targetTop - miniTop) * coverProgress;
        double borderRadius =
            miniBorderRadius + (targetBorderRadius - miniBorderRadius) * coverProgress;

        // ============ 防止封面被容器裁剪 ============
        // 由于最外层 ExpandablePlayer 使用 clipBehavior: Clip.hardEdge，当容器高度变小时，
        // 需要确保封面始终落在 [0, containerHeight - size] 范围内，避免上下被硬裁剪。
        final double maxTop = (containerHeight - size).clamp(0.0, double.infinity);
        top = top.clamp(0.0, maxTop);
        
        // ============ 统一渲染逻辑：使用 Stack 和 AnimatedOpacity 实现淡入淡出 ============
        return Stack(
          children: [
            // ============ 封面（始终渲染） ============
            Positioned(
              left: left,
              top: top,
              child: GestureDetector(
                onTap: widget.percentage > 0.7 ? _toggleView : null,
                child: AnimatedScale(
                  key: const ValueKey('cover_scale'),
                  scale: isPlaying ? 1.0 : 0.95,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                      color: Colors.grey[800],
                      boxShadow: widget.percentage > 0.5 && !_showLyrics
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6 * widget.percentage),
                                blurRadius: 50 * widget.percentage,
                                spreadRadius: 5 * widget.percentage,
                                offset: Offset(0, 15 * widget.percentage),
                              ),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: currentSong?.albumArtPath != null
                        ? _buildAlbumArt(currentSong!.albumArtPath!, fit: BoxFit.cover)
                        : const Icon(Icons.music_note, size: 30, color: Colors.white54),
                  ),
                ),
              ),
            ),
            
            // ============ 歌词模式的歌名和艺术家（固定位置，淡入淡出） ============
            // 在切换动画过程中也渲染，实现平滑淡入淡出
            if (_showLyrics || _coverTransitionController.isAnimating)
              Positioned(
                left: 92, // 固定在封面右侧（20 + 60 + 12）
                top: _getLyricsModeCoverTop(), // 使用固定位置，不跟随动画
                right: 80, // 为歌词按钮留出空间
                child: Opacity(
                  opacity: _calculateSmallCoverContentFinalOpacity(widget.percentage),
                  child: IgnorePointer(
                    ignoring: _calculateSmallCoverContentFinalOpacity(widget.percentage) < 0.1, // 透明时禁用交互
                    child: SizedBox(
                      height: 60, // 固定高度，与小封面一致
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ScrollingText(
                            text: currentSong?.title ?? '未知歌曲',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            scrollSpeed: 30.0,
                            maxWidth: 200,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentSong?.artist ?? '未知艺术家',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            
            // ============ 歌词按钮（固定位置，淡入淡出） ============
            // 在切换动画过程中也渲染，实现平滑淡入淡出
            if (_showLyrics || _coverTransitionController.isAnimating)
              Positioned(
                top: _getLyricsModeCoverTop(), // 使用固定位置，不跟随动画
                right: 20,
                child: Opacity(
                  opacity: _calculateSmallCoverContentFinalOpacity(widget.percentage),
                  child: IgnorePointer(
                    ignoring: _calculateSmallCoverContentFinalOpacity(widget.percentage) < 0.1, // 透明时禁用交互
                    child: SizedBox(
                      height: 60, // 固定高度，垂直居中
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.lyrics, color: Colors.white),
                          tooltip: '歌词操作',
                          onPressed: _showLyricsMenu,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
  
  /// 构建全屏播放器层（计算内容区尺寸并渲染封面）
  Widget _buildExpandedLayerWithCoverCalculation(
    Song? currentSong,
    PlayerProvider playerProvider,
    bool isPlaying,
    Size screenSize,
  ) {
    // 计算UI块的垂直偏移量
    final uiBlockOffset = _calculateUIBlockOffset(widget.percentage);
    
    return Transform.translate(
      offset: Offset(0, uiBlockOffset),
      child: Column(
        children: [
          // 顶部导航栏
          _buildTopBar(currentSong, playerProvider),
          
          // 主内容区（不再包含 AnimatedCoverArt，由外层统一渲染）
          // 使用 LayoutBuilder 获取实际可用高度，避免直接使用整屏高度导致尺寸误差
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildMainContentStack(
                  currentSong,
                  playerProvider,
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
              },
            ),
          ),
          
          // 底部控制区
          _buildBottomControls(currentSong, playerProvider, isPlaying),
        ],
      ),
    );
  }

  /// 构建背景层（毛玻璃效果 + 圆角 + 从小播放器位置展开）
  /// 
  /// 0-2% 期间，背景毛玻璃与小播放器使用完全相同的尺寸和位置动画
  /// 两者完全重叠，通过透明度切换实现视觉过渡
  Widget _buildBackground(Song? currentSong) {
    // 使用平滑的透明度曲线，避免突然消失
    final smoothOpacity = _calculateSmoothOpacity(widget.percentage);
    
    // 小播放器的精确参数（与 _buildMiniPlayerLayer 完全一致）
    const miniPlayerLeft = 8.0;
    const miniPlayerRight = 8.0;
    const miniPlayerTop = 4.0;
    const miniPlayerBottom = 0.0; // 小播放器底部贴近容器底部
    const miniPlayerBorderRadius = 12.0;
    
    // 计算当前背景的位置和尺寸
    double bgLeft, bgRight, bgTop, bgBottom, bgBorderRadius;
    
    if (widget.percentage <= 0.02) {
      // 0-2% 从小播放器尺寸平滑过渡到全屏
      final progress = widget.percentage / 0.02;  // 0.0 → 1.0
      
      bgLeft = miniPlayerLeft * (1.0 - progress);  // 8 → 0
      bgRight = miniPlayerRight * (1.0 - progress);  // 8 → 0
      bgTop = miniPlayerTop * (1.0 - progress);  // 4 → 0
      bgBottom = miniPlayerBottom * (1.0 - progress);  // 0 → 0 (始终贴底)
      bgBorderRadius = miniPlayerBorderRadius;  // 始终保持 12
    } else {
      // 2%以后完全展开到全屏
      bgLeft = 0;
      bgRight = 0;
      bgTop = 0;
      bgBottom = 0;
      bgBorderRadius = miniPlayerBorderRadius;  // 全屏也保持 12 圆角
    }
    
    return Positioned(
      left: bgLeft,
      right: bgRight,
      top: bgTop,
      bottom: bgBottom,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(bgBorderRadius),
        child: Opacity(
          opacity: smoothOpacity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 专辑封面作为背景
              if (currentSong?.albumArtPath != null)
                _buildAlbumArt(
                  currentSong!.albumArtPath!,
                  fit: BoxFit.cover,
                ),
              // 毛玻璃效果
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 20 * smoothOpacity,
                  sigmaY: 20 * smoothOpacity,
                ),
                child: Container(
                  color: Colors.black.withOpacity(0.6 * smoothOpacity),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 计算平滑的透明度，避免突然消失
  double _calculateSmoothOpacity(double percentage) {
    // 使用分段函数，根据动画方向选择不同的计算逻辑
    if (_isExpanding) {
      return _calculateBackgroundOpacity(percentage);
    } else {
      return _calculateBackgroundOpacityReverse(percentage);
    }
  }

  /// 构建迷你播放器层（Apple Music 风格）
  Widget _buildMiniPlayerLayer(
    Song? currentSong,
    PlayerProvider playerProvider,
    bool isPlaying,
  ) {
    // 使用分段函数计算透明度
    final opacity = _isExpanding 
        ? _calculateMiniPlayerOpacity(widget.percentage)
        : _calculateMiniPlayerOpacityReverse(widget.percentage);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Positioned(
      left: 8,
      right: 8,
      top: 4,
      child: Opacity(
        opacity: opacity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12), // 仅在此处设置圆角
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // 毛玻璃效果
            child: Container(
              height: 76, // 恢复原迷你播放器高度，保持视觉比例
              decoration: BoxDecoration(
                // 深浅模式自适应背景
                color: isDarkMode
                    ? Colors.black.withOpacity(0.6)  // 深色模式：60% 黑色
                    : Colors.white.withOpacity(0.8), // 浅色模式：80% 白色
                // 🔧 移除borderRadius，避免与ClipRRect冲突
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  width: 0.5,
                ),
                // 精致的阴影
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // 预留封面位置（60x60 + 12 间距）
                  const SizedBox(width: 72),
                  
                  // 歌曲信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentSong?.title ?? '未播放',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentSong?.artist ?? '选择歌曲开始播放',
                          style: TextStyle(
                            color: isDarkMode 
                                ? Colors.white.withOpacity(0.6)
                                : Colors.black.withOpacity(0.5),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // 播放控制按钮组
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 上一首按钮 - 双三角形图标
                      IconButton(
                        icon: Icon(
                          Icons.fast_rewind_rounded,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        iconSize: 24,
                        padding: const EdgeInsets.all(6),
                        onPressed: currentSong != null && playerProvider.hasPrevious
                            ? () => playerProvider.previous()
                            : null,
                      ),
                      // 播放/暂停按钮 - 无背景，极简设计
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        iconSize: 28, // 稍微放大，补偿背景移除
                        padding: const EdgeInsets.all(6),
                        onPressed: currentSong != null
                            ? () => playerProvider.togglePlay()
                            : null,
                      ),
                      // 下一首按钮 - 双三角形图标
                      IconButton(
                        icon: Icon(
                          Icons.fast_forward_rounded,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        iconSize: 24,
                        padding: const EdgeInsets.all(6),
                        onPressed: currentSong != null && playerProvider.hasNext
                            ? () => playerProvider.next()
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// 构建主内容 Stack（包含布局计算）
  Widget _buildMainContentStack(
    Song? currentSong,
    PlayerProvider playerProvider,
    double contentWidth,
    double contentHeight,
  ) {
    return Column(
      children: [
        // 主视图区域：使用 Stack 同时渲染两个内容，用 AnimatedOpacity 控制显示
        Expanded(
          child: Stack(
            children: [
              // 大封面模式内容（用 AnimatedOpacity 控制淡入淡出）
              AnimatedOpacity(
                opacity: _targetShowLyrics ? 0.0 : 1.0, // 使用目标状态,与封面动画同步
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: _targetShowLyrics,
                  child: _buildCoverSpacerContent(currentSong, playerProvider, contentWidth, contentHeight),
                ),
              ),
              
              // 歌词模式内容（用 AnimatedOpacity 控制淡入淡出）
              AnimatedOpacity(
                opacity: _targetShowLyrics ? 1.0 : 0.0, // 使用目标状态，与封面动画同步
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: !_targetShowLyrics,
                  child: _buildLyricsContent(currentSong, playerProvider),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建顶部导航栏（预留封面空间）
  Widget _buildTopBar(Song? currentSong, PlayerProvider playerProvider) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 68, // 保持原始高度，不影响内容区布局
      ),
    );
  }

  /// 构建歌词内容（不包含歌名，歌名由 Positioned 独立渲染）
  Widget _buildLyricsContent(Song? currentSong, PlayerProvider playerProvider) {
    // 正确计算歌词的顶部边距，紧贴小封面底部
    // 
    // 布局层级：
    // - 屏幕顶部
    // - SafeArea
    // - _buildTopBar (高度 68px)
    // - Expanded (Stack 的父容器) ← Stack 起始位置
    //
    // 小封面绝对位置：SafeArea.top + 61px
    // 小封面高度：60px
    // 封面底部绝对位置：SafeArea.top + 121px
    // Stack 起始位置：SafeArea.top + 68px
    // 歌词 padding（相对于 Stack）：121 - 68 = 53px
    
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final topBarHeight = 68.0;
    final coverTop = safeAreaTop + 61.0;
    final coverHeight = 60.0;
    final coverBottom = coverTop + coverHeight; // safeAreaTop + 121
    
    final stackTop = safeAreaTop + topBarHeight; // safeAreaTop + 68
    final lyricsTopPadding = coverBottom - stackTop; // 53px（相对于 Stack 顶部）
    
    return Padding(
      padding: EdgeInsets.only(top: lyricsTopPadding),
      child: ShaderMask(
        key: const ValueKey('lyrics_content'),
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.1, 0.9, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: _buildLyricsWidget(currentSong, playerProvider),
      ),
    );
  }

  /// 构建小封面模式的信息栏（歌名、作者、歌词按钮）
  Widget _buildSmallCoverInfoBar(Song? currentSong, PlayerProvider playerProvider) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 4,
          bottom: 4,
        ),
        child: SizedBox(
          height: 60, // 固定高度，与小封面一致
          child: Row(
            children: [
              // 歌名和艺术家（在封面右侧）
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 72), // 为小封面留出空间（60 + 12）
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScrollingText(
                        text: currentSong?.title ?? '未知歌曲',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        scrollSpeed: 30.0,
                        maxWidth: 200,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentSong?.artist ?? '未知艺术家',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              
              // 歌词按钮
              IconButton(
                icon: const Icon(Icons.lyrics, color: Colors.white),
                tooltip: '歌词操作',
                onPressed: _showLyricsMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建封面占位内容（响应式计算封面尺寸）
  Widget _buildCoverSpacerContent(
    Song? currentSong,
    PlayerProvider playerProvider,
    double contentWidth,
    double contentHeight,
  ) {
    // 🔧 响应式预留空间计算（短屏幕适配）
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 顶部预留：根据屏幕高度动态调整（12% ~ 10%）
    final topReserved = screenHeight < 650 
        ? screenHeight * 0.10  // 极短屏：~60-65px
        : screenHeight < 750 
            ? screenHeight * 0.12  // 短屏：~78-90px
            : 100.0;  // 正常屏：100px
    
    // 底部UI实际高度（紧凑计算）
    final coverBottomSpacing = screenHeight < 650 ? 8.0 : 12.0;
    final songInfoHeight = 60.0;
    final buttonRowHeight = 48.0;
    final progressBarHeight = screenHeight < 650 ? 32.0 : 40.0;
    final controlsHeight = screenHeight < 650 ? 64.0 : 80.0;
    final bottomButtonsHeight = 60.0;
    final totalSpacing = screenHeight < 650 ? 20.0 : 30.0;
    
    final calculatedBottom = coverBottomSpacing + songInfoHeight + 
                             buttonRowHeight + progressBarHeight + 
                             controlsHeight + bottomButtonsHeight + 
                             totalSpacing;
    
    // 底部预留：使用实际测量值，不再强制 35%
    final bottomReserved = calculatedBottom;
    
    // 可用高度计算
    final availableHeight = contentHeight - topReserved - bottomReserved;
    
    // 封面尺寸：动态最小值，避免重叠
    final coverMinSize = screenHeight < 650 
        ? screenHeight * 0.26  // 极短屏：~156-169px
        : screenHeight < 750 
            ? screenHeight * 0.28  // 短屏：~182-210px
            : 200.0;  // 正常屏：200px
    
    final largeCoverSize = min(contentWidth * 0.80, availableHeight)
        .clamp(coverMinSize, 400.0);

    // 基于内容区域高度的安全封面尺寸，保证不会撑爆 Column
    // 固定区域估算：封面与文字间距 12 + 文本及按钮区域约 72
    const double minReservedForInfo = 84.0;
    final double maxCoverByContent =
        (contentHeight - minReservedForInfo).clamp(0.0, double.infinity);

    double safeCoverSize;
    if (maxCoverByContent <= 0) {
      // 极端小高度：退化为内容高度的一半，并受宽度与上限约束，避免出现负值
      final fallback = min(contentWidth * 0.8, contentHeight * 0.5);
      safeCoverSize = fallback.clamp(0.0, 400.0);
    } else {
      safeCoverSize = largeCoverSize;
      if (safeCoverSize > maxCoverByContent) {
        safeCoverSize = maxCoverByContent;
      }
      safeCoverSize = safeCoverSize.clamp(0.0, 400.0);
    }
    
    // 进一步根据内容高度在顶部与底部之间分配剩余空间
    // 目标：在上下安全空间内，让「顶端→封面→歌名行→底部控制区」的视觉间距尽量均衡
    // 注意：人眼感知的是模块中心的距离，而不是几何边界，因此这里使用加权间距而非纯等分
    const double infoBlockEstimatedHeight = 72.0; // 歌名 + 艺术家 + 按钮区域的估算高度
    final double remainingSpace =
        (contentHeight - (safeCoverSize + infoBlockEstimatedHeight))
            .clamp(0.0, double.infinity);

    double topGap = 0;
    double middleGap = 0;
    double bottomGap = 0;

    if (remainingSpace > 0) {
      // 为了满足「封面-歌名间距保持不变，歌名-播放条更近」：
      // - middleGap 保持与上一版本大致相同的比例（约 1.3 / 3）
      // - bottomGap 在相同 remainingSpace 下进一步缩短
      // - 剩余空间自动分配给 topGap
      const double middleRatio = 1.3 / 3.0; // ~0.4333，与之前保持一致
      const double bottomRatio = 0.12;      // 再次缩短歌名与播放条之间的间距

      middleGap = remainingSpace * middleRatio;
      bottomGap = remainingSpace * bottomRatio;
      topGap = (remainingSpace - middleGap - bottomGap).clamp(0.0, double.infinity);
    }

    return Column(
      key: const ValueKey('cover_spacer_content'),
      children: [
        // 顶部间距：将多余空间的一部分放在封面上方
        if (topGap > 0) SizedBox(height: topGap),
        // 预留封面空间（由 AnimatedCoverArt 渲染），使用经过内容高度校正后的安全尺寸
        SizedBox(
          height: safeCoverSize,
        ),
        // 封面与歌名/按钮信息之间的间距（略大于顶部和底部，提升视觉平衡）
        if (middleGap > 0) SizedBox(height: middleGap),
        // 🔧 歌名、作者和功能按钮（左对齐布局，原地淡出）
        Opacity(
          opacity: _calculateLargeCoverInfoOpacity(widget.percentage),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center, // 改为center，让按钮垂直居中
              children: [
              // 左侧：歌名和艺术家（左对齐，可滚动）
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScrollingText(
                      text: currentSong?.title ?? '未知歌曲',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18, // 从24缩小到18
                        fontWeight: FontWeight.bold,
                      ),
                      scrollSpeed: 40.0,
                    ),
                    const SizedBox(height: 4), // 从8减小到4
                    Text(
                      currentSong?.artist ?? '未知艺术家',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 18, // 从16增大到18，与歌名一致
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 右侧：功能按钮（喜欢 + 详情）- Apple Music 风格，横向排列
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 喜欢按钮 - 液态玻璃圆形衬底
                  Consumer<PlayerProvider>(
                    builder: (context, playerProvider, child) {
                      final currentSong = playerProvider.currentSong;
                      final isFavorite = currentSong?.isFavorite ?? false;
                      
                      return ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.red.shade400 : Colors.white,
                              ),
                              iconSize: 18, // 放大1.5倍 (12 * 1.5 = 18)
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: currentSong != null
                                  ? () => _toggleFavorite(currentSong, playerProvider)
                                  : null,
                              tooltip: isFavorite ? '取消喜欢' : '喜欢',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // 三点详情按钮 - 液态玻璃圆形衬底
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.more_horiz,
                            color: Colors.white,
                          ),
                          iconSize: 18, // 放大1.5倍 (12 * 1.5 = 18)
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: currentSong != null
                              ? () {
                                  _showPlayerMenuOverlay(currentSong, playerProvider);
                                }
                              : null,
                          tooltip: '更多',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ), // 关闭 Opacity
        // 底部间距：歌名/按钮到底部控制区之间，略小于中间间距，抵消下方控件自身的 padding
        if (bottomGap > 0) SizedBox(height: bottomGap),
      ],
    );
  }

  /// 构建歌词Widget
  Widget _buildLyricsWidget(Song? currentSong, PlayerProvider playerProvider) {
    // 优先使用playerProvider的歌词
    final lyrics = playerProvider.currentLyrics;
    
    if (lyrics != null && lyrics.lyrics != null && lyrics.lyrics!.isNotEmpty) {
      return KaraokeLyricsView(
        // 只使用歌曲ID和歌词内容作为key，避免偏移量变化时重建整个视图
        key: ValueKey('${currentSong?.id}_${lyrics.rawOriginalLyrics.hashCode}'),
        lyricsContent: lyrics.rawOriginalLyrics,
        currentPosition: playerProvider.position,
        offsetInSeconds: lyrics.offset,
        onTapLine: (time) {
          playerProvider.seekTo(time);
        },
      );
    }
    
    // 回退到使用Song的lyrics字段
    if (currentSong?.lyrics != null && currentSong!.lyrics!.isNotEmpty) {
      return KaraokeLyricsView(
        key: ValueKey(currentSong.id),
        lyricsContent: currentSong.lyrics,
        currentPosition: playerProvider.position,
        offsetInSeconds: 0.0, // 数据库歌词默认无偏移
        onTapLine: (time) {
          playerProvider.seekTo(time);
        },
      );
    }
    
    // 显示加载状态或暂无歌词
    if (playerProvider.isLoadingLyrics) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Text(
              '正在加载歌词...',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }
    
    return const Center(
      child: Text(
        '暂无歌词',
        style: TextStyle(color: Colors.white54, fontSize: 16),
      ),
    );
  }

  /// 构建底部控制区（响应式 padding + 短屏幕适配）
  Widget _buildBottomControls(
    Song? currentSong,
    PlayerProvider playerProvider,
    bool isPlaying,
  ) {
    // 响应式计算底部 padding（短屏幕减小）
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = screenHeight < 650 
        ? 16.0  // 极短屏：减小底部间距
        : (screenHeight * 0.03).clamp(20.0, 40.0);
    
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            _buildProgressBar(playerProvider, currentSong),
            const SizedBox(height: 16),
            // 播放控制按钮
            _buildControlButtons(playerProvider, isPlaying, currentSong),
            const SizedBox(height: 12),
            // 功能按钮（切换按钮 + 播放列表）
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ToggleButton(
                  showLyrics: _showLyrics,
                  onToggle: _toggleView,
                ),
                const SizedBox(width: 16),
                PlaylistButton(
                  onTap: _showPlaylist, // 直接调用内嵌叠加层
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建进度条（短屏幕适配高度）
  Widget _buildProgressBar(PlayerProvider playerProvider, Song? currentSong) {
    final screenHeight = MediaQuery.of(context).size.height;
    final trackHeight = screenHeight < 650 ? 5.0 : 6.0;  // 极短屏减小高度
    
    return Column(
      children: [
        ValueListenableBuilder<Duration>(
          valueListenable: playerProvider.position,
          builder: (context, position, child) {
            double sliderValue = (_tempSliderValue >= 0
                    ? _tempSliderValue
                    : (playerProvider.duration.inMilliseconds > 0
                        ? position.inMilliseconds / playerProvider.duration.inMilliseconds
                        : 0.0))
                .clamp(0.0, 1.0);

            return AnimatedTrackHeightSlider(
              trackHeight: trackHeight,
              value: sliderValue,
              min: 0.0,
              max: 1.0,
              onChanged: currentSong != null
                  ? (value) {
                      setState(() {
                        _tempSliderValue = value;
                      });
                    }
                  : null,
              onChangeEnd: currentSong != null
                  ? (value) async {
                      final newPosition = Duration(
                        milliseconds: (value * playerProvider.duration.inMilliseconds).round(),
                      );
                      await playerProvider.seekTo(newPosition);
                      setState(() {
                        _tempSliderValue = -1;
                      });
                    }
                  : null,
            );
          },
        ),
        const SizedBox(height: 8),
        // 时间标签
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ValueListenableBuilder<Duration>(
                valueListenable: playerProvider.position,
                builder: (context, position, child) {
                  return Text(
                    CommonUtils.formatDuration(position),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  );
                },
              ),
              Text(
                CommonUtils.formatDuration(playerProvider.duration),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建控制按钮 - Apple Music 风格（短屏幕适配尺寸）
  Widget _buildControlButtons(
    PlayerProvider playerProvider,
    bool isPlaying,
    Song? currentSong,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final shuffleSize = screenHeight < 650 ? 24.0 : 28.0;
    final prevNextSize = screenHeight < 650 ? 32.0 : 36.0;
    final playSize = screenHeight < 650 ? 44.0 : 50.0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 随机播放 - 简洁按钮
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color: playerProvider.playMode == PlayMode.shuffle
                ? Colors.white
                : Colors.white54,
          ),
          iconSize: shuffleSize,
          onPressed: () {
            if (playerProvider.playMode == PlayMode.shuffle) {
              playerProvider.setPlayMode(PlayMode.sequence);
            } else {
              playerProvider.setPlayMode(PlayMode.shuffle);
            }
          },
        ),
        // 上一首 - Apple Music 双三角形图标
        IconButton(
          icon: const Icon(Icons.fast_rewind_rounded, color: Colors.white),
          iconSize: prevNextSize,
          onPressed: (playerProvider.playMode == PlayMode.sequence && !playerProvider.hasPrevious)
              ? null
              : () => playerProvider.previous(),
        ),
        // 播放/暂停 - 无背景，极简设计
        IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
          ),
          iconSize: playSize,
          onPressed: currentSong != null ? () => playerProvider.togglePlay() : null,
        ),
        // 下一首 - Apple Music 双三角形图标
        IconButton(
          icon: const Icon(Icons.fast_forward_rounded, color: Colors.white),
          iconSize: prevNextSize,
          onPressed: (playerProvider.playMode == PlayMode.sequence && !playerProvider.hasNext)
              ? null
              : () => playerProvider.next(),
        ),
        // 循环模式 - 简洁按钮
        IconButton(
          icon: Icon(
            playerProvider.playMode == PlayMode.singleLoop
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: playerProvider.playMode == PlayMode.loop ||
                    playerProvider.playMode == PlayMode.singleLoop
                ? Colors.white
                : Colors.white54,
          ),
          iconSize: shuffleSize,
          onPressed: () {
            if (playerProvider.playMode == PlayMode.singleLoop) {
              playerProvider.setPlayMode(PlayMode.sequence);
            } else {
              playerProvider.setPlayMode(
                playerProvider.playMode == PlayMode.loop
                    ? PlayMode.singleLoop
                    : PlayMode.loop,
              );
            }
          },
        ),
      ],
    );
  }

  /// 构建专辑封面图片（统一使用 UnifiedCoverImage）
  Widget _buildAlbumArt(String albumArtPath, {BoxFit? fit}) {
    return UnifiedCoverImage(
      coverPath: albumArtPath,
      width: double.infinity,
      height: double.infinity,
      borderRadius: 0,
      fit: fit ?? BoxFit.cover,
    );
  }

  // ========== 叠加层UI构建方法 ==========

  /// 生成歌曲唯一键（用于歌词缓存）
  ///
  /// ⭐ 统一使用 LyricService 的方法，确保与缓存系统一致
  String _getUniqueKey(Song song) {
    return lyricService.generateUniqueKey(song);
  }
  
  /// 构建播放列表叠加层（从底部滑入，液态玻璃风格）
  Widget _buildPlaylistOverlay(PlayerProvider playerProvider) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _hideOverlay, // 点击遮罩关闭
        child: Container(
          color: Colors.black54, // 半透明遮罩
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _playlistSlideAnimation,
              child: GestureDetector(
                onTap: () {}, // 阻止点击穿透到遮罩
                // iOS风格拖拽关闭功能（支持双向拖动）
                onVerticalDragUpdate: (details) {
                  final containerHeight = MediaQuery.of(context).size.height * 0.70;
                  // 计算拖拽进度变化量
                  // 向下拖拽（delta.dy > 0）减少进度，向上拖拽（delta.dy < 0）增加进度
                  final delta = -details.delta.dy / containerHeight;
                  // 实时更新动画控制器值（确保在 0.0 到 1.0 之间）
                  _playlistController.value = (_playlistController.value + delta).clamp(0.0, 1.0);
                },
                onVerticalDragEnd: (details) {
                  // 判断是否应该关闭
                  final velocity = details.velocity.pixelsPerSecond.dy;
                  final position = _playlistController.value;
                  
                  // 条件：快速向下滑动 (velocity > 300) 或 拖拽超过一半 (position < 0.5)
                  if (velocity > 300 || position < 0.5) {
                    _hideOverlay(); // 关闭播放列表
                  } else {
                    _playlistController.forward(); // 回弹到完全展开
                  }
                },
                // 拦截水平拖拽，防止穿透到播放器的侧滑返回
                onHorizontalDragUpdate: (details) {},
                onHorizontalDragEnd: (details) {},
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.70,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.5)
                            : Colors.white.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: _buildPlaylistContent(playerProvider),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 为播放列表项生成稳定且尽量唯一的 Key，避免 Dismissible 重复 key 导致渲染异常
  Key _buildPlaylistItemKey(Song song) {
    final components = <String>[
      song.id.toString(),
      song.bvid ?? '',
      (song.cid ?? 0).toString(),
      (song.pageNumber ?? 0).toString(),
      (song.dateAdded?.millisecondsSinceEpoch ?? 0).toString(),
    ];
    return ValueKey<String>(components.join('_'));
  }

  /// 构建播放列表内容
  Widget _buildPlaylistContent(PlayerProvider playerProvider) {
    return ValueListenableBuilder<List<Song>>(
      valueListenable: playerProvider.playlistNotifier,
      builder: (context, playlist, _) {
        return ValueListenableBuilder<Song?>(
          valueListenable: playerProvider.currentSongNotifier,
          builder: (context, currentSong, __) {
            debugPrint(
              '[PlaylistOverlay] 重建: length=${playlist.length}, '
              'currentSongId=${currentSong?.id}, title=${currentSong?.title}',
            );

            return Column(
              children: [
                // 顶部拖拽指示器
                Container(
                  margin: const EdgeInsets.only(top: 6, bottom: 2),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // 标题栏
                SafeArea(
                  bottom: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.queue_music_rounded,
                              color: Theme.of(context).iconTheme.color,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '播放列表',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '共 ${playlist.length} 首',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          onPressed: _hideOverlay,
                        ),
                      ],
                    ),
                  ),
                ),

                // 歌曲列表
                Expanded(
                  child: playlist.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.music_off_rounded,
                                size: 64,
                                color: Theme.of(context)
                                    .iconTheme
                                    .color
                                    ?.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '播放列表为空',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withOpacity(0.5),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          itemCount: playlist.length,
                          padding: const EdgeInsets.only(bottom: 20),
                          onReorder: (oldIndex, newIndex) {
                            // 调用 PlayerProvider 的重排序方法
                            playerProvider.reorderPlaylist(oldIndex, newIndex);
                          },
                          proxyDecorator: (child, index, animation) {
                            // Apple Music 风格的拖动效果
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                final double elevation = Tween<double>(
                                  begin: 0.0,
                                  end: 8.0,
                                ).evaluate(animation);
                                final double scale = Tween<double>(
                                  begin: 1.0,
                                  end: 1.03,
                                ).evaluate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInOut,
                                  ),
                                );
                                return Transform.scale(
                                  scale: scale,
                                  child: Material(
                                    elevation: elevation,
                                    color: Colors.transparent,
                                    shadowColor:
                                        Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    child: child,
                                  ),
                                );
                              },
                              child: child,
                            );
                          },
                          itemBuilder: (context, index) {
                            final song = playlist[index];
                            final currentIndex = playerProvider.currentIndex;
                            final isPlaying =
                                currentIndex >= 0 && index == currentIndex;

                            if (index < 3) {
                              debugPrint(
                                '[PlaylistOverlay] item[$index]: '
                                'songId=${song.id}, bvid=${song.bvid}, '
                                'cid=${song.cid}, page=${song.pageNumber}, '
                                'title=${song.title}, isPlaying=$isPlaying',
                              );
                            }

                            return _buildPlaylistItem(
                              context,
                              song,
                              index,
                              isPlaying,
                              playerProvider,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  /// 构建播放列表单项
  Widget _buildPlaylistItem(
    BuildContext context,
    Song song,
    int index,
    bool isPlaying,
    PlayerProvider playerProvider,
  ) {
    return Dismissible(
      key: _buildPlaylistItemKey(song), // 使用更稳定且唯一的 key，避免重复导致的渲染异常
      direction: DismissDirection.horizontal, // 🔧 支持左滑和右滑
      background: Container(
        // 🔧 左滑显示的背景（从左向右滑）
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      secondaryBackground: Container(
        // 🔧 右滑显示的背景（从右向左滑）
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        // 🔧 防止误删：如果是正在播放的歌曲，需要二次确认
        if (isPlaying) {
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('确认移除'),
              content: const Text('这首歌曲正在播放，确定要从播放列表移除吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('移除'),
                ),
              ],
            ),
          );
        }
        return true; // 非播放中的歌曲直接允许删除
      },
      onDismissed: (direction) {
        // 🔧 从播放列表移除
        playerProvider.removeFromPlaylist(index);
        
        // 显示撤销提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已移除 ${song.title}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 使用当前最新的播放列表和索引，避免使用过期快照
            final currentPlaylist = playerProvider.playlist;
            final currentIndex =
                currentPlaylist.indexWhere((s) => s.id == song.id);
            final safeIndex = currentIndex >= 0 ? currentIndex : index;
            // 直接在当前播放队列中跳转到该歌曲，避免重建/打乱播放列表
            playerProvider.playSong(
              song,
              index: safeIndex,
              shuffle: false,
            );
            _hideOverlay();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isPlaying 
                  ? Theme.of(context).primaryColor.withOpacity(0.1) 
                  : null,
            ),
            child: Row(
              children: [
                // 歌曲封面（圆角）
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: _buildSongCover(song, context),
                  ),
                ),
                const SizedBox(width: 12),
                // 歌曲信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 歌名 - 纯白色
                      Text(
                        song.title,
                        style: TextStyle(
                          color: isPlaying 
                              ? Theme.of(context).primaryColor 
                              : Colors.white, // 🔧 纯白色
                          fontSize: 15,
                          fontWeight: isPlaying ? FontWeight.w600 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // 艺术家 - 偏灰色
                      Text(
                        song.artist ?? '未知艺术家',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.5) // 🔧 暗色主题：50%透明度白色
                              : Colors.black.withOpacity(0.5), // 🔧 亮色主题：50%透明度黑色
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 拖动手柄（4条杠）- 移至尾部
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(4, (i) => Container(
                        margin: EdgeInsets.only(bottom: i < 3 ? 3 : 0),
                        width: 18,
                        height: 2,
                        decoration: BoxDecoration(
                          color: Theme.of(context).iconTheme.color?.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      )),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// 构建歌词菜单叠加层（从底部滑入）
  Widget _buildLyricsMenuOverlay(Song? currentSong, PlayerProvider playerProvider) {
    final hasLyrics = playerProvider.currentLyrics != null &&
                      playerProvider.currentLyrics!.lyrics != null;

    // 获取歌词来源显示文本（增强版：显示更多详细信息）
    List<String> getLyricSourceInfo() {
      final lyrics = playerProvider.currentLyrics;
      if (lyrics == null) return ['暂无歌词'];

      final infoLines = <String>[];

      // 第一行：来源类型
      String sourceType;
      switch (lyrics.source) {
        case 'local':
          sourceType = '本地歌词';
          break;
        case 'netease':
          sourceType = '网易云音乐';
          break;
        case 'cache':
          sourceType = '缓存';
          break;
        case 'manual':
          sourceType = '手动编辑';
          break;
        default:
          sourceType = '未知来源';
      }
      infoLines.add('来源：$sourceType');

      // 第二行：歌词记录的歌名（如果有）
      final title = lyrics.tags['ti']?.trim();
      if (title != null && title.isNotEmpty) {
        infoLines.add('歌名：$title');
      }

      // 第三行：歌词记录的艺术家（如果有）
      final artist = lyrics.tags['ar']?.trim();
      if (artist != null && artist.isNotEmpty) {
        infoLines.add('艺术家：$artist');
      }

      // 第四行：专辑信息（如果有）
      final album = lyrics.tags['al']?.trim();
      if (album != null && album.isNotEmpty) {
        infoLines.add('专辑：$album');
      }

      // 第五行：制作者信息（如果有）
      final by = lyrics.tags['by']?.trim();
      if (by != null && by.isNotEmpty) {
        infoLines.add('制作：$by');
      }

      return infoLines;
    }

    final sourceInfo = getLyricSourceInfo();
    
    return Positioned.fill(
      child: GestureDetector(
        onTap: _hideOverlay, // 点击遮罩关闭
        child: Container(
          color: Colors.black54, // 半透明遮罩
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _lyricsMenuSlideAnimation,
              child: GestureDetector(
                onTap: () {}, // 阻止点击穿透
                // iOS风格拖拽关闭功能（支持双向拖动）
                onVerticalDragUpdate: (details) {
                  // 歌词菜单高度是动态的，使用屏幕高度作为基准
                  final screenHeight = MediaQuery.of(context).size.height;
                  // 向下拖拽减少进度，向上拖拽增加进度
                  final delta = -details.delta.dy / (screenHeight * 0.5);
                  _lyricsMenuController.value = (_lyricsMenuController.value + delta).clamp(0.0, 1.0);
                },
                onVerticalDragEnd: (details) {
                  // 判断是否应该关闭
                  final velocity = details.velocity.pixelsPerSecond.dy;
                  final position = _lyricsMenuController.value;
                  
                  // 条件：快速向下滑动或拖拽超过一半
                  if (velocity > 300 || position < 0.5) {
                    _hideOverlay(); // 关闭歌词菜单
                  } else {
                    _lyricsMenuController.forward(); // 回弹到完全展开
                  }
                },
                // 拦截水平拖拽，防止穿透到播放器的侧滑返回
                onHorizontalDragUpdate: (details) {},
                onHorizontalDragEnd: (details) {},
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.5)
                            : Colors.white.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 顶部拖动条
                            Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 8),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context).dividerColor.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // 标题
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '歌词操作',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            // 菜单项
                            ListTile(
                              leading: const Icon(Icons.search),
                              title: const Text('手动搜索歌词'),
                              onTap: () async {
                                await _hideOverlay(); // 先关闭歌词菜单
                                if (currentSong != null && mounted) {
                                  _showSearchLyrics(currentSong, playerProvider);
                                }
                              },
                            ),
                            if (hasLyrics)
                              ListTile(
                                leading: const Icon(Icons.edit),
                                title: const Text('编辑歌词'),
                                onTap: () async {
                                  await _hideOverlay();
                                  if (currentSong != null && 
                                      playerProvider.currentLyrics != null && 
                                      mounted) {
                                    _showEditLyrics(currentSong, playerProvider);
                                  }
                                },
                              ),
                            if (hasLyrics)
                              ListTile(
                                leading: const Icon(Icons.tune),
                                title: const Text('调整偏移量'),
                                onTap: () async {
                                  await _hideOverlay();
                                  if (currentSong != null && 
                                      playerProvider.currentLyrics != null && 
                                      mounted) {
                                    _showAdjustOffset(currentSong, playerProvider);
                                  }
                                },
                              ),
                            ListTile(
                              leading: const Icon(Icons.refresh),
                              title: const Text('重新获取歌词'),
                              onTap: () {
                                _hideOverlay();
                                playerProvider.loadLyrics(forceRefresh: true);
                              },
                            ),
                            const Divider(height: 1),
                            // 歌词来源信息（增强显示）
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: sourceInfo.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final line = entry.value;
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom: index < sourceInfo.length - 1 ? 4.0 : 0.0,
                                          ),
                                          child: Text(
                                            line,
                                            style: TextStyle(
                                              fontSize: index == 0 ? 13 : 12,
                                              fontWeight: index == 0 ? FontWeight.w500 : FontWeight.normal,
                                              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(
                                                index == 0 ? 0.75 : 0.6,
                                              ),
                                              height: 1.4,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建播放器菜单叠加层(从底部滑入,三点窗口)
  Widget _buildPlayerMenuOverlay() {
    if (_overlayCurrentSong == null || _overlayPlayerProvider == null) {
      return const SizedBox.shrink();
    }

    final song = _overlayCurrentSong!;
    final playerProvider = _overlayPlayerProvider!;
    // 检查音质选择区域的条件
    final showQualitySection = song.source == 'bilibili' && song.bvid != null;

    return Positioned.fill(
      child: GestureDetector(
        onTap: _hideOverlay, // 点击遮罩关闭
        child: Container(
          color: Colors.black54, // 半透明遮罩
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _lyricsMenuSlideAnimation,
              child: GestureDetector(
                onTap: () {}, // 阻止点击穿透
                // iOS风格拖拽关闭功能(支持双向拖动)
                onVerticalDragUpdate: (details) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  final delta = -details.delta.dy / (screenHeight * 0.5);
                  _lyricsMenuController.value = (_lyricsMenuController.value + delta).clamp(0.0, 1.0);
                },
                onVerticalDragEnd: (details) {
                  final velocity = details.velocity.pixelsPerSecond.dy;
                  final position = _lyricsMenuController.value;

                  if (velocity > 300 || position < 0.5) {
                    _hideOverlay();
                  } else {
                    _lyricsMenuController.forward();
                  }
                },
                onHorizontalDragUpdate: (details) {},
                onHorizontalDragEnd: (details) {},
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.5)
                            : Colors.white.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 顶部拖动条
                            Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 8),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context).dividerColor.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),

                            // 歌曲信息
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: _buildSongCover(song, context),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          song.artist ?? '未知艺术家',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                              // 喜欢按钮
                            ListTile(
                              leading: Icon(
                                song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: song.isFavorite ? Colors.red : null,
                              ),
                              title: Text(song.isFavorite ? '取消喜欢' : '喜欢'),
                              onTap: () {
                                _hideOverlay();
                                _toggleFavorite(song, playerProvider);
                              },
                            ),

                            // 添加到收藏夹
                            ListTile(
                              leading: const Icon(Icons.folder_special_rounded),
                              title: const Text('添加到收藏夹'),
                              onTap: () {
                                _hideOverlay();
                                _addToFavorite(song, playerProvider);
                              },
                            ),

                            // 音质选择和下载区域(仅Bilibili歌曲)
                            if (showQualitySection)
                              AudioQualitySection(song: song),

                            // 查看制作人员
                            ListTile(
                              leading: const Icon(Icons.info_outline_rounded),
                              title: const Text('查看制作人员'),
                              onTap: () {
                                _hideOverlay();
                                _showCredits(context, song);
                              },
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========== 对话框样式叠加层 ==========
  
  /// 构建手动搜索歌词叠加层（对话框样式，居中显示，液态玻璃效果）
  Widget _buildSearchLyricsOverlay() {
    if (_overlayCurrentSong == null || _overlayPlayerProvider == null) {
      return const SizedBox.shrink();
    }
    
    return Positioned.fill(
      child: GestureDetector(
        onTap: _hideOverlay, // 点击遮罩关闭
        child: Container(
          color: Colors.black54, // 半透明遮罩
          child: Center(
            child: ScaleTransition(
              scale: _dialogScaleAnimation,
              child: FadeTransition(
                opacity: _dialogOpacityAnimation,
                child: GestureDetector(
                  onTap: () {}, // 阻止点击穿透
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        height: MediaQuery.of(context).size.height * 0.7,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.55)
                              : Colors.white.withOpacity(0.65),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white.withOpacity(0.5),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: _buildSearchLyricsContent(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// 构建搜索歌词的内容（完全自定义UI）
  Widget _buildSearchLyricsContent() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '手动搜索歌词',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _hideOverlay,
                  tooltip: '关闭',
                ),
              ],
            ),
          ),
          
          // 搜索框和按钮
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchLyricsController,
                    decoration: InputDecoration(
                      hintText: '输入歌曲名',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchLyricsController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchLyricsController.clear();
                                });
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _performLyricSearch(),
                    onChanged: (_) => setState(() {}),
                    enabled: !_isFetchingLyric,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isFetchingLyric || _searchLyricsController.text.trim().isEmpty
                      ? null
                      : _performLyricSearch,
                  icon: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: const Text('搜索'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
          
          // 结果列表
          Expanded(
            child: _buildSearchResultsList(),
          ),
          
          // 错误提示
          if (_searchErrorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.error,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _searchErrorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  /// 构建搜索结果列表
  Widget _buildSearchResultsList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_searchResults == null) {
      return const Center(
        child: Text('请修改搜索关键词并点击搜索'),
      );
    }
    
    if (_searchResults!.isEmpty) {
      return const Center(
        child: Text('没有找到匹配的歌词'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _searchResults!.length,
      itemBuilder: (context, index) {
        final item = _searchResults![index];
        return _buildSearchResultItem(item);
      },
    );
  }
  
  /// 构建单个搜索结果项
  Widget _buildSearchResultItem(LyricSearchResult item) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${item.artist} - ${LyricParser.formatDuration(Duration(seconds: item.duration.toInt()))} - ${{
            'netease': '网易云',
          }[item.source] ?? item.source}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: _isFetchingLyric
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download),
        onTap: _isFetchingLyric ? null : () => _selectSearchedLyric(item),
        enabled: !_isFetchingLyric,
      ),
    );
  }
  
  /// 执行歌词搜索
  Future<void> _performLyricSearch() async {
    final query = _searchLyricsController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchErrorMessage = null;
    });

    try {
      final results = await lyricService.manualSearchLyrics(keyword: query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchErrorMessage = '搜索失败: $e';
        _isSearching = false;
      });
    }
  }

  /// 选择搜索到的歌词
  Future<void> _selectSearchedLyric(LyricSearchResult item) async {
    if (_overlayCurrentSong == null || _overlayPlayerProvider == null) return;
    
    setState(() {
      _isFetchingLyric = true;
      _searchErrorMessage = null;
    });

    try {
      final lyrics = await lyricService.fetchLyrics(
        item: item,
        uniqueKey: _getUniqueKey(_overlayCurrentSong!),
      );

      _overlayPlayerProvider!.updateLyrics(lyrics);
      _hideOverlay();
    } catch (e) {
      setState(() {
        _searchErrorMessage = '获取歌词失败: $e';
        _isFetchingLyric = false;
      });
    }
  }
  
  /// 构建编辑歌词叠加层（对话框样式，居中显示，液态玻璃效果）
  Widget _buildEditLyricsOverlay() {
    if (_overlayCurrentSong == null || 
        _overlayPlayerProvider == null || 
        _overlayPlayerProvider!.currentLyrics == null) {
      return const SizedBox.shrink();
    }
    
    return Positioned.fill(
      child: GestureDetector(
        onTap: _hideOverlay,
        child: Container(
          color: Colors.black54,
          child: Center(
            child: ScaleTransition(
              scale: _dialogScaleAnimation,
              child: FadeTransition(
                opacity: _dialogOpacityAnimation,
                child: GestureDetector(
                  onTap: () {},
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        height: MediaQuery.of(context).size.height * 0.7,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.55)
                              : Colors.white.withOpacity(0.65),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white.withOpacity(0.5),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: _buildEditLyricsContent(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// 构建编辑歌词的内容（完全自定义UI）
  Widget _buildEditLyricsContent() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasTranslation = _overlayPlayerProvider!.currentLyrics!.rawTranslatedLyrics != null;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '编辑歌词',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _hideOverlay,
                  tooltip: '关闭',
                ),
              ],
            ),
          ),
          
          // 编辑区域
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 原始歌词输入框
                  Expanded(
                    child: TextField(
                      controller: _editOriginalLyricsController,
                      decoration: const InputDecoration(
                        labelText: '原始歌词',
                        hintText: '请输入LRC格式的歌词',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      enabled: !_isSavingLyrics,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 翻译歌词输入框（如果有翻译）
                  if (hasTranslation)
                    Expanded(
                      child: TextField(
                        controller: _editTranslatedLyricsController,
                        decoration: const InputDecoration(
                          labelText: '翻译歌词',
                          hintText: '请输入LRC格式的翻译歌词',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        enabled: !_isSavingLyrics && _editOriginalLyricsController.text.isNotEmpty,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // 使用说明
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: theme.hintColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'LRC格式示例：[00:12.50]歌词内容',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 底部按钮栏
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSavingLyrics ? null : _hideOverlay,
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSavingLyrics || _editOriginalLyricsController.text.trim().isEmpty
                      ? null
                      : _saveEditedLyrics,
                  icon: _isSavingLyrics
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('保存'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 保存编辑后的歌词
  Future<void> _saveEditedLyrics() async {
    if (_overlayCurrentSong == null || _overlayPlayerProvider == null) return;
    
    setState(() {
      _isSavingLyrics = true;
    });

    try {
      final original = _editOriginalLyricsController.text;
      final translated = _editTranslatedLyricsController.text.trim();

      // 解析原始歌词
      final parsedOriginal = LyricParser.parseLrc(original);

      ParsedLrc finalLyrics;

      if (translated.isEmpty) {
        // 没有翻译，直接使用原始歌词
        finalLyrics = parsedOriginal;
      } else {
        // 有翻译，解析并合并
        final parsedTranslated = LyricParser.parseLrc(translated);
        finalLyrics = LyricParser.mergeLrc(parsedOriginal, parsedTranslated);
      }

      // 保留原来的偏移量，标记为手动编辑
      finalLyrics = finalLyrics.copyWith(
        offset: _overlayPlayerProvider!.currentLyrics!.offset,
        source: 'manual',
      );

      // 保存到缓存
      await lyricService.saveLyricsToFile(
        lyrics: finalLyrics,
        uniqueKey: _getUniqueKey(_overlayCurrentSong!),
      );

      _overlayPlayerProvider!.updateLyrics(finalLyrics);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('歌词保存成功')),
        );
      }
      
      _hideOverlay();
    } catch (e) {
      setState(() {
        _isSavingLyrics = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存歌词失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
  
  /// 构建调整歌词偏移量叠加层（底部滑动条样式，模仿多选下载的圆角容器）
  Widget _buildAdjustOffsetOverlay() {
    if (_overlayCurrentSong == null ||
        _overlayPlayerProvider == null ||
        _overlayPlayerProvider!.currentLyrics == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _dialogOverlayController,
          curve: Curves.easeOutCubic,
        )),
        child: FadeTransition(
          opacity: _dialogOpacityAnimation,
          child: _buildAdjustOffsetContent(),
        ),
      ),
    );
  }
  
  /// 构建调整偏移量的内容（底部滑动条样式，模仿多选下载的圆角容器）
  Widget _buildAdjustOffsetContent() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.45)
                    : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.18)
                      : Colors.black.withOpacity(0.06),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 标题行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '调整歌词偏移',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      // 当前偏移量显示
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatLyricOffset(_currentLyricOffset),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // 提示文字
                  Text(
                    _currentLyricOffset > 0
                        ? '歌词提前显示'
                        : _currentLyricOffset < 0
                            ? '歌词延后显示'
                            : '无偏移',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 滑动条区域
                  Row(
                    children: [
                      Text(
                        '-10s',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: theme.colorScheme.primary,
                            inactiveTrackColor:
                                theme.colorScheme.primary.withOpacity(0.2),
                            thumbColor: theme.colorScheme.primary,
                            overlayColor:
                                theme.colorScheme.primary.withOpacity(0.1),
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                          ),
                          child: Slider(
                            value: _currentLyricOffset.clamp(-10.0, 10.0),
                            min: -10.0,
                            max: 10.0,
                            divisions: 200, // 0.1秒精度
                            onChanged: (value) {
                              setState(() {
                                _currentLyricOffset = value;
                              });
                              // 实时预览歌词偏移
                              _previewLyricOffset(value);
                            },
                          ),
                        ),
                      ),
                      Text(
                        '+10s',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 操作按钮行
                  Row(
                    children: [
                      // 重置按钮
                      Expanded(
                        child: TextButton(
                          onPressed:
                              _currentLyricOffset != 0 ? _resetLyricOffset : null,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                          ),
                          child: const Text('重置'),
                        ),
                      ),
                      // 取消按钮
                      Expanded(
                        child: TextButton(
                          onPressed: _isSavingOffset ? null : _cancelLyricOffset,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                          ),
                          child: const Text('取消'),
                        ),
                      ),
                      // 保存按钮
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSavingOffset ? null : _saveLyricOffset,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                          ),
                          child: _isSavingOffset
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// 构建偏移量调整按钮（已弃用，新UI不再使用）
  Widget _buildOffsetAdjustButton(String label, double delta) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _currentLyricOffset = (_currentLyricOffset + delta).clamp(-10.0, 10.0);
        });
        _previewLyricOffset(_currentLyricOffset);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(70, 40),
      ),
      child: Text(label),
    );
  }
  
  /// 格式化偏移量显示
  String _formatLyricOffset(double offset) {
    final sign = offset >= 0 ? '+' : '';
    return '$sign${offset.toStringAsFixed(1)}s';
  }

  /// 原始偏移量（用于取消时恢复）
  double _originalLyricOffset = 0.0;

  /// 实时预览歌词偏移
  void _previewLyricOffset(double offset) {
    if (_overlayPlayerProvider == null ||
        _overlayPlayerProvider!.currentLyrics == null) return;

    final previewLyrics =
        _overlayPlayerProvider!.currentLyrics!.copyWith(offset: offset);
    _overlayPlayerProvider!.updateLyrics(previewLyrics);
  }

  /// 重置偏移量为0
  void _resetLyricOffset() {
    setState(() {
      _currentLyricOffset = 0.0;
    });
    _previewLyricOffset(0.0);
  }

  /// 取消偏移量调整（恢复原始值）
  void _cancelLyricOffset() {
    // 恢复原始偏移量
    _previewLyricOffset(_originalLyricOffset);
    _hideOverlay();
  }

  /// 保存歌词偏移量
  Future<void> _saveLyricOffset() async {
    if (_overlayCurrentSong == null || _overlayPlayerProvider == null) return;
    
    setState(() {
      _isSavingOffset = true;
    });

    try {
      final updatedLyrics = _overlayPlayerProvider!.currentLyrics!.copyWith(
        offset: _currentLyricOffset,
      );

      await lyricService.saveLyricsToFile(
        lyrics: updatedLyrics,
        uniqueKey: _getUniqueKey(_overlayCurrentSong!),
      );

      _overlayPlayerProvider!.updateLyrics(updatedLyrics);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('偏移量已保存')),
        );
      }
      
      _hideOverlay();
    } catch (e) {
      setState(() {
        _isSavingOffset = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
  
  /// 构建歌曲封面（使用统一封面组件）
  ///
  /// 统一使用 UnifiedCoverImage 组件，确保：
  /// - 网络图片自动缓存
  /// - 本地文件异步检查
  /// - 统一的占位符和错误处理
  Widget _buildSongCover(Song song, BuildContext context) {
    return UnifiedCoverImage(
      coverPath: song.albumArtPath,
      width: 56,
      height: 56,
      borderRadius: 0, // 外层已有 ClipRRect，这里不需要圆角
      fit: BoxFit.cover,
      // 播放列表/菜单中频繁重建，跳过异步 exists 检查以减少“加载中”闪烁
      skipAsyncFileCheck: true,
    );
  }

  /// 构建占位封面（已废弃，由 UnifiedCoverImage 内部处理）
  @Deprecated('Use UnifiedCoverImage instead')
  Widget _buildPlaceholderCover(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Icon(
        Icons.music_note_rounded,
        color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
        size: 24,
      ),
    );
  }

  /// 切换喜欢状态
  Future<void> _toggleFavorite(Song song, PlayerProvider playerProvider) async {
    try {
      final updatedSong = song.copyWith(isFavorite: !song.isFavorite);
      await MusicDatabase.database.updateSong(updatedSong);
      
      // 更新播放器中的歌曲状态
      playerProvider.updateCurrentSong(updatedSong);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedSong.isFavorite ? '已添加到喜欢' : '已取消喜欢'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 添加到收藏夹
  Future<void> _addToFavorite(Song song, PlayerProvider playerProvider) async {
    try {
      final db = MusicDatabase.database;
      // 获取所有收藏夹
      final favorites = await db.getAllBilibiliFavorites();
      
      if (!mounted) return;
      
      if (favorites.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('暂无收藏夹，请先添加收藏夹'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      
      // 显示收藏夹选择对话框
      _showFavoriteSelectionDialog(song, favorites);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载收藏夹失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  /// 显示收藏夹选择对话框
  void _showFavoriteSelectionDialog(Song song, List<BilibiliFavorite> favorites) {
    setState(() {
      _currentOverlay = PlayerOverlayType.none; // 先清空，确保状态重置
      _overlayCurrentSong = song;
      _overlayFavorites = favorites; // 保存收藏夹列表
    });
    
    // 延迟一帧后设置为收藏夹选择叠加层
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentOverlay = PlayerOverlayType.favoriteSelection;
        });
        _lyricsMenuController.forward(from: 0.0);
      }
    });
  }
  
  /// 构建收藏夹选择叠加层(从底部滑入)
  Widget _buildFavoriteSelectionOverlay() {
    if (_overlayCurrentSong == null || _overlayFavorites == null) {
      return const SizedBox.shrink();
    }

    final song = _overlayCurrentSong!;
    final favorites = _overlayFavorites!;

    return Positioned.fill(
      child: GestureDetector(
        onTap: _hideOverlay, // 点击遮罩关闭
        child: Container(
          color: Colors.black54, // 半透明遮罩
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _lyricsMenuSlideAnimation,
              child: GestureDetector(
                onTap: () {}, // 阻止点击穿透
                // iOS风格拖拽关闭功能
                onVerticalDragUpdate: (details) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  final delta = -details.delta.dy / (screenHeight * 0.5);
                  _lyricsMenuController.value = (_lyricsMenuController.value + delta).clamp(0.0, 1.0);
                },
                onVerticalDragEnd: (details) {
                  final velocity = details.velocity.pixelsPerSecond.dy;
                  final position = _lyricsMenuController.value;

                  if (velocity > 300 || position < 0.5) {
                    _hideOverlay();
                  } else {
                    _lyricsMenuController.forward();
                  }
                },
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.5)
                            : Colors.white.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 顶部拖动条
                            Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 8),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // 标题
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: Text(
                                '添加到收藏夹',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            // 收藏夹列表
                            if (favorites.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  '暂无收藏夹',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            else
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: favorites.length,
                                  itemBuilder: (context, index) {
                                    final favorite = favorites[index];
                                    return ListTile(
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: favorite.coverUrl != null && favorite.coverUrl!.isNotEmpty
                                            ? Image.network(
                                                favorite.coverUrl!,
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  width: 48,
                                                  height: 48,
                                                  color: Colors.grey[800],
                                                  child: const Icon(Icons.folder, color: Colors.white54),
                                                ),
                                              )
                                            : Container(
                                                width: 48,
                                                height: 48,
                                                color: Colors.grey[800],
                                                child: const Icon(Icons.folder, color: Colors.white54),
                                              ),
                                      ),
                                      title: Text(
                                        favorite.title,
                                        style: TextStyle(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${favorite.mediaCount} 个视频',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                      onTap: () async {
                                        await _addSongToFavorite(song, favorite);
                                        _hideOverlay();
                                      },
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// 将歌曲添加到指定收藏夹
  Future<void> _addSongToFavorite(Song song, BilibiliFavorite favorite) async {
    try {
      final db = MusicDatabase.database;
      final isLocalFavorite = favorite.isLocal;

      // 统一构造稳定的 filePath（避免 UNIQUE 约束冲突）
      final filePath = song.filePath.isNotEmpty
          ? song.filePath
          : buildBilibiliFilePath(
              bvid: song.bvid,
              cid: song.cid,
              pageNumber: song.pageNumber,
            );

      // 如果是在线收藏夹且为 Bilibili 歌曲，优先同步到远端收藏夹
      if (!isLocalFavorite &&
          song.source == 'bilibili' &&
          song.bvid != null &&
          song.bvid!.isNotEmpty) {
        await _addSongToOnlineFavorite(song, favorite);
      }

      // 如果歌曲已存在于数据库中（本地正式记录）
      if (song.id > 0) {
        final updatedSong =
            song.copyWith(bilibiliFavoriteId: Value(favorite.id));
        await db.updateSong(updatedSong);
      } else {
        // 临时歌曲：先检查数据库中是否已有同一音源
        Song? existingSong = await db.getSongByPath(filePath);

        if (existingSong == null &&
            song.bvid != null &&
            song.cid != null) {
          existingSong =
              await db.getSongByBvidAndCid(song.bvid!, song.cid!);
        }

        if (existingSong != null) {
          // 已存在记录，只更新收藏夹 ID，避免重复插入触发 UNIQUE
          final updatedExisting = existingSong.copyWith(
            bilibiliFavoriteId: Value(favorite.id),
          );
          await db.updateSong(updatedExisting);
        } else {
          // 不存在记录，插入新歌曲，确保带上稳定的 filePath
          await db.insertSong(
            SongsCompanion.insert(
              title: song.title,
              filePath: filePath,
              source: Value(song.source),
              artist: Value(song.artist),
              album: Value(song.album),
              duration: Value(song.duration),
              albumArtPath: Value(song.albumArtPath),
              dateAdded: Value(song.dateAdded),
              isFavorite: Value(song.isFavorite),
              bvid: Value(song.bvid),
              cid: Value(song.cid),
              lastPlayedTime: Value(song.lastPlayedTime),
              playedCount: Value(song.playedCount),
              bilibiliFavoriteId: Value(favorite.id),
            ),
          );
        }
      }

      if (mounted) {
        // 通知对应收藏夹需要刷新一次（收藏夹详情页会监听此事件）
        FavoriteSyncNotifier.instance
            .notifyFavoriteChanged(favorite.remoteId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加到收藏夹「${favorite.title}」'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 将 Bilibili 歌曲添加到在线收藏夹（同步到 B 站服务器）
  Future<void> _addSongToOnlineFavorite(
      Song song, BilibiliFavorite favorite) async {
    // 解析出对应视频的 AV 号（mediaId）
    final mediaId = await _resolveBilibiliMediaId(song);
    if (mediaId == null) {
      throw Exception('无法解析 B 站视频ID，添加到在线收藏夹失败');
    }

    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    final apiService = BilibiliApiService(apiClient);

    await apiService.addToFavorite(
      mediaId: mediaId,
      favoriteId: favorite.remoteId,
    );
  }

  /// 根据当前歌曲解析对应的 Bilibili AV 号（优先使用本地缓存）
  Future<int?> _resolveBilibiliMediaId(Song song) async {
    final db = MusicDatabase.database;

    // 1. 优先使用已关联的 bilibiliVideoId
    if (song.bilibiliVideoId != null) {
      final video =
          await db.getBilibiliVideoById(song.bilibiliVideoId!);
      if (video != null && video.aid > 0) {
        return video.aid;
      }
    }

    // 2. 通过 bvid 在本地视频表中查找
    if (song.bvid != null && song.bvid!.isNotEmpty) {
      final video =
          await db.getBilibiliVideoByBvid(song.bvid!);
      if (video != null && video.aid > 0) {
        return video.aid;
      }

      // 3. 兜底：调用接口获取视频详情（不强制写回本地）
      final cookieManager = CookieManager();
      final apiClient = BilibiliApiClient(cookieManager);
      final apiService = BilibiliApiService(apiClient);

      final remoteVideo =
          await apiService.getVideoDetails(song.bvid!);
      if (remoteVideo.aid > 0) {
        return remoteVideo.aid;
      }
    }

    return null;
  }

  /// 查看制作人员（跳转到UP主页面）
  Future<void> _showCredits(BuildContext context, Song song) async {
    // 检查是否为Bilibili歌曲
    if (song.source != 'bilibili' || song.bvid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('该歌曲不是来自Bilibili，无法查看制作人员'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    try {
      // 从数据库获取UP主信息
      final db = MusicDatabase.database;
      final video = await db.getBilibiliVideoByBvid(song.bvid!);
      
      if (video != null) {
        // 如果数据库中有视频信息，直接跳转
        _navigateToUserVideos(video.authorMid, video.author);
      } else {
        // 如果数据库中没有，尝试从artist字段提取UP主名称
        final artistName = song.artist ?? 'UP主';
        
        // 显示提示信息
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在获取UP主信息...'),
            duration: Duration(seconds: 1),
          ),
        );
        
        // 尝试通过API获取视频信息
        await _fetchAndNavigateToCreator(song.bvid!, artistName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取UP主信息失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  /// 通过API获取视频信息并跳转到UP主页面
  Future<void> _fetchAndNavigateToCreator(String bvid, String defaultName) async {
    try {
      final cookieManager = CookieManager();
      final apiClient = BilibiliApiClient(cookieManager);
      final apiService = BilibiliApiService(apiClient);
      
      // 获取视频详情
      final video = await apiService.getVideoDetails(bvid);
      
      // 提取UP主ID和名称
      final mid = video.owner.mid;
      final name = video.owner.name;
      
      if (mid > 0) {
        _navigateToUserVideos(mid, name);
      } else {
        throw Exception('无法获取UP主信息');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  /// 导航到UP主视频页面
  void _navigateToUserVideos(int mid, String userName) {
    // 缩小播放器
    if (widget.onRequestClose != null) {
      widget.onRequestClose!();
    }
    
    // 延迟一小段时间，等待播放器开始缩小动画
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        Navigator.of(context).push(
          NamidaPageRoute(
            page: UserVideosPage(
              mid: mid,
              userName: userName,
            ),
            type: PageTransitionType.slideLeft,
          ),
        );
      }
    });
  }

  Widget _buildCreditRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// 播放器音质选择组件已迁移至 audio_quality_section.dart
