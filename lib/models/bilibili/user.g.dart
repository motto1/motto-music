// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BilibiliUser _$BilibiliUserFromJson(Map<String, dynamic> json) => BilibiliUser(
      mid: (json['mid'] as num).toInt(),
      name: json['name'] as String,
      face: json['face'] as String?,
      sign: json['sign'] as String?,
    );

Map<String, dynamic> _$BilibiliUserToJson(BilibiliUser instance) =>
    <String, dynamic>{
      'mid': instance.mid,
      'name': instance.name,
      'face': instance.face,
      'sign': instance.sign,
    };
