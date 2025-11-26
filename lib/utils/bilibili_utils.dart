/// Bilibili 工具函数
/// 
/// 包含 BV 号和 AV 号的相互转换等实用工具函数

/// BV 号转 AV 号
/// 
/// 示例:
/// ```dart
/// final avid = bv2av('BV1xx411c7mD'); // 返回 170001
/// ```
int bv2av(String bvid) {
  const xorCode = 23442827791579;
  const maskCode = 2251799813685247;
  const base = 58;
  const data = 'FcwAPNKTMug3GV5Lj7EJnHpWsx4tb8haYeviqBz6rkCy12mUSDQX9RdoZf';
  
  // 转换为字符列表
  final bvidArr = bvid.split('');
  
  // 交换位置
  final temp1 = bvidArr[3];
  bvidArr[3] = bvidArr[9];
  bvidArr[9] = temp1;
  
  final temp2 = bvidArr[4];
  bvidArr[4] = bvidArr[7];
  bvidArr[7] = temp2;
  
  // 移除前3个字符 ("BV1")
  bvidArr.removeRange(0, 3);
  
  // 计算 AV 号 (使用 BigInt 确保精度)
  BigInt tmp = BigInt.zero;
  for (final char in bvidArr) {
    tmp = tmp * BigInt.from(base) + BigInt.from(data.indexOf(char));
  }
  
  return ((tmp & BigInt.from(maskCode)) ^ BigInt.from(xorCode)).toInt();
}

/// AV 号转 BV 号
/// 
/// 示例:
/// ```dart
/// final bvid = av2bv(170001); // 返回 "BV1xx411c7mD"
/// ```
String av2bv(int avid) {
  const xorCode = 23442827791579;
  const maxAid = 2251799813685248;
  const base = 58;
  const magicStr = 'FcwAPNKTMug3GV5Lj7EJnHpWsx4tb8haYeviqBz6rkCy12mUSDQX9RdoZf';
  
  BigInt tempNum = (BigInt.from(avid) | BigInt.from(maxAid)) ^ BigInt.from(xorCode);
  
  final resultArray = 'BV1000000000'.split('');
  
  for (var i = 11; i >= 3; i--) {
    resultArray[i] = magicStr[(tempNum % BigInt.from(base)).toInt()];
    tempNum = tempNum ~/ BigInt.from(base);
  }
  
  // 交换位置
  final temp1 = resultArray[3];
  resultArray[3] = resultArray[9];
  resultArray[9] = temp1;
  
  final temp2 = resultArray[4];
  resultArray[4] = resultArray[7];
  resultArray[7] = temp2;
  
  return resultArray.join('');
}

/// 从 URL 中提取 BV 号
/// 
/// 支持的格式:
/// - https://www.bilibili.com/video/BV1xx411c7mD
/// - https://b23.tv/BV1xx411c7mD
/// - BV1xx411c7mD
String? extractBvidFromUrl(String url) {
  final bvRegex = RegExp(r'(BV[a-zA-Z0-9]{10})');
  final match = bvRegex.firstMatch(url);
  return match?.group(1);
}

/// 从 URL 中提取 AV 号
/// 
/// 支持的格式:
/// - https://www.bilibili.com/video/av170001
/// - av170001
int? extractAvidFromUrl(String url) {
  final avRegex = RegExp(r'av(\d+)', caseSensitive: false);
  final match = avRegex.firstMatch(url);
  if (match != null) {
    return int.tryParse(match.group(1)!);
  }
  return null;
}

/// 标准化视频 ID 为 BV 号
/// 
/// 自动检测输入是 BV 号还是 AV 号，统一转换为 BV 号
String normalizeVideoId(String videoId) {
  // 尝试提取 BV 号
  final bvid = extractBvidFromUrl(videoId);
  if (bvid != null) {
    return bvid;
  }
  
  // 尝试提取 AV 号并转换
  final avid = extractAvidFromUrl(videoId);
  if (avid != null) {
    return av2bv(avid);
  }
  
  // 如果都不是，返回原始输入
  return videoId;
}
