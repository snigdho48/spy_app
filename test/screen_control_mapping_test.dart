import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:spy_love/features/monitoring/screen_share/screen_control_mapping.dart';

void main() {
  test('maps the center of a contained preview to 0.5, 0.5', () {
    final mapped = mapNormalizedPointer(
      local: const Offset(100, 200),
      viewSize: const Size(200, 400),
      imageWidth: 100,
      imageHeight: 200,
    );
    expect(mapped, isNotNull);
    expect(mapped!.dx, closeTo(0.5, 0.001));
    expect(mapped.dy, closeTo(0.5, 0.001));
  });

  test('ignores letterbox taps beside a contained landscape frame', () {
    // 200x100 image in a 200x200 view: dest is 200x100, letterboxed 50px top/bottom.
    final mapped = mapNormalizedPointer(
      local: const Offset(100, 10),
      viewSize: const Size(200, 200),
      imageWidth: 200,
      imageHeight: 100,
    );
    expect(mapped, isNull);
  });

  test('maps a point on the fitted frame, not the raw view', () {
    final mapped = mapNormalizedPointer(
      local: const Offset(100, 50),
      viewSize: const Size(200, 200),
      imageWidth: 200,
      imageHeight: 100,
    );
    expect(mapped, isNotNull);
    expect(mapped!.dx, closeTo(0.5, 0.001));
    expect(mapped.dy, closeTo(0.0, 0.001));
  });

  test('rejects empty sizes', () {
    expect(
      mapNormalizedPointer(
        local: Offset.zero,
        viewSize: Size.zero,
        imageWidth: 100,
        imageHeight: 100,
      ),
      isNull,
    );
  });
}
