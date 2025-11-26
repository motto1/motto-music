import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// Bilibili 用户信息
@JsonSerializable()
class BilibiliUser {
  /// 用户 UID
  final int mid;
  
  /// 用户名
  final String name;
  
  /// 头像 URL
  final String? face;
  
  /// 个性签名
  final String? sign;
  
  BilibiliUser({
    required this.mid,
    required this.name,
    this.face,
    this.sign,
  });
  
  factory BilibiliUser.fromJson(Map<String, dynamic> json) => _$BilibiliUserFromJson(json);
  
  Map<String, dynamic> toJson() => _$BilibiliUserToJson(this);
  
  @override
  String toString() => 'BilibiliUser(mid: $mid, name: $name)';
}
