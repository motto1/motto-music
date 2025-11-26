import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:motto_music/services/bilibili/download_manager.dart';
import 'package:motto_music/models/bilibili/audio_quality.dart';
import 'package:motto_music/widgets/frosted_page_header.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:open_filex/open_filex.dart';

import 'package:motto_music/views/bilibili/widgets/setting_card.dart';

/// Bilibili 设置页面
///
/// 使用单页面滚动布局,包含:
/// - 音质设置区域
/// - 下载设置区域
/// - 账号管理区域
class BilibiliSettingsPage extends StatelessWidget {
  const BilibiliSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark 
          ? ThemeUtils.backgroundColor(context)
          : const Color(0xFFF2F2F7),
      body: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: (notification) {
          notification.disallowIndicator();
          return true;
        },
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
          // 液态玻璃头部
          SliverToBoxAdapter(
            child: FrostedPageHeader(
              title: 'Bilibili 设置',
            ),
          ),
          
          // 音质设置区域
          SliverToBoxAdapter(
            child: _QualitySettingsSection(),
          ),
          
          // 下载设置区域
          SliverToBoxAdapter(
            child: _DownloadSettingsSection(),
          ),
          
          // 账号管理区域
          SliverToBoxAdapter(
            child: _AccountSettingsSection(),
          ),
          
          // 底部间距
          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
      ),
    );
  }
}

/// 音质设置区域
class _QualitySettingsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 区域标题
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              '音质设置',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          Consumer<DownloadManager>(
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
                children: [
                  // 默认播放音质
                  SettingCard(
                    child: ListTile(
                      leading: Icon(
                        CupertinoIcons.play_circle,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('默认播放音质'),
                      subtitle: Text(defaultPlayQuality.displayName),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      onTap: () => _showQualityPicker(
                        context,
                        title: '选择默认播放音质',
                        currentQuality: defaultPlayQuality,
                        onSelected: (quality) {
                          downloadManager.setDefaultPlayQuality(quality);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 默认下载音质
                  SettingCard(
                    child: ListTile(
                      leading: Icon(
                        CupertinoIcons.arrow_down_circle,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('默认下载音质'),
                      subtitle: Text(defaultDownloadQuality.displayName),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      onTap: () => _showQualityPicker(
                        context,
                        title: '选择默认下载音质',
                        currentQuality: defaultDownloadQuality,
                        onSelected: (quality) {
                          downloadManager.setDefaultDownloadQuality(quality);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 自动选择音质
                  SettingCard(
                    child: SwitchListTile(
                      secondary: Icon(
                        CupertinoIcons.sparkles,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('根据网络自动选择音质'),
                      subtitle: const Text('WiFi使用无损,移动网络使用高音质'),
                      value: settings.autoSelectQuality,
                      onChanged: (value) {
                        downloadManager.setAutoSelectQuality(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 音质说明卡片
                  _buildQualityInfoCard(context),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 显示音质选择器
  static void _showQualityPicker(
    BuildContext context, {
    required String title,
    required BilibiliAudioQuality currentQuality,
    required Function(BilibiliAudioQuality) onSelected,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: BilibiliAudioQuality.values.map((quality) {
            final isSelected = quality == currentQuality;
            return ListTile(
              leading: Icon(
                quality.getIcon(),
                color: isSelected ? quality.color : null,
              ),
              title: Text(quality.name),
              subtitle: Text('${quality.description} · ${quality.estimatedSize}'),
              trailing: isSelected
                  ? Icon(Icons.check, color: quality.color)
                  : null,
              selected: isSelected,
              onTap: () {
                onSelected(quality);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 构建音质信息卡片
  static Widget _buildQualityInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    
    return SettingCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.info_circle,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '音质说明',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...BilibiliAudioQuality.values.map((quality) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    quality.getBadge(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quality.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '约 ${quality.estimatedSize}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.orange[700],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '注意:Hi-Res、Dolby 等高级音质可能需要大会员权限',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


/// 下载设置区域
class _DownloadSettingsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 区域标题
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              '下载设置',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          Consumer<DownloadManager>(
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

              return Column(
                children: [
                  // 仅WiFi下载
                  SettingCard(
                    child: SwitchListTile(
                      secondary: Icon(
                        CupertinoIcons.wifi,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('仅WiFi下载'),
                      subtitle: const Text('移动网络环境下禁止下载'),
                      value: settings.wifiOnlyDownload,
                      onChanged: (value) {
                        downloadManager.setWifiOnlyDownload(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 最大并发下载数
                  SettingCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.speedometer,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '最大并发下载数',
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                    Text(
                                      '当前: ${settings.maxConcurrentDownloads} 个',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: settings.maxConcurrentDownloads.toDouble(),
                            min: 1,
                            max: 5,
                            divisions: 4,
                            label: '${settings.maxConcurrentDownloads} 个',
                            onChanged: (value) {
                              downloadManager.setMaxConcurrentDownloads(value.toInt());
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 自动重试失败任务
                  SettingCard(
                    child: SwitchListTile(
                      secondary: Icon(
                        CupertinoIcons.arrow_2_circlepath,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('自动重试失败任务'),
                      subtitle: const Text('下载失败后自动重试(最多3次)'),
                      value: settings.autoRetryFailed,
                      onChanged: (value) {
                        downloadManager.setAutoRetryFailed(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 自动缓存空间限制
                  SettingCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.folder,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '自动缓存空间限制',
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                    Text(
                                      '当前: ${settings.autoCacheSizeGB} GB',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: settings.autoCacheSizeGB.toDouble(),
                            min: 1,
                            max: 20,
                            divisions: 19,
                            label: '${settings.autoCacheSizeGB} GB',
                            onChanged: (value) {
                              downloadManager.setAutoCacheSizeGB(value.toInt());
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 下载目录
                  SettingCard(
                    child: ListTile(
                      leading: Icon(
                        CupertinoIcons.folder_open,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('下载目录'),
                      subtitle: Text(
                        settings.downloadDirectory ?? '默认目录（点击打开，长按更改）',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        Icons.open_in_new,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      onTap: () => _openDownloadDirectory(context, downloadManager),
                      onLongPress: () => _selectDownloadDirectory(context, downloadManager),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 选择下载目录
  static Future<void> _selectDownloadDirectory(BuildContext context, DownloadManager downloadManager) async {
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
  static Future<void> _openDownloadDirectory(
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
}


/// 账号管理区域
class _AccountSettingsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 区域标题
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              '账号管理',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // 提示卡片
          SettingCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.person_circle,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Cookie 管理',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '账号管理功能将在后续版本中添加',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '敬请期待:\n• Cookie 导入/导出\n• 账号信息查看\n• 会员状态显示\n• 登出功能',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
