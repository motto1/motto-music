import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motto_music/utils/theme_utils.dart';

import '../../config/default_config_manager.dart';
import '../../widgets/frosted_page_header.dart';
import '../../widgets/motto_toast.dart';

class ConfigManagementPage extends StatefulWidget {
  const ConfigManagementPage({super.key});

  @override
  State<ConfigManagementPage> createState() => _ConfigManagementPageState();
}

class _ConfigManagementPageState extends State<ConfigManagementPage> {
  bool _includeSensitive = false;
  bool _isWorking = false;

  Future<void> _exportBackup() async {
    if (_isWorking) return;
    setState(() => _isWorking = true);

    try {
      final manager = createDefaultConfigManager();
      final jsonString = await manager.exportBackupJsonString(
        includeSensitive: _includeSensitive,
        pretty: true,
      );
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      final defaultName =
          'motto-music-backup-${DateTime.now().millisecondsSinceEpoch}.json';

      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出配置备份',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        lockParentWindow: true,
        bytes: bytes,
      );

      // Android/iOS 下 saveFile 已直接保存 bytes，返回的路径可能是虚拟 URI，不应再写文件。
      if (Platform.isAndroid || Platform.isIOS) {
        MottoToast.show(context, '已导出备份');
        return;
      }

      if (path != null && path.isNotEmpty) {
        await File(path).writeAsBytes(bytes, flush: true);
        final name = path.split(Platform.pathSeparator).last;
        MottoToast.show(context, '已导出备份：$name');
      } else {
        MottoToast.show(context, '已导出备份');
      }
    } catch (e) {
      MottoToast.show(context, '导出失败: $e');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _importBackup() async {
    if (_isWorking) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.first.path;
    if (filePath == null) return;

    bool? merge;
    merge = await _selectImportMode();
    if (merge == null) return;

    setState(() => _isWorking = true);
    try {
      final content = await File(filePath).readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('备份文件格式错误');
      }

      final manager = createDefaultConfigManager();
      await manager.importBackupFromJson(
        decoded,
        merge: merge,
        includeSensitive: _includeSensitive,
      );

      MottoToast.show(
        context,
        merge ? '合并导入完成' : '覆盖导入完成',
      );
    } catch (e) {
      MottoToast.show(context, '导入失败: $e');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<bool?> _selectImportMode() async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择导入方式'),
          content: const Text(
            '合并导入会保留本地已有数据；覆盖导入会以备份为准更新相关模块。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('覆盖导入'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('合并导入'),
            ),
          ],
        );
      },
    );
  }

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
            const SliverToBoxAdapter(
              child: FrostedPageHeader(title: '配置管理'),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 150),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSensitiveSwitch(isDark),
                  const SizedBox(height: 16),
                  _buildActionCard(
                    isDark,
                    title: '导出配置备份',
                    subtitle: '导出默认配置与 Bilibili 音乐库快照',
                    onTap: _exportBackup,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    isDark,
                    title: '导入配置备份',
                    subtitle: '从备份文件恢复配置与音乐库快照',
                    onTap: _importBackup,
                  ),
                  if (_isWorking) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '处理中...',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensitiveSwitch(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SwitchListTile.adaptive(
        title: const Text('包含账号/鉴权信息'),
        subtitle: Text(
          '仅在你需要跨设备自动登录时开启',
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? Colors.white.withOpacity(0.5)
                : Colors.grey[600],
          ),
        ),
        value: _includeSensitive,
        onChanged: (v) => setState(() => _includeSensitive = v),
      ),
    );
  }

  Widget _buildActionCard(
    bool isDark, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w400)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color:
                isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
          ),
        ),
        trailing: Icon(CupertinoIcons.chevron_right,
            size: 18, color: Colors.grey[400]),
        onTap: _isWorking ? null : onTap,
      ),
    );
  }
}
