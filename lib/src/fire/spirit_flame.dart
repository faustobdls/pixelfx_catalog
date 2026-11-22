// The layered tongue, its noise-torn edges and the shed puffs are adapted from Sprite Fusion's open-source fire
// (https://www.spritefusion.com/pixel-art-vfx/fire), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'fire_lib.dart';

const double _d = 3.0;
final FireNoiseFn _nl = noiseFor(_d);

const List<(double, double, int)> _ghost = [
  (1.0, 1.0, 1),
  (0.8, 0.92, 3),
  (0.6, 0.78, 6),
  (0.3, 0.42, 2),
  (0.14, 0.22, 0),
];

class _CurlSeed {
  final double x, y, vx, vy, life, s, a, w;
  _CurlSeed(this.x, this.y, this.vx, this.vy, this.life, this.s, this.a, this.w);
}

class _SparkSeed {
  final double x, y, vx, vy, life, a;
  _SparkSeed(this.x, this.y, this.vx, this.vy, this.life, this.a);
}

void _ghostTongue(
  Painter p,
  double x,
  double y,
  double h,
  double w,
  double Function(double v, double r) centre,
  double Function(double rate, [int seed, double off]) n,
  int seedN,
  List<int> hRamp,
  List<(double, double, int)> layers, [
  double jit = 0.5,
]) {
  for (final (lw, lh, ri) in layers) {
    final l = h * lh;
    final c = hRamp[ri];
    final maxR = l.floor();
    for (var r = 0; r <= maxR; r++) {
      final u = r / math.max(1.0, l);
      final v = r / h;
      final half = w *
              lw *
              math.pow(1.0 - u, 0.75) *
              math.min(1.0, (r + 1.5) / 4.0) +
          n(6.0, seedN, r * 0.4) * jit * u;
      if (half < 0.3) continue;
      final cx = x + centre(v, r.toDouble());
      final yRow = (y - r + 0.5).floor();
      final x0 = (cx - half + 0.5).floor();
      final x1 = (cx + half + 0.5).floor();
      for (var px = x0; px <= x1; px++) {
        p.px(px, yRow, c);
      }
    }
  }
}

final PureEffect spiritFlameEffect = PureEffect(
  meta: const EffectMeta(
    id: 'fire/spirit-flame',
    name: 'Spirit flame',
    desc:
        'A cold blue-teal ghost fire floating in the air: a bright rim round a hollow dark heart, a wave climbing its wispy tail, curls breaking off, cold sparks rising.',
    category: 'fire',
    tags: ['fire', 'spirit', 'ghost', 'magic', 'cold', 'ambient', 'loop'],
    size: (80, 124),
    origin: (40, 94),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#040a16', '#08203a', '#0b3a52', '#0f5e6e',
        '#16908e', '#2cc4b4', '#7ef0dc', '#c8fff2', '#ffffff',
      ],
      'seed': 7,
    },
  ),
  onDraw: (p, t, o) {
    final f = fit(o.palette, 9);
    final h = hotFirst(f);
    final s = o.seed;
    final ph = t / _d;
    double n(double rate, [int sd = 0, double off = 0.0]) =>
        _nl(t, rate, sd, off);
    final cold = mix(h[3], kWhite, 0.15);
    final bob = math.sin(ph * tau) * 1.5;
    final lean = n(0.67, s + 2) * 3.0;
    double wave(double v, double r, [double k = 0.0]) =>
        (math.sin(r * 0.24 - ph * tau * 2.0 + k) * 2.2 +
                math.sin(r * 0.11 - ph * tau + k * 0.5) * 3.2) *
            v *
            v +
        lean * v * v;
    final h0 = 44.0 * (0.92 + 0.08 * n(1.3, s + 3));
    final y0 = bob;

    final br = 0.9 + 0.1 * n(2.0, s + 4);
    p.glow(0, y0 - 16.0, 60, cold, 0.36 * br);
    p.glow(wave(0.5, 20.0) * 0.5, y0 - 20.0, 26, h[2], 0.2 * br);

    looped<_CurlSeed>(
      t,
      _d,
      40,
      s + 300,
      (r, _) {
        final x = r.range(-4.0, 4.0);
        final y = -h0 * r.range(0.55, 0.95);
        final vx = r.range(-7.0, 7.0);
        final vy = -r.range(10.0, 22.0);
        final life = r.range(1.0, 1.9);
        return (
          _CurlSeed(
            x,
            y,
            vx,
            vy,
            life,
            r.range(1.4, 2.8),
            r.range(0.0, tau),
            r.range(2.0, 3.5),
          ),
          life,
        );
      },
      (q, age, _) {
        final (x, y, _, _) = drift(
          q.x + wave(0.9, 26.0, 0.0) * 0.5,
          q.y + y0,
          q.vx,
          q.vy,
          age,
          0.0,
          -6.0,
          1.2,
          0.6,
        );
        final k = 1.0 - age / q.life;
        final cx = x + math.sin(age * q.w + q.a) * 3.0 * (age + 0.2);
        final a = math.min(1.0, age * 5.0) * k;
        softDisc(p, cx, y, q.s * (0.8 + age * 0.8), h[4], 0.35 * a);
        softDisc(
            p, cx - 0.4, y - 0.6, q.s * 0.5 * (0.8 + age * 0.5), h[2], 0.4 * a * k);
        p.glow(cx, y, 6, h[3], 0.15 * a);
      },
    );

    final wl = math.max(0.0, 0.25 + 0.55 * n(1.7, s + 6));
    final wr = math.max(0.0, 0.25 + 0.55 * n(1.7, s + 7));
    if (wl > 0.12) {
      _ghostTongue(
        p,
        -4,
        y0 - 4.0,
        h0 * wl,
        2.4,
        (v, r) =>
            wave(v, r, 2.1) -
            6.0 * v * v +
            3.0 * math.sin(v * 5.0 - ph * tau * 2.0) * v,
        n,
        s * 11 + 1,
        h,
        _ghost,
      );
    }
    if (wr > 0.12) {
      _ghostTongue(
        p,
        4.2,
        y0 - 4.0,
        h0 * wr,
        2.4,
        (v, r) =>
            wave(v, r, -1.8) +
            6.0 * v * v -
            3.0 * math.sin(v * 5.0 - ph * tau * 2.0 + 1.0) * v,
        n,
        s * 11 + 2,
        h,
        _ghost,
      );
    }
    _ghostTongue(p, 0, y0, h0, 8.6, (v, r) => wave(v, r), n, s * 11, h, _ghost, 0.6);

    for (final k in const [0, 1]) {
      for (var r = 4; r < h0 * 0.72; r++) {
        final v = r / h0;
        final x = wave(v, r.toDouble()) +
            math.sin(r * 0.35 - ph * tau * 3.0 + k * math.pi) *
                2.2 *
                (1.0 - v);
        final on = math.sin(r * 0.2 - ph * tau * 4.0 + k * 2.0) > 0.2;
        if (on) p.px(x, y0 - r, k != 0 ? h[2] : h[1]);
      }
    }

    for (final v in const [0.2, 0.45, 0.7]) {
      p.glow(wave(v, h0 * v), y0 - h0 * v, 12, h[2], 0.16 * br);
    }
    p.glow(0, y0 - 4.0, 9, h[1], 0.22 + 0.06 * n(3.0, s + 5));

    looped<_SparkSeed>(
      t,
      _d,
      34,
      s + 400,
      (r, _) {
        final x = r.range(-7.0, 7.0);
        final y = -r.range(4.0, 28.0);
        final vx = r.range(-12.0, 12.0);
        final vy = -r.range(14.0, 34.0);
        final life = r.range(0.9, 1.8);
        return (_SparkSeed(x, y, vx, vy, life, r.range(0.0, tau)), life);
      },
      (q, age, _) {
        final (x, y, _, _) =
            drift(q.x, q.y + y0, q.vx, q.vy, age, 0.0, -10.0, 1.2, 1.2);
        final k = 1.0 - age / q.life;
        final tw = 0.5 + 0.5 * math.sin(age * 14.0 + q.a);
        final sx = x + math.sin(age * 3.0 + q.a) * 3.0;
        if (k * (0.4 + 0.6 * tw) < 0.2) return;
        p.px(sx, y, tw > 0.7 && k > 0.5 ? h[0] : (k > 0.5 ? h[1] : h[3]));
        if (tw > 0.85 && k > 0.6) {
          p.px(sx - 1.0, y, h[3]);
          p.px(sx + 1.0, y, h[3]);
          p.px(sx, y - 1.0, h[3]);
          p.px(sx, y + 1.0, h[3]);
        }
        p.glow(sx, y, 4, h[2], 0.3 * k);
      },
    );
  },
);
