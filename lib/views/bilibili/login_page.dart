import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:motto_music/services/bilibili/login_service.dart';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bilibili 登录页面
class BilibiliLoginPage extends StatefulWidget {
  const BilibiliLoginPage({super.key});

  @override
  State<BilibiliLoginPage> createState() => _BilibiliLoginPageState();
}

class _BilibiliLoginPageState extends State<BilibiliLoginPage> {
  late final BilibiliLoginService _loginService;
  
  LoginStatus _status = LoginStatus.idle;
  QRCodeInfo? _qrCodeInfo;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // 初始化登录服务
    final cookieManager = CookieManager();
    final apiClient = BilibiliApiClient(cookieManager);
    _loginService = BilibiliLoginService(apiClient, cookieManager);
    
    // 检查是否已登录
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _loginService.dispose();
    super.dispose();
  }

  /// 检查登录状态
  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await _loginService.isLoggedIn();
    if (isLoggedIn && mounted) {
      // 已登录，返回上一页
      Navigator.of(context).pop(true);
    } else {
      // 未登录，获取二维码
      _getQRCode();
    }
  }

  /// 获取登录二维码
  Future<void> _getQRCode() async {
    setState(() {
      _status = LoginStatus.loading;
      _errorMessage = null;
    });

    try {
      final qrCode = await _loginService.getLoginQRCode();
      
      if (mounted) {
        setState(() {
          _qrCodeInfo = qrCode;
          _status = LoginStatus.waitingScan;
        });

        // 开始轮询
        _loginService.startPolling(
          qrcodeKey: qrCode.qrcodeKey,
          onStatusChanged: _handleStatusChange,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = LoginStatus.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// 处理状态变化
  void _handleStatusChange(LoginStatus status) {
    if (!mounted) return;

    setState(() {
      _status = status;
    });

    // 登录成功
    if (status == LoginStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('登录成功！'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 延迟一下再返回，让用户看到成功提示
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    }
    
    // 二维码过期
    else if (status == LoginStatus.expired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('二维码已过期，请刷新'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// 刷新二维码
  void _refreshQRCode() {
    _loginService.stopPolling();
    _getQRCode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_status == LoginStatus.expired || _status == LoginStatus.error)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshQRCode,
              tooltip: '刷新二维码',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFB7299), // Bilibili Pink
              const Color(0xFF23ADE5), // Bilibili Blue
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(32),
                  child: _buildBody(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case LoginStatus.idle:
      case LoginStatus.loading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              '正在获取登录二维码...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        );

      case LoginStatus.waitingScan:
      case LoginStatus.scanned:
        return _buildQRCodeView();

      case LoginStatus.success:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            SizedBox(height: 24),
            Text(
              '登录成功！',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text('正在跳转...', style: TextStyle(color: Colors.grey)),
          ],
        );

      case LoginStatus.expired:
        return _buildExpiredView();

      case LoginStatus.error:
        return _buildErrorView();

      case LoginStatus.cancelled:
        return const Text('登录已取消');
    }
  }

  /// 构建二维码视图
  Widget _buildQRCodeView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题
        Text(
          _status == LoginStatus.scanned ? '请在手机上确认登录' : '扫码登录',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 32),
        
        // 二维码
        if (_qrCodeInfo != null)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () async {
                try {
                  final uri = Uri.parse(_qrCodeInfo!.url);
                  await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('无法打开链接: $e')),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: _qrCodeInfo!.url,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '点击跳转到浏览器登录',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        const SizedBox(height: 32),
        
        // 状态提示
        if (_status == LoginStatus.scanned)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  '已扫码，请在手机上确认',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        else
          const Text(
            '请使用 Bilibili 客户端扫码',
            style: TextStyle(color: Colors.grey),
          ),
      ],
    );
  }

  /// 构建过期视图
  Widget _buildExpiredView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.qr_code_scanner, size: 80, color: Colors.orange),
        const SizedBox(height: 24),
        const Text(
          '二维码已过期',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _refreshQRCode,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新二维码'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建错误视图
  Widget _buildErrorView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 80, color: Colors.red),
        const SizedBox(height: 24),
        const Text(
          '获取二维码失败',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _refreshQRCode,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ],
    );
  }
}
