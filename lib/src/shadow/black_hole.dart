import 'dart:math' as math;
import 'package:pixelfx_core/pixelfx_core.dart';
import 'shadow_lib.dart';

const double _y = -70;
const double _rs = 13.5;
const double _e = 17.5;
const double _si = 0.25;
const double _siArch = 0.46;
const double _tilt = -0.14;
const double _d = 4;
final double _ct = math.cos(_tilt);
final double _st = math.sin(_tilt);

class _Band {
  const _Band(this.r0, this.r1, this.n, this.hot, this.k);
  final double r0;
  final double r1;
  final int n;
  final double hot;
  final double k;
}

const List<_Band> _bands = [
  _Band(18, 24, 5, 1.35, 0.3),
  _Band(26, 34, 3, 0.92, 1.9),
  _Band(35.5, 46, 2, 0.64, 3.7),
  _Band(47.5, 60, 1, 0.42, 5.2),
];
const double _rout = 60;
const List<double> _bayer = [
  0.5 / 16,
  8.5 / 16,
  2.5 / 16,
  10.5 / 16,
  12.5 / 16,
  4.5 / 16,
  14.5 / 16,
  6.5 / 16,
  3.5 / 16,
  11.5 / 16,
  1.5 / 16,
  9.5 / 16,
  15.5 / 16,
  7.5 / 16,
  13.5 / 16,
  5.5 / 16,
];
final int _ice = hex('#e4f7ff');

class _DiskSample {
  const _DiskSample(this.intensity, this.dop);
  final double intensity;
  final double dop;
}

_DiskSample? _disk(double X, double Z, double t) {
  final rho = math.sqrt(X * X + Z * Z);
  for (final b in _bands) {
    if (rho < b.r0 || rho > b.r1) continue;
    final w = (rho - b.r0) / (b.r1 - b.r0);
    final ph = math.atan2(Z, X) - (tau * b.n * t) / _d;
    final streak =
        0.62 +
        0.22 * math.cos(7 * ph + rho * 0.8 + b.k) +
        0.16 * math.cos(13 * ph - rho * 1.6 + b.k * 2);
    final lane = 0.72 + 0.28 * math.cos(rho * 2.3 + b.k);
    final edge = smooth(0, 0.18, w) * (1 - smooth(0.78, 1, w));
    return _DiskSample(b.hot * streak * lane * (0.35 + 0.65 * edge), -X / rho);
  }
  return null;
}

void _hole(Painter p, List<int> C, double t, double pulse) {
  final rampColors = [C[1], C[2], C[3], C[4], C[5], C[6], C[7], kWhite];
  final n = rampColors.length;
  const w = _rout + 2;
  const h = 42.0;
  p.shade(-w, _y - h, w, _y + h, (x, y, out) {
    final dx = x;
    final dy = y - _y;
    final u = dx * _ct + dy * _st;
    final v = -dx * _st + dy * _ct;
    final r = math.sqrt(u * u + v * v);
    _DiskSample? s;
    if (v > 0) s = _disk(u, -v / _si, t);
    if (s == null && r > _rs) {
      final k = 1 - (_e * _e) / (r * r);
      final bu = u * k;
      final bv = v * k;
      final si = k > 0 ? _siArch : _si;
      if (-bv / si > 0) s = _disk(bu, -bv / si, t);
    }
    if (s == null || s.intensity < 0.06) {
      if (r < _rs - 0.4) return C[0];
      if (r < _rs + 0.7) {
        final a = math.atan2(v, u);
        final f = 0.5 + 0.5 * math.cos(3 * a + (tau * 2 * t) / _d) + pulse * 0.4;
        out.k = 0.3;
        return f > 0.55 ? kWhite : C[7];
      }
      return null;
    }
    final intensity = s.intensity * 1.3 * (1 + 0.55 * s.dop) * (1 + 0.25 * pulse);
    final f = clamp(intensity) * (n - 1);
    int i = f.floor();
    if (f - i > _bayer[((y.floor() & 3) << 2) | (x.floor() & 3)]) {
      i = math.min(n - 1, i + 1);
    }
    if (i == 0 && intensity < 0.12) return null;
    int c = rampColors[i];
    if (s.dop > 0.35 && i >= n - 3) {
      c = mix(c, _ice, math.min(1.0, (s.dop - 0.35) * 2));
    }
    if (s.dop < -0.4 && i >= 2 && i < n - 2) {
      c = mix(c, C[3], 0.35);
    }
    if (i >= n - 4 && ((x.floor() + y.floor()) & 1) == 0) {
      out.k = 0.3 * math.min(1.0, intensity - 0.35);
    }
    return c;
  });
}

void _drawBack(Painter p, double t, Map<String, Object?> o) {
  final C = fit(o.palette, 8);
  p.glow(0, -1, 44, C[4], 0.12);
  p.glow(0, _y, 80, C[4], 0.32);
  p.glow(0, _y, 46, mix(C[6], C[5], 0.5), 0.45);
}

void _draw(Painter p, double t, Map<String, Object?> o) {
  final C = fit(o.palette, 8);
  final K = fit(
    o['rock'] is List
        ? o.rampOpt('rock')
        : const ['#120d1c', '#2e2440', '#544468', '#857399'],
    4,
  );
  final S = o.seed;
  final pulse = math.pow(math.max(0.0, math.cos((tau * 2 * t) / _d)), 12).toDouble();

  cycle(t, _d, 10, S + 3, (r) => r.range(1.6, 2.6), (age, L, r, _) {
    final x0 = r.range(-60, 60);
    final u = math.pow(age / L, 1.5).toDouble();
    final signX0 = x0 == 0 ? 1.0 : (x0 > 0 ? 1.0 : -1.0);
    final tx = signX0 * r.range(40, 56);
    final ty = _y + r.range(4, 9);
    final x = x0 + (tx - x0) * u;
    final y = -1 + (ty + 1) * u - math.sin(math.pi * u) * 10;
    p.px(x, y, u > 0.6 ? K[3] : K[2]);
    if (age < 0.25) {
      p.disc(x0, -1.5, 2 + age * 8, K[2], 0.4 * (1 - age / 0.25));
    }
  });

  _hole(p, C, t, pulse);

  cycle(t, _d, 40, S + 7, (r) => r.range(0.5, 0.9), (age, L, r, _) {
    final a0 = r.range(0, tau);
    final d0 = r.range(48, 76);
    final q = math.pow(age / L, 1.6).toDouble();
    final d = _rs + 2 + (d0 - _rs - 2) * (1 - q);
    final a = a0 + 0.9 * q;
    final x = math.cos(a) * d * 1.15;
    final y = _y + math.sin(a) * d * 0.75;
    final q2 = math.pow(math.max(0.0, age - 0.09) / L, 1.6).toDouble();
    final d2 = _rs + 2 + (d0 - _rs - 2) * (1 - q2);
    final a2 = a0 + 0.9 * q2;
    if (d < _rs + 3 ||
        y > -3 ||
        y < -120 ||
        _y + math.sin(a2) * d2 * 0.75 < -120 ||
        x.abs() > 90) {
      return;
    }
    final col = r.pick([kWhite, C[7], C[6], C[5]]);
    p.lineShaded(
      math.cos(a2) * d2 * 1.15,
      _y + math.sin(a2) * d2 * 0.75,
      x,
      y,
      color: (u) => u > 0.6 ? col : C[4],
      alpha: (_) => math.min(1.0, age * 6),
    );
    p.glow(x, y, 3, col, 0.3);
  });

  cycle(t, _d, 22, S, (r) => r.range(1.4, 2.4), (age, L, r, _) {
    final ph0 = r.range(0, tau);
    final rho0 = r.range(58, 80);
    final hgt = r.range(-8, 8);
    final size = r.range(1.6, 2.8);
    ({double x, double y, double Z, double rho}) atPos(double aa) {
      final q = clamp(aa / L);
      final rho = _rs + 1 + (rho0 - _rs - 1) * (1 - math.pow(q, 1.5).toDouble());
      final ph = ph0 + 2.4 * math.pow(q, 1.6).toDouble() * (1 + 1.5 * q);
      final X = math.cos(ph) * rho;
      final Z = math.sin(ph) * rho;
      final sx = X;
      final sy = -Z * _si + hgt * (1 - q);
      return (
        x: sx * _ct - sy * _st,
        y: _y + sx * _st + sy * _ct,
        Z: Z,
        rho: rho,
      );
    }

    final a = atPos(age);
    final b = atPos(age - 0.04);
    final hidden = a.Z > 0 && hypot(a.x, a.y - _y) < _rs + 1;
    if (hidden) return;
    if (a.rho < _rs + 3) {
      p.px(a.x, a.y, kWhite);
      p.glow(a.x, a.y, 6, C[6], 0.6);
      return;
    }
    final heat = 1 - smooth(16, 34, a.rho);
    final len = 1 + heat * 7;
    if (heat > 0.05) {
      final dx = a.x - b.x;
      final dy = a.y - b.y;
      final lRaw = hypot(dx, dy);
      final l = lRaw > 0 ? lRaw : 1.0;
      p.lineShaded(
        a.x - (dx / l) * len,
        a.y - (dy / l) * len,
        a.x,
        a.y,
        color: (u) => u > 0.7 ? kWhite : u > 0.35 ? C[6] : C[4],
      );
      p.glow(a.x, a.y, 4, C[6], 0.4 * heat);
    } else {
      final distA = hypot(a.x, a.y - _y);
      final denom = distA > 0 ? distA : 1.0;
      final lx = -a.x / denom;
      final ly = -(a.y - _y) / denom;
      final c = atPos(age - 0.09);
      final d = atPos(age - 0.15);
      p.px(b.x, b.y, C[3]);
      p.dot(c.x, c.y, C[3], 0.7);
      p.dot(d.x, d.y, C[2], 0.5);
      final s2 = size > 2.2;
      p.px(a.x, a.y, K[2]);
      p.px(a.x + 1, a.y, K[1]);
      p.px(a.x, a.y + 1, K[1]);
      if (s2) {
        p.px(a.x + 1, a.y + 1, K[0]);
        p.px(a.x - 1, a.y, K[1]);
        p.px(a.x, a.y - 1, K[2]);
      }
      p.px(
        a.x + (lx * 1.4 + 0.5).floor(),
        a.y + (ly * 1.4 + 0.5).floor(),
        s2 ? C[6] : C[5],
      );
      p.glow(a.x, a.y, 4, C[5], 0.15);
    }
  });

  halo(p, 0, _y, _rs - 0.4, _rs + 4, C[6], 0.35 + 0.3 * pulse);
  unlight(p, -_rs, _y - _rs, _rs, _y + _rs, (x, y) {
    final dx = x;
    final dy = y - _y;
    final v = -dx * _st + dy * _ct;
    final u = dx * _ct + dy * _st;
    return u * u + v * v < (_rs - 0.6) * (_rs - 0.6) &&
        !(v > 0 && _disk(u, -v / _si, t) != null);
  });
}

final PixelEffect blackHoleEffect = PureEffect(
  meta: const EffectMeta(
    id: 'shadow/black-hole',
    name: 'Black hole',
    desc:
        'A tilted disk of banded rings turns round a black hole, its far side bent up over the top and under the bottom; debris spirals in, stretches and is swallowed.',
    category: 'shadow',
    kind: AssetKind.effect,
    tags: [
      'shadow',
      'black-hole',
      'void',
      'space',
      'gravity',
      'dark',
      'magic',
      'loop',
    ],
    size: (184, 132),
    origin: (92, 124),
    duration: 4,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': kVoidPalette,
      'rock': ['#120d1c', '#2e2440', '#544468', '#857399'],
      'seed': 4,
    },
  ),
  onDrawBack: _drawBack,
  onDraw: _draw,
);
