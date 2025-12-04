import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:motto_music/services/bilibili/download_manager.dart';
import 'package:motto_music/models/bilibili/audio_quality.dart';
import 'package:motto_music/widgets/frosted_page_header.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:open_filex/open_filex.dart';

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

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
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
        ),
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
