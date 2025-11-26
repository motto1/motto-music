// 歌词数据模型
class LyricLine {
  /// 歌词的起始时间，单位：秒
  final double timestamp;
  
  /// 原始歌词内容
  final String text;
  
  /// 翻译歌词
  final String? translation;

  const LyricLine({
    required this.timestamp,
    required this.text,
    this.translation,
  });

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      timestamp: (json['timestamp'] as num).toDouble(),
      text: json['text'] as String,
      translation: json['translation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'text': text,
      if (translation != null) 'translation': translation,
    };
  }

  LyricLine copyWith({
    double? timestamp,
    String? text,
    String? translation,
  }) {
    return LyricLine(
      timestamp: timestamp ?? this.timestamp,
      text: text ?? this.text,
      translation: translation ?? this.translation,
    );
  }
}

class ParsedLrc {
  /// 歌词标签（如：ti, ar, al等）
  final Map<String, String> tags;
  
  /// 解析后的歌词行列表
  final List<LyricLine>? lyrics;
  
  /// 原始歌词文本
  final String rawOriginalLyrics;
  
  /// 原始翻译歌词文本
  final String? rawTranslatedLyrics;
  
  /// 歌词偏移量，单位：秒
  final double offset;
  
  /// 歌词来源：'local'(本地/数据库), 'netease'(网易云音乐), 'cache'(缓存), 'manual'(手动编辑)
  final String source;

  const ParsedLrc({
    required this.tags,
    required this.lyrics,
    required this.rawOriginalLyrics,
    this.rawTranslatedLyrics,
    this.offset = 0.0,
    this.source = 'netease',
  });

  factory ParsedLrc.fromJson(Map<String, dynamic> json) {
    return ParsedLrc(
      tags: Map<String, String>.from(json['tags'] as Map),
      lyrics: (json['lyrics'] as List?)
          ?.map((e) => LyricLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      rawOriginalLyrics: json['rawOriginalLyrics'] as String,
      rawTranslatedLyrics: json['rawTranslatedLyrics'] as String?,
      offset: (json['offset'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] as String? ?? 'netease',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tags': tags,
      'lyrics': lyrics?.map((e) => e.toJson()).toList(),
      'rawOriginalLyrics': rawOriginalLyrics,
      if (rawTranslatedLyrics != null) 'rawTranslatedLyrics': rawTranslatedLyrics,
      'offset': offset,
      'source': source,
    };
  }

  ParsedLrc copyWith({
    Map<String, String>? tags,
    List<LyricLine>? lyrics,
    String? rawOriginalLyrics,
    String? rawTranslatedLyrics,
    double? offset,
    String? source,
  }) {
    return ParsedLrc(
      tags: tags ?? this.tags,
      lyrics: lyrics ?? this.lyrics,
      rawOriginalLyrics: rawOriginalLyrics ?? this.rawOriginalLyrics,
      rawTranslatedLyrics: rawTranslatedLyrics ?? this.rawTranslatedLyrics,
      offset: offset ?? this.offset,
      source: source ?? this.source,
    );
  }
}

/// 歌词搜索结果项
class LyricSearchResult {
  final String source; // 'netease'
  final double duration; // 秒
  final String title;
  final String artist;
  final int remoteId;

  const LyricSearchResult({
    required this.source,
    required this.duration,
    required this.title,
    required this.artist,
    required this.remoteId,
  });

  factory LyricSearchResult.fromJson(Map<String, dynamic> json) {
    return LyricSearchResult(
      source: json['source'] as String,
      duration: (json['duration'] as num).toDouble(),
      title: json['title'] as String,
      artist: json['artist'] as String,
      remoteId: json['remoteId'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'duration': duration,
      'title': title,
      'artist': artist,
      'remoteId': remoteId,
    };
  }
}
