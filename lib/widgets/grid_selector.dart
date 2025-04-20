import 'package:flutter/material.dart';

class GridSelector extends StatefulWidget {
  final int rows;
  final int cols;
  final bool allowMultiple;
  final Function(List<Point>) onChanged;
  final List<Point> initialValue;

  const GridSelector({
    super.key,
    required this.rows,
    required this.cols,
    this.allowMultiple = false,
    required this.onChanged,
    this.initialValue = const [],
  });

  @override
  State<GridSelector> createState() => _GridSelectorState();
}

class _GridSelectorState extends State<GridSelector> {
  late List<Point> selectedPoints;

  @override
  void initState() {
    super.initState();
    selectedPoints = List.from(widget.initialValue);
  }

  void _handleTap(int row, int col) {
    setState(() {
      final point = Point(row, col);
      if (widget.allowMultiple) {
        if (selectedPoints.contains(point)) {
          selectedPoints.remove(point);
        } else {
          selectedPoints.add(point);
        }
      } else {
        selectedPoints = [point];
      }
      widget.onChanged(selectedPoints);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.rows, (row) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.cols, (col) {
              final point = Point(row, col);
              final isSelected = selectedPoints.contains(point);
              return Padding(
                padding: const EdgeInsets.all(2),
                child: InkWell(
                  onTap: () => _handleTap(row, col),
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? theme.colorScheme.primary.withOpacity(0.15)
                          : theme.colorScheme.surface,
                    ),
                    child: isSelected
                        ? Center(
                            child: Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}

class Point {
  final int row;
  final int col;

  Point(this.row, this.col);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Point && other.row == row && other.col == col;
  }

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  Map<String, int> toJson() {
    return {
      'row': row,
      'col': col,
    };
  }

  factory Point.fromJson(Map<String, dynamic> json) {
    return Point(
      json['row'] as int,
      json['col'] as int,
    );
  }
}
