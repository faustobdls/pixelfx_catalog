// The orb's build (a see-through body with a lit rim, an inner current drawn as streaks on a tilted plane, motes
// on tilted orbits split behind and in front, a pulsing light) follows Sprite Fusion's open-source energy orb
// (https://www.spritefusion.com/pixel-art-vfx/energy), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'water_lib.dart';

const double _d = 3.0;
const double _sy = 0.3;
const double _g = 700.0;
const double _drip = 1.5;
const double _let = 0.5;

(double, double) _center(double ph) => (0.0, -52.0 + math.sin(ph * tau) * 2.0);

double _skin(double a, double rad, double ph) {
  final frac = ((ph * _d) % _drip) / _drip;
  final sag = math.pow(math.max(0.0, math.sin(a)), 6.0) *
      2.2 *
      smooth(0.1, _let, frac) *
      (frac < _let ? 1.0 : 0.0);
  return rad +
      math.sin(a * 3.0 + ph * tau * 2.0) * 0.6 +
      math.sin(a * 5.0 - ph * tau * 3.0) * 0.35 +
      sag;
}

class _Mote {
  final double x;
  final double y;
  final double z;
  final int i;

  _Mote(this.x, this.y, this.z, this.i);
}

List<_Mote> _motes(double ph, double rad) => List.generate(7, (i) {
      final a = (i / 7.0) * tau + ph * tau * (i % 2 != 0 ? 1 : -1);
      final r = rad + 5.0 + (i % 3) * 3.0;
      final tilt = (i - 3) * 0.22;
      final x = math.cos(a) * r;
      final z = math.sin(a);
      return _Mote(
        x * math.cos(tilt),
        x * math.sin(tilt) + z * r * 0.28,
        z,
        i,
      );
    });

final PureEffect waterOrbEffect = PureEffect(
  meta: const EffectMeta(
    id: 'water/water-orb',
    name: 'Water orb',
    desc:
        'A sphere of water floats and wobbles: a current circles inside it, the floor shows upside down through it, it shines, light gathers on the floor under it, and drips fall and plink.',
    category: 'water',
    tags: ['water', 'orb', 'sphere', 'magic', 'float', 'ambient', 'loop'],
    size: (100, 108),
    origin: (50, 100),
    duration: 3.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': kWaterPalette,
      'radius': 19,
      'seed': 2,
    },
  ),
  onDrawBack: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _d;
    final rad = o.numOpt('radius', 19);
    final (cx, cy) = _center(ph);
    p.glow(cx, 0, 22, c[5], 0.32);
    p.shade(cx - 9.0, -2.0, cx + 9.0, 2.0, (x, y, out) {
      final d = ((x - cx) * (x - cx)) / 64.0 + ((y * 2.5) * (y * 2.5)) / 9.0;
      if (d > 1.0) return null;
      out.c = d < 0.25 ? kWhite : (d < 0.6 ? c[6] : c[5]);
      out.a = 1.2 - d;
      return null;
    });
    for (final m in _motes(ph, rad)) {
      if (m.z < 0.0) p.px(cx + m.x, cy + m.y, c[4]);
    }
    p.glow(cx, cy, rad * 3.2, c[4], 0.3 + 0.05 * math.sin(ph * tau * 2.0));
  },
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _d;
    final rad = o.numOpt('radius', 19);
    final (cx, cy) = _center(ph);
    final tt = ph * tau;

    p.shade(cx - rad - 4.0, cy - rad - 4.0, cx + rad + 4.0, cy + rad + 6.0,
        (x, y, out) {
      final dx = x - cx;
      final dy = y - cy;
      final d = hypot(dx, dy);
      final a = math.atan2(dy, dx);
      final r = _skin(a, rad, ph);
      if (d > r) return null;
      final q = d / r;
      final lit = (-dx - dy) / math.sqrt2 / math.max(0.5, d);
      if (q > 0.9) {
        return lit > 0.35 ? kWhite : (lit > -0.2 ? c[5] : c[3]);
      }
      final gather = math.max(0.0, (dx + dy) / math.sqrt2 / r) * q;
      p.blend(
        x,
        y,
        gather > 0.45
            ? c[4]
            : (gather > 0.25 ? c[3] : (q > 0.7 ? c[2] : c[1])),
        gather > 0.25 ? 0.7 : 0.35 + 0.3 * q,
      );
      return null;
    });

    for (var k = 0; k < 3; k++) {
      final rr = rad * (0.38 + 0.2 * k);
      final tilt = -0.5 + k * 0.35;
      final spin = tt * (k % 2 != 0 ? -2 : 3) + k * 2.0;
      for (var s = 0.0; s < 1.0; s += 0.012) {
        final a = spin + s * tau;
        final x = math.cos(a) * rr;
        final z = math.sin(a);
        final y = x * math.sin(tilt) * 0.6 + z * rr * 0.62;
        final dash = (s * 3.0 + k * 0.3) % 1.0;
        if (dash > 0.62) continue;
        p.px(
          cx + x * math.cos(tilt),
          cy + y,
          z > 0.0
              ? (dash < 0.1 ? kWhite : (dash < 0.4 ? c[6] : c[5]))
              : c[3],
        );
      }
    }

    cycle(t, _d, 8, o.seed, (g) => g.range(1.0, 1.8), (age, life, r, _) {
      final k = age / life;
      final x = r.range(-0.5, 0.5) * rad +
          math.sin(age * 4.0 + r.range(0.0, tau)) * 1.5;
      final y = rad * 0.6 - k * rad * 1.2;
      if (hypot(x, y) > rad * 0.8) return;
      p.px(cx + x, cy + y, k < 0.8 ? c[6] : kWhite);
      if (r.next() < 0.35) p.px(cx + x + 1.0, cy + y, c[5]);
    });

    p.arcShaded(
      cx,
      cy,
      rad * 0.74,
      math.pi * 1.12,
      math.pi * 1.4,
      width: (_) => 1.8,
      color: (u, v) => (u > 0.25 && u < 0.75 && v > 0.4) ? kWhite : c[6],
    );
    p.px(cx - rad * 0.45, cy - rad * 0.62, kWhite);
    p.px(cx + rad * 0.48, cy + rad * 0.5, c[6]);
    p.px(cx + rad * 0.48 + 1.0, cy + rad * 0.5, c[5]);

    for (final m in _motes(ph, rad)) {
      if (m.z >= 0.0) {
        p.px(cx + m.x, cy + m.y, kWhite);
        p.px(cx + m.x - (m.i % 2 != 0 ? -1 : 1), cy + m.y, c[5]);
        p.glow(cx + m.x, cy + m.y, 4, c[5], 0.35);
      }
    }

    final dtFrac = (t % _drip) / _drip;
    final fall = (t % _drip) - _drip * _let;
    final y0 = cy + rad + 3.0;
    final land = math.sqrt((2.0 * -y0) / _g);
    if (fall < 0.0 && dtFrac > 0.2) {
      final s = smooth(0.2, _let, dtFrac);
      p.circle(cx, cy + rad + 1.0 + s * 1.5, 0.8 + s * 1.2, c[5]);
      p.px(cx - 0.5, cy + rad + s * 1.5, c[6]);
    } else if (fall >= 0.0 && fall < land) {
      bead(p, cx, y0 + 0.5 * _g * fall * fall, 0.0, _g * fall, 2, c);
    } else if (fall >= land) {
      final since = fall - land;
      if (since < 0.08) p.px(cx, 0, kWhite);
      ring(
        p,
        cx,
        0.0,
        1.5 + since * 18.0,
        _sy,
        1.1 * (1.0 - since / 0.4),
        c,
        n: 1,
        half: 1,
        seed: 3,
        hot: since < 0.05,
      );
    }

    final fx = cx + rad * 0.36;
    final fy = cy + rad * 0.4;
    final pulse = 0.8 + 0.2 * math.sin(tt * 4.0);
    p.circle(fx, fy, 1.6, c[6]);
    p.px(fx, fy, kWhite);
    p.glow(fx, fy, 9, c[5], 0.45 * pulse);
    p.glow(cx, cy, rad * 1.4, c[5], 0.22);
    p.glow(cx - rad * 0.4, cy - rad * 0.5, 6, kWhite, 0.25);
  },
);
