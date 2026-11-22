import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'critters_lib.dart';

const double _duration = 3.2;
const double _beat = _duration / 2.0;
final CritterGrid _grid = CritterGrid(-22, -28, 44, 36);
final CritterGrid _armsGrid = CritterGrid(-40, -40, 80, 100);
const double _w0 = 32.0;
const double _h0 = 18.0;

double _squeeze(double u) {
  if (u < 0.16) return Ease.outCubic(u / 0.16);
  if (u < 0.22) return 1.0;
  if (u < 0.72) return lerp(1.0, -0.14, Ease.inOutSine((u - 0.22) / 0.5));
  return lerp(-0.14, 0.0, Ease.inOutSine((u - 0.72) / 0.28));
}

double _lift(double u) => u < 0.42
    ? -6.0 * Ease.outCubic(seg(u, 0.04, 0.42))
    : -6.0 + 6.0 * Ease.inOutSine((u - 0.42) / 0.58);

typedef _BellState = ({
  double x,
  double y,
  double c,
  double w,
  double h,
});

_BellState _bell(double time) {
  final t = wrap(time, _duration);
  final u = t.remainder(_beat) / _beat;
  final c = _squeeze(u);
  return (
    x: 2.0 * math.sin((t / _duration) * tau),
    y: _lift(u),
    c: c,
    w: _w0 * (1.0 - 0.3 * c),
    h: _h0 * (1.0 + 0.24 * c),
  );
}

double _halfW(double h, _BellState b) {
  if (h > b.h) return -1.0;
  final v = math.max(0.0, h) / b.h;
  var hw = (b.w / 2.0) * math.sqrt(math.max(0.0, 1.0 - v * v));
  if (h < b.h * 0.3) hw -= b.c * 2.4 * (1.0 - h / (b.h * 0.3));
  return hw;
}

double _scallop(double dx, _BellState b) =>
    1.1 *
    math.max(
      0.0,
      math.sin((dx / (b.w / 2.0)) * math.pi * 4.0 + math.pi / 2.0),
    );

void _drawBell(
  Painter p,
  List<int> c,
  List<int> gl,
  _BellState b,
  double t,
) {
  final g = _grid.clear();
  final bx = roundJs(b.x);
  final by = roundJs(b.y);
  bool inside(double x, double y) {
    final dx = x - b.x;
    final h = b.y - y;
    if (h < -_scallop(dx, b)) return false;
    final hw = _halfW(math.max(0.0, h), b);
    return hw >= 0.0 && dx.abs() <= hw;
  }

  g.shade(-20, -26, 20, 3, (x, y, out) {
    final xx = x + bx;
    final yy = y + by;
    if (!inside(xx, yy)) return 0;
    out.t = 1;
    return c[3];
  });
  g.depths(4);

  final iw = b.w * 0.36;
  final ih = b.h * 0.66;
  final lx = b.x - b.w * 0.22;
  final ly = b.y - b.h * 0.78;

  g.recolor((x, y, col, a, tag) {
    if (tag != 1) return col;
    final xx = x + bx + 0.5;
    final yy = y + by + 0.5;
    final d = g.depth(x, y);
    final dx = xx - b.x;
    final h = b.y - yy;
    final v = h / b.h;
    final i = g.idx(x, y);
    var outCol = c[3];
    var al = 0.26 + 0.2 * clamp(v);
    final ie = (dx / iw) * (dx / iw) +
        (math.max(0.0, h) / ih) * (math.max(0.0, h) / ih);
    if (ie > 0.8 && ie < 1.12 && h > 0.5) {
      outCol = c[4];
      al = 0.55;
    }
    if (h < 1.0) {
      outCol = c[5];
      al = 0.85;
    }
    if (d == 2) {
      outCol = (v > 0.5 && dx < 0.0) ? c[5] : c[4];
      al = 0.75;
    }
    if (d == 1) {
      outCol = (dx < 0.0 && v > 0.25) ? c[6] : c[5];
      al = 0.92;
    }
    final gx = xx - lx;
    final gy = yy - ly;
    if (d == 2 && dx < -1.0 && v > 0.45 && gx * gx + gy * gy < 26.0) {
      outCol = c[7];
      al = 1.0;
    }
    g.a[i] = al;
    return outCol;
  });

  for (final s in const [-0.62, 0.62]) {
    for (var h = 2; h < b.h - 2.0; h++) {
      final hw = _halfW(h.toDouble(), b);
      final x = b.x + s * hw * 0.9;
      final y = b.y - h;
      if (g.depth(x - bx, y - by) >= 3) {
        g.set(x - bx, y - by, c[4], 0.5);
      }
    }
  }

  final pulse = 0.5 + 0.5 * b.c;
  final cy = b.y - b.h * 0.42;
  final rx = b.w * 0.2;
  final ry = b.h * 0.2;
  final yEnd = cy + ry;
  final xEnd = b.x + rx;
  for (var y = (cy - ry).floor(); y <= yEnd; y++) {
    for (var x = (b.x - rx).floor(); x <= xEnd; x++) {
      final dx = (x + 0.5 - b.x) / rx;
      final dy = (y + 0.5 - cy) / ry;
      final d = dx * dx + dy * dy;
      if (d > 1.0 || g.depth(x - bx, y - by) < 2) continue;
      g.set(
        x - bx,
        y - by,
        d < 0.3 ? c[6] : (d < 0.65 ? c[5] : c[4]),
        d < 0.3 ? 0.9 : 0.6,
      );
    }
  }

  g.outlineShaded((_, _, _, ny) => ny > 0 ? 0 : c[1], 0.9);
  g.draw(p, 1.0, bx.toDouble(), by.toDouble());

  p.glow(b.x, b.y - b.h * 0.45, 30.0 + 6.0 * b.c, c[4], 0.22 + 0.12 * pulse);
  p.glow(b.x, b.y - b.h * 0.45, 11, c[6], 0.14 + 0.16 * pulse);
  for (final s in const [-1, 1]) {
    for (final q in const [0.14, 0.42, 0.78]) {
      final x = b.x + s * _halfW(0.5, b) * q;
      final y = b.y + 1.0;
      final tw =
          0.6 + 0.4 * math.sin((t / _duration) * tau * 3.0 + q * 9.0 + s);
      p.px(x, y, tw > 0.85 ? gl[3] : gl[2]);
      p.glow(x, y, 4, gl[2], 0.4 * tw);
    }
  }
}

List<(double, double)> _strand(
  double t,
  (double, double) Function(_BellState) off,
  double len,
  double step,
  double lag,
  double sway,
  double ph,
  double pull,
) {
  final pts = <(double, double)>[];
  final b1 = _bell(t);
  final o1 = off(b1);
  for (var s = 0.0; s <= len; s += step) {
    final b = _bell(t - s * lag);
    final relax = 1.0 - clamp(b.c);
    final ox = lerp(o1.$1, off(b).$1, 0.4);
    final w = (0.3 + s * sway) *
        (0.55 + 0.65 * relax) *
        math.sin((t / _duration) * tau * 2.0 - s * 0.11 + ph);
    pts.add((
      b.x + ox + w + ox * s * (0.009 * relax - 0.005 * pull * b.c),
      b.y + o1.$2 + s * (0.88 + 0.05 * b.c),
    ));
  }
  return pts;
}

void _drawTentacle(
  Painter p,
  List<int> c,
  List<int> gl,
  List<(double, double)> pts,
  bool back,
  double t,
  int i,
) {
  final n = pts.length;
  for (var k = 1; k < n; k++) {
    final u = k / (n - 1);
    final (x0, y0) = pts[k - 1];
    final (x1, y1) = pts[k];
    final col = back
        ? (u < 0.3 ? c[3] : (u < 0.7 ? c[2] : c[1]))
        : (u < 0.2 ? c[5] : (u < 0.45 ? c[4] : (u < 0.78 ? c[3] : c[2])));
    p.line(x0, y0, x1, y1, col);
  }
  if (back) return;
  for (var k = 3; k < n; k += 4) {
    final tw = math.sin((t / _duration) * tau * 2.0 - k * 0.5 + i * 1.7);
    if (tw < 0.3) continue;
    final (x, y) = pts[k];
    p.px(x, y, tw > 0.8 ? gl[3] : gl[2]);
    p.glow(x, y, 3.5, gl[2], 0.35 * tw);
  }
}

void _drawArms(
  Painter p,
  List<int> c,
  List<({bool back, List<(double, double)> pts})> list,
  bool back,
) {
  final g = _armsGrid.clear();
  final a = back ? 0.6 : 0.88;
  for (final arm in list) {
    if (arm.back != back) continue;
    final pts = arm.pts;
    final n = pts.length;
    var lastRow = -1000000000;
    for (var k = 1; k < n; k++) {
      final (x0, y0) = pts[k - 1];
      final (x1, y1) = pts[k];
      final m = math.max<int>(1, ((y1 - y0).abs() * 2.0).ceil());
      for (var j = 0; j < m; j++) {
        final q = j / m;
        final x = lerp(x0, x1, q);
        final y = lerp(y0, y1, q);
        final u = (k - 1 + q) / (n - 1);
        final wd = lerp(2.2, 0.6, u);
        final wdCeil = wd.ceil();
        for (var i = -wdCeil; i <= wdCeil; i++) {
          if (i.abs() > wd + 0.2) continue;
          g.set(
            x + i,
            y,
            i < 0
                ? c[back ? 4 : 6]
                : (i > 0 ? c[back ? 2 : 4] : c[back ? 3 : 5]),
            a,
          );
        }
        final row = y.floor();
        if (row != lastRow && row % 3 == 0 && u < 0.85) {
          g.set(
            x + ((row ~/ 3).isOdd ? -wd - 1.2 : wd + 1.2),
            y,
            c[back ? 4 : 6],
            a,
          );
        }
        lastRow = row;
      }
    }
  }
  g.draw(p);
}

final PureEffect jellyfishEffect = PureEffect(
  meta: const EffectMeta(
    id: 'critters/jellyfish',
    name: 'Jellyfish',
    desc:
        'A see-through jellyfish pulses: its bell squeezes to shove it up and relaxes as it sinks, frilled arms and long tentacles trailing, a glow inside, bubbles drifting by.',
    category: 'critters',
    tags: ['critter', 'jellyfish', 'sea', 'underwater', 'glow', 'swim', 'loop'],
    size: (96, 120),
    origin: (48, 38),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#140b2b',
        '#2a1650',
        '#4b2386',
        '#7a3cb8',
        '#b066e0',
        '#e09cf5',
        '#ffd6ff',
        '#ffffff',
      ],
      'glow': ['#0b3550', '#1f7fa8', '#4fd2e8', '#b8fbff'],
      'seed': 1,
    },
  ),
  onDraw: (p, time, o) {
    final seed = o.seed;
    final t = shift(time, _duration, seed);
    final c = fit(o.palette, 8);
    final gl = fit(o.rampOpt('glow'), 4);
    final b = _bell(t);

    cycle(t, _duration, 16, seed * 5 + 1, (_) => _duration, (age, len, r, _) {
      final x = r.range(-42.0, 42.0) + math.sin(age * 0.8 + r.next() * 6.0) * 3.0;
      final y = r.range(-34.0, 66.0) + age * r.range(1.0, 4.0);
      final tw = math.sin(age * 2.2 + r.next() * 6.0);
      final a = math.min(1.0, math.min(age * 2.0, (len - age) * 2.0)) *
          (0.35 + 0.35 * tw);
      p.dot(x, y, tw > 0.8 ? gl[2] : c[3], a);
    });

    final tents = <({bool back, int i, List<(double, double)> pts})>[];
    final arms = <({bool back, List<(double, double)> pts})>[];
    for (var i = 0; i < 9; i++) {
      final r = rng(seed, i, 4);
      final q = -0.88 + (1.76 * i) / 8.0 + r.range(-0.05, 0.05);
      final back = i.isOdd;
      tents.add((
        back: back,
        i: i,
        pts: _strand(
          t,
          (bellState) => (q * _halfW(0.5, bellState), 0.5),
          r.range(36.0, 50.0),
          1.5,
          0.022,
          0.065,
          r.range(0.0, tau),
          1.0,
        ),
      ));
    }

    const armOffsets = [-0.32, -0.1, 0.12, 0.3];
    for (var i = 0; i < 4; i++) {
      final r = rng(seed, i, 9);
      final q = armOffsets[i];
      final back = i == 1 || i == 2;
      arms.add((
        back: back,
        pts: _strand(
          t,
          (bellState) => (q * bellState.w * 0.5, -1.0),
          r.range(20.0, 27.0),
          1.0,
          0.03,
          0.06,
          r.range(0.0, tau) + i,
          0.4,
        ),
      ));
    }

    for (var bb = 0; bb < 2; bb++) {
      final age = wrap(t - bb * _beat - 0.05, _duration);
      if (age > 0.9) continue;
      final b0 = _bell(bb * _beat + 0.05);
      final e = Ease.outCubic(age / 0.9);
      final k = 1.0 - age / 0.9;
      final cx = b0.x;
      final cy = b0.y + 3.0 + 14.0 * e;
      final rx = b0.w * 0.32 + 9.0 * e;
      final ry = 1.5 + 2.5 * e;
      for (var j = 0; j < 8; j++) {
        final a = (j / 8.0) * tau + e * 0.8;
        p.glow(
          cx + math.cos(a) * rx,
          cy + math.sin(a) * ry,
          5.0 + 3.0 * e,
          c[5],
          0.14 * k,
        );
      }
      for (var j = 0; j < 7; j++) {
        final a = (j / 7.0) * tau + e * 2.4 + bb;
        final x = cx + math.cos(a) * rx * 1.05;
        final y = cy + math.sin(a) * ry * 1.4 - math.cos(a * 2.0) * 0.6;
        if (k < 0.15 && j.isOdd) continue;
        p.dot(x, y, math.sin(a) > 0.0 ? gl[3] : gl[2], math.min(1.0, k * 2.5));
        p.glow(x, y, 3, gl[2], 0.3 * k);
      }
      for (var i = 0; i < 4; i++) {
        final r = rng(seed, bb, i, 13);
        final len = r.range(1.4, 2.2);
        final ag = wrap(t - bb * _beat - 0.08 - i * 0.04, _duration);
        if (ag > len) continue;
        final rad = r.range(0.6, 1.5);
        final sx = r.sign();
        final x = b0.x + sx * (b0.w * 0.4 + r.range(0.0, 4.0) + ag * r.range(4.0, 10.0));
        final y = b0.y + 2.0 - (14.0 + 10.0 * rad) * ag + 6.0 * math.exp(-ag * 4.0);
        if (y < -33.0) continue;
        bubble(
          p,
          x + math.sin(ag * 5.0 + i) * 0.8,
          y,
          rad,
          [gl[3], gl[3], gl[2], gl[1]],
          math.min(
            1.0,
            math.min(ag * 6.0, math.min((len - ag) * 3.0, (y + 33.0) / 6.0)),
          ),
        );
      }
    }

    for (final a in tents) {
      if (a.back) _drawTentacle(p, c, gl, a.pts, true, t, a.i);
    }
    _drawArms(p, c, arms, true);
    _drawBell(p, c, gl, b, t);
    _drawArms(p, c, arms, false);
    for (final a in tents) {
      if (!a.back) _drawTentacle(p, c, gl, a.pts, false, t, a.i);
    }

    cycle(t, _duration, 7, seed * 5 + 2, (r) => r.range(1.8, 3.0),
        (age, len, r, _) {
      final rad = r.chance(0.6) ? r.range(0.6, 1.4) : r.range(1.6, 2.6);
      final x0 = r.range(-30.0, 30.0);
      final y0 = r.range(10.0, 70.0);
      final v = 20.0 + 13.0 * rad;
      final end = math.min(len, (y0 + 30.0) / v);
      if (age > end) return;
      final ph = r.next() * tau;
      final x = x0 + math.sin(age * (4.0 + 2.0 / rad) + ph) * (0.6 + rad * 0.8);
      final y = y0 - v * age;
      bubble(
        p,
        x,
        y,
        rad,
        [gl[3], gl[3], gl[2], gl[1]],
        math.min(1.0, math.min(age * 3.0, (end - age) * 3.0)),
        0.1 * math.sin(age * 9.0 + ph),
      );
    });

    p.glow(b.x, b.y + 6.0, 58, c[3], 0.14);
  },
);
