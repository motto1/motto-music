import 'package:flutter/material.dart';

class ResolutionDisplay extends StatefulWidget {
  final bool showPhysical;
  final bool showDPR;
  final bool isMinimized;
  
  const ResolutionDisplay({
    super.key,
    this.showPhysical = true,
    this.showDPR = true,
    this.isMinimized = false,
  });

  @override
  State<ResolutionDisplay> createState() => _ResolutionDisplayState();
}

class _ResolutionDisplayState extends State<ResolutionDisplay> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = !widget.isMinimized;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = MediaQuery.of(context).size;
            final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
            final logicalWidth = screenSize.width;
            final logicalHeight = screenSize.height;
            final physicalWidth = (logicalWidth * devicePixelRatio).round();
            final physicalHeight = (logicalHeight * devicePixelRatio).round();
            
            if (!_isExpanded) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.monitor,
                    color: Colors.white70,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${logicalWidth.toInt()}×${logicalHeight.toInt()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monitor,
                      color: Colors.white70,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Resolution',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Logic: ${logicalWidth.toInt()}×${logicalHeight.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.showPhysical) ...[
                  Text(
                    'Physical: ${physicalWidth}×${physicalHeight}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (widget.showDPR) ...[
                  Text(
                    'DPR: ${devicePixelRatio.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
