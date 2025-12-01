// theme_provider.dart - 主题管理
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:motto_music/utils/platform_utils.dart';
import 'package:motto_music/widgets/show_aware_page.dart';
import 'package:provider/provider.dart';
import '../../services/theme_provider.dart';
import '../../services/player_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../widgets/motto_toast.dart';
import '../../router/router.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:motto_music/widgets/frosted_container.dart';
import 'package:motto_music/widgets/themed_background.dart';
import '../../widgets/page_header.dart';
import '../../widgets/frosted_page_header.dart';
import 'package:motto_music/utils/common_utils.dart';
import 'package:motto_music/utils/theme_utils.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> with ShowAwarePage {
  @override
  void onPageShow() {
    print('settings ...');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await windowManager.minimize();
        }
      },
      child: Consumer<AppThemeProvider>(
        builder: (context, themeProvider, child) {
          return Scaffold(
            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                ? ThemeUtils.backgroundColor(context)
                : const Color(0xFFF2F2F7),
            body: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: FrostedPageHeader(
                    title: '系统设置',
                    showBackButton: false,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildSectionHeader('外观设置'),
                      _buildThemeSettingCard(),
                      const SizedBox(height: 18),
                      _buildSectionHeader('存储设置'),
                      _buildStorageSettingCard(),
                      const SizedBox(height: 18),
                      _buildSectionHeader('播放设置'),
                      _buildPlaybackSettingCard(),
                      const SizedBox(height: 18),
                      _buildSectionHeader('其他设置'),
                      _buildOtherSettingsCard(),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 构建分组标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // 主题设置卡片
  Widget _buildThemeSettingCard() {
    return Consumer<AppThemeProvider>(
      builder: (context, themeProvider, child) {
        return _buildSettingCard(
          child: Column(
            children: [
              // 主题模式
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Icon(
                    themeProvider.getThemeIcon(),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text(
                  '主题模式',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(themeProvider.getThemeName()),
                trailing: const Icon(CupertinoIcons.chevron_right),
                onTap: () => _showThemeDialog(themeProvider),
              ),
              // 主题色选择
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Icon(
                    CupertinoIcons.paintbrush_fill,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  '主题色&背景透明度(高斯模糊)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  '通过调色盘调整主题色和背景透明度',
                ), // 可以显示色名或者 HEX，如 themeProvider.seedColor.toString()
                trailing: const Icon(CupertinoIcons.chevron_right),
                onTap: () async {
                  // 弹出颜色选择对话框
                  await showDialog<Color>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('选择主题色'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 颜色选择器
                            ColorPicker(
                              hexInputBar: true,
                              paletteType: PaletteType.rgbWithBlue,
                              displayThumbColor: true,
                              portraitOnly: true,
                              enableAlpha: true,
                              labelTypes: [],
                              colorPickerWidth: 300,
                              onHistoryChanged: (color) {},
                              colorHistory: [
                                Color(0xFF016B5B),
                                Colors.red,
                                Colors.green,
                                Colors.blue,
                                Colors.orange,
                                Colors.purple,
                                Colors.pink,
                                Colors.amber,
                              ],
                              pickerColor: themeProvider.seedColor,
                              onColorChanged: (color) {
                                themeProvider.setSeedColor(color);
                              },
                            ),

                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "透明区域",
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Radio<String>(
                                      value: "window",
                                      groupValue: themeProvider.opacityTarget,
                                      onChanged: (value) {
                                        if (value != null) {
                                          themeProvider.setOpacityTarget(value);
                                        }
                                      },
                                    ),
                                    const Text("窗口"),
                                    SizedBox(width: 12),
                                    Radio<String>(
                                      value: "sidebar",
                                      groupValue: themeProvider.opacityTarget,
                                      onChanged: (value) {
                                        if (value != null) {
                                          themeProvider.setOpacityTarget(value);
                                        }
                                      },
                                    ),
                                    const Text("仅侧边栏"),
                                    SizedBox(width: 12),
                                    Radio<String>(
                                      value: "body",
                                      groupValue: themeProvider.opacityTarget,
                                      onChanged: (value) {
                                        if (value != null) {
                                          themeProvider.setOpacityTarget(value);
                                        }
                                      },
                                    ),
                                    const Text("仅主体"),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStorageSettingCard() {
    return Consumer<AppThemeProvider>(
      builder: (context, themeProvider, child) {
        return _buildSettingCard(
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Icon(
                    CupertinoIcons.folder,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text(
                  '存储设置',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('添加存储本地/WebDav/More...'),
                trailing: const Icon(CupertinoIcons.chevron_right),
                onTap: () {
                  NestedNavigationHelper.push(context, "/settings/storage");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 播放设置卡片
  Widget _buildPlaybackSettingCard() {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        return _buildSettingCard(
          child: Column(
            children: [
              // 音量设置 - 简洁横向滑块
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    // 音量图标
                    Icon(
                      playerProvider.volume == 0
                          ? CupertinoIcons.volume_mute
                          : CupertinoIcons.volume_up,
                      color: Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    // 圆角容器滑块
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onTapDown: (details) {
                              final percentage = details.localPosition.dx / constraints.maxWidth;
                              playerProvider.setVolume((percentage * 1.5).clamp(0.0, 1.5));
                            },
                            onHorizontalDragUpdate: (details) {
                              final percentage = details.localPosition.dx / constraints.maxWidth;
                              playerProvider.setVolume((percentage * 1.5).clamp(0.0, 1.5));
                            },
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // 填充部分（类似水位）
                                  FractionallySizedBox(
                                    widthFactor: (playerProvider.volume / 1.5).clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.green.shade300, Colors.green.shade600],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  // 百分比文字
                                  Center(
                                    child: Text(
                                      '${(playerProvider.volume * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: playerProvider.volume > 0.3
                                            ? Colors.white
                                            : (Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white70
                                                : Colors.black54),
                                        shadows: playerProvider.volume > 0.3
                                            ? [
                                                Shadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  blurRadius: 2,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 音量数值
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(playerProvider.volume * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 音效设置
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  child: const Icon(CupertinoIcons.waveform, color: Colors.orange),
                ),
                title: const Text(
                  '音效设置',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('均衡器和音效'),
                trailing: const Icon(CupertinoIcons.chevron_right),
                onTap: () {
                  MottoToast.show(context, '音效设置功能尚未实现');
                },
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                secondary: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(
                    CupertinoIcons.music_note_list,
                    color: Colors.blue,
                  ),
                ),
                value: playerProvider.lyricsNotificationEnabled,
                onChanged: (value) {
                  playerProvider.setLyricsNotificationEnabled(value);
                },
                title: const Text(
                  '歌词通知',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('在系统通知中显示歌词'),
              ),
              SwitchListTile.adaptive(
                secondary: CircleAvatar(
                  backgroundColor: Colors.purple.withOpacity(0.1),
                  child: const Icon(
                    CupertinoIcons.device_phone_portrait,
                    color: Colors.purple,
                  ),
                ),
                value: playerProvider.lockScreenEnabled,
                onChanged: (value) {
                  playerProvider.setLockScreenEnabled(value);
                },
                title: const Text(
                  '锁屏播放界面',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('在系统锁屏显示 Metro 风格播放界面'),
              ),
            ],
          ),
        );
      },
    );
  }

  // 其他设置卡片
  Widget _buildOtherSettingsCard() {
    return _buildSettingCard(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.withOpacity(0.1),
              child: const Icon(CupertinoIcons.chat_bubble, color: Colors.red),
            ),
            title: const Text(
              '反馈建议及联系方式',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('发送反馈和建议'),
            trailing: const Icon(CupertinoIcons.chevron_right),
            onTap: () {
              _feedbackAndImproveDialog();
            },
          ),

          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(CupertinoIcons.doc_plaintext, color: Colors.blue),
            ),
            title: const Text(
              '许可证 Apache 2.0',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('查看软件许可证信息'),
            trailing: const Icon(CupertinoIcons.chevron_right),
            onTap: () {
              _showLicenseDialog();
            },
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.withOpacity(0.1),
              child: const Icon(CupertinoIcons.info_circle_fill, color: Colors.purple),
            ),
            title: const Text(
              '关于应用',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('版本信息和开发者'),
            trailing: const Icon(CupertinoIcons.chevron_right),
            onTap: () {
              _showAboutDialog();
            },
          ),
        ],
      ),
    );
  }

  // 通用设置卡片构建器
  Widget _buildSettingCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.grey.withOpacity(isDark ? 0.1 : 0.15),

      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias, // 裁剪水波纹
      child: child,
    );
  }

  // 显示主题选择对话框
  void _showThemeDialog(AppThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => ThemeSelectionDialog(themeProvider: themeProvider),
    );
  }

  // 显示关于对话框
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于 Motto Music'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Motto Music',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('版本: 0.1.0-beta'),
                const SizedBox(height: 4),
                const Text('基于 Flutter 开发的 Android 音乐播放器'),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  '✨ 核心特性',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• Bilibili 音源聚合与下载管理'),
                const Text('• 本地音乐文件播放'),
                const Text('• 智能歌词系统（网易云 API）'),
                const Text('• Apple Music 风格播放器'),
                const Text('• 精美锁屏界面与歌词滚动'),
                const SizedBox(height: 12),
                const Text(
                  '📝 开源信息',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('许可证: Apache License 2.0'),
                const Text('仓库: github.com/motto1/motto-music'),
                const SizedBox(height: 12),
                const Text(
                  '💖 致谢',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '本项目借鉴了 namida、BBPlayer、LZF-Music、Metro 等优秀开源项目的经验。',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  '完全由 vibe coding 驱动开发。',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final uri = Uri.parse('https://github.com/motto1/motto-music');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('访问 GitHub'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 许可证弹窗示例
  void _showLicenseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('软件许可证 Apache 2.0'),
        content: SingleChildScrollView(
          child: Text("""Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

1. Definitions.

"License" shall mean the terms and conditions for use, reproduction, and distribution as defined by Sections 1 through 9 of this document.

"Licensor" shall mean the copyright owner or entity authorized by the copyright owner that is granting the License.

"Legal Entity" shall mean the union of the acting entity and all other entities that control, are controlled by, or are under common control with that entity. For the purposes of this definition, "control" means (i) the power, direct or indirect, to cause the direction or management of such entity, whether by contract or otherwise, or (ii) ownership of fifty percent (50%) or more of the outstanding shares, or (iii) beneficial ownership of such entity.

"You" (or "Your") shall mean an individual or Legal Entity exercising permissions granted by this License.

"Source" form shall mean the preferred form for making modifications, including but not limited to software source code, documentation source, and configuration files.

"Object" form shall mean any form resulting from mechanical transformation or translation of a Source form, including but not limited to compiled object code, generated documentation, and conversions to other media types.

"Work" shall mean the work of authorship, whether in Source or Object form, made available under the License, as indicated by a copyright notice that is included in or attached to the work (an example is provided in the Appendix below).

"Derivative Works" shall mean any work, whether in Source or Object form, that is based on (or derived from) the Work and for which the editorial revisions, annotations, elaborations, or other modifications represent, as a whole, an original work of authorship. For the purposes of this License, Derivative Works shall not include works that remain separable from, or merely link (or bind by name) to the interfaces of, the Work and Derivative Works thereof.

"Contribution" shall mean any work of authorship, including the original version of the Work and any modifications or additions to that Work or Derivative Works thereof, that is intentionally submitted to Licensor for inclusion in the Work by the copyright owner or by an individual or Legal Entity authorized to submit on behalf of the copyright owner. For the purposes of this definition, "submitted" means any form of electronic, verbal, or written communication sent to the Licensor or its representatives, including but not limited to communication on electronic mailing lists, source code control systems, and issue tracking systems that are managed by, or on behalf of, the Licensor for the purpose of discussing and improving the Work, but excluding communication that is conspicuously marked or otherwise designated in writing by the copyright owner as "Not a Contribution."

"Contributor" shall mean Licensor and any individual or Legal Entity on behalf of whom a Contribution has been received by Licensor and subsequently incorporated within the Work.

2. Grant of Copyright License. Subject to the terms and conditions of this License, each Contributor hereby grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable copyright license to reproduce, prepare Derivative Works of, publicly display, publicly perform, sublicense, and distribute the Work and such Derivative Works in Source or Object form.

3. Grant of Patent License. Subject to the terms and conditions of this License, each Contributor hereby grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable (except as stated in this section) patent license to make, have made, use, offer to sell, sell, import, and otherwise transfer the Work, where such license applies only to those patent claims licensable by such Contributor that are necessarily infringed by their Contribution(s) alone or by combination of their Contribution(s) with the Work to which such Contribution(s) was submitted. If You institute patent litigation against any entity (including a cross-claim or counterclaim in a lawsuit) alleging that the Work or a Contribution incorporated within the Work constitutes direct or contributory patent infringement, then any patent licenses granted to You under this License for that Work shall terminate as of the date such litigation is filed.

4. Redistribution. You may reproduce and distribute copies of the Work or Derivative Works thereof in any medium, with or without modifications, and in Source or Object form, provided that You meet the following conditions:

You must give any other recipients of the Work or Derivative Works a copy of this License; and
You must cause any modified files to carry prominent notices stating that You changed the files; and
You must retain, in the Source form of any Derivative Works that You distribute, all copyright, patent, trademark, and attribution notices from the Source form of the Work, excluding those notices that do not pertain to any part of the Derivative Works; and
If the Work includes a "NOTICE" text file as part of its distribution, then any Derivative Works that You distribute must include a readable copy of the attribution notices contained within such NOTICE file, excluding those notices that do not pertain to any part of the Derivative Works, in at least one of the following places: within a NOTICE text file distributed as part of the Derivative Works; within the Source form or documentation, if provided along with the Derivative Works; or, within a display generated by the Derivative Works, if and wherever such third-party notices normally appear. The contents of the NOTICE file are for informational purposes only and do not modify the License. You may add Your own attribution notices within Derivative Works that You distribute, alongside or as an addendum to the NOTICE text from the Work, provided that such additional attribution notices cannot be construed as modifying the License.
You may add Your own copyright statement to Your modifications and may provide additional or different license terms and conditions for use, reproduction, or distribution of Your modifications, or for any such Derivative Works as a whole, provided Your use, reproduction, and distribution of the Work otherwise complies with the conditions stated in this License.

5. Submission of Contributions. Unless You explicitly state otherwise, any Contribution intentionally submitted for inclusion in the Work by You to the Licensor shall be under the terms and conditions of this License, without any additional terms or conditions. Notwithstanding the above, nothing herein shall supersede or modify the terms of any separate license agreement you may have executed with Licensor regarding such Contributions.

6. Trademarks. This License does not grant permission to use the trade names, trademarks, service marks, or product names of the Licensor, except as required for reasonable and customary use in describing the origin of the Work and reproducing the content of the NOTICE file.

7. Disclaimer of Warranty. Unless required by applicable law or agreed to in writing, Licensor provides the Work (and each Contributor provides its Contributions) on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied, including, without limitation, any warranties or conditions of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A PARTICULAR PURPOSE. You are solely responsible for determining the appropriateness of using or redistributing the Work and assume any risks associated with Your exercise of permissions under this License.

8. Limitation of Liability. In no event and under no legal theory, whether in tort (including negligence), contract, or otherwise, unless required by applicable law (such as deliberate and grossly negligent acts) or agreed to in writing, shall any Contributor be liable to You for damages, including any direct, indirect, special, incidental, or consequential damages of any character arising as a result of this License or out of the use or inability to use the Work (including but not limited to damages for loss of goodwill, work stoppage, computer failure or malfunction, or any and all other commercial damages or losses), even if such Contributor has been advised of the possibility of such damages.

9. Accepting Warranty or Additional Liability. While redistributing the Work or Derivative Works thereof, You may choose to offer, and charge a fee for, acceptance of support, warranty, indemnity, or other liability obligations and/or rights consistent with this License. However, in accepting such obligations, You may act only on Your own behalf and on Your sole responsibility, not on behalf of any other Contributor, and only if You agree to indemnify, defend, and hold each Contributor harmless for any liability incurred by, or claims asserted against, such Contributor by reason of your accepting any such warranty or additional liability.

END OF TERMS AND CONDITIONS
""", style: const TextStyle(fontSize: 14)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _feedbackAndImproveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('反馈与联系'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '欢迎通过以下方式与我们联系：',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildLinkRow(
              context,
              '🐛 反馈 Bug',
              'https://github.com/motto1/motto-music/issues',
            ),
            const SizedBox(height: 8),
            _buildLinkRow(
              context,
              '💡 功能建议',
              'https://github.com/motto1/motto-music/discussions',
            ),
            const SizedBox(height: 8),
            _buildLinkRow(
              context,
              '📖 项目主页',
              'https://github.com/motto1/motto-music',
            ),
            const SizedBox(height: 8),
            _buildLinkRow(
              context,
              '👤 开发者',
              'https://github.com/motto1',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }


  Widget _buildLinkRow(BuildContext context, String label, String url) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('无法打开链接: $url')));
              }
            },
            child: Text(
              url,
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ThemeSelectionDialog extends StatelessWidget {
  final AppThemeProvider themeProvider;

  const ThemeSelectionDialog({Key? key, required this.themeProvider})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择主题'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              context,
              ThemeMode.light,
              '亮色模式',
              CupertinoIcons.sun_max,
              '始终使用亮色主题',
            ),
            _buildThemeOption(
              context,
              ThemeMode.dark,
              '深色模式',
              CupertinoIcons.moon,
              '始终使用深色主题',
            ),
            _buildThemeOption(
              context,
              ThemeMode.system,
              '跟随系统',
              CupertinoIcons.device_phone_portrait,
              '跟随系统设置自动切换',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeMode mode,
    String title,
    IconData icon,
    String subtitle,
  ) {
    final isSelected = themeProvider.themeMode == mode;

    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // 设置圆角半径
      ),
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? Icon(
              CupertinoIcons.checkmark_circle_fill,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: () {
        themeProvider.setThemeMode(mode);
        Navigator.of(context).pop();
      },
      splashColor: Theme.of(
        context,
      ).colorScheme.primary.withOpacity(0.2), // 可选：点击水波纹颜色
    );
  }
}

class LibraryHeader extends StatefulWidget {
  const LibraryHeader({super.key});

  @override
  State<LibraryHeader> createState() => _LibraryHeaderState();
}

class _LibraryHeaderState extends State<LibraryHeader> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '喜欢',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
      ],
    );
  }
}

class TransparentPageRoute<T> extends PageRoute<T> {
  TransparentPageRoute({required this.builder, RouteSettings? settings})
    : super(settings: settings, fullscreenDialog: false);

  final WidgetBuilder builder;

  @override
  bool get opaque => false; // 核心：页面非不透明

  @override
  Color? get barrierColor => null; // 我们不需要背景遮罩

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350); // 动画时长

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 我们只对新页面（child）应用淡入动画
    // 旧页面（由 secondaryAnimation 控制）我们不给它应用任何动画，让它保持静止
    return FadeTransition(opacity: animation, child: child);
  }
}
