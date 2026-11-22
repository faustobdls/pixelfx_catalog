import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

class BodyPixel {
  BodyPixel({
    required this.x,
    required this.y,
    required this.mx,
    required this.my,
    required this.c,
    required this.edge,
  });

  final int x;
  final int y;
  final int mx;
  final int my;
  final int c;
  final bool edge;
  double key = 0;
  bool gone = false;
}

class RimCell {
  const RimCell({
    required this.x,
    required this.y,
    required this.mx,
    required this.my,
  });

  final int x;
  final int y;
  final int mx;
  final int my;
}

class BodyData {
  BodyData({
    required this.list,
    required this.w,
    required this.h,
    required this.x,
    required this.y,
    required this.maskData,
    required this.cells,
  });

  final List<BodyPixel> list;
  final int w;
  final int h;
  final int x;
  final int y;
  final Uint8List maskData;
  final List<BodyPixel?> cells;

  bool on(int mx, int my) =>
      mx >= 0 && my >= 0 && mx < w && my < h && maskData[my * w + mx] != 0;

  BodyPixel? cell(int mx, int my) => on(mx, my) ? cells[my * w + mx] : null;
}

/// The actor's body: pixels to break up, burn, freeze or copy, in local space
/// with the feet at (0, 0).
BodyData bodyOf(ActorDefinition actor, List<int> cRamp) {
  final m = actor.mask;
  final px = actor.pixels;
  final list = <BodyPixel>[];
  final cells = List<BodyPixel?>.filled(m.w * m.h, null);

  bool on(int mx, int my) =>
      mx >= 0 && my >= 0 && mx < m.w && my < m.h && m.data[my * m.w + mx] != 0;

  for (var my = 0; my < m.h; my++) {
    for (var mx = 0; mx < m.w; mx++) {
      if (!on(mx, my)) continue;
      final own = px[my * m.w + mx];
      final c = own != 0
          ? own
          : cRamp[math.max(
              1,
              math.min(
                cRamp.length - 2,
                ((cRamp.length - 2) * (0.85 - (my / m.h) * 0.5) + 0.5).floor(),
              ),
            )];
      final b = BodyPixel(
        x: actor.x + mx,
        y: actor.y + my,
        mx: mx,
        my: my,
        c: c,
        edge:
            !on(mx - 1, my) ||
            !on(mx + 1, my) ||
            !on(mx, my - 1) ||
            !on(mx, my + 1),
      );
      list.add(b);
      cells[my * m.w + mx] = b;
    }
  }

  return BodyData(
    list: list,
    w: m.w,
    h: m.h,
    x: actor.x,
    y: actor.y,
    maskData: m.data,
    cells: cells,
  );
}

/// Cells just outside the body (4-neighbours of its rim), local space.
List<RimCell> rimOf(BodyData body) {
  final out = <RimCell>[];
  for (var my = -1; my <= body.h; my++) {
    for (var mx = -1; mx <= body.w; mx++) {
      if (!body.on(mx, my) &&
          (body.on(mx - 1, my) ||
              body.on(mx + 1, my) ||
              body.on(mx, my - 1) ||
              body.on(mx, my + 1))) {
        out.add(RimCell(x: body.x + mx, y: body.y + my, mx: mx, my: my));
      }
    }
  }
  return out;
}
