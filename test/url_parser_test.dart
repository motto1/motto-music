import 'package:flutter_test/flutter_test.dart';

void main() {
  test('测试 BV 号提取', () {
    final testUrl = 'https://www.bilibili.com/video/BV1gq4y167mq/?spm_id_from=333.337.search-card.all.click&vd_source=c351d31d3cfd062f1d391179d3fcb2e9';
    
    // BV号正则表达式
    final bvRegex = RegExp(
      r'(?<![A-Za-z0-9])(BV[0-9A-Za-z]{10})(?![A-Za-z0-9])',
      caseSensitive: false,
    );
    
    final match = bvRegex.firstMatch(testUrl);
    
    expect(match, isNotNull);
    expect(match!.group(1), equals('BV1gq4y167mq'));
    
    print('✅ 提取的 BV 号: ${match.group(1)}');
  });
}
