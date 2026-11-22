import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _duration = 3.0;
const double _tip = 0.28;

(double, double, double) _norm(double x, double y, double z) {
  final l = math.sqrt(x * x + y * y + z * z);
  final d = l == 0.0 ? 1.0 : l;
  return (x / d, y / d, z / d);
}

final (double, double, double) _light = _norm(-0.55, -0.75, -0.45);

class _CrystalFace {
  final List<(double, double)> pts;
  final double lit;
  final double spec;
  final double cx;
  final double cy;

  const _CrystalFace(this.pts, this.lit, this.spec, this.cx, this.cy);
}

List<_CrystalFace> _crystalFaces(double th, double r) {
  final ct = math.cos(_tip);
  final st = math.sin(_tip);
  (double, double, double) proj(double x, double y, double z) =>
      (x, y * ct - z * st, y * st + z * ct);
  List<(double, double, double)> ring(double y) => [
        for (var k = 0; k < 6; k++)
          proj(
            math.cos(th + (k * tau) / 6.0) * r,
            y,
            math.sin(th + (k * tau) / 6.0) * r,
          ),
      ];
  final top = ring(-r * 0.45);
  final bot = ring(r * 0.45);
  final apex = proj(0.0, -r * 2.2, 0.0);
  final nadir = proj(0.0, r * 1.7, 0.0);
  final faces = <List<(double, double, double)>>[];
  for (var k = 0; k < 6; k++) {
    final j = (k + 1) % 6;
    faces.add([apex, top[j], top[k]]);
    faces.add([top[k], top[j], bot[j], bot[k]]);
    faces.add([bot[k], bot[j], nadir]);
  }
  final out = <_CrystalFace>[];
  final halfVec = _norm(_light.$1, _light.$2, _light.$3 - 1.0);
  for (final f in faces) {
    final a = f[0];
    final b = f[1];
    final c = f[2];
    final ux = b.$1 - a.$1;
    final uy = b.$2 - a.$2;
    final uz = b.$3 - a.$3;
    final vx = c.$1 - a.$1;
    final vy = c.$2 - a.$2;
    final vz = c.$3 - a.$3;
    var n = _norm(
      uy * vz - uz * vy,
      uz * vx - ux * vz,
      ux * vy - uy * vx,
    );
    var cx = 0.0;
    var cy = 0.0;
    var cz = 0.0;
    for (final q in f) {
      cx += q.$1;
      cy += q.$2;
      cz += q.$3;
    }
    cx /= f.length;
    cy /= f.length;
    cz /= f.length;
    if (n.$1 * cx + n.$2 * cy + n.$3 * cz < 0.0) {
      n = (-n.$1, -n.$2, -n.$3);
    }
    if (n.$3 >= -0.02) continue;
    final lit = math.max(
      0.0,
      n.$1 * _light.$1 + n.$2 * _light.$2 + n.$3 * _light.$3,
    );
    final spec = math.max(
      0.0,
      n.$1 * halfVec.$1 + n.$2 * halfVec.$2 + n.$3 * halfVec.$3,
    );
    out.add(_CrystalFace(
      [for (final q in f) (q.$1, q.$2)],
      lit,
      spec,
      cx,
      cy,
    ));
  }
  return out;
}

List<(double, double)> _hullOf(List<(double, double)> pts) {
  final p = pts.toList()
    ..sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
  double cross((double, double) o, (double, double) a, (double, double) b) =>
      (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);
  final lo = <(double, double)>[];
  final hi = <(double, double)>[];
  for (final q in p) {
    while (lo.length >= 2 && cross(lo[lo.length - 2], lo.last, q) <= 0.0) {
      lo.removeLast();
    }
    lo.add(q);
  }
  for (final q in p.reversed) {
    while (hi.length >= 2 && cross(hi[hi.length - 2], hi.last, q) <= 0.0) {
      hi.removeLast();
    }
    hi.add(q);
  }
  return [
    ...lo.sublist(0, lo.length - 1),
    ...hi.sublist(0, hi.length - 1),
  ];
}

void _motes(
  Painter p,
  List<int> c,
  double t,
  Map<String, Object?> o,
  double yBase,
  bool front,
) {
  cycle(t, _duration, 16, o.seed, (g) => g.range(1.6, 2.6),
      (age, life, r, i) {
    final th = r.range(0, tau) + age * r.range(1.6, 2.6);
    final rad = r.range(14, 22);
    final y = yBase + r.range(-14, 12) - age * r.range(3, 7);
    final s = math.sin(th);
    final k = age / life;
    if ((s >= 0.0) != front) return;
    final x = math.cos(th) * rad;
    final yy = y + s * rad * 0.3;
    final a =
        math.min(1.0, age / 0.2) * (k > 0.75 ? (1.0 - k) / 0.25 : 1.0);
    if (front) {
      p.dot(x, yy, i % 4 == 0 ? kWhite : c[6], a);
      if (i % 4 == 0) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          p.dot(x + dx, yy + dy, c[5], a);
        }
      }
      p.glow(x, yy, 4, c[5], 0.3 * a);
    } else {
      p.dot(x, yy, c[4], a * 0.9);
    }
  });
}

final PureEffect iceCrystalEffect = PureEffect(
  meta: const EffectMeta(
    id: 'ice/ice-crystal',
    name: 'Ice crystal',
    desc:
        'A floating ice crystal turning slowly in its own cold light: its facets brighten and darken as they turn, glints flash on them, frost motes circle it.',
    category: 'ice',
    tags: ['ice', 'crystal', 'gem', 'pickup', 'float', 'magic', 'loop'],
    size: (96, 100),
    origin: (48, 92),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#151a3d', '#212f6b', '#2c58aa', '#3a8bd8',
        '#62c8f4', '#a6ecff', '#dcfbff', '#ffffff',
      ],
      'height': 34,
      'seed': 21,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _duration;
    final bob = math.sin(tau * ph) * 2.5;
    final yBase = -o.numOpt('height', 34.0) + bob;
    final s = 1.0 - bob / 12.0;
    final rx = 11.0 * s;
    for (var x = (-rx).floor(); x <= rx; x++) {
      final f = 1.0 - math.pow(x / rx, 2);
      p.blend(x + 0.5, 0, c[0], 0.65 * f);
      if (x.abs() < rx * 0.6) p.blend(x + 0.5, 1, c[0], 0.4 * f);
    }
    p.glow(0, -1, 24, c[4], 0.2 + 0.05 * math.sin(tau * ph * 2.0));
    _motes(p, c, t, o, yBase, false);
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _duration;
    final bob = math.sin(tau * ph) * 2.5;
    final yBase = -o.numOpt('height', 34.0) + bob;
    const rad = 8.0;
    p.glow(0, yBase, 34, c[3], 0.26);
    p.glow(0, yBase, 14, c[5], 0.18 + 0.08 * math.sin(tau * ph * 3.0));
    final faces = _crystalFaces((tau / 6.0) * ph, rad);
    final hull = _hullOf([for (final f in faces) ...f.pts]);
    var mx = 0.0;
    var my = 0.0;
    for (final (x, y) in hull) {
      mx += x;
      my += y;
    }
    mx /= hull.length;
    my /= hull.length;
    p.poly(
      [
        for (final (x, y) in hull)
          (() {
            final rawD = hypot(x - mx, y - my);
            final d = rawD == 0.0 ? 1.0 : rawD;
            return (
              x + ((x - mx) / d) * 1.2,
              y + yBase + ((y - my) / d) * 1.2,
            );
          })(),
      ],
      c[1],
    );
    for (final f in faces) {
      final col = f.spec > 0.985
          ? kWhite
          : c[clampInt(
              (1.0 + math.pow(f.lit, 1.4) * 6.6 + 0.5).floor(),
              1,
              7,
            )];
      p.poly([for (final (x, y) in f.pts) (x, y + yBase)], col);
    }
    for (final f in faces) {
      for (var i = 0; i < f.pts.length; i++) {
        final (x0, y0) = f.pts[i];
        final (x1, y1) = f.pts[(i + 1) % f.pts.length];
        p.line(
          x0,
          y0 + yBase,
          x1,
          y1 + yBase,
          f.lit > 0.6 ? c[7] : (f.lit > 0.3 ? c[6] : c[4]),
        );
      }
    }
    for (final f in faces) {
      if (f.spec > 0.96) {
        sparkle(
          p,
          f.cx,
          f.cy + yBase,
          (2.0 + (f.spec - 0.96) * 150.0 + 0.5).floorToDouble(),
          c[6],
          c[4],
          0.5,
        );
      }
    }
    final g = (ph * 2.0) % 1.0;
    if (g < 0.12) {
      sparkle(
        p,
        0,
        yBase - rad * 2.2 * math.cos(_tip),
        (5.0 * math.sin((g / 0.12) * math.pi) + 0.5).floorToDouble(),
        c[6],
        c[4],
        0.6,
      );
    }
    _motes(p, c, t, o, yBase, true);
  },
);
