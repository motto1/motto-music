/// Bilibili BV/AV 号互转工具
/// 
/// 提供视频ID在BV号和AV号之间的转换功能
class BilibiliIdConverter {
  // XOR 编码
  static const int _xorCode = 23442827791579;
  
  // 掩码编码
  static const int _maskCode = 2251799813685247;
  
  // 最大AID
  static const int _maxAid = 2251799813685248;
  
  // 基数
  static const int _base = 58;
  
  // 魔法字符串
  static const String _magicStr = 'FcwAPNKTMug3GV5Lj7EJnHpWsx4tb8haYeviqBz6rkCy12mUSDQX9RdoZf';

  /// 将 BV 号转换为 AV 号
  /// 
  /// 例如: bv2av('BV1xx4y1x7xx') => 123456789
  static int bv2av(String bvid) {
    final bvidArr = bvid.split('');
    
    // 交换位置
    _swap(bvidArr, 3, 9);
    _swap(bvidArr, 4, 7);
    
    // 移除前3个字符 "BV1"
    final processedArr = bvidArr.sublist(3);
    
    // 计算
    int tmp = 0;
    for (final char in processedArr) {
      tmp = tmp * _base + _magicStr.indexOf(char);
    }
    
    return (tmp & _maskCode) ^ _xorCode;
  }

  /// 将 AV 号转换为 BV 号
  /// 
  /// 例如: av2bv(123456789) => 'BV1xx4y1x7xx'
  static String av2bv(int avid) {
    int tempNum = (avid | _maxAid) ^ _xorCode;
    
    final resultArray = 'BV1000000000'.split('');
    
    for (int i = 11; i >= 3; i--) {
      resultArray[i] = _magicStr[tempNum % _base];
      tempNum = tempNum ~/ _base;
    }
    
    // 交换位置
    _swap(resultArray, 3, 9);
    _swap(resultArray, 4, 7);
    
    return resultArray.join('');
  }

  /// 交换数组中两个位置的元素
  static void _swap(List<String> arr, int i, int j) {
    final temp = arr[i];
    arr[i] = arr[j];
    arr[j] = temp;
  }

  /// 验证BV号格式是否正确
  /// 
  /// 正确格式: BV + 10位字符
  static bool isValidBvid(String bvid) {
    if (bvid.length != 12) return false;
    if (!bvid.startsWith('BV')) return false;
    
    // 检查是否所有字符都在魔法字符串中
    final body = bvid.substring(2);
    for (final char in body.split('')) {
      if (!_magicStr.contains(char)) return false;
    }
    
    return true;
  }

  /// 验证AV号是否在有效范围内
  static bool isValidAvid(int avid) {
    return avid > 0 && avid < _maxAid;
  }
}
