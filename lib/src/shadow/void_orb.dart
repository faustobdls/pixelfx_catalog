import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pixelfx_core/pixelfx_core.dart';
import 'shadow_lib.dart';

const double _y = -62;
const double _r = 12;
const int _vr = 48;
const double _gap = _r + 9;
const double _e = _r + 4.5;
const double _d = 3.2;
const int _arms = 3;
const double _k = 7;
const double _wind = (tau * 2) / _d;

const List<double> _gulps = [0.2, 0.68];

double _wrap1(double x) => x - x.floor();

double _gulp(double t) {
  double s = 0;
  for (final g in _gulps) {
    final v = ((_wrap1(t / _d - g + 0.5) - 0.5) * _d) / 0.07;
    s += math.exp(-(v * v));
  }
  return s;
}

class _Source {
  const _Source(this.cx, this.cy, this.rho, this.n, this.ph, this.s, this.sy);
  final double cx;
  final double cy;
  final double rho;
  final int n;
  final double ph;
  final double s;
  final double sy;
}

const List<_Source> _sources = [
  _Source(0, 0, 6, 1, 0, 2.6, 0.75),
  _Source(1, -1, 8, -1, 2.2, 2, 0.6),
  _Source(18, -6, 24, 1, 0.4, 2.4, 0.7),
  _Source(-26, 10, 30, 1, 2.6, 2, 0.55),
  _Source(8, 22, 20, 2, 4.1, 1.6, 0.8),
  _Source(-12, -26, 34, 1, 5.3, 1.8, 0.6),
  _Source(34, 18, 16, 2, 1.2, 1.4, 0.9),
];

class _VortexTables {
  _VortexTables(this.n, this.r, this.th, this.ln, this.nz);
  final int n;
  final Float32List r;
  final Float32List th;
  final Float32List ln;
  final Float32List nz;
}

_VortexTables? _tab;

_VortexTables _tables() {
  final cached = _tab;
  if (cached != null) return cached;
  const n = _vr * 2;
  const total = n * n;
  final r = Float32List(total);
  final th = Float32List(total);
  final ln = Float32List(total);
  final nz = Float32List(total);
  for (int j = 0; j < n; j++) {
    for (int i = 0; i < n; i++) {
      final x = i - _vr + 0.5;
      final y = j - _vr + 0.5;
      final k = j * n + i;
      final a = math.atan2(y, x);
      final d = hypot(x, y);
      final l = math.log(math.max(1.0, d));
      r[k] = d;
      th[k] = a;
      ln[k] = l;
      nz[k] = fbm(math.cos(a) * 2.5 + l * 2.4, math.sin(a) * 2.5 + l * 2.4, 17, 3);
    }
  }
  return _tab = _VortexTables(n, r, th, ln, nz);
}

void _vortex(Painter p, List<int> C, double t, double g) {
  final T = _tables();
  final n = T.n;
  const wf = (tau * 12) / _d;
  for (int j = 0; j < n; j++) {
    for (int i = 0; i < n; i++) {
      final k = j * n + i;
      final r = T.r[k];
      if (r < _gap || r > _vr) continue;
      final env = smooth(_vr.toDouble(), _vr * 0.42, r) * smooth(_gap, _gap + 4, r);
      final ph = _arms * T.th[k] + _k * T.ln[k] + _wind * t + T.nz[k] * 2.6;
      final cs = math.cos(ph);
      final A = (0.5 + 0.5 * cs) * env * (1 + 0.4 * g);
      if (A < 0.16) continue;
      final x = i - _vr + 0.5;
      final y = _y + j - _vr + 0.5;
      final hot = 1 - smooth(_gap, _gap + 16, r);
      final fil = math.cos(12 * T.th[k] + 28 * T.ln[k] + wf * t + T.nz[k] * 1.6);
      final dash = math.cos(9 * T.ln[k] * 2.2 + 2.2 * T.th[k] + wf * 0.75 * t);
      if (fil > 0.86 && A > 0.3 && dash > -0.55) {
        final c = hot > 0.6
            ? C[7]
            : (hot > 0.25 || fil > 0.97) && dash > 0
                ? C[6]
                : C[5];
        p.px(x, y, c);
        p.light(x, y, c, 0.1 + 0.2 * hot);
        continue;
      }
      if (A > 0.36 && A < 0.46 && math.sin(ph) > 0) {
        p.px(x, y, hot > 0.4 ? C[6] : C[4]);
        continue;
      }
      p.blend(x, y, A > 0.6 ? C[3] : C[2], math.min(0.75, (A - 0.16) * 1.4));
    }
  }
}

void _lensing(Painter p, List<int> C, double t, double g) {
  const st = 0.7 / _e;
  for (double a = 0; a < tau; a += st) {
    final f = 0.5 + 0.5 * math.cos(5 * a - (tau * 2 * t) / _d) + 0.5 * g;
    p.px(
      math.cos(a) * _e,
      _y + math.sin(a) * _e,
      f > 0.85 ? C[5] : f > 0.45 ? C[4] : C[3],
    );
  }
  for (final s in _sources) {
    final q = (tau * s.n * t) / _d + s.ph;
    final sx = s.cx + s.rho * math.cos(q);
    final sy = s.cy + s.rho * math.sin(q) * s.sy;
    final b = math.max(0.3, hypot(sx, sy));
    final al = math.atan2(sy, sx);
    final root = math.sqrt(b * b + 4 * _e * _e);
    final images = [
      ((b + root) / 2, al, 1.0),
      ((root - b) / 2, al + math.pi, 0.55),
    ];
    for (final (r, a0, w) in images) {
      if (r < _r + 1.5) continue;
      final mag = (r / b) * w;
      final hw = math.min(math.pi, (s.s * 1.6) / (2 * b));
      final step = 0.6 / r;
      for (double a = a0 - hw; a <= a0 + hw + 1e-6; a += step) {
        final u = hw > 0 ? (a - a0).abs() / hw : 0.0;
        final x = math.cos(a) * r;
        final y = _y + math.sin(a) * r;
        p.dot(
          x,
          y,
          u < 0.3 && mag > 0.8 ? kWhite : u < 0.65 ? C[7] : C[5],
          math.min(1.0, mag * 1.4) * (1.15 - u),
        );
        if (mag > 1.2 && u < 0.6) {
          p.dot(x + math.cos(a), y + math.sin(a), C[6], 0.8);
        }
      }
      p.glow(
        math.cos(a0) * r,
        _y + math.sin(a0) * r,
        4 + math.min(10.0, hw * r),
        C[6],
        math.min(0.5, 0.18 * mag),
      );
    }
  }
}

void _orb(Painter p, List<int> C, double t, double g) {
  p.shade(-_r - 1, _y - _r - 1, _r + 1, _y + _r + 1, (x, y, _) {
    final dx = x;
    final dy = y - _y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d > _r + 0.5) return null;
    final a = math.atan2(dy, dx);
    if (d > _r - 0.6) {
      final f =
          0.5 * math.cos(3 * a - (tau * 2 * t) / _d) +
          0.3 * math.cos(7 * a + (tau * 3 * t) / _d + 1) +
          0.25 * math.cos(13 * a - (tau * 5 * t) / _d + 2) +
          g;
      return f > 0.5 ? kWhite : f > 0.05 ? C[6] : f > -0.4 ? C[5] : C[4];
    }
    if (_r - d < 1.4 && math.cos(a - 0.8) > 0.6) return C[2];
    final gx = dx + _r * 0.42;
    final gy = dy + _r * 0.45;
    if (gx * gx + gy * gy < 1.6) return C[3];
    return C[0];
  });
}

void _drawBack(Painter p, double t, Map<String, Object?> o) {
  final C = fit(o.palette, 8);
  final g = _gulp(t);
  p.glow(0, -1, 52, C[4], 0.22 + 0.1 * g);
  _vortex(p, C, t, g);
  _lensing(p, C, t, g);
}

void _draw(Painter p, double t, Map<String, Object?> o) {
  final C = fit(o.palette, 8);
  final g = _gulp(t);
  final S = o.seed;

  cycle(t, _d, 14, S + 2, (r) => r.range(1.6, 2.4), (age, L, r, _) {
    final x0 = r.range(-44, 44);
    final u = math.pow(age / L, 1.7).toDouble();
    final side = x0 == 0 ? 1.0 : (x0 > 0 ? 1.0 : -1.0);
    final ea = math.pi / 2 + side * r.range(0.3, 1);
    final ex = math.cos(ea) * _r;
    final ey = _y + math.sin(ea) * _r;
    final mx = x0 * 0.2;
    final my = -18 - r.range(0, 12);
    final x = (1 - u) * (1 - u) * x0 + 2 * (1 - u) * u * mx + u * u * ex;
    final y = (1 - u) * (1 - u) * -1 + 2 * (1 - u) * u * my + u * u * ey;
    if (age < 0.5) p.disc(x0, -1.5, 2 + age * 6, C[3], 0.4 * (1 - age / 0.5));
    p.dot(x, y, u > 0.6 ? C[7] : u > 0.25 ? C[6] : C[5], math.min(1.0, age * 4));
    if (u > 0.3) p.glow(x, y, 3, C[5], 0.25);
  });

  cycle(t, _d, 30, S, (r) => r.range(1.1, 1.8), (age, L, r, _) {
    double th0 = r.range(0, tau);
    if (math.sin(th0) > 0.75) th0 = -th0;
    final r0 = r.range(30, 64);
    final sw = r.range(1.4, 2.6);
    final col = r.pick([kWhite, C[7], C[6], C[6], C[5]]);
    (double, double, double) pos(double aa) {
      final u = clamp(aa / L);
      final k = math.pow(u, 1.8).toDouble();
      final rr = _r + 1 + (r0 - _r - 1) * (1 - k);
      final th = th0 - sw * (k + 0.5 * u);
      return (math.cos(th) * rr, _y + math.sin(th) * rr, rr);
    }

    final (x, y, rr) = pos(age);
    final (tx, ty, _) = pos(age - 0.05);
    final a = math.min(1.0, age * 5);
    if (rr < _r + 3) {
      p.px(x, y, kWhite);
      p.glow(x, y, 5, C[6], 0.5);
      return;
    }
    p.line(tx, ty, (tx + x) / 2, (ty + y) / 2, C[4], a * 0.8);
    p.line((tx + x) / 2, (ty + y) / 2, x, y, col, a);
    p.glow(x, y, 3, col, 0.3 * a);
  });

  cycleFixed(t, _d, 9, S + 1, 0.42, (age, L, r, _) {
    double th = r.range(0, tau);
    if (math.sin(th) > 0.45) th = -th;
    final r0 = r.range(56, 74);
    final u = age / L;
    final k = (math.exp(3 * u) - 1) / (math.exp(3) - 1);
    final rr = r0 - (r0 - _r - 1) * k;
    final len = 2 + 10 * k;
    final ca = math.cos(th);
    final sa = math.sin(th);
    for (double d = 0; d <= len; d += 0.5) {
      p.dot(
        ca * (rr + d),
        _y + sa * (rr + d),
        d < 1 ? kWhite : d < len * 0.5 ? C[6] : C[4],
        d < len * 0.5 ? 1.0 : 1.2 - d / len,
      );
    }
    p.glow(ca * rr, _y + sa * rr, 4, C[6], 0.4);
  });

  for (final gp in _gulps) {
    final u = _wrap1(t / _d - gp) / (0.4 / _d);
    if (u >= 1) continue;
    final rr = _r + 2 + (_vr - _r) * (1 - Ease.inQuad(u));
    ringFast(p, 0, _y, rr, 1, C[4], 0.35 * (1 - u));
    ringLight(p, 0, _y, rr, 4, C[5], 0.3 * (1 - u));
  }

  _orb(p, C, t, g);
  halo(p, 0, _y, _r - 0.5, _r + 7, C[6], 0.6 + 0.3 * g);
  halo(p, 0, _y, _r - 0.5, _r + 46, C[4], 0.38 + 0.15 * g);
  unlight(
    p,
    -_r,
    _y - _r,
    _r,
    _y + _r,
    (x, y) => x * x + (y - _y) * (y - _y) < (_r - 0.6) * (_r - 0.6),
  );
}

final PixelEffect voidOrbEffect = PureEffect(
  meta: const EffectMeta(
    id: 'shadow/void-orb',
    name: 'Void orb',
    desc:
        'A black orb hangs in the air, a pale rim crawling round it; a dark vortex winds into it, motes and streaks are pulled in, and light bends round its edge.',
    category: 'shadow',
    kind: AssetKind.effect,
    tags: ['shadow', 'void', 'orb', 'vortex', 'dark', 'magic', 'loop'],
    size: (168, 160),
    origin: (84, 150),
    duration: 3.2,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': kVoidPalette, 'seed': 5},
  ),
  onDrawBack: _drawBack,
  onDraw: _draw,
);
