import 'package:flutter/material.dart';

class MottoSearchField extends StatelessWidget {
  static const Color accentColor = Color(0xFFE84C4C);

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final bool autofocus;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  /// 是否显示默认搜索图标（leadingIcon 为空时生效）
  final bool showSearchIcon;

  /// 自定义左侧 leading 图标（例如返回箭头），优先级高于 showSearchIcon
  final IconData? leadingIcon;

  /// leading 图标颜色，默认使用 [accentColor]
  final Color? leadingIconColor;

  /// leading 图标点击回调
  final VoidCallback? onLeadingTap;

  const MottoSearchField({
    super.key,
    required this.hintText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.search,
    this.autofocus = false,
    this.isLoading = false,
    this.onTap,
    this.onClear,
    this.showSearchIcon = true,
    this.leadingIcon,
    this.leadingIconColor,
    this.onLeadingTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF1F1F4);
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.38);
    final textColor =
        isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.6);

    final canClear = (controller?.text.trim().isNotEmpty ?? false) &&
        (onClear != null || controller != null) &&
        !isLoading;

    Widget body;
    final hasEditableController = controller != null && (onChanged != null || onSubmitted != null);
    if (hasEditableController) {
      body = TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        textAlignVertical: TextAlignVertical.center,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(fontSize: 15, color: textColor),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 15, color: hintColor),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      );
    } else {
      final displayText = controller?.text.trim();
      final shown = (displayText != null && displayText.isNotEmpty) ? displayText : hintText;
      final shownColor =
          (displayText != null && displayText.isNotEmpty) ? textColor : hintColor;
      body = Text(
        shown,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: shownColor),
      );
    }

    final resolvedLeadingColor = leadingIconColor ?? accentColor;

    final content = SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 16),
          if (leadingIcon != null) ...[
            IconButton(
              icon: Icon(leadingIcon, size: 20, color: resolvedLeadingColor),
              onPressed: onLeadingTap,
              tooltip: '返回',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ] else if (showSearchIcon) ...[
            Icon(Icons.search, size: 18, color: hintColor),
            const SizedBox(width: 8),
          ],
          Expanded(child: body),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (canClear)
            IconButton(
              icon: Icon(Icons.cancel, size: 18, color: hintColor),
              onPressed: onClear ?? controller!.clear,
              tooltip: '清除',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: content,
            ),
    );
  }
}

