import 'package:flutter/painting.dart';

/// Maps a pointer on a [BoxFit.contain] preview to normalized 0..1 frame
/// coordinates. Returns null when the point lands in letterbox padding or
/// the sizes are not usable yet.
Offset? mapNormalizedPointer({
  required Offset local,
  required Size viewSize,
  required int imageWidth,
  required int imageHeight,
}) {
  if (imageWidth <= 0 || imageHeight <= 0) return null;
  if (viewSize.width <= 0 || viewSize.height <= 0) return null;

  final fitted = applyBoxFit(
    BoxFit.contain,
    Size(imageWidth.toDouble(), imageHeight.toDouble()),
    viewSize,
  );
  final dest = fitted.destination;
  if (dest.width <= 0 || dest.height <= 0) return null;

  final dx = (viewSize.width - dest.width) / 2;
  final dy = (viewSize.height - dest.height) / 2;
  final x = (local.dx - dx) / dest.width;
  final y = (local.dy - dy) / dest.height;
  if (x < 0 || x > 1 || y < 0 || y > 1) return null;
  return Offset(x, y);
}
