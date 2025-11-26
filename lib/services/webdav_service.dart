// lib/services/webdav_service.dart
import 'package:webdav_client/webdav_client.dart';

class WebDavService {
  // 单例
  WebDavService._internal();
  static final WebDavService _instance = WebDavService._internal();
  factory WebDavService() => _instance;

  late Client _client;

  /// 初始化客户端（登录、配置等）
  void init({
    required String baseUrl,
    required String username,
    required String password,
  }) {
    _client = newClient(baseUrl, user: username, password: password);
  }

  /// 获取客户端实例
  Client get client => _client;

  
}
