import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Bilibili Cookie 管理器
/// 负责 Cookie 的存储、读取和验证
class CookieManager {
  static const String _cookieKey = 'bilibili_cookie';
  
  /// 保存 Cookie (Map 格式)
  /// 
  /// 示例: {'SESSDATA': 'xxx', 'bili_jct': 'xxx', 'DedeUserID': 'xxx'}
  Future<void> saveCookie(Map<String, String> cookieMap) async {
    final prefs = await SharedPreferences.getInstance();
    final cookieJson = jsonEncode(cookieMap);
    await prefs.setString(_cookieKey, cookieJson);
  }
  
  /// 获取 Cookie (Map 格式)
  Future<Map<String, String>> getCookieMap() async {
    final prefs = await SharedPreferences.getInstance();
    final cookieJson = prefs.getString(_cookieKey);
    
    if (cookieJson == null || cookieJson.isEmpty) {
      return {};
    }
    
    try {
      final decoded = jsonDecode(cookieJson) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      // Cookie 数据损坏，返回空 Map
      return {};
    }
  }
  
  /// 获取 Cookie 字符串 (用于 HTTP Header)
  /// 
  /// 返回格式: "SESSDATA=xxx; bili_jct=xxx; DedeUserID=xxx"
  Future<String> getCookieString() async {
    final cookieMap = await getCookieMap();
    
    if (cookieMap.isEmpty) {
      return '';
    }
    
    return cookieMap.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');
  }
  
  /// 从 Cookie 字符串解析并保存
  /// 
  /// 输入格式: "SESSDATA=xxx; bili_jct=xxx; DedeUserID=xxx"
  Future<void> saveCookieFromString(String cookieString) async {
    if (cookieString.isEmpty) {
      return;
    }
    
    final cookieMap = <String, String>{};
    final pairs = cookieString.split(';');
    
    for (final pair in pairs) {
      final trimmed = pair.trim();
      final index = trimmed.indexOf('=');
      
      if (index > 0) {
        final key = trimmed.substring(0, index).trim();
        final value = trimmed.substring(index + 1).trim();
        cookieMap[key] = value;
      }
    }
    
    await saveCookie(cookieMap);
  }
  
  /// 清除 Cookie
  Future<void> clearCookie() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cookieKey);
  }
  
  /// 检查是否已登录
  /// 
  /// 判断依据：SESSDATA 和 bili_jct 是否存在
  Future<bool> isLoggedIn() async {
    final cookieMap = await getCookieMap();
    return cookieMap.containsKey('SESSDATA') && 
           cookieMap.containsKey('bili_jct') &&
           cookieMap['SESSDATA']!.isNotEmpty &&
           cookieMap['bili_jct']!.isNotEmpty;
  }
  
  /// 获取用户 UID (DedeUserID)
  Future<String?> getUserId() async {
    final cookieMap = await getCookieMap();
    return cookieMap['DedeUserID'];
  }
  
  /// 获取 CSRF Token (bili_jct)
  /// 
  /// 用于需要 CSRF 验证的 POST 请求
  Future<String?> getCsrfToken() async {
    final cookieMap = await getCookieMap();
    return cookieMap['bili_jct'];
  }
}
