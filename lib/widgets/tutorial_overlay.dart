import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Displays a modal coach mark over an existing screen element.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.title,
    required this.description,
    required this.step,
    required this.totalSteps,
    required this.skipLabel,
    required this.nextLabel,
    required this.onSkip,
    required this.onNext,
    this.targetKey,
  });

  final String title;
  final String description;
  final int step;
  final int totalSteps;
  final String skipLabel;
  final String nextLabel;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final GlobalKey? targetKey;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  final GlobalKey _overlayKey = GlobalKey();
  Rect? _targetRect;
  bool _measurementScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleTargetMeasurement();
  }

  @override
  void didUpdateWidget(covariant TutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey ||
        oldWidget.step != widget.step) {
      _targetRect = null;
      _scheduleTargetMeasurement();
    }
  }

  void _scheduleTargetMeasurement() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      final nextRect = _measureTargetRect();
      if (nextRect != _targetRect) {
        setState(() => _targetRect = nextRect);
      }
    });
  }

  Rect? _measureTargetRect() {
    final targetContext = widget.targetKey?.currentContext;
    final overlayContext = _overlayKey.currentContext;
    if (targetContext == null || overlayContext == null) return null;

    final targetBox = targetContext.findRenderObject();
    final overlayBox = overlayContext.findRenderObject();
    if (targetBox is! RenderBox ||
        overlayBox is! RenderBox ||
        !targetBox.hasSize ||
        !overlayBox.hasSize) {
      return null;
    }

    final targetOrigin = targetBox.localToGlobal(Offset.zero);
    final overlayOrigin = overlayBox.localToGlobal(Offset.zero);
    return (targetOrigin - overlayOrigin) & targetBox.size;
  }

  @override
  Widget build(BuildContext context) {
    _scheduleTargetMeasurement();
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      key: const Key('tutorial-overlay'),
      child: BlockSemantics(
        child: Stack(
          key: _overlayKey,
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: CustomPaint(
                key: const Key('tutorial-spotlight'),
                painter: _TutorialSpotlightPainter(
                  targetRect: _targetRect,
                  highlightColor: colorScheme.primary,
                ),
              ),
            ),
            const ModalBarrier(
              dismissible: false,
              color: Colors.transparent,
            ),
            _TutorialCalloutPositioner(
              targetRect: _targetRect,
              child: Semantics(
                container: true,
                scopesRoute: true,
                liveRegion: true,
                explicitChildNodes: true,
                label: '${widget.title}. ${widget.description}',
                child: Focus(
                  autofocus: true,
                  child: _TutorialCallout(
                    title: widget.title,
                    description: widget.description,
                    step: widget.step,
                    totalSteps: widget.totalSteps,
                    skipLabel: widget.skipLabel,
                    nextLabel: widget.nextLabel,
                    onSkip: widget.onSkip,
                    onNext: widget.onNext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialSpotlightPainter extends CustomPainter {
  const _TutorialSpotlightPainter({
    required this.targetRect,
    required this.highlightColor,
  });

  final Rect? targetRect;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final backgroundPath = Path()..addRect(bounds);
    final target = targetRect;

    if (target == null) {
      canvas.drawPath(
        backgroundPath,
        Paint()..color = Colors.black.withValues(alpha: 0.66),
      );
      return;
    }

    final spotlightRect = target.inflate(8).intersect(bounds);
    final spotlight = RRect.fromRectAndRadius(
      spotlightRect,
      const Radius.circular(20),
    );
    final spotlightPath = Path()..addRRect(spotlight);
    final maskPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      spotlightPath,
    );

    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.66),
    );
    canvas.drawRRect(
      spotlight,
      Paint()
        ..color = highlightColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _TutorialSpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.highlightColor != highlightColor;
  }
}

class _TutorialCalloutPositioner extends StatelessWidget {
  const _TutorialCalloutPositioner({
    required this.targetRect,
    required this.child,
  });

  final Rect? targetRect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final safeTop = mediaQuery.padding.top + 16;
    final safeBottom = mediaQuery.padding.bottom + 16;
    final width = math.min(480.0, math.max(0.0, size.width - 32));
    final left = math.max(16.0, (size.width - width) / 2);
    final target = targetRect;

    if (target == null) {
      return SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              maxHeight: math.max(0.0, size.height - safeTop - safeBottom),
            ),
            child: SingleChildScrollView(child: child),
          ),
        ),
      );
    }

    final placeAbove = target.center.dy >= size.height * 0.5;
    if (placeAbove) {
      final bottom = math.max(safeBottom, size.height - target.top + 16);
      final maxHeight = math.max(0.0, size.height - bottom - safeTop);
      return Positioned(
        left: left,
        width: width,
        bottom: bottom,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(child: child),
        ),
      );
    }

    final top = math.max(safeTop, target.bottom + 16);
    final maxHeight = math.max(0.0, size.height - top - safeBottom);
    return Positioned(
      left: left,
      width: width,
      top: top,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _TutorialCallout extends StatelessWidget {
  const _TutorialCallout({
    required this.title,
    required this.description,
    required this.step,
    required this.totalSteps,
    required this.skipLabel,
    required this.nextLabel,
    required this.onSkip,
    required this.onNext,
  });

  final String title;
  final String description;
  final int step;
  final int totalSteps;
  final String skipLabel;
  final String nextLabel;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      key: const Key('tutorial-callout'),
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$step / $totalSteps',
              key: const Key('tutorial-progress'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              key: const Key('tutorial-title'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('tutorial-skip'),
                    onPressed: onSkip,
                    child: Text(skipLabel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const Key('tutorial-next'),
                    onPressed: onNext,
                    child: Text(nextLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
