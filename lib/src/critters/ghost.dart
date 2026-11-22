import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'critters_lib.dart';

const double _duration = 2.4;
final CritterGrid _grid = CritterGrid(-20, -40, 40, 46);
const double _r = 10.5;

({double x, double y}) _at(double t, double hover) {
  final a = (t / _duration) * tau;
  return (
    x: 4.0 * math.sin(a),
    y: -hover - 3.0 * math.sin(2.0 * a + 0.8),
  );
}

double _halfW(double h) {
  const top = 2.0 * _r + 9.0;
  if (h > top || h < -1.0) return -1.0;
  if (h > top - _r) {
    final dy = h - (top - _r);
    return math.sqrt(math.max(0.0, _r * _r - dy * dy));
  }
  return lerp(_r + 2.2, _r, math.pow(h / (top - _r), 0.7).toDouble());
}

double _sheet(
  CritterGrid g,
  List<int> c,
  double t,
  double lagX,
) {
  g.clear();
  const top = 2.0 * _r + 9.0;
  final ph = (t / _duration) * tau * 2.0;
  const nl = 4;
  const hwMax = _r + 2.2;
  const lw = (2.0 * hwMax) / nl;

  double off(double h) =>
      lagX * math.pow(1.0 - clamp(h / top), 1.4).toDouble();

  ({int j, double u, double d}) lobe(double xPos) {
    final j = clampInt(((xPos + hwMax) / lw).floor(), 0, nl - 1);
    final center = -hwMax + (j + 0.5) * lw;
    final u = (xPos - center) / (lw / 2.0);
    return (
      j: j,
      u: u,
      d: (2.2 + 1.1 * math.sin(ph - j * 1.5)) *
          math.sqrt(math.max(0.0, 1.0 - u * u)),
    );
  }

  bool inside(double x, double y) {
    final h = -y;
    final xLocal = x - off(h);
    if (h < 0.0 && -h > lobe(xLocal).d) return false;
    final hw = _halfW(math.max(0.0, h));
    return hw >= 0.0 && xLocal.abs() <= hw;
  }

  bool arm(double x, double y) {
    for (final s in const [-1, 1]) {
      final ax = s * (_r + 1.2) + off(13.0);
      final ay = -13.0 + 1.6 * math.sin(ph + s * 1.3);
      final dx = (x - ax) / 3.0;
      final dy = (y - ay) / 2.2;
      if (dx * dx + dy * dy <= 1.0) return true;
    }
    return false;
  }

  bool any(double x, double y) => inside(x, y) || arm(x, y);
  const lx = -9.0;
  const ly = -top - 1.0;
  bool lit(double x, double y, double k) =>
      any(lx + (x - lx) / k, ly + (y - ly) / k);

  g.shade(-19, -top - 2.0, 19, 5, (x, y, out) {
    if (!any(x, y)) return 0;
    final h = -y;
    final xLocal = x - off(h);
    var i = lit(x, y, 0.62) ? 5 : 4;
    if (!any(x + 2.4, y + 1.8)) i = 3;
    if (!any(x + 1.2, y + 1.0) && xLocal > 2.0) i = 2;
    if (h > top - _r - 2.0 &&
        xLocal < 1.0 &&
        !any(x - 1.5, y - 1.5) &&
        any(x - 0.6, y - 0.6)) {
      i = 6;
    }
    if (h < 1.0) {
      final l = lobe(xLocal);
      if (l.u > 0.1 || -h > l.d - 1.2) i = math.min(i, 3);
    }
    if (h < 7.0 && h >= -0.5) {
      for (var j = 1; j < nl; j++) {
        final cx = -hwMax + j * lw + 0.6 * math.sin(ph - j);
        final w = (7.0 - h) * 0.09;
        if ((xLocal - cx).abs() <= w + 0.3) {
          i = math.min(i, 3);
        } else if (cx - xLocal > w + 0.3 && cx - xLocal < w + 1.3 && i == 4) {
          i = 5;
        }
      }
    }
    out.a = h < 2.0 ? 0.86 : 0.95;
    return c[i];
  });
  return top;
}

final PureEffect ghostEffect = PureEffect(
  meta: const EffectMeta(
    id: 'critters/ghost',
    name: 'Ghost',
    desc:
        'A sheet ghost bobs over the floor: its scalloped hem ripples and trails its drift, little arms flutter, it glances about and blinks, motes trickle off its hem.',
    category: 'critters',
    tags: ['critter', 'ghost', 'spirit', 'undead', 'spooky', 'float', 'loop'],
    size: (96, 100),
    origin: (48, 90),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#10142a',
        '#232c52',
        '#3e4f86',
        '#6b84bb',
        '#a3b8e2',
        '#d8e4ff',
        '#ffffff',
      ],
      'hover': 14,
      'seed': 1,
    },
  ),
  onDrawBack: (p, time, o) {
    final t = shift(time, _duration, o.seed);
    final c = fit(o.palette, 7);
    final s = _at(t, o.numOpt('hover', 14.0));
    final hgt = clamp((-s.y - 8.0) / 16.0);
    shadow(p, s.x, 0, 11.0 - 3.0 * hgt, 1.6, c[0], 0.55 - 0.2 * hgt);
    for (var x = -24; x <= 24; x += 6) {
      p.glow(
        s.x + x,
        -1,
        16,
        c[4],
        0.14 * (1.0 - x.abs() / 34.0) * (1.0 - 0.4 * hgt),
      );
    }
  },
  onDraw: (p, time, o) {
    final seed = o.seed;
    final hover = o.numOpt('hover', 14.0);
    final t = shift(time, _duration, seed);
    final c = fit(o.palette, 7);
    final s = _at(t, hover);
    final lagX = _at(t - 0.3, hover).x - s.x;

    final g = _grid;
    final top = _sheet(g, c, t, lagX);

    final tw = wrap(t, _duration);
    final look = tw < 0.7 ? 0 : (tw < 1.3 ? 1 : (tw < 1.9 ? -1 : 0));
    final blink = tw > 1.95 && tw < 2.03;
    final ey = -top + _r - 1.0;
    final mo = 0.5 + 0.5 * math.sin((t / _duration) * tau * 2.0);

    for (final side in const [-1, 1]) {
      final ex = side * 4 - (side > 0 ? 1 : 0) + look;
      if (blink) {
        g.set(ex, ey + 2.0, c[1]);
        g.set(ex + 1, ey + 2.0, c[1]);
      } else {
        for (var k = 0; k < 4; k++) {
          g.set(ex, ey + k, c[0]);
          g.set(ex + 1, ey + k, c[0]);
        }
        g.set(ex + (look < 0 ? 0 : 1), ey, c[2]);
      }
    }

    final my = ey + 6.0;
    g.set(look - 1, my, c[1]);
    g.set(look, my, c[1]);
    if (mo > 0.4) {
      g.set(look - 1, my + 1.0, c[0]);
      g.set(look, my + 1.0, c[0]);
    }
    g.outlineShaded((_, _, _, ny) => ny > 0 ? c[2] : c[1], 0.95);
    g.draw(p, 1.0, s.x, s.y);

    cycle(t, _duration, 12, seed * 3 + 1, (r) => r.range(1.0, 1.7),
        (age, len, r, i) {
      final s0 = _at(wrap(t - age, _duration), hover);
      final k = age / len;
      final x0 = s0.x + r.range(-10.0, 10.0);
      final y0 = s0.y + 1.5;
      final x = x0 + math.sin(age * 2.2 + i) * 2.4;
      final y = y0 + r.range(5.0, 11.0) * age - 3.0 * age * age;
      final a = math.min(1.0, k * 6.0) * math.min(1.0, (1.0 - k) * 2.2);
      final twnk = 0.6 + 0.4 * math.sin(age * 8.0 + i * 1.7);
      p.dot(x, y, twnk > 0.8 ? c[6] : c[5], a);
      if (r.chance(0.3)) p.dot(x, y - 1.0, c[4], a * 0.7);
      p.glow(x, y, 7, c[4], 0.42 * a * twnk);
    });

    p.glow(s.x, s.y - top * 0.55, 54, c[3], 0.3);
    p.glow(s.x - 3.0, s.y - top * 0.72, 14, c[5], 0.12);
  },
);
