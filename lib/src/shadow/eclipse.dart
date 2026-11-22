import 'dart:math' as math;
import 'package:pixelfx_core/pixelfx_core.dart';
import 'shadow_lib.dart';

const double _r = 19;
const double _d = 4;
const double _bead = -0.72;

double _breathe(double t, num k, double ph) =>
    math.sin((tau * k * t) / _d + ph);

class _Stream {
  const _Stream(this.a, this.len, this.curl, this.k, this.ph, this.w);
  final double a;
  final double len;
  final double curl;
  final int k;
  final double ph;
  final double w;
}

final List<_Stream> _streams = List.generate(30, (i) {
  final side = i % 2 != 0 ? 0.0 : math.pi;
  final spread = (rand(i, 1) - 0.5) * (rand(i, 2) < 0.7 ? 1.3 : 3.1);
  final a = side + spread;
  final eq = math.cos(a).abs();
  return _Stream(
    a,
    (10 + rand(i, 3) * 28) * (0.45 + 0.75 * eq),
    (rand(i, 4) - 0.5) * 0.00018,
    1 + (i % 3),
    rand(i, 5) * tau,
    rand(i, 6),
  );
});

void _drawBack(Painter p, double t, Map<String, Object?> o) {
  final C = fit(o.palette, 8);
  final Q = fit(
    o['pearl'] is List
        ? o.rampOpt('pearl')
        : const ['#5a4f8a', '#a99be0', '#e6defa', '#fffaf2'],
    4,
  );
  final S = o.seed;

  cycle(t, _d, 26, S, (r) => r.range(1.2, 2.6), (age, L, r, _) {
    final x = r.range(-78, 78);
    final y = r.range(-70, 70);
    if (hypot(x, y) < _r + 22) return;
    final k = math.sin((math.pi * age) / L);
    p.dot(x, y, k > 0.7 ? kWhite : Q[1], k * 1.2);
    if (k > 0.85 && r.next() < 0.4) {
      p.dot(x - 1, y, Q[0], 0.8);
      p.dot(x + 1, y, Q[0], 0.8);
    }
  });

  final b = 1 + 0.08 * _breathe(t, 1, 0);
  p.glow(0, 0, 72 * b, C[4], 0.38);
  p.glow(0, 0, 46 * b, Q[1], 0.34);

  for (final s in _streams) {
    final L = s.len * (1 + 0.18 * _breathe(t, s.k, s.ph));
    for (double d = 4; d <= L; d += 0.5) {
      final u = d / L;
      final a = s.a + s.curl * d * d;
      final r = _r + 1 + d;
      final x = math.cos(a) * r;
      final y = math.sin(a) * r;
      p.dot(
        x,
        y,
        u < 0.3 ? Q[2] : u < 0.65 ? Q[1] : C[5],
        u < 0.75 ? 1.0 : (1 - u) * 4,
      );
    }
    p.glowLine(
      math.cos(s.a) * (_r + 4),
      math.sin(s.a) * (_r + 4),
      math.cos(s.a) * (_r + L * 0.6),
      math.sin(s.a) * (_r + L * 0.6),
      3,
      Q[1],
      0.12,
    );
  }
}

void _draw(Painter p, double t, Map<String, Object?> o) {
  final C = fit(o.palette, 8);
  final Q = fit(
    o['pearl'] is List
        ? o.rampOpt('pearl')
        : const ['#5a4f8a', '#a99be0', '#e6defa', '#fffaf2'],
    4,
  );
  final b = 1 + 0.08 * _breathe(t, 1, 0);

  const w = _r + 10;
  p.shade(-w, -w, w, w, (x, y, out) {
    final r = math.sqrt(x * x + y * y);
    if (r < _r - 0.5 || r > _r + 9 * b) return null;
    final a = math.atan2(y, x);
    final e = (r - _r) / (9 * b);
    final streak =
        0.55 +
        0.3 * math.cos(a * 23 + math.sin(a * 5) * 2) +
        0.15 * math.cos(a * 41 - (tau * t) / _d);
    final intensity =
        math.pow(1 - e, 2.2) * streak * (0.75 + 0.4 * math.cos(a).abs());
    if (r < _r + 0.9) return Q[3];
    if (intensity < 0.1) return null;
    if (intensity > 0.45 && ((x.floor() + y.floor()) & 1) == 0) {
      out.k = 0.2 * intensity;
    }
    return intensity > 0.72
        ? Q[2]
        : intensity > 0.42
            ? Q[1]
            : intensity > 0.22
                ? C[5]
                : C[4];
  });

  p.shade(-_r, -_r, _r, _r, (x, y, _) {
    final r = math.sqrt(x * x + y * y);
    if (r >= _r - 0.5) return null;
    return r > _r - 2.2 && x < -_r * 0.45 ? C[1] : C[0];
  });

  final bx = math.cos(_bead) * (_r + 0.4);
  final by = math.sin(_bead) * (_r + 0.4);
  final k = 0.75 + 0.25 * _breathe(t, 2, 1);
  for (int i = 0; i < 8; i++) {
    final a = (i * math.pi) / 4 + 0.12;
    final len = (i % 2 != 0 ? 7.0 : 22.0) * k * (i == 1 || i == 5 ? 1.6 : 1.0);
    for (double d = 1; d <= len; d += 0.5) {
      final u = d / len;
      final x = bx + math.cos(a) * d;
      final y = by + math.sin(a) * d;
      if (x * x + y * y < (_r - 0.5) * (_r - 0.5)) break;
      p.dot(
        x,
        y,
        u < 0.35 ? kWhite : u < 0.7 ? Q[2] : Q[1],
        u < 0.5 ? 1.0 : (1 - u) * 2.2,
      );
    }
  }
  p.circle(bx, by, 3 * k, Q[2]);
  p.circle(bx, by, 2.2 * k, Q[3]);
  p.circle(bx, by, 1.4, kWhite);
  p.glow(bx, by, 46 * k, Q[2], 0.8 * k);
  p.glow(bx, by, 14, kWhite, 0.8);
  halo(p, 0, 0, _r - 0.5, _r + 16, Q[2], 0.35 * b);
  unlight(p, -_r, -_r, _r, _r, (x, y) => x * x + y * y < (_r - 0.6) * (_r - 0.6));
}

final PixelEffect eclipseEffect = PureEffect(
  meta: const EffectMeta(
    id: 'shadow/eclipse',
    name: 'Eclipse',
    desc:
        'A black moon over the sun: a breathing pearl corona with long streamers, a thin white rim, and one diamond bead blazing on its edge.',
    category: 'shadow',
    kind: AssetKind.effect,
    tags: [
      'shadow',
      'eclipse',
      'moon',
      'sun',
      'corona',
      'sky',
      'magic',
      'loop',
    ],
    size: (160, 144),
    origin: (80, 72),
    duration: 4,
    loop: true,
    fps: 30,
    bg: BackdropKind.sky,
    defaultOptions: {
      'palette': kVoidPalette,
      'pearl': ['#5a4f8a', '#a99be0', '#e6defa', '#fffaf2'],
      'seed': 3,
    },
  ),
  onDrawBack: _drawBack,
  onDraw: _draw,
);
