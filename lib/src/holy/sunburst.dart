import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'holy_lib.dart';

const double _dur = 4.0;
const double _core = 4.5;
const double _ring = 7.5;
const double _r0 = 9.0;

// One tapered ray from radius _r0 out to _r0 + l at angle a.
void _ray(Painter p, List<int> c, double a, double l, double w0, double k) {
  final ca = math.cos(a);
  final sa = math.sin(a);
  final x1 = ca * (_r0 + l);
  final y1 = sa * (_r0 + l);
  final pad = w0 + 1.0;
  p.shade(
    math.min(0.0, x1) - pad,
    math.min(0.0, y1) - pad,
    math.max(0.0, x1) + pad,
    math.max(0.0, y1) + pad,
    (x, y, out) {
      final along = x * ca + y * sa - _r0;
      final u = along / l;
      if (u < 0.0 || u > 1.0) return null;
      final across = (-x * sa + y * ca).abs();
      final w = (w0 / 2.0) * (1.0 - u * 0.85) + 0.25;
      if (across > w) return null;
      final spine = across < 0.5;
      final rim = across > w - 0.6 && w > 0.9;
      out.c = spine
          ? (u < 0.4 ? kWhite : (u < 0.75 ? c[6] : c[5]))
          : (rim && u > 0.15
              ? c[3]
              : (u < 0.3 ? c[6] : (u < 0.62 ? c[5] : c[4])));
      out.a = u < 0.72 ? k : k * (1.0 - (u - 0.72) / 0.28) * 1.2;
      return null;
    },
  );
  p.glowLine(
    ca * _r0,
    sa * _r0,
    ca * (_r0 + l * 0.8),
    sa * (_r0 + l * 0.8),
    5,
    c[5],
    0.16 * k,
  );
}

final PureEffect sunburstEffect = PureEffect(
  meta: const EffectMeta(
    id: 'holy/sunburst',
    name: 'Sunburst',
    desc:
        'A white-hot core in a gold corona; long and short rays turn slowly round it, breathing, with glints running out along them that wink at the tips.',
    category: 'holy',
    tags: ['holy', 'sun', 'radiant', 'rays', 'light', 'glow', 'loop'],
    size: (128, 128),
    origin: (64, 64),
    duration: _dur,
    loop: true,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {'palette': kHolyGold, 'rays': 8, 'seed': 3},
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final n = o.intOpt('rays', 8) * 2;
    final seed = o.seed;
    final rot = (t / _dur) * ((2.0 * tau) / n);
    p.glow(0, 0, 62, c[4], 0.3 + 0.06 * math.sin((t / _dur) * tau * 2.0));

    // Fine threads of light between the rays.
    for (var i = 0; i < n; i++) {
      final a = rot + ((i + 0.5) * tau) / n;
      final l = 14.0 + 6.0 * math.sin(a * 3.0 + (t / _dur) * tau);
      p.lineShaded(
        math.cos(a) * (_r0 + 1.0),
        math.sin(a) * (_r0 + 1.0),
        math.cos(a) * (_r0 + l),
        math.sin(a) * (_r0 + l),
        color: (u) => u < 0.3 ? c[6] : c[5],
        alpha: (u) => 0.7 - u * 0.8,
      );
    }

    // The rays, long and short by turns, breathing as a wave runs round them.
    for (var i = 0; i < n; i++) {
      final a = rot + (i * tau) / n;
      final isLong = i.isEven;
      final breathe = 0.86 + 0.14 * math.sin(a * 3.0 - (t / _dur) * tau * 2.0);
      final l = (isLong ? 36.0 : 21.0) * breathe;
      _ray(p, c, a, l, isLong ? 4.0 : 2.6, 1.0);
      // A glint runs out along each long ray and winks at the tip.
      if (isLong) {
        final g = fract((t / _dur) * 2.0 + (a * 3.0) / tau);
        final r = _r0 + g * l;
        if (g < 0.9) {
          p.px(math.cos(a) * r, math.sin(a) * r, kWhite);
          p.glow(math.cos(a) * r, math.sin(a) * r, 5, c[6], 0.45 * (1.0 - g));
        } else {
          sparkle(
            p,
            math.cos(a) * (_r0 + l),
            math.sin(a) * (_r0 + l),
            1.0 + 3.0 * math.sin(((g - 0.9) / 0.1) * math.pi),
            kWhite,
            c[6],
            0.5,
          );
        }
      }
    }

    // The corona and the core.
    p.shade(-_ring - 2.0, -_ring - 2.0, _ring + 2.0, _ring + 2.0, (x, y, out) {
      final d = hypot(x, y);
      if (d > _ring) return null;
      final flick =
          0.5 + 0.5 * math.sin(math.atan2(y, x) * 5.0 + (t / _dur) * tau * 3.0);
      out.c = d < _core
          ? kWhite
          : (d < _core + 1.5
              ? (flick > 0.6 ? kWhite : c[6])
              : (flick > 0.5 ? c[5] : c[4]));
      return null;
    });
    p.glow(0, 0, 16, kWhite, 0.28);

    // Twinkles round it.
    cycle(t, _dur, 10, seed, (g) => g.range(0.35, 0.7), (age, life, r, _) {
      final a = r.range(0.0, tau);
      final d = r.range(16.0, 44.0);
      final k = math.sin((age / life) * math.pi);
      sparkle(
        p,
        math.cos(a) * d,
        math.sin(a) * d,
        1.0 + 2.4 * k * r.range(0.5, 1.0),
        kWhite,
        c[5],
        0.4 * k,
      );
    });
  },
);
