import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ui_lib.dart';

const double _land = -8.0;
const double _fade = 0.84;
const double _duration = 1.05;

class _DamageNumberSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final int shadowCol;
  late final SpelledWord word;
  late final Particles ps;
  final Lights lights = Lights();
  late final List<(double, double)> spikes;

  double x = 0.0;
  double y = _land;
  double vx = 34.0;
  double vy = -175.0;
  double sq = 0.0;
  int hops = 0;

  double t = 0.0;
  bool hit = false;

  _DamageNumberSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed),
        shadowCol = scaleColor(fit(o.palette, 8)[0], 0.5) {
    word = spell(o.strOpt('text', '-27'));
    ps = Particles(rng: r, sparks: [c[7], c[6], c[4], c[2]]);
    spikes = List<(double, double)>.generate(
      9,
      (i) => ((i / 9.0) * tau + r.range(-0.2, 0.2), r.range(8.0, 14.0)),
    );
  }

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    if (!hit) {
      hit = true;
      lights.add(0, -4, 30, c[5], 0.7, 0.25);
      lights.add(0, -4, 14, kWhite, 0.6, 0.08);
      for (var i = 0; i < 9; i++) {
        final an = r.range(-math.pi * 0.95, -0.05) +
            (i % 2 != 0 ? math.pi * 0.08 : 0.0);
        final sp = r.range(90.0, 200.0);
        ps.spawn(
          P.spark,
          0,
          -4,
          math.cos(an) * sp,
          math.sin(an) * sp,
          r.range(0.1, 0.25),
        );
      }
    }

    if (hops < 2) {
      vy += 900.0 * dt;
      vx -= vx * 2.0 * dt;
      x += vx * dt;
      y += vy * dt;
      if (y >= _land && vy > 0.0) {
        y = _land;
        sq = 1.0;
        hops++;
        vy = hops < 2 ? -vy * 0.36 : 0.0;
        if (hops == 1) {
          for (final s in const [-1, 1]) {
            ps.spawn(
              P.star,
              x + s * 14.0,
              _land + r.range(-2.0, 1.0),
              s * r.range(15.0, 35.0),
              -r.range(5.0, 20.0),
              r.range(0.2, 0.35),
              c[6],
              r.range(0.5, 1.2),
            );
          }
        }
      }
    }

    sq = math.max(0.0, sq - dt / 0.09);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    if (t < 0.07) {
      final big = t < 0.035;
      for (var i = 0; i < spikes.length; i++) {
        final (an, baseL) = spikes[i];
        final l = baseL * (big ? 1.0 : 1.3);
        final ca = math.cos(an);
        final sa = math.sin(an);
        if (big) {
          p.line(-sa, -4.0 + ca, ca * l * 0.7 - sa, -4.0 + sa * l * 0.7 + ca, c[4]);
          p.line(sa, -4.0 - ca, ca * l * 0.7 + sa, -4.0 + sa * l * 0.7 - ca, c[4]);
        }
        p.line(
          ca * (big ? 0.0 : l * 0.45),
          -4.0 + sa * (big ? 0.0 : l * 0.45),
          ca * l,
          -4.0 + sa * l,
          big ? kWhite : (i % 2 != 0 ? c[6] : c[5]),
        );
      }
      if (big) p.circle(0, -4, 3.2, kWhite);
    } else if (t < 0.16) {
      sparkle(
        p,
        0,
        -4,
        5.0 * (1.0 - (t - 0.07) / 0.09),
        kWhite,
        c[5],
        0.6,
      );
    }

    final rk = t / 0.22;
    if (rk < 1.0) {
      p.ring(
        0,
        -4,
        3.0 + 10.0 * Ease.outCubic(rk),
        math.max(1.0, 2.0 * (1.0 - rk)),
        rk < 0.4 ? kWhite : c[5],
        1.2 - rk,
      );
    }

    ps.draw(p);

    final out = seg(t, _fade, _duration - 0.04);
    if (out < 1.0) {
      final s = 2.0 + 1.4 * math.exp(-t * 22.0) * math.cos(t * 30.0);
      var sx = s;
      var sy = s;
      if (sq > 0.0) {
        sx = s * (1.0 + 0.18 * sq);
        sy = s * (1.0 - 0.2 * sq);
      } else if (hops < 2 && vy.abs() > 120.0) {
        sx = s * 0.92;
        sy = s * 1.1;
      }
      final w = word.w * sx;
      final h = 7.0 * sy;
      final x0 = x - w / 2.0;
      final y0 = y - h - 6.0 * Ease.inQuad(out);
      final flash = t < 0.035 ? 1.0 : (t < 0.07 ? 0.4 : 0.0);
      final items = [
        for (final l in word.letters)
          if (l.g != null)
            WordLetter(
              g: l.g!,
              x: x0 + l.x * sx,
              y: y0,
              sx: sx,
              sy: sy,
              flash: flash,
              a: 1.0 - out,
            ),
      ];
      drawWord(
        p,
        items,
        WordStyle(
          fill: [c[3], c[3], c[4], c[5]],
          edge: c[6],
          under: c[2],
          outline: c[0],
          shadow: shadowCol,
        ),
      );
      p.glow(
        x,
        y0 + h / 2.0,
        18,
        c[4],
        0.3 * (1.0 - out) + (t < 0.1 ? 0.4 * (1.0 - t / 0.1) : 0.0),
      );
    }

    lights.draw(p);
  }
}

final SimulatedEffect damageNumberEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ui/damage-number',
    name: 'Damage number',
    desc:
        'A red -27 punches out of a hit spark, white for a frame, arcs up, lands with a squash and a little hop, then fades as it lifts away.',
    category: 'ui',
    tags: ['ui', 'damage', 'number', 'combat', 'text', 'hit', 'one-shot'],
    size: (76, 68),
    origin: (30, 52),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#1a0508',
        '#4a0b12',
        '#8c1420',
        '#d42a2e',
        '#ff5a4a',
        '#ff9a86',
        '#ffd8cc',
        '#ffffff',
      ],
      'text': '-27',
      'seed': 2,
    },
  ),
  onCreate: _DamageNumberSim.new,
);
