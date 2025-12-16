import '../config_module.dart';
import '../../services/bilibili/cookie_manager.dart';

class BilibiliAuthModule extends ConfigModule {
  BilibiliAuthModule(this._cookieManager);

  final CookieManager _cookieManager;

  @override
  String get id => 'bilibili_auth';

  @override
  String get name => 'Bilibili 账号/鉴权';

  @override
  String get description => 'Cookie 等敏感登录信息';

  @override
  int get version => 1;

  @override
  bool get isSensitive => true;

  @override
  bool get enabledByDefault => false;

  @override
  Future<Map<String, dynamic>> exportData(
      {bool includeSensitive = false}) async {
    if (!includeSensitive) return {};
    final cookieMap = await _cookieManager.getCookieMap();
    return {'cookie': cookieMap};
  }

  @override
  Future<void> importData(Map<String, dynamic> data,
      {required bool merge}) async {
    final cookie = data['cookie'];
    if (cookie is Map) {
      final map =
          cookie.map((k, v) => MapEntry(k.toString(), v.toString()));
      await _cookieManager.saveCookie(Map<String, String>.from(map));
    }
  }
}

