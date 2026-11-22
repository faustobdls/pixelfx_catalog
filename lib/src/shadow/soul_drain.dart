import 'dart:math' as math;
import 'package:pixelfx_core/pixelfx_core.dart';
import 'shadow_lib.dart';

const double _vy = -50;
const double _d = 3.2;
const int _lines = 11;
const int _souls = 4;
const double _travel = 1.45;

double _wrapD(double x) => ((x % _d) + _d) % _d;

class _Streamline {
  const _Streamline(this.sx, this.sy, this.c1x, this.c1y, this.c2x, this.c2y);
  final double sx;
  final double sy;
  final double c1x;
  final double c1y;
  final double c2x;
  final double c2y;
}

final List<_Streamline> _ln = List.generate(_lines, (i) {
  final sx = 96 + rand(i, 1) * 64;
  final sy = -88 + rand(i, 2) * 72;
  final bend = (rand(i, 3) - 0.5) * 50;
  return _Streamline(
    sx,
    sy,
    sx * 0.55,
    sy + bend,
    22 + rand(i, 4) * 14,
    _vy + (sy - _vy) * 0.25,
  );
});

(double, double) _along(_Streamline L, double u) {
  final v = 1 - u;
  final a = v * v * v;
  final b = 3 * v * v * u;
  final c = 3 * v * u * u;
  final d = u * u * u;
  return (
    a * L.sx + b * L.c1x + c * L.c2x,
    a * L.sy + b * L.c1y + c * L.c2y + d * (_vy - L.sy) + d * L.sy,
  );
}

({double born, int line}) _soul(int j) => (
  born: (j + 0.15 + rand(j, 7) * 0.5) * (_d / _souls),
  line: (rand(j, 8) * _lines).floor(),
);

double _landings(double t) {
  double f = 0;
  for (int j = 0; j < _souls; j++) {
    final since = _wrapD(t - _soul(j).born - _travel);
    f += math.exp(-since / 0.14) * (since < 1 ? 1 : 0);
  }
  return math.min(1.4, f);
}

double _vessel(Painter p, List<int> C, double t, double f) {
  final y0 = _vy + math.sin((tau * t) / _d) * 1.5;
  const w = 9.0;
  const up = 14.0;
  const dn = 12.0;
  p.shade(-w - 1, y0 - up - 1, w + 1, y0 + dn + 1, (x, y, _) {
    final dy = y - y0;
    final half = dy < 0 ? w * (1 + dy / up) : w * (1 - dy / dn);
    if (half <= 0 || x.abs() > half + 0.6) return null;
    if (x.abs() > half - 0.4) return f > 0.5 ? C[6] : C[1];
    final ridge = (x + dy * 0.12).abs() < 0.6;
    final heart = x.abs() + (dy - 1).abs() < 2.6 + f * 1.5;
    if (heart) return f > 0.4 ? kWhite : C[6];
    if (ridge) return f > 0.3 ? C[7] : C[5];
    if (x < 0) return dy < 0 ? (f > 0.2 ? C[5] : C[4]) : C[3];
    return dy < 0 ? C[2] : C[1];
  });
  p.glow(0, y0, 30 + 14 * f, C[5], 0.5 + 0.5 * f);
  p.glow(0, y0 + 1, 8, kWhite, 0.25 + 0.6 * f);
  return y0;
}

void _drawBack(Painter p, double t, Map<String, Object?> o) {
  final C = fit(o.palette, 8);
  for (int i = 0; i < _lines; i++) {
    final L = _ln[i];
    final ph = _wrapD(t + i * 0.37) / _d;
    double? px;
    double? py;
    for (double u = 0; u <= 1.0001; u += 0.01) {
      final (x, y) = _along(L, u);
      final dash = (((u * 5 - ph * 10 + i * 0.3) % 1.0) + 1.0) % 1.0;
      if (px != null && py != null) {
        p.line(px, py, x, y, u > 0.6 ? C[3] : C[2], 0.4 + 0.6 * u);
      }
      if (dash < 0.18) {
        p.px(x, y, u > 0.7 ? C[7] : u > 0.35 ? C[6] : C[5]);
      }
      px = x;
      py = y;
    }
  }
  p.glow(10, _vy, 40, C[4], 0.22);
}

void _draw(Painter p, double t, Map<String, Object?> o) {
  final C = fit(o.palette, 8);
  final S = fit(
    o['soul'] is List
        ? o.rampOpt('soul')
        : const ['#2c3f66', '#7d9fd0', '#cfe6ff', '#ffffff'],
    4,
  );
  final f = _landings(t);
  final seed = o.seed;

  cycle(t, _d, 10, seed, (r) => r.range(0.8, 1.3), (age, lf, r, _) {
    final x = r.range(100, 150);
    final y = r.range(-80, -20) - age * 18;
    final u = age / lf;
    p.dot(x, y, S[2], (1 - u) * 0.8);
    p.glow(x, y, 4, S[1], 0.2 * (1 - u));
  });

  cycle(t, _d, 22, seed + 1, (r) => r.range(0.4, 0.7), (age, lf, r, _) {
    final L = _ln[(r.next() * _lines).floor()];
    final u0 = r.range(0.15, 0.5);
    final q = u0 + (1 - u0) * math.pow(age / lf, 2.2).toDouble();
    final q2 = u0 + (1 - u0) * math.pow(math.max(0.0, age - 0.06) / lf, 2.2).toDouble();
    final (x, y) = _along(L, q);
    final (tx, ty) = _along(L, q2);
    p.lineShaded(
      tx,
      ty,
      x,
      y,
      color: (v) => v > 0.7 ? kWhite : v > 0.35 ? C[6] : C[4],
    );
    p.glow(x, y, 4, C[6], 0.35);
  });

  final y0 = _vessel(p, C, t, f);

  for (int k = 0; k < 6; k++) {
    final a = (tau * (2 * t)) / _d + (k * tau) / 6;
    final ex = math.cos(a) * 15;
    final ey = math.sin(a) * 5 - 2;
    final z = math.sin(a);
    p.px(ex, y0 + ey, z > 0 ? C[7] : C[4]);
    if (z > 0) p.glow(ex, y0 + ey, 4, C[6], 0.35);
  }

  for (int j = 0; j < _souls; j++) {
    final s = _soul(j);
    final age = _wrapD(t - s.born);
    if (age > _travel) continue;
    final L = _ln[s.line];
    final u = math.pow(age / _travel, 1.8).toDouble();
    final (x, y) = _along(L, u);
    if (age < 0.18) {
      final k = 1 - age / 0.18;
      ringFast(p, L.sx, L.sy, 3 + 9 * (1 - k), 1, k > 0.5 ? S[2] : S[1]);
      p.glow(L.sx, L.sy, 12, S[1], 0.5 * k);
    }
    for (int k = 14; k >= 1; k--) {
      final uu = math.pow(math.max(0.0, age - k * 0.03) / _travel, 1.8).toDouble();
      final (tx, ty) = _along(L, uu);
      final w = math.sin(t * 12 + k * 0.8 + j) * k * 0.16;
      final r = math.max(0.5, 2.6 - k * 0.17);
      p.disc(
        tx,
        ty + w,
        r,
        k < 4 ? S[2] : k < 9 ? S[1] : C[5],
        0.75 * (1 - k / 15),
      );
    }
    final near = smooth(0.82, 1, u);
    final hr = 3.4 - near * 1.6;
    p.circle(x, y, hr + 0.8, S[1]);
    p.circle(x, y, hr, S[2]);
    p.px(x - 1, y - 2, S[3]);
    p.px(x - 2, y - 1, S[3]);
    if (near < 0.5) {
      p.px(x - 1.5, y, S[0]);
      p.px(x + 1.5, y, S[0]);
      p.px(x, y + 1.6, S[0]);
      p.px(x, y + 2.4, S[0]);
    }
    p.glow(x, y, 10, S[1], 0.5);
  }

  for (int j = 0; j < _souls; j++) {
    final since = _wrapD(t - _soul(j).born - _travel);
    if (since < 0.3) {
      final k = since / 0.3;
      ringFast(
        p,
        0,
        y0,
        6 + 18 * Ease.outCubic(k),
        math.max(1.0, 2 * (1 - k)),
        k < 0.4 ? C[7] : k < 0.7 ? C[5] : C[3],
      );
    }
  }
  halo(p, 0, y0, 4, 22, C[6], 0.25 * f);
}

final PixelEffect soulDrainEffect = PureEffect(
  meta: const EffectMeta(
    id: 'shadow/soul-drain',
    name: 'Soul drain',
    desc:
        'Pale souls are torn loose on the right and dragged down a funnel of streaks into a black crystal vessel, which flares violet as each one lands.',
    category: 'shadow',
    kind: AssetKind.effect,
    tags: [
      'shadow',
      'soul',
      'drain',
      'necromancy',
      'funnel',
      'directional',
      'magic',
      'loop',
    ],
    size: (208, 120),
    origin: (40, 110),
    duration: 3.2,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': kVoidPalette,
      'soul': ['#2c3f66', '#7d9fd0', '#cfe6ff', '#ffffff'],
      'seed': 8,
    },
  ),
  onDrawBack: _drawBack,
  onDraw: _draw,
);
