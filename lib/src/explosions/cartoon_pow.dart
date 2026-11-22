import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'explosions_lib.dart';

const int _n = 14;
const double _in = 0.05;
const double _go = 0.66;
const double _end = 0.8;

class _Spike {
  final double r, j;
  const _Spike(this.r, this.j);
}

class _ActionLine {
  final double a, r, l, t0;
  const _ActionLine(this.a, this.r, this.l, this.t0);
}

class _CartoonPowSim extends BaseEffectSim {
  final EffectMeta meta;
  final List<int> c;
  final int ink;
  final Rng r;
  final String word;
  late final Particles ps;
  late final List<_Spike> spikes;
  late final List<_ActionLine> lines;
  double t = 0.0;
  bool popped = false;
  bool burst = false;

  _CartoonPowSim(this.meta, Map<String, Object?> o)
      : c = fit(o.palette, 7),
        ink = fit(o.palette, 7)[0],
        r = Rng(o.seed),
        word = '${o['text'] ?? 'POW!'}' {
    ps = Particles(rng: r, sparks: [c[6], c[5], c[4], c[3]]);
    spikes = List.generate(
      _n * 2,
      (i) => _Spike(
        (i % 2 != 0) ? r.range(0.5, 0.6) : r.range(0.85, 1.05),
        r.next() * 100.0,
      ),
      growable: false,
    );
    lines = List.generate(
      16,
      (i) => _ActionLine(
        ((i + r.range(0.2, 0.8)) / 16.0) * tau,
        r.range(0.92, 1.08),
        r.range(10, 17),
        r.range(0, 0.06),
      ),
      growable: false,
    );
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (!burst && t >= _in) {
      burst = true;
      for (var i = 0; i < 22; i++) {
        final a = r.range(0, tau);
        final sp = r.range(180, 360);
        ps.spawn(
          P.spark,
          math.cos(a) * 14.0,
          math.sin(a) * 10.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.12, 0.3),
        );
      }
    }
    if (!popped && t >= _go) {
      popped = true;
      for (var i = 0; i < 14; i++) {
        final a = r.range(0, tau);
        final sp = r.range(60, 150);
        ps.spawn(
          P.star,
          math.cos(a) * 26.0,
          math.sin(a) * 18.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.25, 0.42),
          r.pick([c[6], c[5], c[4]]),
          r.range(1.2, 2.4),
        );
      }
    }
    ps.update(dt);
    cullParticles(
      ps,
      -meta.origin.$1 + 3.0,
      -meta.origin.$2 + 3.0,
      meta.size.$1 - meta.origin.$1 - 3.0,
      meta.size.$2 - meta.origin.$2 - 3.0,
    );
  }

  @override
  void draw(Painter p) {
    final k = clamp(t / _in);
    final s = t < _in
        ? 0.25 + 0.95 * Ease.outCubic(k)
        : (t < _go
            ? 1.0 +
                0.18 *
                    math.exp(-(t - _in) * 18.0) *
                    math.cos((t - _in) * 40.0)
            : 1.0 - Ease.inBack(clamp((t - _go) / (_end - _go)), 2.0));
    final shake = t < 0.3 ? (1.0 - t / 0.3) * 2.2 : 0.0;
    final sx = (math.sin(t * 97.0) * shake + 0.5).floor();
    final sy = (math.cos(t * 83.0) * shake + 0.5).floor();

    if (s > 0.02) {
      final boil = (t * 12.0).floor();
      final outer = 50.0 * s;
      final rot = -0.1 + (t > _go ? (t - _go) * 3.0 : 0.0);
      const m = _n * 2;
      final rad = List<double>.generate(
        m,
        (i) => spikes[i].r * (1.0 + (rand(i, boil, 7) - 0.5) * 0.08),
        growable: false,
      );
      p.shade(sx - outer - 4, sy - outer - 4, sx + outer + 4, sy + outer + 4,
          (x, y, out) {
        final dx = x - sx;
        final dy = (y - sy) / 0.82;
        final d = hypot(dx, dy);
        final rawTurn = (math.atan2(dy, dx) - rot) / tau;
        final u = ((rawTurn % 1.0) + 1.0) % 1.0 * m;
        final i = u.floor() % m;
        final f = u - u.floor();
        final rVal = rad[i] + (rad[(i + 1) % m] - rad[i]) * f;
        final e = d / rVal;
        if (e > outer + 2.5) return null;
        if (e > outer) return ink;
        if (e > outer * 0.66 + 2.0) {
          return dx * 0.6 + dy * 0.8 > outer * 0.25 &&
                  ((x.floor() + y.floor() * 2) % 4) == 0 &&
                  (y.floor() % 2) == 0
              ? c[4]
              : c[5];
        }
        if (e > outer * 0.66) return ink;
        return e > outer * 0.44 ? c[3] : c[4];
      });
      p.glow(sx, sy, outer * 1.3, c[5], 0.3 * math.min(1.0, s));
    }

    for (final q in lines) {
      final u = (t - _in - q.t0) / 0.32;
      if (u <= 0.0 || u >= 1.0) continue;
      final r0 = (46.0 + 22.0 * Ease.outCubic(u)) * q.r;
      final l = q.l * 0.7 * (1.0 - u);
      final ca = math.cos(q.a);
      final sa = math.sin(q.a) * 0.82;
      p.lineShaded(
        ca * r0,
        sa * r0,
        ca * (r0 + l),
        sa * (r0 + l),
        color: (v) => v < 0.5 ? kWhite : c[5],
      );
    }

    final ru = (t - _in) / 0.24;
    if (ru > 0.0 && ru < 1.0) {
      p.ring(0, 0, 30.0 + 34.0 * Ease.outCubic(ru),
          math.max(1.0, 2.5 * (1.0 - ru)), ru < 0.4 ? kWhite : c[5], 1.1 - ru);
    }

    const scale = 3;
    final chars = word.runes.map(String.fromCharCode).toList(growable: false);
    final widths = [
      for (final ch in chars) p.measure(ch, font: PixelFontKind.big, scale: scale).$1,
    ];
    var totalW = -scale;
    for (final w in widths) {
      totalW += w + scale;
    }
    var x = -totalW / 2.0;
    for (var i = 0; i < chars.length; i++) {
      final ch = chars[i];
      final u = (t - _in - 0.04 - i * 0.05) / 0.12;
      final away = clamp((t - _go) / (_end - _go - 0.04));
      if (u > 0.0 && away < 1.0) {
        final drop = (1.0 - Ease.outBack(clamp(u), 2.4)) * -14.0;
        final y = (-11.0 + drop - i * 1.5 + sy + away * 6.0 + 0.5).floor();
        final lx = (x + sx + 0.5).floor();
        final a = 1.0 - away;
        for (var d = 4; d >= 1; d--) {
          p.text(
            ch,
            lx + d,
            y + d,
            d >= 3 ? ink : c[1],
            font: PixelFontKind.big,
            scale: scale,
            a: a,
            outline: d == 4 ? ink : null,
          );
        }
        for (final (ox, oy) in const [
          (-2, 0),
          (2, 0),
          (0, -2),
          (0, 2),
          (-1, -1),
          (1, -1),
          (-1, 1),
          (1, 1),
        ]) {
          p.text(ch, lx + ox, y + oy, ink,
              font: PixelFontKind.big, scale: scale, a: a);
        }
        p.textShaded(
          ch,
          lx,
          y,
          color: (gx, gy) => gy < 4 ? c[6] : (gy < 6 ? c[5] : c[4]),
          font: PixelFontKind.big,
          scale: scale,
          a: a,
        );
      }
      x += widths[i] + scale;
    }

    ps.draw(p);
    if (t > _in && t < _in + 0.12) {
      sparkle(
        p,
        sx + 34,
        sy - 22,
        6.0 * (1.0 - (t - _in) / 0.12),
        c[6],
        c[5],
        0.6,
      );
    }
  }
}

const EffectMeta _cartoonPowMeta = EffectMeta(
  id: 'explosions/cartoon-pow',
  name: 'Cartoon POW',
  desc:
      'A comic-book hit: a jagged two-tone burst star slams in with a shake and boiling edges, POW! drops in letter by letter, action lines fly, then it all snaps away.',
  category: 'explosions',
  tags: ['cartoon', 'comic', 'pow', 'hit', 'impact', 'text', 'one-shot'],
  size: (184, 144),
  origin: (92, 72),
  duration: 1.05,
  loop: false,
  fps: 30,
  bg: BackdropKind.dark,
  defaultOptions: {
    'palette': [
      '#1a0e14',
      '#6e1a12',
      '#c8361a',
      '#f47a24',
      '#ffc23c',
      '#fff07a',
      '#ffffff',
    ],
    'text': 'POW!',
    'seed': 5,
  },
);

final SimulatedEffect cartoonPowEffect = SimulatedEffect(
  meta: _cartoonPowMeta,
  onCreate: (o) => _CartoonPowSim(_cartoonPowMeta, o),
);
