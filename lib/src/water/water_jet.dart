// The stream's build (a white core banded out to darker edges, surges running along it, light down its length, a
// flare where it leaves the source) follows Sprite Fusion's open-source energy beam
// (https://www.spritefusion.com/pixel-art-vfx/energy), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'water_lib.dart';

const double _d = 1.0;
const double _g = 520.0;
const double _speed = 260.0;

double _drop(double x, double l) => (x / l) * (x / l) * 9.0;
double _thick(double x, double l) => 2.6 + 5.4 * math.pow(x / l, 1.1);

final PureEffect waterJetEffect = PureEffect(
  meta: const EffectMeta(
    id: 'water/water-jet',
    name: 'Water jet',
    desc:
        'A pressurised stream blasts right: a tight glassy rod with surges running down it that swells, roughens, bends under its weight and breaks into chunks, spray and mist.',
    category: 'water',
    tags: ['water', 'jet', 'stream', 'hose', 'spray', 'directional', 'loop'],
    size: (188, 80),
    origin: (14, 32),
    duration: 1.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': kWaterPalette,
      'length': 118,
      'seed': 3,
    },
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _d;
    final l = o.numOpt('length', 118);
    final s = o.seed;
    final tt = ph * tau;
    final rodPalette = [kWhite, c[6], c[5], c[4]];

    for (var xi = 0; xi <= l + 3; xi++) {
      final x = xi + 0.5;
      final u = x / l;
      if (u > 1.0) break;
      final yc = _drop(x, l);
      final rough = smooth(0.25, 1.0, u);
      final sd = ((((x - ph * _speed * 2.0) % 130.0) + 130.0) % 130.0) - 65.0;
      final w0 = _thick(x, l) + math.exp(-(sd * sd) / 90.0) * 1.4 * (1.0 - u * 0.5);
      final up = w0 + tileNoise(x * 0.18 - ph * 30.0, 9.0, 30, 0, s + 1) * 2.2 * rough;
      final dn = w0 + tileNoise(x * 0.18 - ph * 30.0, 3.0, 30, 0, s + 1) * 2.2 * rough;
      for (var yi = (yc - up).floor(); yi <= (yc + dn).ceil(); yi++) {
        final y = yi + 0.5;
        final q = (y - yc) / math.max(0.8, y < yc ? up : dn);
        final aq = q.abs();
        if (aq > 1.0) continue;
        if (u > 0.55 &&
            tileNoise(x * 0.12 - ph * 25.0, (y - yc) * 0.25, 25, 0, s + 2) <
                -0.9 + 1.6 * smooth(0.55, 1.0, u)) {
          continue;
        }
        final streak = tileNoise(
          x * 0.06 - ph * 40.0,
          (y - yc + 20.0).floor() * 1.7,
          40,
          0,
          s,
        );
        var lvl = aq < 0.2 ? 0 : (aq < 0.48 ? 1 : (aq < 0.78 ? 2 : 3));
        if (streak > 0.35) lvl = math.max(0, lvl - 1);
        if (q > 0.4) lvl = math.min(3, lvl + 1);
        p.px(xi, yi, rodPalette[lvl]);
        if (lvl == 0) p.light(x, y, c[5], 0.12);
      }
    }

    final fl = 0.85 + 0.15 * math.sin(tt * 6.0);
    p.circle(0, 0, 4.4 * fl, c[5]);
    p.circle(0, 0, 3.4 * fl, c[6]);
    p.circle(0, 0, 2.2 * fl, kWhite);
    for (var a = 0.0; a < tau; a += 0.35) {
      p.dot(
        math.cos(a + tt * 2.0) * 5.2 * fl,
        math.sin(a + tt * 2.0) * 5.2 * fl,
        c[5],
        0.6,
      );
    }
    p.glow(0, 0, 24, c[5], 0.6 * fl);
    p.glow(0, 0, 8, kWhite, 0.4 * fl);

    for (var k = 0; k < 6; k++) {
      final x = l * 0.82 + ((k * 13.0 + ph * _speed) % 78.0);
      final y = _drop(math.min(x, l), l) +
          (x > l ? ((x - l) / 60.0) * ((x - l) / 60.0) * 10.0 : 0.0) +
          math.sin(k * 2.1) * 1.5;
      if (x < l + 34.0) bead(p, x, y, _speed, 40.0, k % 3 == 0 ? 3 : 2, c);
    }

    cycle(t, _d, 70, s + 3, (g) => g.range(0.2, 0.42), (age, life, r, _) {
      final f = math.sqrt(r.next());
      final x0 = l * (0.3 + 0.7 * f);
      final y0 = _drop(x0, l) + r.range(-1.0, 1.0) * _thick(x0, l);
      final vx = r.range(150.0, 270.0) * (0.55 + 0.45 * f);
      final vy = r.range(-1.0, 1.0) * 110.0 * f + r.range(-10.0, 20.0);
      final x = x0 + vx * age;
      final y = y0 + vy * age + 0.5 * _g * age * age;
      final k = age / life;
      if (x > l + 50.0 ||
          y > 40.0 ||
          y < -28.0 ||
          (k > 0.75 && r.next() < (k - 0.75) * 4.0)) {
        return;
      }
      if (r.next() < 0.45) {
        p.px(x, y, k < 0.5 ? kWhite : c[6]);
      } else {
        bead(p, x, y, vx, vy + _g * age, r.next() < 0.2 ? 2 : 1, c);
      }
    });

    cycle(t, _d, 12, s + 4, (g) => g.range(0.7, 1.0), (age, life, r, _) {
      final k = age / life;
      final x = l * r.range(0.7, 1.0) + age * r.range(20.0, 45.0);
      final y = _drop(math.min(x, l), l) +
          r.range(-5.0, 5.0) +
          age * r.range(4.0, 14.0);
      final rad = r.range(3.0, 5.0) + k * r.range(5.0, 9.0);
      final a = r.range(0.1, 0.18) *
          math.min(1.0, k / 0.15) *
          math.pow(1.0 - k, 1.5);
      p.discShaded(
        x,
        y,
        rad,
        color: (_, _) => c[6],
        alpha: (d, _) => a * (1.0 - d * d),
      );
    });

    for (var x = 0.0; x < l; x += 10.0) {
      p.glow(x, _drop(x, l), 14.0 + x * 0.1, c[4], 0.26 * (1.0 - (x / l) * 0.5));
    }
    p.glow(l * 0.9, _drop(l * 0.9, l), 26, c[5], 0.22);
  },
);
