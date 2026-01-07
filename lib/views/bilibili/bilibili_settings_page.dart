import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:motto_music/services/bilibili/download_manager.dart';
import 'package:motto_music/models/bilibili/audio_quality.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:ui';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Bilibili 设置页面
///
/// 使用单页面滚动布局,包含:
/// - 音质设置区域
/// - 下载设置区域
/// - 账号管理区域
class BilibiliSettingsPage extends StatefulWidget {
  const BilibiliSettingsPage({super.key});

  @override
  State<BilibiliSettingsPage> createState() => _BilibiliSettingsPageState();
}

class _BilibiliSettingsPageState extends State<BilibiliSettingsPage> {
  final ScrollController _scrollController = ScrollController();
  double _collapseProgress = 0.0;
  static const double _collapseDistance = 40.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final progress = (_scrollController.offset / _collapseDistance).clamp(0.0, 1.0);
    if ((progress - _collapseProgress).abs() > 0.01) {
      setState(() => _collapseProgress = progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    const topBarHeight = 52.0;

    return Scaffold(
      backgroundColor: isDark
          ? ThemeUtils.backgroundColor(context)
          : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          NotificationListener<OverscrollIndicatorNotification>(
            onNotification: (notification) {
              notification.disallowIndicator();
              return true;
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: topPadding + topBarHeight + 1),
                ),
                SliverToBoxAdapter(
                  child: _buildLargeTitle(),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 150),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildQualitySection(isDark),
                      const SizedBox(height: 32),
                      _buildDownloadSection(isDark),
                      const SizedBox(height: 32),
                      _buildAccountSection(isDark),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          _buildTopBar(topPadding, topBarHeight, isDark),
        ],
      ),
    );
  }

  Widget _buildTopBar(double topPadding, double topBarHeight, bool isDark) {
    final eased = Curves.easeOutCubic.transform(_collapseProgress);
    final bgOpacity = (eased * 0.95).clamp(0.0, 0.95);
    final titleOpacity = eased.clamp(0.0, 1.0);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20 * eased, sigmaY: 20 * eased),
          child: Container(
            height: topPadding + topBarHeight,
            decoration: BoxDecoration(
              color: isDark
                  ? ThemeUtils.backgroundColor(context).withOpacity(bgOpacity)
                  : const Color(0xFFF2F2F7).withOpacity(bgOpacity),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08 * eased)
                      : Colors.black.withOpacity(0.08 * eased),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: topBarHeight,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '返回',
                    ),
                    Expanded(
                      child: Opacity(
                        opacity: titleOpacity,
                        child: const Text(
                          'Bilibili 设置',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // 右侧占位
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeTitle() {
    final eased = Curves.easeOutCubic.transform(_collapseProgress);
    final opacity = (1 - eased).clamp(0.0, 1.0);
    final translateY = -14 * eased;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Opacity(
          opacity: opacity,
          child: const Text(
            'Bilibili 设置',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
        ),
      ),
    );
  }

  // 构建音质设置分组
  Widget _buildQualitySection(bool isDark) {
    return Consumer<DownloadManager>(
      builder: (context, downloadManager, child) {
        final settings = downloadManager.userSettings;

        if (settings == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final defaultPlayQuality = BilibiliAudioQuality.fromId(settings.defaultPlayQuality);
        final defaultDownloadQuality = BilibiliAudioQuality.fromId(settings.defaultDownloadQuality);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                '音质设置',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.red,
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('默认播放音质', style: TextStyle(fontWeight: FontWeight.w400)),
                    subtitle: Text(
                      defaultPlayQuality.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                      ),
                    ),
                    trailing: Icon(CupertinoIcons.chevron_right, size: 18, color: Colors.grey[400]),
                    onTap: () => _showQualityPicker(
                      context,
                      title: '选择默认播放音质',
                      currentQuality: defaultPlayQuality,
                      onSelected: (quality) {
                        downloadManager.setDefaultPlayQuality(quality);
                      },
                    ),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 0),

                  ListTile(
                    title: const Text('默认下载音质', style: TextStyle(fontWeight: FontWeight.w400)),
                    subtitle: Text(
                      defaultDownloadQuality.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                      ),
                    ),
                    trailing: Icon(CupertinoIcons.chevron_right, size: 18, color: Colors.grey[400]),
                    onTap: () => _showQualityPicker(
                      context,
                      title: '选择默认下载音质',
                      currentQuality: defaultDownloadQuality,
                      onSelected: (quality) {
                        downloadManager.setDefaultDownloadQuality(quality);
                      },
                    ),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 0),

                  SwitchListTile.adaptive(
                    title: const Text('根据网络自动选择音质', style: TextStyle(fontWeight: FontWeight.w400)),
                    subtitle: Text(
                      'WiFi使用无损,移动网络使用高音质',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                      ),
                    ),
                    value: settings.autoSelectQuality,
                    activeColor: Colors.red,
                    onChanged: (value) {
                      downloadManager.setAutoSelectQuality(value);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 构建下载设置分组
  Widget _buildDownloadSection(bool isDark) {
    return Consumer<DownloadManager>(
      builder: (context, downloadManager, child) {
        final settings = downloadManager.userSettings;

        if (settings == null) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                '下载设置',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.red,
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: const Text('仅WiFi下载', style: TextStyle(fontWeight: FontWeight.w400)),
                    subtitle: Text(
                      '移动网络环境下禁止下载',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                      ),
                    ),
                    value: settings.wifiOnlyDownload,
                    activeColor: Colors.red,
                    onChanged: (value) {
                      downloadManager.setWifiOnlyDownload(value);
                    },
                  ),
                  Divider(height: 1, indent: 16, endIndent: 0),

                  // 最大并发下载数
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '最大并发下载数',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              '${settings.maxConcurrentDownloads} 个',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: settings.maxConcurrentDownloads.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          activeColor: Colors.red,
                          label: '${settings.maxConcurrentDownloads} 个',
                          onChanged: (value) {
                            downloadManager.setMaxConcurrentDownloads(value.toInt());
                          },
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 0),

                  SwitchListTile.adaptive(
                    title: const Text('自动重试失败任务', style: TextStyle(fontWeight: FontWeight.w400)),
                    subtitle: Text(
                      '下载失败后自动重试(最多3次)',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                      ),
                    ),
                    value: settings.autoRetryFailed,
                    activeColor: Colors.red,
                    onChanged: (value) {
                      downloadManager.setAutoRetryFailed(value);
                    },
                  ),
                  Divider(height: 1, indent: 16, endIndent: 0),

                  // 自动缓存空间限制
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '自动缓存空间限制',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              '${settings.autoCacheSizeGB} GB',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: settings.autoCacheSizeGB.toDouble(),
                          min: 1,
                          max: 20,
                          divisions: 19,
                          activeColor: Colors.red,
                          label: '${settings.autoCacheSizeGB} GB',
                          onChanged: (value) {
                            downloadManager.setAutoCacheSizeGB(value.toInt());
                          },
                        ),
                        FutureBuilder<String>(
                          future: _getCacheSize(downloadManager),
                          builder: (context, snapshot) {
                            final cacheSize = snapshot.data ?? '计算中...';
                            return Text(
                              '已使用: $cacheSize',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 0),

                  ListTile(
                    title: const Text('缓存管理', style: TextStyle(fontWeight: FontWeight.w400)),
                    subtitle: Text(
                      '打开缓存目录或清空缓存',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(CupertinoIcons.folder, size: 18, color: Colors.grey[400]),
                          onPressed: () => _openCacheDirectory(context, downloadManager),
                        ),
                        IconButton(
                          icon: Icon(CupertinoIcons.trash, size: 18, color: Colors.red),
                          onPressed: () => _clearCache(context, downloadManager),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 0),

                  ListTile(
                    title: const Text('下载目录', style: TextStyle(fontWeight: FontWeight.w400)),
                    subtitle: Text(
                      settings.downloadDirectory ?? '默认目录',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                      ),
                    ),
                    trailing: Icon(CupertinoIcons.folder, size: 18, color: Colors.grey[400]),
                    onTap: () => _openDownloadDirectory(context, downloadManager),
                    onLongPress: () => _selectDownloadDirectory(context, downloadManager),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 构建账号管理分组
  Widget _buildAccountSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            '账号管理',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.red,
            ),
          ),
        ),

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cookie 管理',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '账号管理功能将在后续版本中添加',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '敬请期待:\n• Cookie 导入/导出\n• 账号信息查看\n• 会员状态显示\n• 登出功能',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white.withOpacity(0.7) : Colors.grey[700],
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 显示音质选择器
  void _showQualityPicker(
    BuildContext context, {
    required String title,
    required BilibiliAudioQuality currentQuality,
    required Function(BilibiliAudioQuality) onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 120),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)]
                      : [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.25)
                      : Colors.white.withOpacity(0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  ...BilibiliAudioQuality.values.map((quality) {
                    final isSelected = quality == currentQuality;
                    return ListTile(
                      title: Text(quality.name),
                      subtitle: Text('${quality.description} · ${quality.estimatedSize}'),
                      trailing: isSelected
                          ? Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.red)
                          : null,
                      selected: isSelected,
                      onTap: () {
                        onSelected(quality);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 选择下载目录
  Future<void> _selectDownloadDirectory(BuildContext context, DownloadManager downloadManager) async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        await downloadManager.setDownloadDirectory(result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('下载目录已更新')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择目录失败: $e')),
        );
      }
    }
  }

  /// 打开当前下载目录
  Future<void> _openDownloadDirectory(
    BuildContext context,
    DownloadManager downloadManager,
  ) async {
    final path = await downloadManager.getCurrentDownloadDirectory();
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await OpenFilex.open(path);
      if (!context.mounted) return;

      if (result.type != ResultType.done) {
        final message =
            result.message.isEmpty ? '未知错误' : result.message;
        messenger.showSnackBar(
          SnackBar(content: Text('无法打开目录：$message')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('无法打开目录: $e')),
      );
    }
  }

  /// 获取缓存大小
  Future<String> _getCacheSize(DownloadManager downloadManager) async {
    try {
      final appCacheDir = await getApplicationCacheDirectory();
      final cacheDir = p.join(appCacheDir.path, 'bilibili_auto');
      final dir = Directory(cacheDir);
      if (!await dir.exists()) return '0 MB';

      int totalSize = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      final sizeInMB = totalSize / (1024 * 1024);
      if (sizeInMB < 1024) {
        return '${sizeInMB.toStringAsFixed(2)} MB';
      } else {
        return '${(sizeInMB / 1024).toStringAsFixed(2)} GB';
      }
    } catch (e) {
      return '计算失败';
    }
  }

  /// 打开缓存目录
  Future<void> _openCacheDirectory(BuildContext context, DownloadManager downloadManager) async {
    try {
      final appCacheDir = await getApplicationCacheDirectory();
      final cacheDir = p.join(appCacheDir.path, 'bilibili_auto');
      final result = await OpenFilex.open(cacheDir);

      if (!context.mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开缓存目录: ${result.message}')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开缓存目录: $e')),
      );
    }
  }

  /// 清空缓存
  Future<void> _clearCache(BuildContext context, DownloadManager downloadManager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空缓存'),
        content: const Text('确定要清空所有自动缓存吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final appCacheDir = await getApplicationCacheDirectory();
      final cacheDir = p.join(appCacheDir.path, 'bilibili_auto');
      final dir = Directory(cacheDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('缓存已清空')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清空缓存失败: $e')),
      );
    }
  }
}
