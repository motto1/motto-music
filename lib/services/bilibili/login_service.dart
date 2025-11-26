import 'dart:async';
import 'package:motto_music/services/bilibili/api_client.dart';
import 'package:motto_music/services/bilibili/cookie_manager.dart';
import 'package:motto_music/services/bilibili/bilibili_exception.dart';

/// 登录状态
enum LoginStatus {
  idle,           // 空闲，未开始
  loading,        // 正在获取二维码
  waitingScan,    // 等待扫码
  scanned,        // 已扫码，等待确认
  success,        // 登录成功
  expired,        // 二维码过期
  cancelled,      // 取消登录
  error,          // 登录出错
}

/// 二维码信息
class QRCodeInfo {
  final String url;           // 二维码 URL
  final String qrcodeKey;     // 二维码 key，用于轮询
  
  QRCodeInfo({
    required this.url,
    required this.qrcodeKey,
  });
}

/// Bilibili 登录服务
/// 
/// 实现二维码扫码登录流程
class BilibiliLoginService {
  final BilibiliApiClient _apiClient;
  final CookieManager _cookieManager;
  
  Timer? _pollTimer;
  QRCodeInfo? _currentQRCode;
  
  BilibiliLoginService(this._apiClient, this._cookieManager);
  
  /// 获取登录二维码
  Future<QRCodeInfo> getLoginQRCode() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        'https://passport.bilibili.com/x/passport-login/web/qrcode/generate',
        fullUrl: 'https://passport.bilibili.com/x/passport-login/web/qrcode/generate',
      );
      
      final url = response['url'] as String;
      final qrcodeKey = response['qrcode_key'] as String;
      
      _currentQRCode = QRCodeInfo(
        url: url,
        qrcodeKey: qrcodeKey,
      );
      
      return _currentQRCode!;
    } catch (e) {
      throw BilibiliApiException(
        message: '获取登录二维码失败: $e',
        type: BilibiliApiExceptionType.networkError,
      );
    }
  }
  
  /// 检查二维码状态
  /// 
  /// 返回值:
  /// - 0: 未扫码
  /// - 86038: 二维码已过期
  /// - 86090: 已扫码未确认
  /// - 86101: 未扫码
  /// - 0 且有 cookie: 登录成功
  Future<LoginStatus> checkQRCodeStatus(String qrcodeKey) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        'https://passport.bilibili.com/x/passport-login/web/qrcode/poll',
        params: {'qrcode_key': qrcodeKey},
        fullUrl: 'https://passport.bilibili.com/x/passport-login/web/qrcode/poll',
      );
      
      final code = response['code'] as int?;
      
      // 特殊处理：这个接口把状态码放在 data.code 里
      if (code == 0) {
        // 登录成功，保存 Cookie
        final url = response['url'] as String?;
        if (url != null) {
          await _parseCookieFromUrl(url);
          return LoginStatus.success;
        }
      }
      
      // 根据错误码判断状态
      switch (code) {
        case 86038:
          return LoginStatus.expired;
        case 86090:
          return LoginStatus.scanned;
        case 86101:
          return LoginStatus.waitingScan;
        default:
          return LoginStatus.waitingScan;
      }
    } catch (e) {
      print('检查二维码状态失败: $e');
      return LoginStatus.error;
    }
  }
  
  /// 从 URL 中解析 Cookie
  Future<void> _parseCookieFromUrl(String url) async {
    // URL 格式: https://passport.biligame.com/crossDomain?...&DedeUserID=xxx&SESSDATA=xxx&bili_jct=xxx&...
    final uri = Uri.parse(url);
    final params = uri.queryParameters;
    
    final cookieMap = <String, String>{};
    
    // 提取关键 Cookie
    final sessdata = params['SESSDATA'];
    final biliJct = params['bili_jct'];
    final dedeUserId = params['DedeUserID'];
    
    if (sessdata != null && biliJct != null) {
      cookieMap['SESSDATA'] = sessdata;
      cookieMap['bili_jct'] = biliJct;
      
      if (dedeUserId != null) {
        cookieMap['DedeUserID'] = dedeUserId;
      }
      
      await _cookieManager.saveCookie(cookieMap);
    } else {
      throw BilibiliApiException(
        message: '无法从响应中提取 Cookie',
        type: BilibiliApiExceptionType.parseError,
      );
    }
  }
  
  /// 开始轮询检查二维码状态
  /// 
  /// [qrcodeKey] 二维码 key
  /// [onStatusChanged] 状态变化回调
  /// [interval] 轮询间隔（默认 2 秒）
  void startPolling({
    required String qrcodeKey,
    required Function(LoginStatus) onStatusChanged,
    Duration interval = const Duration(seconds: 2),
  }) {
    stopPolling(); // 停止之前的轮询
    
    _pollTimer = Timer.periodic(interval, (timer) async {
      final status = await checkQRCodeStatus(qrcodeKey);
      onStatusChanged(status);
      
      // 如果登录成功、过期或出错，停止轮询
      if (status == LoginStatus.success ||
          status == LoginStatus.expired ||
          status == LoginStatus.error) {
        stopPolling();
      }
    });
  }
  
  /// 停止轮询
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
  
  /// 检查是否已登录
  Future<bool> isLoggedIn() async {
    return await _cookieManager.isLoggedIn();
  }
  
  /// 登出
  Future<void> logout() async {
    stopPolling();
    await _cookieManager.clearCookie();
    _currentQRCode = null;
  }
  
  /// 释放资源
  void dispose() {
    stopPolling();
  }
}
