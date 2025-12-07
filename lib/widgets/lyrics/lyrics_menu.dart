import 'package:flutter/material.dart';
import 'package:motto_music/models/lyrics/lyric_models.dart';
import 'package:motto_music/database/database.dart';
import 'package:motto_music/widgets/lyrics/manual_search_lyrics_dialog.dart';
import 'package:motto_music/widgets/lyrics/edit_lyrics_dialog.dart';
import 'package:motto_music/widgets/lyrics/lyric_offset_dialog.dart';

/// 歌词菜单组件
class LyricsMenu extends StatelessWidget {
  final Song? currentMusic;
  final ParsedLrc? currentLyrics;
  final Function()? onRefreshLyrics;
  final Function(ParsedLrc)? onLyricsUpdated;

  const LyricsMenu({
    Key? key,
    this.currentMusic,
    this.currentLyrics,
    this.onRefreshLyrics,
    this.onLyricsUpdated,
  }) : super(key: key);

  String _getUniqueKey(Song music) {
    return '${music.id}_${music.source}';
  }

  @override
  Widget build(BuildContext context) {
    final hasMusic = currentMusic != null;
    final hasLyrics = currentLyrics != null && currentLyrics!.lyrics != null;
    
    // 获取歌词来源显示文本
    String getLyricSourceText() {
      if (currentLyrics == null) return '暂无歌词';
      
      switch (currentLyrics!.source) {
        case 'local':
          return '本地歌词';
        case 'netease':
          return '网易云音乐';
        case 'cache':
          return '缓存';
        case 'manual':
          return '手动编辑';
        default:
          return '未知来源';
      }
    }

    return IconButton(
      icon: const Icon(Icons.lyrics, color: Colors.white),
      tooltip: '歌词操作',
      onPressed: hasMusic ? () async {
        debugPrint('========== 歌词菜单点击 ==========');
        debugPrint('[LyricsMenu] 当前 Context: ${context.widget.runtimeType}');
        
        // 检查导航器信息
        final navigator = Navigator.of(context, rootNavigator: true);
        debugPrint('[LyricsMenu] Root Navigator: ${navigator.hashCode}');
        debugPrint('[LyricsMenu] Root Navigator Overlay: ${navigator.overlay?.hashCode}');
        
        final localNavigator = Navigator.of(context, rootNavigator: false);
        debugPrint('[LyricsMenu] Local Navigator: ${localNavigator.hashCode}');
        debugPrint('[LyricsMenu] Local Navigator Overlay: ${localNavigator.overlay?.hashCode}');
        
        debugPrint('[LyricsMenu] 即将推送歌词菜单页面...');
        
        // 使用 Navigator.push 创建透明全屏页面，确保显示在最顶层
        debugPrint('[LyricsMenu] 开始调用 Navigator.push');
        final String? selected = await Navigator.of(context, rootNavigator: true).push<String>(
          PageRouteBuilder(
            opaque: false, // 透明背景
            barrierDismissible: true,
            barrierColor: Colors.black54,
            pageBuilder: (context, animation, secondaryAnimation) {
              debugPrint('[LyricsMenu PageBuilder] ========== 页面构建开始 ==========');
              debugPrint('[LyricsMenu PageBuilder] Context: ${context.widget.runtimeType}');
              debugPrint('[LyricsMenu PageBuilder] Animation value: ${animation.value}');
              debugPrint('[LyricsMenu PageBuilder] Animation status: ${animation.status}');
              
              return SizedBox.expand(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Stack(
                      children: [
                        // 半透明遮罩（点击关闭）
                        Positioned.fill(
                          child: Container(color: Colors.transparent),
                        ),
                        // 底部菜单
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () {}, // 阻止点击事件传播到遮罩
                            child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[900]
                                    : Colors.white,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              child: SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 顶部拖动条
                                    Container(
                                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[400],
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
                                      onTap: () => Navigator.pop(context, 'search'),
                                    ),
                                    if (hasLyrics)
                                      ListTile(
                                        leading: const Icon(Icons.edit),
                                        title: const Text('编辑歌词'),
                                        onTap: () => Navigator.pop(context, 'edit'),
                                      ),
                                    if (hasLyrics)
                                      ListTile(
                                        leading: const Icon(Icons.tune),
                                        title: const Text('调整偏移量'),
                                        onTap: () => Navigator.pop(context, 'offset'),
                                      ),
                                    ListTile(
                                      leading: const Icon(Icons.refresh),
                                      title: const Text('重新获取歌词'),
                                      onTap: () => Navigator.pop(context, 'refresh'),
                                    ),
                                    const Divider(height: 1),
                                    // 歌词来源信息
                                    ListTile(
                                      leading: const Icon(Icons.info_outline, size: 20),
                                      title: Text(
                                        '来源：${getLyricSourceText()}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      dense: true,
                                      enabled: false,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        ),],
                    ),
                  ),
                ),
              );
            },
          ),
        );

        debugPrint('[LyricsMenu] 菜单已关闭，选择: $selected');
        debugPrint('========== 歌词菜单结束 ==========\n');
        
        if (selected != null) {
          _handleMenuAction(context, selected);
        }
      } : null,
    );
  }

  void _handleMenuAction(BuildContext context, String action) async {
    if (currentMusic == null) return;

    final uniqueKey = _getUniqueKey(currentMusic!);

    switch (action) {
      case 'search':
        _showSearchDialog(context, uniqueKey);
        break;
      case 'edit':
        if (currentLyrics != null) {
          _showEditDialog(context, uniqueKey);
        }
        break;
      case 'offset':
        if (currentLyrics != null) {
          _showOffsetDialog(context, uniqueKey);
        }
        break;
      case 'refresh':
        _refreshLyrics();
        break;
    }
  }

  void _showSearchDialog(BuildContext context, String uniqueKey) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      useRootNavigator: true, // 使用根导航器，确保显示在最顶层
      builder: (context) => ManualSearchLyricsDialog(
        uniqueKey: uniqueKey,
        initialQuery: currentMusic!.title,
        onLyricSelected: (lyrics) {
          if (onLyricsUpdated != null) {
            onLyricsUpdated!(lyrics);
          }
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, String uniqueKey) {
    showDialog(
      context: context,
      useRootNavigator: true, // 使用根导航器，确保显示在最顶层
      builder: (context) => EditLyricsDialog(
        uniqueKey: uniqueKey,
        lyrics: currentLyrics!,
        onLyricsSaved: (lyrics) {
          if (onLyricsUpdated != null) {
            onLyricsUpdated!(lyrics);
          }
        },
      ),
    );
  }

  void _showOffsetDialog(BuildContext context, String uniqueKey) {
    showLyricOffsetPanel(
      context: context,
      uniqueKey: uniqueKey,
      lyrics: currentLyrics!,
      onOffsetChanged: (lyrics) {
        if (onLyricsUpdated != null) {
          onLyricsUpdated!(lyrics);
        }
      },
      onOffsetPreview: (offset) {
        // 实时预览：创建临时歌词对象并通知更新
        if (onLyricsUpdated != null) {
          final previewLyrics = currentLyrics!.copyWith(offset: offset);
          onLyricsUpdated!(previewLyrics);
        }
      },
    );
  }

  void _refreshLyrics() {
    if (onRefreshLyrics != null) {
      onRefreshLyrics!();
    }
  }
}
