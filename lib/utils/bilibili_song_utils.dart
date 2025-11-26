/// 构建 Bilibili 歌曲在数据库中的唯一 `filePath`
///
/// Bilibili 歌曲没有真实的本地文件路径，因此需要用一个虚拟的、
/// 且可重复计算的键值来满足 `songs.file_path` 的唯一约束。
/// 使用 `bvid` 搭配 `cid`/`pageNumber` 生成即可保证同一分P得到同一 key。
String buildBilibiliFilePath({
  required String? bvid,
  int? cid,
  int? pageNumber,
}) {
  final normalizedBvid = (bvid ?? '').trim();
  final prefix = normalizedBvid.isEmpty ? 'unknown' : normalizedBvid;

  final suffix = cid != null && cid > 0
      ? 'cid$cid'
      : pageNumber != null && pageNumber > 0
          ? 'p$pageNumber'
          : 'cid0';

  return 'bilibili://$prefix/$suffix';
}
