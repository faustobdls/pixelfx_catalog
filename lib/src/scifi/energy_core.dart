import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'scifi_lib.dart';

const double _d = 2.4;
const double _cy = -36.0;
const double _r0 = 11.0;
const double _rc = 24.0;
const double _topY = -64.0;
const double _botY = -9.0;
const double _slot = 0.1;
final int _ns = ((_d / _slot) + 0.5).floor();

const List<(double, double, bool)> _beats = [
  (0.05, 1.0, true),
  (0.25, 0.5, false),
  (1.25, 1.0, true),
  (1.45, 0.5, false),
];

double _env(double a) =>
    a < 0.03 ? a / 0.03 : math.exp(-(a - 0.03) / 0.12);

double _pulseAt(double t) {
  var m = 0.0;
  for (final (b, k, _) in _beats) {
    m = math.max(m, k * _env(since(t, b, _d)));
  }
  return m;
}

class _Bar {
  final double x;
  final double z;

  const _Bar(this.x, this.z);
}

final List<_Bar> _bars = List<_Bar>.generate(6, (i) {
  final a = (i / 6.0) * tau + math.pi / 6.0;
  return _Bar(_rc * math.sin(a), math.cos(a));
});

(double, double, double) _ringPt(
  double r,
  double tilt,
  double spin,
  double a,
) {
  final x = r * math.cos(a);
  final z0 = r * math.sin(a);
  final y = -z0 * math.sin(tilt);
  final z = z0 * math.cos(tilt);
  return (
    x * math.cos(spin) + z * math.sin(spin),
    _cy - y,
    -x * math.sin(spin) + z * math.cos(spin),
  );
}

class _RingSpec {
  final double r;
  final double tilt;
  final double Function(double t) spin;

  const _RingSpec(this.r, this.tilt, this.spin);
}

final List<_RingSpec> _rings = [
  _RingSpec(17.0, 1.15, (t) => tau * (t / _d)),
  _RingSpec(19.0, -0.9, (t) => -tau * 2.0 * (t / _d) + 1.0),
];

class _CoreArc {
  final int s;
  final List<Point2> path;
  final List<List<Point2>> fk;

  const _CoreArc(this.s, this.path, this.fk);
}

class _CoreSetup {
  final List<int> c;
  final List<_CoreArc> arcs;
  final Ghosts g;

  const _CoreSetup(this.c, this.arcs, this.g);
}

final Map<String, _CoreSetup> _cache = {};

_CoreSetup _setup(Map<String, Object?> o) {
  final pal = o.palette;
  final key = '${o.seed}:${pal.join(',')}';
  final hit = _cache[key];
  if (hit != null) return hit;

  final c = fit(pal, 8);
  final rn = Rng(o.seed);
  final g = Ghosts(
    _d,
    ground: (_) => 0.0,
    sparks: [kWhite, c[6], c[5], c[4]],
    haze: c[5],
    box: (-54.0, -98.0, 54.0, 11.0),
  );
  final arcs = <_CoreArc>[];
  final frontBars = _bars.where((b) => b.z > -0.2).toList(growable: false);
  for (var s = 0; s < _ns; s++) {
    final ts = s * _slot;
    final hot = _beats.any(
      (b) => b.$3 && since(ts, b.$1, _d) < 0.16,
    );
    for (var n = 0; n < (hot ? 2 : 1); n++) {
      if (!hot && !rn.chance(0.4)) continue;
      final bar = rn.pick(frontBars);
      final ty = rn.range(_topY + 8.0, _botY - 6.0);
      final ang = math.atan2(ty - _cy, bar.x);
      final sx = math.cos(ang) * _r0;
      final sy = _cy + math.sin(ang) * _r0;
      final path = bolt(
        rn,
        sx,
        sy,
        bar.x - (bar.x > 0 ? 1.0 : (bar.x < 0 ? -1.0 : 0.0)) * 1.5,
        ty,
        jag: 0.3,
        depth: 4,
      );
      arcs.add(_CoreArc(
        s,
        path,
        forks(rn, path, count: rn.intRange(0, 1), len: 7.0, jag: 0.35),
      ));
      for (var i = 0; i < 5; i++) {
        final a =
            math.atan2(ty - sy, bar.x - sx) + math.pi + rn.range(-1.2, 1.2);
        final sp = rn.range(60.0, 170.0);
        g.add(
          ts,
          P.spark,
          bar.x,
          ty,
          math.cos(a) * sp,
          math.sin(a) * sp - 40.0,
          rn.range(0.2, 0.5),
        );
      }
    }
  }
  for (final (b, _, strong) in _beats) {
    if (!strong) continue;
    for (var i = 0; i < 12; i++) {
      final a = rn.range(0.0, tau);
      final sp = rn.range(40.0, 110.0);
      g.add(
        b + 0.02,
        P.mote,
        math.cos(a) * _r0,
        _cy + math.sin(a) * _r0,
        math.cos(a) * sp,
        math.sin(a) * sp,
        rn.range(0.25, 0.5),
        rn.pick([kWhite, c[6], c[5]]),
        0.7,
      );
    }
  }
  final v = _CoreSetup(c, arcs, g);
  _cache[key] = v;
  return v;
}

void _plinth(Painter p, List<int> c, List<int> h, double t, double pulse) {
  p.shade(-30, -10, 30, 2, (x, y, out) {
    final topEq = (x / 29.0) * (x / 29.0) + ((y + 7.0) / 4.0) * ((y + 7.0) / 4.0);
    final top = topEq <= 1.0;
    final side = x.abs() <= 29.0 && y > -7.0 && y <= 0.0;
    if (!top && !side) return null;
    if (top) {
      out.c = topEq > 0.82
          ? h[0]
          : (y < -8.0 ? h[5] : (x < 0.0 ? h[4] : h[3]));
    } else {
      out.c = x.abs() > 28.0 || y == 0.0
          ? h[0]
          : (y == -6.0
              ? h[4]
              : (x < -14.0 ? h[3] : (x > 14.0 ? h[1] : h[2])));
    }
    return null;
  });
  for (var i = 0; i < 7; i++) {
    final x = -18 + i * 6;
    final k = 0.5 + 0.5 * math.cos(tau * (2.0 * (t / _d) - i / 7.0));
    p.px(x, -3, k > 0.75 ? kWhite : (k > 0.4 ? c[5] : c[2]));
    if (k > 0.6) p.glow(x, -3, 4, c[4], 0.3 * k);
  }
  p.glow(0, -8, 26, c[4], 0.25 + 0.3 * pulse);
}

void _barDraw(
  Painter p,
  _Bar b,
  List<int> c,
  List<int> h,
  double pulse,
  bool back,
) {
  final lit = back ? c[3] : (pulse > 0.5 ? c[6] : c[5]);
  final inward = b.x > 0 ? -1 : (b.x < 0 ? 1 : 0);
  for (var y = (_topY + 2).toInt(); y < _botY; y++) {
    for (var i = -1; i <= 1; i++) {
      final face = i == inward;
      p.px(
        b.x + i,
        y,
        back
            ? (face ? lit : h[1])
            : (face ? lit : (i == 0 ? h[3] : h[1])),
      );
    }
  }
}

void _hoop(
  Painter p,
  double y,
  double rx,
  List<int> h,
  List<int> c,
  bool near,
  double pulse,
) {
  final n = (rx * 8.0).ceil();
  for (var i = 0; i < n; i++) {
    final g = (i / n) * tau;
    final s = math.sin(g);
    if ((s >= 0.0) != near) continue;
    final x = math.cos(g) * rx;
    final yy = y + s * 4.0;
    p.px(x, yy, near ? (s > 0.6 ? h[4] : h[3]) : h[1]);
    p.px(x, yy + 1.0, near ? h[1] : h[0]);
    if (near && s < 0.3) {
      p.px(x, yy - 1.0, pulse > 0.5 ? c[5] : c[3]);
    }
  }
}

void _core(
  Painter p,
  double t,
  List<int> c,
  double rad,
  double pulse,
  int seed,
) {
  final ph = t / _d;
  p.shade(-rad - 2, _cy - rad - 2, rad + 2, _cy + rad + 2, (x, y, out) {
    final dx = x;
    final dy = y - _cy;
    final d = math.sqrt(dx * dx + dy * dy) / rad;
    if (d > 1.1) return null;
    if (d > 1.0) {
      out.c = c[2];
      return null;
    }
    if (d > 0.9) {
      out.c = dy < -rad * 0.3 && dx < rad * 0.3 ? c[6] : c[4];
      return null;
    }
    final a = math.atan2(dy, dx);
    final n = 0.5 +
        0.5 *
            tileFbm(
              (a / tau) * 6.0 + ph * 6.0 + d * 1.5,
              d * 2.2 - ph * 4.0,
              6,
              4,
              seed,
              2,
            );
    final bandOn = (n - 0.5).abs() < 0.05 + 0.05 * pulse;
    final heat = (1.0 - d) * (1.0 - d) + pulse * 0.45;
    if (bandOn) {
      out.c = heat > 0.5 ? kWhite : (heat > 0.2 ? c[6] : c[5]);
    } else {
      out.c = heat > 0.7
          ? c[6]
          : (heat > 0.42
              ? c[5]
              : (heat > 0.2 ? c[3] : (n > 0.5 ? c[2] : c[1])));
    }
    return null;
  });

  final f = (t * 15.0).floor();
  final r = rng(seed, f, 5);
  for (var i = 0; i < 3; i++) {
    final a = (i / 3.0) * tau + f * 0.7 + r.range(-0.4, 0.4);
    final pts = bolt(
      r,
      0.0,
      _cy,
      math.cos(a) * rad * 0.88,
      _cy + math.sin(a) * rad * 0.88,
      jag: 0.32,
      depth: 3,
    );
    for (var j = 1; j < pts.length; j++) {
      p.lineShaded(
        pts[j - 1].$1,
        pts[j - 1].$2,
        pts[j].$1,
        pts[j].$2,
        color: (u) => u < 0.4 ? kWhite : c[6],
      );
    }
    final (ex, ey) = pts.last;
    p.px(ex, ey, kWhite);
    p.glow(ex, ey, 4, c[5], 0.4);
  }
  p.circle(0, _cy, 1.8 + pulse * 2.0, kWhite);
  p.circleShaded(
    0,
    _cy,
    3.0 + pulse * 2.0,
    color: (d, _) => d > 0.6 ? c[6] : kWhite,
    alpha: (_, _) => 0.0001,
  );
  p.px(-rad * 0.45, _cy - rad * 0.55, kWhite);
  p.px(-rad * 0.45 + 1.0, _cy - rad * 0.55, c[6]);
}

void _ring(
  Painter p,
  double t,
  _RingSpec rg,
  List<int> c,
  bool front,
  double pulse,
) {
  final spin = rg.spin(t);
  final bead = (t / _d) * tau * 3.0;
  final n = (rg.r * 9.0).ceil();
  for (var i = 0; i < n; i++) {
    final a = (i / n) * tau;
    final (x, y, z) = _ringPt(rg.r, rg.tilt, spin, a);
    if ((z >= 0.0) != front) continue;
    final u = ((((a - bead) / tau) % 1.0) + 1.0) % 1.0;
    final head = u > 0.9;
    p.px(
      x,
      y,
      head
          ? kWhite
          : (!front
              ? c[3]
              : (z > 0.5 * rg.r || pulse > 0.6 ? c[6] : c[5])),
    );
  }
  if (front) {
    final (x, y, _) = _ringPt(rg.r, rg.tilt, spin, bead);
    p.glow(x, y, 6, c[5], 0.5);
  }
}

void _drawBack(Painter p, double t, Map<String, Object?> o) {
  final c = fit(o.palette, 8);
  final h = fit(o.rampOpt('metal'), 6);
  final pulse = _pulseAt(t);
  _hoop(p, _botY, _rc, h, c, false, pulse);
  _hoop(p, _topY, _rc, h, c, false, pulse);
  for (final b in _bars) {
    if (b.z < 0.0) _barDraw(p, b, c, h, pulse, true);
  }
  for (final rg in _rings) {
    _ring(p, t, rg, c, false, pulse);
  }
}

void _draw(Painter p, double t, Map<String, Object?> o) {
  final setup = _setup(o);
  final c = setup.c;
  final arcs = setup.arcs;
  final g = setup.g;
  final h = fit(o.rampOpt('metal'), 6);
  final pulse = _pulseAt(t);
  final rad = _r0 * (1.0 + 0.14 * pulse);
  _plinth(p, c, h, t, pulse);
  _core(p, t, c, rad, pulse, o.seed);
  for (final rg in _rings) {
    _ring(p, t, rg, c, true, pulse);
  }
  for (final b in _bars) {
    if (b.z >= 0.0) _barDraw(p, b, c, h, pulse, false);
  }
  _hoop(p, _botY, _rc, h, c, true, pulse);
  _hoop(p, _topY, _rc, h, c, true, pulse);
  p.shade(-15, _topY - 7, 15, _topY, (x, y, out) {
    final d = (x / 14.5) * (x / 14.5) +
        ((y - _topY) / 6.5) * ((y - _topY) / 6.5);
    if (d > 1.0) return null;
    final l = -x * 0.05 - (y - _topY) * 0.12;
    out.c = d > 0.8
        ? h[0]
        : (l > 0.55 ? h[5] : (l > 0.3 ? h[4] : h[3]));
    return null;
  });
  p.px(0, _topY - 7, pulse > 0.4 ? kWhite : c[5]);
  p.glow(0, _topY - 7, 5, c[4], 0.4 + 0.4 * pulse);

  final slotIdx = (t / _slot).floor() % _ns;
  final k = 1.0 - (t - (t / _slot).floor() * _slot) / _slot;
  for (final a in arcs) {
    if (a.s != slotIdx) continue;
    strokeArc(p, a.path, [c[2], c[5], c[4]], k);
    for (final fk in a.fk) {
      strokeArc(p, fk, [c[2], c[5], c[4]], k, 0.6);
    }
    final (ex, ey) = a.path.last;
    p.glow(ex, ey, 8, c[5], 0.6 * k);
  }
  for (final (b, _, strong) in _beats) {
    final a = since(t, b, _d);
    if (!strong || a > 0.45) continue;
    final q = a / 0.45;
    final r = _r0 + 34.0 * Ease.outCubic(q);
    p.ring(
      0,
      _cy,
      r,
      math.max(1.0, 3.0 * (1.0 - q)),
      q < 0.25 ? kWhite : (q < 0.5 ? c[6] : c[5]),
      1.1 - q,
    );
    p.glowRing(0, _cy, r, 6, c[4], 0.35 * (1.0 - q));
  }
  g.at(t).draw(p);
  p.glow(0, _cy, 46, c[4], 0.2 + 0.3 * pulse);
  p.glow(0, _cy, 9, kWhite, 0.35 + 0.4 * pulse);
}

final PixelEffect energyCoreEffect = PureEffect(
  meta: const EffectMeta(
    id: 'scifi/energy-core',
    name: 'Energy core',
    desc:
        'A plasma core beating in a steel cage: it swells and throws a shock ring on each beat, two tilted rings orbit it, and arcs jump to the bars and spark.',
    category: 'scifi',
    tags: [
      'scifi',
      'reactor',
      'core',
      'power',
      'plasma',
      'machine',
      'prop',
      'ground',
      'loop',
    ],
    size: (112, 100),
    origin: (56, 88),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#1a0516',
        '#3d0a33',
        '#701560',
        '#b0228f',
        '#f53cd1',
        '#ff86e6',
        '#ffd2f6',
        '#ffffff',
      ],
      'metal': [
        '#0e0d14',
        '#1e1c27',
        '#312e3e',
        '#4b4759',
        '#6f6a82',
        '#9d98b0',
      ],
      'seed': 35,
    },
  ),
  onDrawBack: _drawBack,
  onDraw: _draw,
);
