import 'package:flutter/material.dart';

enum SplitDirection { horizontal, vertical }

class ResizableSplitView extends StatefulWidget {
  final Widget first;
  final Widget second;
  final SplitDirection direction;
  final double initialRatio;
  final double minRatio;
  final double maxRatio;

  const ResizableSplitView({
    super.key,
    required this.first,
    required this.second,
    this.direction = SplitDirection.horizontal,
    this.initialRatio = 0.5,
    this.minRatio = 0.1,
    this.maxRatio = 0.9,
  });

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  late double _ratio;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
  }

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.direction == SplitDirection.horizontal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size =
            isHorizontal ? constraints.maxWidth : constraints.maxHeight;

        if (size <= 0 || size.isInfinite) {
          return widget.first;
        }

        final firstSize = size * _ratio;
        final secondSize = size - firstSize - 1; // 1px for divider

        return Stack(
          children: [
            if (isHorizontal)
              Row(
                children: [
                  SizedBox(width: firstSize, child: widget.first),
                  _buildDivider(isHorizontal),
                  SizedBox(width: secondSize, child: widget.second),
                ],
              )
            else
              Column(
                children: [
                  SizedBox(height: firstSize, child: widget.first),
                  _buildDivider(isHorizontal),
                  SizedBox(height: secondSize, child: widget.second),
                ],
              ),
            _buildDragHandle(isHorizontal, size),
          ],
        );
      },
    );
  }

  Widget _buildDivider(bool isHorizontal) {
    return Container(
      width: isHorizontal ? 1 : null,
      height: isHorizontal ? null : 1,
      color: Theme.of(context).dividerTheme.color,
    );
  }

  Widget _buildDragHandle(bool isHorizontal, double totalSize) {
    final position = totalSize * _ratio;

    return Positioned(
      left: isHorizontal ? position - 3 : 0,
      right: isHorizontal ? null : 0,
      top: isHorizontal ? 0 : position - 3,
      bottom: isHorizontal ? 0 : null,
      child: MouseRegion(
        cursor: isHorizontal
            ? SystemMouseCursors.resizeColumn
            : SystemMouseCursors.resizeRow,
        child: GestureDetector(
          onHorizontalDragStart: isHorizontal ? _onDragStart : null,
          onVerticalDragStart: isHorizontal ? null : _onDragStart,
          onHorizontalDragUpdate: isHorizontal ? _onDragUpdate : null,
          onVerticalDragUpdate: isHorizontal ? null : _onDragUpdate,
          onHorizontalDragEnd: isHorizontal ? _onDragEnd : null,
          onVerticalDragEnd: isHorizontal ? null : _onDragEnd,
          child: Container(
            width: isHorizontal ? 6 : null,
            height: isHorizontal ? null : 6,
            color: _isDragging
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final size = widget.direction == SplitDirection.horizontal
        ? box.size.width
        : box.size.height;

    if (size <= 0) return;

    final localPosition = box.globalToLocal(details.globalPosition);
    final position = widget.direction == SplitDirection.horizontal
        ? localPosition.dx
        : localPosition.dy;

    setState(() {
      _ratio = (position / size).clamp(widget.minRatio, widget.maxRatio);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
  }
}
