import 'package:flutter_test/flutter_test.dart';
import 'package:motto_music/utils/bilibili_utils.dart';

void main() {
  group('BV/AV 转换测试', () {
    test('BV 转 AV - 标准测试用例', () {
      // 已知的 BV 和 AV 对应关系（来自社区验证）
      expect(bv2av('BV1xx411c7mD'), equals(2));
      expect(bv2av('BV17x411w7KC'), equals(170001));
      expect(bv2av('BV1Q541167Qg'), equals(455017605));
      expect(bv2av('BV1mK4y1C7Bz'), equals(882584971));
    });
    
    test('AV 转 BV - 标准测试用例', () {
      expect(av2bv(2), equals('BV1xx411c7mD'));
      expect(av2bv(170001), equals('BV17x411w7KC'));
      expect(av2bv(455017605), equals('BV1Q541167Qg'));
      expect(av2bv(882584971), equals('BV1mK4y1C7Bz'));
    });
    
    test('BV 和 AV 互转应该一致', () {
      const testCases = [2, 170001, 455017605, 882584971, 123456, 987654321];
      
      for (final avid in testCases) {
        final bvid = av2bv(avid);
        final convertedBack = bv2av(bvid);
        expect(convertedBack, equals(avid), 
          reason: 'AV$avid -> $bvid -> AV$convertedBack 应该保持一致');
      }
    });
    
    test('从 URL 提取 BV 号', () {
      expect(
        extractBvidFromUrl('https://www.bilibili.com/video/BV1xx411c7mD'),
        equals('BV1xx411c7mD'),
      );
      
      expect(
        extractBvidFromUrl('https://b23.tv/BV1Q541167Qg'),
        equals('BV1Q541167Qg'),
      );
      
      expect(
        extractBvidFromUrl('BV1mK4y1C7Bz'),
        equals('BV1mK4y1C7Bz'),
      );
    });
    
    test('从 URL 提取 AV 号', () {
      expect(
        extractAvidFromUrl('https://www.bilibili.com/video/av170001'),
        equals(170001),
      );
      
      expect(
        extractAvidFromUrl('av455017605'),
        equals(455017605),
      );
      
      expect(
        extractAvidFromUrl('AV882584971'),
        equals(882584971),
      );
    });
    
    test('标准化视频 ID', () {
      // BV 号应该直接返回
      expect(
        normalizeVideoId('BV1xx411c7mD'),
        equals('BV1xx411c7mD'),
      );
      
      // AV 号应该转换为 BV 号
      expect(
        normalizeVideoId('av2'),
        equals('BV1xx411c7mD'),
      );
      
      // URL 应该提取并返回 BV 号
      expect(
        normalizeVideoId('https://www.bilibili.com/video/BV1Q541167Qg'),
        equals('BV1Q541167Qg'),
      );
    });
  });
}
