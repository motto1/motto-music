import 'dart:convert';
import 'package:crypto/crypto.dart';

/// WBI 签名器
/// 
/// 用于对 Bilibili API 请求参数进行 WBI (Web Browser Interface) 签名
/// 这是 Bilibili 的反爬虫机制之一
class WbiSigner {
  /// WBI 混淆编码表
  /// 
  /// 该表用于对 img_key 和 sub_key 进行位置重排
  static const List<int> mixinKeyEncTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
    33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61,
    26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36,
    20, 34, 44, 52,
  ];
  
  /// 对 img_key 和 sub_key 进行字符顺序打乱编码
  /// 
  /// [orig] imgKey + subKey 拼接的字符串
  /// 返回混淆后的前 32 个字符
  String _getMixinKey(String orig) {
    final mixed = StringBuffer();
    
    for (final index in mixinKeyEncTab) {
      if (index < orig.length) {
        mixed.write(orig[index]);
      }
    }
    
    final result = mixed.toString();
    return result.length > 32 ? result.substring(0, 32) : result;
  }
  
  /// 为请求参数进行 WBI 签名
  /// 
  /// [params] 请求参数
  /// [imgKey] 从导航接口获取的 img_key
  /// [subKey] 从导航接口获取的 sub_key
  /// 
  /// 返回签名后的查询字符串，包含 wts 和 w_rid 参数
  /// 
  /// 示例:
  /// ```dart
  /// final signer = WbiSigner();
  /// final signed = signer.encodeWbi(
  ///   {'keyword': '测试', 'page': '1'},
  ///   'img_key_here',
  ///   'sub_key_here',
  /// );
  /// // 返回: "keyword=%E6%B5%8B%E8%AF%95&page=1&wts=1234567890&w_rid=abc123..."
  /// ```
  String encodeWbi(
    Map<String, dynamic> params,
    String imgKey,
    String subKey,
  ) {
    final mixinKey = _getMixinKey(imgKey + subKey);
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // 添加 wts 字段（时间戳）
    final paramsWithTime = Map<String, dynamic>.from(params);
    paramsWithTime['wts'] = currentTime;
    
    // 按照 key 重排参数
    final sortedKeys = paramsWithTime.keys.toList()..sort();
    
    // 构建查询字符串
    final queryParts = <String>[];
    for (final key in sortedKeys) {
      final value = paramsWithTime[key].toString();
      // 过滤 value 中的 "!'()*" 字符
      final filteredValue = value.replaceAll(RegExp(r"[!'()*]"), '');
      final encodedKey = Uri.encodeComponent(key);
      final encodedValue = Uri.encodeComponent(filteredValue);
      queryParts.add('$encodedKey=$encodedValue');
    }
    
    final query = queryParts.join('&');
    
    // 计算 MD5 签名
    final wbiSign = md5.convert(utf8.encode(query + mixinKey)).toString();
    
    // 返回带签名的完整查询字符串
    return '$query&w_rid=$wbiSign';
  }
  
  /// 将签名后的查询字符串转换为 Map 格式
  /// 
  /// 某些 HTTP 库可能需要 Map 格式的参数
  Map<String, String> encodeWbiToMap(
    Map<String, dynamic> params,
    String imgKey,
    String subKey,
  ) {
    final queryString = encodeWbi(params, imgKey, subKey);
    final result = <String, String>{};
    
    for (final pair in queryString.split('&')) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        result[Uri.decodeComponent(parts[0])] = Uri.decodeComponent(parts[1]);
      }
    }
    
    return result;
  }
}
