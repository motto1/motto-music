import 'package:flutter_test/flutter_test.dart';
import 'package:motto_music/services/bilibili/wbi_signer.dart';

void main() {
  group('WBI 签名测试', () {
    late WbiSigner signer;
    
    setUp(() {
      signer = WbiSigner();
    });
    
    test('WBI 签名应该包含必要的参数', () {
      final result = signer.encodeWbi(
        {'keyword': '测试', 'page': '1'},
        'test_img_key_1234567890abcdef',
        'test_sub_key_1234567890abcdef',
      );
      
      // 应该包含 wts (时间戳)
      expect(result, contains('wts='));
      
      // 应该包含 w_rid (签名)
      expect(result, contains('w_rid='));
      
      // 应该包含原始参数
      expect(result, contains('keyword='));
      expect(result, contains('page='));
    });
    
    test('WBI 签名应该过滤特殊字符', () {
      final result = signer.encodeWbi(
        {'test': "value!'()*"},
        'key',
        'key',
      );
      
      // 特殊字符应该被过滤
      expect(result, isNot(contains("'")));
      expect(result, isNot(contains('!')));
      expect(result, isNot(contains('(')));
      expect(result, isNot(contains(')')));
      expect(result, isNot(contains('*')));
    });
    
    test('WBI 签名参数应该按字母顺序排列', () {
      final result = signer.encodeWbi(
        {'z': '3', 'a': '1', 'm': '2'},
        'key',
        'key',
      );
      
      // 参数应该按 a, m, z 的顺序
      final aIndex = result.indexOf('a=');
      final mIndex = result.indexOf('m=');
      final zIndex = result.indexOf('z=');
      
      expect(aIndex, lessThan(mIndex));
      expect(mIndex, lessThan(zIndex));
    });
    
    test('encodeWbiToMap 应该返回正确的 Map', () {
      final result = signer.encodeWbiToMap(
        {'keyword': '测试'},
        'key',
        'key',
      );
      
      expect(result, isA<Map<String, String>>());
      expect(result['keyword'], equals('测试'));
      expect(result.containsKey('wts'), isTrue);
      expect(result.containsKey('w_rid'), isTrue);
    });
  });
}
