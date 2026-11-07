import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class _WallWrapParentData extends ContainerBoxParentData<RenderBox> {}

// CSS flex-wrap with align-items:baseline: a multi-line artist/album label must not vertically centre the other items beside it.
class WallBaselineWrap extends MultiChildRenderObjectWidget {
  const WallBaselineWrap({
    super.key,
    super.children,
    this.spacing = 10,
    this.runSpacing = 6,
  });
  final double spacing, runSpacing;
  @override
  RenderWallBaselineWrap createRenderObject(BuildContext context) =>
      RenderWallBaselineWrap(spacing, runSpacing);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderWallBaselineWrap renderObject,
  ) => renderObject.update(spacing, runSpacing);
}

class RenderWallBaselineWrap extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  RenderWallBaselineWrap(this._spacing, this._runSpacing);
  double _spacing, _runSpacing;
  void update(double spacing, double runSpacing) {
    if (_spacing == spacing && _runSpacing == runSpacing) return;
    _spacing = spacing;
    _runSpacing = runSpacing;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _WallWrapParentData) {
      child.parentData = _WallWrapParentData();
    }
  }

  Size _layout(BoxConstraints constraints, bool dry) {
    final childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    var run = <({RenderBox child, Size size, double baseline})>[],
        width = 0.0,
        top = 0.0,
        ascent = 0.0,
        descent = 0.0,
        widest = 0.0;
    void finish() {
      if (run.isEmpty) return;
      widest = math.max(widest, width);
      var left = 0.0;
      for (final entry in run) {
        if (!dry) {
          (entry.child.parentData! as ContainerBoxParentData<RenderBox>)
              .offset = Offset(
            left,
            top + ascent - entry.baseline,
          );
        }
        left += entry.size.width + _spacing;
      }
      top += ascent + descent + _runSpacing;
      run = [];
      width = ascent = descent = 0;
    }

    var child = firstChild;
    while (child != null) {
      final next = childAfter(child);
      final Size childSize;
      final double baseline;
      if (dry) {
        childSize = child.getDryLayout(childConstraints);
        baseline =
            child.getDryBaseline(childConstraints, TextBaseline.alphabetic) ??
            childSize.height;
      } else {
        child.layout(childConstraints, parentUsesSize: true);
        childSize = child.size;
        baseline =
            child.getDistanceToBaseline(
              TextBaseline.alphabetic,
              onlyReal: true,
            ) ??
            childSize.height;
      }
      if (run.isNotEmpty &&
          width + _spacing + childSize.width > constraints.maxWidth) {
        finish();
      }
      width += (run.isEmpty ? 0 : _spacing) + childSize.width;
      ascent = math.max(ascent, baseline);
      descent = math.max(descent, childSize.height - baseline);
      run.add((child: child, size: childSize, baseline: baseline));
      child = next;
    }
    finish();
    return constraints.constrain(
      Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : widest,
        math.max(0, top - _runSpacing),
      ),
    );
  }

  @override
  void performLayout() {
    size = _layout(constraints, false);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, true);
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);
  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
