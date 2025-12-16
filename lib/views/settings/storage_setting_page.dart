import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:motto_music/utils/theme_utils.dart';
import 'package:webdav_client/webdav_client.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../router/route_observer.dart';
import '../../widgets/motto_dialog.dart';
import '../../widgets/motto_toast.dart';
import '../../services/player_provider.dart';
import '../../storage/player_state_storage.dart';
import '../../widgets/frosted_page_header.dart';

class StorageSettingPage extends StatefulWidget {
  const StorageSettingPage({super.key});

  @override
  StorageSettingPageState createState() => StorageSettingPageState();
}

class StorageSettingPageState extends State<StorageSettingPage>
    with RouteAware {
  List<StorageConfig> _storageList = [];
  int _cacheSizeGB = 5;
  String _cacheUsage = '加载中...';
  bool _isLoadingCache = true;

  @override
  void initState() {
    super.initState();
    _loadStorageList();
    _loadBilibiliCacheSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    debugPrint("StorageSettingPage: didPush (页面被打开)");
  }

  @override
  void didPop() {
    debugPrint("StorageSettingPage: didPop (页面被关闭)");
  }

  @override
  void didPopNext() {
    debugPrint("StorageSettingPage: didPopNext (别的页面返回到我)");
  }

  @override
  void didPushNext() {
    debugPrint("StorageSettingPage: didPushNext (我被盖住了)");
  }

  Future<void> _loadStorageList() async {
    // TODO: 从持久化存储加载配置列表
    setState(() {
      _storageList = [];
    });
  }

  Future<void> _loadBilibiliCacheSettings() async {
    final storage = await PlayerStateStorage.getInstance();
    
    setState(() {
      _cacheSizeGB = storage.bilibiliCacheSizeGB;
      _isLoadingCache = true;
    });
    
    try {
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      final stats = await playerProvider.getBilibiliAutoCacheStatistics();
      setState(() {
        _cacheUsage = stats != null
            ? '${stats.formattedTotalSize} / ${stats.formattedMaxSize} (${stats.fileCount} 个文件)'
            : '缓存服务未初始化';
        _isLoadingCache = false;
      });
    } catch (e) {
      setState(() {
        _cacheUsage = '加载失败';
        _isLoadingCache = false;
      });
    }
  }

  Future<void> _saveStorageList() async {
    // TODO: 保存到持久化存储
  }

  void _showAddStorageDialog({StorageConfig? editConfig, int? editIndex}) {
    MottoDialog.show(
      context,
      width: 600,
      titleText: editConfig == null ? '添加存储' : '编辑存储',
      content: StorageConfigDialogContent(
        config: editConfig,
        onSave: (config) {
          setState(() {
            if (editIndex != null) {
              _storageList[editIndex] = config;
            } else {
              _storageList.add(config);
            }
          });
          _saveStorageList();
          MottoDialog.close(context); // 保存后关闭弹窗
        },
      ),
      // MottoDialog 默认的按钮逻辑在 content 内部处理，所以这里可以不传
      // 如果需要在外部控制按钮，则需要修改 MottoDialog 的实现
      // 这里我们在 StorageConfigDialogContent 内部实现按钮逻辑
    );
  }

  void _deleteStorage(int index) {
    MottoDialog.show(
      context,
      titleText: '确认删除',
      content: Text('确定要删除存储「${_storageList[index].name}」吗？此操作无法撤销。'),
      confirmText: '删除',
      danger: true,
      onConfirm: () {
        setState(() {
          _storageList.removeAt(index);
        });
        _saveStorageList();
        MottoToast.show(context, '已删除存储配置');
      },
      cancelText: '取消',
    );
  }

  Future<void> _updateCacheSize(int newSize) async {
    final storage = await PlayerStateStorage.getInstance();
    await storage.setBilibiliCacheSize(newSize);
    setState(() {
      _cacheSizeGB = newSize;
    });
    MottoToast.show(context, '缓存大小已更新为 $newSize GB');
    await _loadBilibiliCacheSettings();
  }

  Future<void> _clearCache() async {
    MottoDialog.show(
      context,
      titleText: '清空缓存',
      content: const Text('确定要清空所有 Bilibili 音频缓存吗？此操作无法撤销。'),
      confirmText: '清空',
      danger: true,
      onConfirm: () async {
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        try {
          await playerProvider.clearBilibiliAutoCache();
          MottoToast.show(context, '✓ 缓存已清空');
          await _loadBilibiliCacheSettings();
        } catch (e) {
          MottoToast.show(context, '清空失败: $e');
        }
      },
      cancelText: '取消',
    );
  }

  Future<void> _openCacheDirectory() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final cachePath = await playerProvider.getBilibiliAutoCacheDirectory();
    if (cachePath == null || cachePath.isEmpty) {
      MottoToast.show(context, '缓存服务未初始化');
      return;
    }

    try {
      // 桌面平台
      if (Platform.isWindows) {
        await Process.run('explorer', [cachePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [cachePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [cachePath]);
      } 
      // 移动平台
      else if (Platform.isAndroid) {
        // Android 使用 Intent 打开文件管理器
        // 这里先显示路径，让用户手动打开
        await _showCachePathDialog(cachePath);
      } else if (Platform.isIOS) {
        // iOS 由于沙盒限制，无法直接打开文件管理器
        await _showCachePathDialog(cachePath);
      } else {
        MottoToast.show(context, '当前平台不支持打开目录');
      }
    } catch (e) {
      MottoToast.show(context, '打开目录失败: $e');
    }
  }

  Future<void> _showCachePathDialog(String path) async {
    MottoDialog.show(
      context,
      titleText: '缓存目录路径',
      content: SelectableText(
        path,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      confirmText: '复制路径',
      onConfirm: () async {
        // 复制到剪贴板
        await Clipboard.setData(ClipboardData(text: path));
        MottoToast.show(context, '路径已复制到剪贴板');
      },
      cancelText: '关闭',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? ThemeUtils.backgroundColor(context)
          : const Color(0xFFFFFFFF),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: FrostedPageHeader(
              title: '存储设置',
              onBack: () => Navigator.pop(context),
            ),
          ),
          // Bilibili 缓存设置部分
          SliverToBoxAdapter(
            child: _buildBilibiliCacheSection(),
          ),
          // WebDAV 存储列表标题
          if (_storageList.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'WebDAV 同步',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          // WebDAV 存储列表
          if (_storageList.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildStorageCard(_storageList[index], index),
                  childCount: _storageList.length,
                ),
              ),
            ),
          // 底部间距
          const SliverToBoxAdapter(
            child: SizedBox(height: kBottomNavigationBarHeight + 100),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddStorageDialog(),
          icon: const Icon(CupertinoIcons.add),
          label: const Text('添加存储'),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.cloud,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '还没有添加存储',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加 WebDAV 或其他云存储开始同步数据',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBilibiliCacheSection() {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bilibili 音频缓存',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 缓存使用情况
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.layers,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '缓存使用情况',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isLoadingCache ? '加载中...' : _cacheUsage,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  // 缓存大小设置
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.slider_horizontal_3,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '最大缓存大小',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '超出后自动删除最旧的缓存',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_cacheSizeGB GB',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(CupertinoIcons.pencil, size: 20),
                        onPressed: () => _showCacheSizeDialog(),
                        tooltip: '修改大小',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 操作按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openCacheDirectory,
                          icon: const Icon(CupertinoIcons.folder, size: 18),
                          label: const Text('打开目录'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _clearCache,
                          icon: const Icon(CupertinoIcons.trash, size: 18),
                          label: const Text('清空缓存'),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.errorContainer,
                            foregroundColor: theme.colorScheme.onErrorContainer,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCacheSizeDialog() {
    final theme = Theme.of(context);
    int selectedSize = _cacheSizeGB;
    
    MottoDialog.show(
      context,
      width: 400,
      titleText: '设置缓存大小',
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '当前选择: $selectedSize GB',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              Slider(
                value: selectedSize.toDouble(),
                min: 1,
                max: 50,
                divisions: 49,
                label: '$selectedSize GB',
                onChanged: (value) {
                  setState(() {
                    selectedSize = value.toInt();
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '1 GB',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '50 GB',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => MottoDialog.close(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      MottoDialog.close(context);
                      _updateCacheSize(selectedSize);
                    },
                    child: const Text('确定'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStorageCard(StorageConfig storage, int index) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            _showAddStorageDialog(editConfig: storage, editIndex: index),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getStorageIcon(storage.type),
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            storage.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            storage.type == StorageType.webdav
                                ? 'WebDAV'
                                : '阿里云',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          storage.protocol == 'https'
                              ? CupertinoIcons.lock
                              : CupertinoIcons.lock_open,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${storage.protocol}://${storage.host}${storage.path}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.person,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            storage.username,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                  ),
                  const SizedBox(width: 8),
                  // 菜单按钮
                  PopupMenuButton<String>(
                    icon: const Icon(CupertinoIcons.ellipsis_vertical),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showAddStorageDialog(
                            editConfig: storage, editIndex: index);
                      } else if (value == 'delete') {
                        _deleteStorage(index);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('编辑'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('删除'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
  }

  IconData _getStorageIcon(StorageType type) {
    switch (type) {
      case StorageType.webdav:
        return CupertinoIcons.cloud;
      case StorageType.aliyun:
        return CupertinoIcons.cloud_upload;
    }
  }
}

// 将原来的 StorageConfigDialog 的内容提取出来，作为 MottoDialog 的 content
class StorageConfigDialogContent extends StatefulWidget {
  final StorageConfig? config;
  final Function(StorageConfig) onSave;

  const StorageConfigDialogContent({
    super.key,
    this.config,
    required this.onSave,
  });

  @override
  State<StorageConfigDialogContent> createState() =>
      _StorageConfigDialogContentState();
}

class _StorageConfigDialogContentState
    extends State<StorageConfigDialogContent> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _pathController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  StorageType _selectedType = StorageType.webdav;
  String _selectedProtocol = 'https';
  bool _isPasswordVisible = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.config?.name ?? '');
    _hostController = TextEditingController(text: widget.config?.host ?? '');
    _pathController = TextEditingController(text: widget.config?.path ?? '/');
    _usernameController =
        TextEditingController(text: widget.config?.username ?? '');
    _passwordController =
        TextEditingController(text: widget.config?.password ?? '');

    if (widget.config != null) {
      _selectedType = widget.config!.type;
      _selectedProtocol = widget.config!.protocol;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _pathController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isTesting = true);
    try {
      final url =
          '$_selectedProtocol://${_hostController.text}${_pathController.text}';
      final client = newClient(
        url,
        user: _usernameController.text,
        password: _passwordController.text,
      );
      client.setConnectTimeout(8000);
      client.setReceiveTimeout(8000);
      client.setSendTimeout(8000);
      await client.ping();
      if (mounted) {
        MottoToast.show(context, '✓ 连接成功');

        var list = await client.readDir('/');
        list.forEach((f) {
          print('${f.name} ${f.path}');
        });
      }
    } catch (e) {
      if (mounted) {
        MottoToast.show(context, '连接失败: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final config = StorageConfig(
      name: _nameController.text,
      type: _selectedType,
      protocol: _selectedProtocol,
      host: _hostController.text,
      path: _pathController.text,
      username: _usernameController.text,
      password: _passwordController.text,
    );
    widget.onSave(config);
  }

  // 1. 统一的输入框样式函数 (关键)
  InputDecoration _buildInputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.04);
    final focusedBorderColor = theme.colorScheme.primary;

    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: fillColor,
      isDense: true,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: focusedBorderColor, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // 2. 创建一个可复用的表单行布局 (关键)
  Widget _buildFormRow({required String label, required Widget inputField}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80, // 统一标签宽度，确保对齐
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: inputField),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFormRow(
              label: '存储类型',
              inputField: ElegantDropdown<StorageType>(
                value: _selectedType,
                hintText: '选择类型',
                items: const [
                  ElegantDropdownItem(
                      value: StorageType.webdav, text: 'WebDAV'),
                  ElegantDropdownItem(
                      value: StorageType.aliyun,
                      text: '阿里云 OSS (即将支持)',
                      disabled: true),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedType = value);
                },
              ),
            ),
            _buildFormRow(
              label: '存储名称',
              inputField: TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration(hintText: '例如: 我的云盘'),
                validator: (v) => v == null || v.isEmpty ? '请输入存储名称' : null,
              ),
            ),
            _buildFormRow(
              label: '服务器',
              inputField: Row(
                children: [
                  ElegantDropdown<String>(
                    width: 110, // 可以指定固定宽度
                    value: _selectedProtocol,
                    items: const [
                      ElegantDropdownItem(value: 'https', text: 'HTTPS'),
                      ElegantDropdownItem(value: 'http', text: 'HTTP'),
                    ],
                    onChanged: (value) {
                      if (value != null)
                        setState(() => _selectedProtocol = value);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _hostController,
                      decoration: _buildInputDecoration(
                          hintText: 'example.com:8080'), // 复用之前的输入框样式
                      validator: (v) =>
                          v == null || v.isEmpty ? '请输入主机地址' : null,
                    ),
                  ),
                ],
              ),
            ),
            _buildFormRow(
              label: '路径',
              inputField: TextFormField(
                controller: _pathController,
                decoration: _buildInputDecoration(hintText: '/webdav'),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入路径';
                  if (!v.startsWith('/')) return '路径必须以 / 开头';
                  return null;
                },
              ),
            ),
            _buildFormRow(
              label: '用户名',
              inputField: TextFormField(
                controller: _usernameController,
                decoration: _buildInputDecoration(hintText: '选填'),
              ),
            ),
            _buildFormRow(
              label: '密码',
              inputField: TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: _buildInputDecoration(
                  hintText: '选填',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? CupertinoIcons.eye_slash
                          : CupertinoIcons.eye,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 底部按钮区域
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(CupertinoIcons.wifi),
                label: Text(_isTesting ? '测试中...' : '测试连接'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => MottoDialog.close(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _save,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 存储配置模型 (保持不变)
class StorageConfig {
  final String name;
  final StorageType type;
  final String protocol;
  final String host;
  final String path;
  final String username;
  final String password;

  StorageConfig({
    required this.name,
    required this.type,
    required this.protocol,
    required this.host,
    required this.path,
    this.username = '',
    this.password = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.name,
      'protocol': protocol,
      'host': host,
      'path': path,
      'username': username,
      'password': password,
    };
  }

  factory StorageConfig.fromJson(Map<String, dynamic> json) {
    return StorageConfig(
      name: json['name'],
      type: StorageType.values.firstWhere((e) => e.name == json['type']),
      protocol: json['protocol'],
      host: json['host'],
      path: json['path'],
      username: json['username'] ?? '',
      password: json['password'] ?? '',
    );
  }
}

enum StorageType {
  webdav,
  aliyun,
}

class ElegantDropdownItem<T> {
  final T value;
  final String text;
  final bool disabled;

  const ElegantDropdownItem(
      {required this.value, required this.text, this.disabled = false});
}

class ElegantDropdown<T> extends StatefulWidget {
  final T? value;
  final List<ElegantDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hintText;
  final double width;

  const ElegantDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.hintText = '',
    this.width = double.infinity,
  });

  @override
  State<ElegantDropdown<T>> createState() => _ElegantDropdownState<T>();
}

class _ElegantDropdownState<T> extends State<ElegantDropdown<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  OverlayEntry? _barrierEntry;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool get _isMenuOpen =>
      _animationController.status == AnimationStatus.completed ||
      _animationController.status == AnimationStatus.forward;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _hideMenu();
    } else {
      _showMenu();
    }
  }

  void _showMenu() {
  final overlay = Overlay.of(context);
  final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
  final size = renderBox.size;

  // 1. 创建屏障层 (Barrier)
  _barrierEntry = OverlayEntry(
    builder: (context) => Positioned.fill(
      // 使用 Flutter 内置的 ModalBarrier，它能很好地处理点击事件
      child: GestureDetector(
        onTap: _hideMenu, // 点击屏障时关闭菜单
        behavior: HitTestBehavior.opaque, // 确保整个区域都能响应点击
        child: Container(color: Colors.transparent), // 透明背景
      ),
    ),
  );

  // 2. 创建菜单层 (和以前一样)
  _overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      width: size.width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: Offset(0.0, size.height + 6.0),
        child: _buildMenu(),
      ),
    ),
  );

  // 3. 关键：先插入屏障，再插入菜单
  overlay.insert(_barrierEntry!);
  overlay.insert(_overlayEntry!);

  _animationController.forward();
}

void _hideMenu() async {
  // 等待动画完成
  await _animationController.reverse();

  // 关键：同时移除菜单和屏障
  _overlayEntry?.remove();
  _overlayEntry = null;

  _barrierEntry?.remove();
  _barrierEntry = null;
}

  void _onItemSelected(ElegantDropdownItem<T> item) {
    if (item.disabled) return;
    widget.onChanged(item.value);
    _hideMenu();
  }

  // 构建真正美观的菜单
  Widget _buildMenu() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2A2A2E) : Colors.white;
    final shadowColor =
        isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.08);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {},
            child: Container(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 20.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Padding(padding: EdgeInsets.all(6),child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: widget.items.length,
                shrinkWrap: true,
                 separatorBuilder: (context, index) => const SizedBox(height: 6.0),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final isSelected = item.value == widget.value;

                  return Material(
                      // 1. 直接在 Material 上定义形状
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      // 2. 将背景色也移到 Material 上
                      color: isSelected
                          ? theme.colorScheme.onSurface.withOpacity(0.1)
                          : Colors.transparent,
                      // 3. 使用 Clip.antiAlias 确保子内容被完美裁剪
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _onItemSelected(item),
                        splashColor: item.disabled ? Colors.transparent : null,
                        highlightColor:
                            item.disabled ? Colors.transparent : null,
                        child: Container(
                          // 4. Container 现在只负责内边距(padding)
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          child: Text(
                            item.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: item.disabled
                                  ? theme.disabledColor
                                  : (isSelected
                                      ? theme.colorScheme.onSurface
                                      : theme.textTheme.bodyLarge?.color),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                },
              ),),
            ),
          ),
          )
        ),
      ),
    );
  }

  // 构建按钮部分
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.04);
    final selectedItem = widget.items.firstWhere(
        (item) => item.value == widget.value,
        orElse: () => ElegantDropdownItem<T>(
            value: widget.value as T, text: widget.hintText));

    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        key: _buttonKey,
        width: widget.width,
        child: GestureDetector(
          onTap: _toggleMenu,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: _isMenuOpen
                    ? theme.colorScheme.onSurface
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedItem.text,
                    style: TextStyle(
                      color: widget.value != null
                          ? theme.textTheme.bodyLarge?.color
                          : theme.hintColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isMenuOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child:
                      const Icon(CupertinoIcons.chevron_down, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
