// 网易云API响应类型定义

class NeteaseLyricResponse {
  final NeteaseLyric lrc;
  final NeteaseLyric? tlyric;
  final int code;

  const NeteaseLyricResponse({
    required this.lrc,
    this.tlyric,
    required this.code,
  });

  factory NeteaseLyricResponse.fromJson(Map<String, dynamic> json) {
    return NeteaseLyricResponse(
      lrc: NeteaseLyric.fromJson(json['lrc'] as Map<String, dynamic>),
      tlyric: json['tlyric'] != null
          ? NeteaseLyric.fromJson(json['tlyric'] as Map<String, dynamic>)
          : null,
      code: json['code'] as int,
    );
  }
}

class NeteaseLyric {
  final String lyric;

  const NeteaseLyric({required this.lyric});

  factory NeteaseLyric.fromJson(Map<String, dynamic> json) {
    return NeteaseLyric(lyric: json['lyric'] as String? ?? '');
  }
}

class NeteaseSearchResponse {
  final NeteaseSearchResult? result;
  final int code;

  const NeteaseSearchResponse({
    this.result,
    required this.code,
  });

  factory NeteaseSearchResponse.fromJson(Map<String, dynamic> json) {
    return NeteaseSearchResponse(
      result: json['result'] != null
          ? NeteaseSearchResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
      code: json['code'] as int,
    );
  }
}

class NeteaseSearchResult {
  final List<NeteaseSong>? songs;
  final int songCount;

  const NeteaseSearchResult({
    this.songs,
    required this.songCount,
  });

  factory NeteaseSearchResult.fromJson(Map<String, dynamic> json) {
    return NeteaseSearchResult(
      songs: (json['songs'] as List?)
          ?.map((e) => NeteaseSong.fromJson(e as Map<String, dynamic>))
          .toList(),
      songCount: json['songCount'] as int,
    );
  }
}

class NeteaseSong {
  final int id;
  final String name;
  final List<NeteaseArtist> ar;
  final NeteaseAlbum al;
  final List<String> alia;
  final int dt; // 歌曲时长，单位：ms
  final List<String> tns;

  const NeteaseSong({
    required this.id,
    required this.name,
    required this.ar,
    required this.al,
    required this.alia,
    required this.dt,
    required this.tns,
  });

  factory NeteaseSong.fromJson(Map<String, dynamic> json) {
    return NeteaseSong(
      id: json['id'] as int,
      name: json['name'] as String,
      ar: (json['ar'] as List)
          .map((e) => NeteaseArtist.fromJson(e as Map<String, dynamic>))
          .toList(),
      al: NeteaseAlbum.fromJson(json['al'] as Map<String, dynamic>),
      alia: (json['alia'] as List?)?.map((e) => e as String).toList() ?? [],
      dt: json['dt'] as int,
      tns: (json['tns'] as List?)?.map((e) => e as String).toList() ?? [],
    );
  }
}

class NeteaseArtist {
  final int id;
  final String name;
  final List<String> alias;
  final List<String> tns;

  const NeteaseArtist({
    required this.id,
    required this.name,
    required this.alias,
    required this.tns,
  });

  factory NeteaseArtist.fromJson(Map<String, dynamic> json) {
    return NeteaseArtist(
      id: json['id'] as int,
      name: json['name'] as String,
      alias: (json['alias'] as List?)?.map((e) => e as String).toList() ?? [],
      tns: (json['tns'] as List?)?.map((e) => e as String).toList() ?? [],
    );
  }
}

class NeteaseAlbum {
  final int id;
  final String name;
  final String picUrl;

  const NeteaseAlbum({
    required this.id,
    required this.name,
    required this.picUrl,
  });

  factory NeteaseAlbum.fromJson(Map<String, dynamic> json) {
    return NeteaseAlbum(
      id: json['id'] as int,
      name: json['name'] as String,
      picUrl: json['picUrl'] as String? ?? '',
    );
  }
}
