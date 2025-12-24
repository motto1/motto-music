import 'package:flutter/material.dart';

class CompactPageHeader extends StatelessWidget {
  final String title;
  final Color textColor;
  final bool showBackButton;
  final bool centerTitle;
  final Color? backIconColor;
  final VoidCallback? onBack;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double titleOpacity;
  final double titleTranslateY;

  const CompactPageHeader({
    super.key,
    required this.title,
    required this.textColor,
    this.showBackButton = true,
    this.centerTitle = true,
    this.backIconColor,
    this.onBack,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(12, 6, 12, 6),
    this.titleOpacity = 1.0,
    this.titleTranslateY = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final needsPlaceholder = centerTitle;
    final leading = showBackButton
        ? SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                color: backIconColor ?? textColor,
                size: 20,
              ),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            ),
          )
        : SizedBox(width: needsPlaceholder ? 40 : 0);
    final trailingWidget = trailing ?? SizedBox(width: needsPlaceholder ? 40 : 0);
    final titleWidget = Transform.translate(
      offset: Offset(0, titleTranslateY),
      child: Opacity(
        opacity: titleOpacity,
        child: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return Padding(
      padding: padding,
      child: Row(
        children: [
          leading,
          Expanded(
            child: centerTitle
                ? Center(child: titleWidget)
                : Align(alignment: Alignment.centerLeft, child: titleWidget),
          ),
          trailingWidget,
        ],
      ),
    );
  }
}
