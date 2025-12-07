import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

// ===============================================================
// 数据模型
// ===============================================================

class LyricLine {
  final List<LyricChar> chars;
  final Duration startTime;
  final Duration endTime;
  LyricLine({
    required this.chars,
    required this.startTime,
    required this.endTime,
  });
}

class LyricChar {
  final String char;
  final Duration start;
  final Duration end;
  LyricChar({required this.char, required this.start, required this.end});
}

// ===============================================================
// 主 Widget: KaraokeLyricsView
// ===============================================================

class KaraokeLyricsView extends StatefulWidget {
  final String? lyricsContent;
  final ValueNotifier<Duration> currentPosition;
  final Function(Duration) onTapLine;
  final double offsetInSeconds; // 歌词偏移量（秒），正数=提前，负数=延后

  const KaraokeLyricsView({
    Key? key,
    required this.lyricsContent,
    required this.currentPosition,
    required this.onTapLine,
    this.offsetInSeconds = 0.0, // 默认无偏移
  }) : super(key: key);

  @override
  State<KaraokeLyricsView> createState() => _KaraokeLyricsViewState();
}

class _KaraokeLyricsViewState extends State<KaraokeLyricsView> {
  List<LyricLine> _lyricLines = [];
  int _currentLineIndex = 0;

  late ScrollController _scrollController;
  final Map<int, double> _lineHeights = {};
  bool _isHoveringLyrics = false;

  // 高亮行应该显示在歌词区域的什么位置（比例），0.4 表示偏上的位置
  static const double _highlightPositionRatio = 0.4;

  // 缓存每行歌词的字符宽度和偏移量，避免每帧重复计算
  final Map<int, List<double>> _charWidthsCache = {};
  final Map<int, List<double>> _charOffsetsCache = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _parseLyrics();
    widget.currentPosition.addListener(_onPositionChanged);
  }

  @override
  void didUpdateWidget(KaraokeLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyricsContent != oldWidget.lyricsContent) {
      _parseLyrics();
    }
    // 如果父 Widget 替换了 ValueNotifier，需要重新监听
    if (widget.currentPosition != oldWidget.currentPosition) {
      oldWidget.currentPosition.removeListener(_onPositionChanged);
      widget.currentPosition.addListener(_onPositionChanged);
    }
    // 偏移量变化时，立即更新当前行（不重新解析歌词）
    if (widget.offsetInSeconds != oldWidget.offsetInSeconds) {
      _updateCurrentLine(widget.currentPosition.value);
    }
  }

  void _onPositionChanged() {
    // 每次 currentPosition.value 改变都会调用这里
    final pos = widget.currentPosition.value;
    _updateCurrentLine(pos); // 更新高亮歌词
  }

  @override
  void dispose() {
    widget.currentPosition.removeListener(_onPositionChanged);
    _scrollController.dispose();
    super.dispose();
  }

  // ... 在 _KaraokeLyricsViewState 类中 ...

  Future<void> _parseLyrics() async {
    if (widget.lyricsContent == null || widget.lyricsContent!.trim().isEmpty) {
      if (mounted) setState(() => _lyricLines = []);
      return;
    }

    List<LyricLine> parsed;

    // --- 智能格式检测 ---
    final trimmedLyrics = widget.lyricsContent!.trim();

    // LRC格式通常以时间戳 [mm:ss.xx] 开头
    if (trimmedLyrics.startsWith('<tt')) {
      parsed = await _parseTtmlContent(trimmedLyrics);
    }
    // LRC格式的新检查：不要求时间戳在开头，只要整个文件包含时间戳即可
    else if (RegExp(r'\[\d{2}:\d{2}\.\d{1,3}\]').hasMatch(trimmedLyrics)) {
      parsed = await _parseLrcContent(trimmedLyrics);
    } else {
      // 无法识别格式
      debugPrint("无法识别的歌词格式。");
      parsed = [];
    }
    // --- 检测结束 ---

    if (mounted) {
      setState(() {
        _lyricLines = parsed;
        _currentLineIndex = 0;
        _lineHeights.clear();
        // 清除字符宽度缓存
        _charWidthsCache.clear();
        _charOffsetsCache.clear();
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      });
      // 解析完成后立即更新一次当前行
      _updateCurrentLine(widget.currentPosition.value);
    }
  }

  void _updateCurrentLine(Duration position) {
    if (_lyricLines.isEmpty) return;
    
    // 🔧 应用偏移量：将播放位置减去偏移量来计算实际应该显示的歌词
    // 例如：offset = 0.5s（提前），position = 10s，实际查找 10s + 0.5s = 10.5s 的歌词
    // 例如：offset = -0.5s（延后），position = 10s，实际查找 10s - 0.5s = 9.5s 的歌词
    final adjustedPosition = position + Duration(
      milliseconds: (widget.offsetInSeconds * 1000 + 200).round(),
    );
    
    final newIndex = _lyricLines.lastIndexWhere(
      (line) => adjustedPosition >= line.startTime,
    );

    if (newIndex != -1 && newIndex != _currentLineIndex) {
      setState(() => _currentLineIndex = newIndex);
      _scrollToCurrentLine();
    }
  }

  Future<void> _scrollToCurrentLine({bool force = false}) async {
    // 等待 ScrollController 挂载
    while (!_scrollController.hasClients) {
      await Future.delayed(const Duration(milliseconds: 16));
    }

    if (_isHoveringLyrics && !force) return;

    // 计算当前行之前所有行的累计高度
    double offsetUpToCurrent = 0;
    for (int i = 0; i < _currentLineIndex; i++) {
      offsetUpToCurrent += _lineHeights[i] ?? 80.0;
    }

    // 滚动目标：让当前行显示在顶部留白之后的位置
    // 由于顶部留白 = viewportHeight * _highlightPositionRatio
    // 当 scrollOffset = offsetUpToCurrent 时，当前行正好在顶部留白结束的位置
    // 也就是屏幕的 1/3 处
    double targetOffset = offsetUpToCurrent;
    targetOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 800),
      curve: const Cubic(0.46, 1.2, 0.43, 1.04),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_lyricLines.isEmpty) {
      return const Center(
        child: Text(
          "暂无歌词",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // 使用 LayoutBuilder 获取歌词组件自身的可用高度
    return LayoutBuilder(
      builder: (context, constraints) {
        // 歌词显示区域的高度
        final viewportHeight = constraints.maxHeight;

        // 动态计算留白：让高亮行显示在歌词区域的中心
        // 顶部留白 = 区域高度 * 0.5，确保第一行歌词能滚动到中心
        // 底部留白 = 区域高度 * 0.5，确保最后一行也能滚动到中心
        final topPadding = viewportHeight * _highlightPositionRatio;
        final bottomPadding = viewportHeight * _highlightPositionRatio;

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                SizedBox(height: topPadding),
                ..._lyricLines.asMap().entries.map((entry) {
                  int index = entry.key;
                  LyricLine line = entry.value;
                  bool isCurrentLine = index == _currentLineIndex;

                  // 只有当前行需要监听位置变化实现逐字高亮
                  if (isCurrentLine) {
                    return ValueListenableBuilder<Duration>(
                      valueListenable: widget.currentPosition,
                      builder: (context, position, child) {
                        return HoverableLyricLine(
                          isCurrent: true,
                          onSizeChange: (size) {
                            _lineHeights[index] = size.height;
                          },
                          child: _buildCurrentLyricLine(index, line, position),
                          onHoverChanged: (hover) {
                            _isHoveringLyrics = hover;
                          },
                          onTap: () {
                            widget.onTapLine(line.startTime);
                          },
                        );
                      },
                    );
                  }

                  // 非当前行：静态渲染，不监听位置变化
                  final isPast = widget.currentPosition.value > line.endTime;
                  return HoverableLyricLine(
                    isCurrent: false,
                    onSizeChange: (size) {
                      _lineHeights[index] = size.height;
                    },
                    child: _buildStaticLyricLine(line, isPast),
                    onHoverChanged: (hover) {
                      _isHoveringLyrics = hover;
                    },
                    onTap: () {
                      widget.onTapLine(line.startTime);
                      setState(() => _currentLineIndex = index);
                      _scrollToCurrentLine(force: true);
                    },
                  );
                }),
                SizedBox(height: bottomPadding),
              ],
            ),
          ),
        );
      },
    );
  }

  // 歌词文本样式
  static const _textStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.4,
  );

  TextStyle get _textStyleWithShadow => _textStyle.copyWith(
        shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
      );

  /// 构建静态歌词行（非当前行，不需要逐字高亮）
  Widget _buildStaticLyricLine(LyricLine line, bool isPast) {
    final color = isPast ? Colors.white : Colors.white70;
    final text = line.chars.map((c) => c.char).join();
    return Text(
      text,
      style: _textStyleWithShadow.copyWith(color: color),
    );
  }

  /// 获取或计算字符宽度缓存
  void _ensureCharWidthsCache(int lineIndex, LyricLine line) {
    if (_charWidthsCache.containsKey(lineIndex)) return;

    final List<double> charWidths = [];
    final List<double> charOffsets = [];
    double currentOffset = 0.0;

    for (final lyricChar in line.chars) {
      final painter = TextPainter(
        text: TextSpan(text: lyricChar.char, style: _textStyleWithShadow),
        textDirection: TextDirection.ltr,
      )..layout();
      charWidths.add(painter.width);
      charOffsets.add(currentOffset);
      currentOffset += painter.width;
    }

    _charWidthsCache[lineIndex] = charWidths;
    _charOffsetsCache[lineIndex] = charOffsets;
  }

  /// 构建当前歌词行（带逐字高亮效果）
  Widget _buildCurrentLyricLine(int lineIndex, LyricLine line, Duration position) {
    // 确保缓存已计算
    _ensureCharWidthsCache(lineIndex, line);

    final charWidths = _charWidthsCache[lineIndex]!;
    final charOffsets = _charOffsetsCache[lineIndex]!;

    // 计算当前进度
    double progressInPixels = 0.0;
    final currentCharIndex = line.chars.lastIndexWhere(
      (c) => position >= c.start,
    );

    if (currentCharIndex != -1) {
      final currentChar = line.chars[currentCharIndex];
      final charOffset = charOffsets[currentCharIndex];
      final charWidth = charWidths[currentCharIndex];

      double charProgress = 0.0;
      final duration = (currentChar.end - currentChar.start).inMilliseconds;
      if (duration > 0) {
        charProgress =
            (position.inMilliseconds - currentChar.start.inMilliseconds) /
                duration;
        charProgress = charProgress.clamp(0.0, 1.0);
      } else if (position >= currentChar.end) {
        charProgress = 1.0;
      }

      progressInPixels = charOffset + (charWidth * charProgress);
    }

    // 渲染逐字高亮
    final transitionWidthPixels = 20.0;
    final gradientStart = progressInPixels;
    final gradientEnd = progressInPixels + transitionWidthPixels;

    final charWidgets = <Widget>[];
    for (int i = 0; i < line.chars.length; i++) {
      final charStartOffset = charOffsets[i];
      final charEndOffset = charStartOffset + charWidths[i];

      final shaderMaskedChar = ShaderMask(
        shaderCallback: (rect) {
          if (charEndOffset <= gradientStart) {
            return const LinearGradient(
              colors: [Colors.white, Colors.white],
            ).createShader(rect);
          }
          if (charStartOffset >= gradientEnd) {
            return const LinearGradient(
              colors: [Colors.white70, Colors.white70],
            ).createShader(rect);
          }
          final localGradientStart =
              (gradientStart - charStartOffset) / rect.width;
          final localGradientEnd = (gradientEnd - charStartOffset) / rect.width;
          return LinearGradient(
            colors: const [Colors.white, Colors.white70],
            stops: [
              localGradientStart.clamp(0.0, 1.0),
              localGradientEnd.clamp(0.0, 1.0),
            ],
          ).createShader(rect);
        },
        child: Text(
          line.chars[i].char,
          style: _textStyleWithShadow.copyWith(color: Colors.white),
        ),
      );
      charWidgets.add(shaderMaskedChar);
    }

    return Wrap(alignment: WrapAlignment.start, children: charWidgets);
  }
}

// ===============================================================
// 辅助 Widget 和 TTML 解析器
// ===============================================================

class HoverableLyricLine extends StatefulWidget {
  final Widget child;
  final bool isCurrent;
  final Function(Size) onSizeChange;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHoverChanged;

  const HoverableLyricLine({
    super.key,
    required this.child,
    required this.isCurrent,
    required this.onSizeChange,
    this.onTap,
    this.onHoverChanged,
  });

  @override
  State<HoverableLyricLine> createState() => _HoverableLyricLineState();
}

class _HoverableLyricLineState extends State<HoverableLyricLine> {
  bool _isHovered = false;

  void _updateHover(bool hover) {
    if (_isHovered != hover) {
      setState(() => _isHovered = hover);
      widget.onHoverChanged?.call(hover);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MeasureSize(
      onChange: widget.onSizeChange,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _updateHover(true),
        onExit: (_) => _updateHover(false),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onTap,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(
              end: (widget.isCurrent || _isHovered) ? 0 : 2.5,
            ),
            duration: const Duration(milliseconds: 250),
            builder: (context, blurValue, child) {
              return Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? Colors.white.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: blurValue,
                    sigmaY: blurValue,
                  ),
                  child: child,
                ),
              );
            },
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: widget.isCurrent ? 1.05 : 1.0),
              duration: const Duration(milliseconds: 400),
              curve: const Cubic(0.46, 1.2, 0.43, 1.04),
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                alignment: Alignment.centerLeft,
                child: child,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _LrcLineInfo {
  final int timeInMs;
  final String text;
  _LrcLineInfo(this.timeInMs, this.text);
}

class MeasureSize extends StatefulWidget {
  final Widget child;
  final Function(Size) onChange;
  const MeasureSize({Key? key, required this.onChange, required this.child})
    : super(key: key);
  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? _oldSize;
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = context.size;
      if (size != null && _oldSize != size) {
        _oldSize = size;
        widget.onChange(size);
      }
    });
    return widget.child;
  }
}

// 在 karaoke_lyrics_view.dart 文件中找到并替换这个函数
// 在 karaoke_lyrics_view.dart 文件中

Future<List<LyricLine>> _parseLrcContent(
  String lrcContent, {
  bool originalOnly = true,
}) async {
  // 步骤 1 & 2: 分组和合并歌词 (保持不变)
  final Map<int, List<String>> timeToTexts = {};
  final lines = lrcContent.split('\n');
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final matches = RegExp(r'\[(\d{2}):(\d{2})\.(\d{1,3})\]').allMatches(line);
    final text = line.substring(line.lastIndexOf(']') + 1).trim();
    if (matches.isNotEmpty && text.isNotEmpty) {
      for (final match in matches) {
        final m = int.parse(match.group(1)!), s = int.parse(match.group(2)!);
        final ms = int.parse(match.group(3)!.padRight(3, '0'));
        final timeInMs = (m * 60 + s) * 1000 + ms;
        if (!timeToTexts.containsKey(timeInMs)) timeToTexts[timeInMs] = [];
        timeToTexts[timeInMs]!.add(text);
      }
    }
  }
  final rawLines = <_LrcLineInfo>[];
  final sortedTimes = timeToTexts.keys.toList()..sort();
  for (final timeInMs in sortedTimes) {
    List<String> texts = timeToTexts[timeInMs]!;
    rawLines.add(
      _LrcLineInfo(timeInMs, originalOnly ? texts.first : texts.join('\n')),
    );
  }
  if (rawLines.isEmpty) return [];

  // --- 步骤 3: 构建逐字/逐词时间戳 (核心修改点) ---
  final lyricLines = <LyricLine>[];
  for (int i = 0; i < rawLines.length; i++) {
    final currentLrcLine = rawLines[i];
    final nextTimeInMs = (i + 1 < rawLines.length)
        ? rawLines[i + 1].timeInMs
        : currentLrcLine.timeInMs + 5000;
    final startTime = Duration(milliseconds: currentLrcLine.timeInMs);
    final endTime = Duration(milliseconds: nextTimeInMs);
    final lineDurationMs = (endTime - startTime).inMilliseconds;

    final chars = <LyricChar>[];
    final lineText = currentLrcLine.text;

    if (lineDurationMs > 0 && lineText.isNotEmpty) {
      // --- 语言检测与分词 (简化版) ---
      // 简单地检查是否包含英文字母来判断
      final isEnglishLike = RegExp(r'[a-zA-Z]').hasMatch(lineText);
      List<String> tokens;

      if (isEnglishLike) {
        // 英文：按空格分词
        final words = lineText.split(' ');
        tokens = [];
        for (int w = 0; w < words.length; w++) {
          // 将空格加回到前一个单词的末尾，以保持正确的间距
          tokens.add(words[w] + (w < words.length - 1 ? ' ' : ''));
        }
      } else {
        // 中文或其他语言：按单字分词
        tokens = lineText.split('');
      }
      // --- 分词结束 ---

      if (tokens.isEmpty) continue;

      // 按字符数比例分配时间 (逻辑保持不变)
      final totalChars = lineText.length;
      if (totalChars == 0) continue;

      double msPerChar = lineDurationMs.toDouble() / totalChars;
      Duration currentTokenStart = startTime;

      for (final token in tokens) {
        final tokenDurationMs = (msPerChar * token.length).round();
        final tokenDuration = Duration(milliseconds: tokenDurationMs);
        final tokenEndTime = currentTokenStart + tokenDuration;

        chars.add(
          LyricChar(
            char: token, // token 可能是 "word " 或 "字"
            start: currentTokenStart,
            end: tokenEndTime,
          ),
        );
        currentTokenStart = tokenEndTime;
      }
    } else {
      chars.add(LyricChar(char: lineText, start: startTime, end: endTime));
    }

    lyricLines.add(
      LyricLine(chars: chars, startTime: startTime, endTime: endTime),
    );
  }

  return lyricLines;
}

// 在 karaoke_lyrics_view.dart 文件中

Future<List<LyricLine>> _parseTtmlContent(String ttmlContent) async {
  try {
    final document = XmlDocument.parse(ttmlContent);
    final paragraphs = document.findAllElements('p');
    final lyricLines = <LyricLine>[];

    for (final p in paragraphs) {
      final lineStartTimeStr = p.getAttribute('begin') ?? '0.0s';
      final lineEndTimeStr = p.getAttribute('end') ?? '0.0s';
      final lineStartTime = _parseTtmlTime(lineStartTimeStr);
      final lineEndTime = _parseTtmlTime(lineEndTimeStr);

      final tempChars = <_TempLyricChar>[]; // 使用一个临时列表

      // --- 步骤 1: 第一次遍历，提取所有原文span和它们之间的空格 ---
      for (final node in p.children) {
        if (node is XmlElement &&
            node.name.local == 'span' &&
            node.getAttribute('ttm:role') == null) {
          final text = node.text;
          if (text.isNotEmpty) {
            final startTime = _parseTtmlTime(
              node.getAttribute('begin') ?? lineStartTimeStr,
            );
            tempChars.add(_TempLyricChar(text, startTime));
          }
        } else if (node is XmlText &&
            node.text.trim().isEmpty &&
            tempChars.isNotEmpty) {
          tempChars.last.text += node.text; // 将空格追加到前一个单词
        }
      }

      if (tempChars.isEmpty) continue;

      // --- 步骤 2: 第二次遍历，根据下一个span的开始时间来确定结束时间 ---
      final finalChars = <LyricChar>[];
      for (int i = 0; i < tempChars.length; i++) {
        final currentTemp = tempChars[i];

        // 确定结束时间：用下一个span的开始时间，或者是整行的结束时间
        final endTime = (i + 1 < tempChars.length)
            ? tempChars[i + 1].start
            : lineEndTime;

        // 如果计算出的结束时间早于开始时间，则用开始时间+一个小量，避免负时长
        final validEndTime =
            endTime.inMilliseconds > currentTemp.start.inMilliseconds
            ? endTime
            : currentTemp.start + const Duration(milliseconds: 1);

        // (后续的逐字/逐词分配逻辑)
        final lineText = currentTemp.text;
        final startTime = currentTemp.start;
        final lineDurationMs = (validEndTime - startTime).inMilliseconds;

        if (lineDurationMs > 0 && lineText.isNotEmpty) {
          final isEnglishLike = RegExp(r'[a-zA-Z]').hasMatch(lineText);
          List<String> tokens;
          if (isEnglishLike) {
            final words = lineText.split(' ');
            tokens = [];
            for (int w = 0; w < words.length; w++) {
              tokens.add(words[w] + (w < words.length - 1 ? ' ' : ''));
            }
          } else {
            tokens = lineText.split('');
          }

          if (tokens.isNotEmpty) {
            final totalChars = lineText.length;
            if (totalChars > 0) {
              double msPerChar = lineDurationMs.toDouble() / totalChars;
              Duration currentTokenStart = startTime;
              for (final token in tokens) {
                if (token.isEmpty) continue;
                final tokenDurationMs = (msPerChar * token.length).round();
                final tokenDuration = Duration(
                  milliseconds: tokenDurationMs > 0 ? tokenDurationMs : 1,
                );
                final tokenEndTime = currentTokenStart + tokenDuration;
                finalChars.add(
                  LyricChar(
                    char: token,
                    start: currentTokenStart,
                    end: tokenEndTime,
                  ),
                );
                currentTokenStart = tokenEndTime;
              }
            }
          }
        } else {
          // 无时长或文本为空
          finalChars.add(
            LyricChar(char: lineText, start: startTime, end: validEndTime),
          );
        }
      }

      if (finalChars.isNotEmpty) {
        lyricLines.add(
          LyricLine(
            chars: finalChars,
            startTime: lineStartTime,
            endTime: lineEndTime,
          ),
        );
      }
    }

    return lyricLines;
  } catch (e) {
    debugPrint('Error parsing TTML content: $e');
    return [];
  }
}

// 新增一个临时辅助类，用于解析过程
class _TempLyricChar {
  String text;
  final Duration start;
  _TempLyricChar(this.text, this.start);
}

Duration _parseTtmlTime(String time) {
  if (time.endsWith('s')) {
    final seconds = double.tryParse(time.replaceAll('s', '')) ?? 0.0;
    return Duration(milliseconds: (seconds * 1000).round());
  }
  final parts = time.split(':');
  int h = 0, m = 0;
  double s = 0;
  try {
    if (parts.length == 3) {
      h = int.parse(parts[0]);
      m = int.parse(parts[1]);
      s = double.parse(parts[2]);
    } else if (parts.length == 2) {
      m = int.parse(parts[0]);
      s = double.parse(parts[1]);
    } else if (parts.length == 1) {
      s = double.parse(parts[0]);
    }
    return Duration(milliseconds: h * 3600000 + m * 60000 + (s * 1000).round());
  } catch (e) {
    debugPrint('Error parsing time format "$time": $e');
    return Duration.zero;
  }
}
