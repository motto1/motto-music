/// Bilibili API 异常
/// 
/// 用于表示与 Bilibili API 交互时发生的各种错误
class BilibiliApiException implements Exception {
  /// 错误消息
  final String message;
  
  /// Bilibili API 返回的错误代码
  final int? code;
  
  /// 原始错误数据
  final dynamic rawData;
  
  /// 异常类型
  final BilibiliApiExceptionType type;
  
  BilibiliApiException({
    required this.message,
    this.code,
    this.rawData,
    this.type = BilibiliApiExceptionType.unknown,
  });
  
  @override
  String toString() {
    if (code != null) {
      return 'BilibiliApiException($type): $message (code: $code)';
    }
    return 'BilibiliApiException($type): $message';
  }
}

/// Bilibili API 异常类型
enum BilibiliApiExceptionType {
  /// 网络请求失败
  networkError,
  
  /// HTTP 响应错误 (非 200 状态码)
  httpError,
  
  /// Bilibili API 返回错误代码
  apiError,
  
  /// JSON 解析失败
  parseError,
  
  /// 未登录
  notLoggedIn,
  
  /// Cookie 无效
  invalidCookie,
  
  /// WBI 签名错误
  wbiError,
  
  /// 未知错误
  unknown,
}
