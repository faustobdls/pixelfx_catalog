import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'impacts_lib.dart';

final SimulatedEffect bluntHitEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'impacts/blunt-hit',
    name: 'Blunt hit',
    desc:
        'A heavy, soft thud: a white-hot lumpy blob cools to cream in a warm pool of light, inked wedges jab out and snap back, a squashed ring of dust puffs swells and drifts, clods drop.',
    category: 'impacts',
    tags: [
      'impact',
      'hit',
      'blunt',
      'punch',
      'club',
      'thump',
      'dust',
      'comic',
      'one-shot',
    ],
    size: (128, 88),
    origin: (64, 72),
    duration: 0.9,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#1d1620',
        '#4a3a3c',
        '#7d6a66',
        '#b09c90',
        '#dccab4',
        '#f6ead2',
        '#ffffff',
      ],
      'warm': '#ffc98a',
      'dust': '#b7a8a6',
      'clod': '#6e5a5a',
      'height': 22,
      'seed': 9,
    },
  ),
  onCreate: (o) => _BluntHitSim(o),
);

double _lump(double r, double a, double ph) =>
    r *
    (1.0 +
        0.15 * math.sin(5.0 * a + ph) +
        0.08 * math.sin(9.0 * a + ph * 2.3));

class _Wedge {
  final double a;
  final double len;
  final double w;
  final double r0;
  final double t0;
  final double out;
  final double back;

  const _Wedge({
    required this.a,
    required this.len,
    required this.w,
    required this.r0,
    required this.t0,
    required this.out,
    required this.back,
  });
}

class _Puff {
  double x;
  double y;
  double vx;
  double vy;
  final double r;
  double life;
  final double max;
  final double t0;
  final double lift;

  _Puff({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.r,
    required this.life,
    required this.max,
    required this.t0,
    required this.lift,
  });
}

class _BluntHitSim extends BaseEffectSim {
  static double _floor(double _) => 0.0;

  final List<int> c;
  final Rng r;
  final double x = 0.0;
  final double y;
  late final double ph;
  final int warm;
  final int dust;
  final StonePalette st;
  final Lights lights = Lights();
  final Bits bits = Bits(ground: _floor);
  final List<_Wedge> wedges = [];
  final List<_Puff> puffs = [];
  final List<_Puff> kicks = [];
  final Map<DebrisBit, List<double>> rockPts = {};
  final Map<DebrisBit, double> pvy = {};
  double t = 0.0;

  _BluntHitSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        r = Rng(o.seed),
        y = -o.numOpt('height', 22.0),
        warm = hex(o['warm'] ?? '#ffc98a'),
        dust = hex(o['dust'] ?? '#b7a8a6'),
        st = stone(o['clod'] ?? '#6e5a5a') {
    ph = r.range(0.0, tau);
    lights.add(x, y, 48.0, warm, 0.6, 0.4);
    lights.add(x, y, 16.0, kWhite, 0.6, 0.07);
    lights.add(x, -2.0, 36.0, warm, 0.25, 0.4);

    for (var i = 0; i < 9; i++) {
      wedges.add(
        _Wedge(
          a: (i / 9) * tau + r.range(-0.2, 0.2),
          len: r.range(6.0, 15.0),
          w: r.range(3.2, 5.0),
          r0: r.range(13.0, 16.0),
          t0: r.range(0.015, 0.04),
          out: r.range(0.04, 0.06),
          back: r.range(0.09, 0.14),
        ),
      );
    }

    for (var i = 0; i < 30; i++) {
      final a = (i / 30) * tau + r.range(-0.12, 0.12);
      final side = math.cos(a).abs();
      final v = r.range(40.0, 140.0) * (0.6 + 0.5 * side);
      final px = x + math.cos(a) * 9.0;
      final py = y + math.sin(a) * 6.0;
      final vx = math.cos(a) * v;
      final vy = math.sin(a) * v * 0.5;
      final rad = r.range(2.4, 6.2) * (0.75 + 0.35 * side);
      final life = r.range(0.35, 0.85);
      puffs.add(
        _Puff(
          x: px,
          y: py,
          vx: vx,
          vy: vy,
          r: rad,
          life: life,
          max: life,
          t0: r.range(0.03, 0.1),
          lift: r.range(4.0, 16.0),
        ),
      );
    }

    for (var i = 0; i < 5; i++) {
      final px = x + r.range(-6.0, 6.0);
      final py = y - r.range(3.0, 6.0);
      final vx = r.range(-30.0, 30.0);
      final vy = -r.range(20.0, 45.0);
      final rad = r.range(3.5, 5.5);
      final life = r.range(0.6, 0.85);
      puffs.add(
        _Puff(
          x: px,
          y: py,
          vx: vx,
          vy: vy,
          r: rad,
          life: life,
          max: life,
          t0: r.range(0.05, 0.1),
          lift: r.range(14.0, 24.0),
        ),
      );
    }

    for (var i = 0; i < 5; i++) {
      final s = r.sign();
      final a = -math.pi / 2.0 + s * r.range(0.5, 1.3);
      final v = r.range(70.0, 140.0);
      final bit = DebrisBit(
        kind: B.chunk,
        x: x + s * r.range(4.0, 8.0),
        y: y + r.range(-3.0, 3.0),
        vx: math.cos(a) * v,
        vy: math.sin(a) * v,
        g: 1.0,
        drag: 0.6,
        bounce: 0.28,
        life: r.range(0.65, 0.85),
        a: r.range(0.0, tau),
        va: s * r.range(8.0, 16.0),
        s: r.chance(0.4) ? 2.0 : 1.0,
      );
      bits.add(bit);
      rockPts[bit] = rockShape(r);
      pvy[bit] = 0.0;
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    for (final q in puffs) {
      if (t < q.t0) continue;
      q.life -= dt;
      q.vx -= q.vx * 4.5 * dt;
      q.vy -= q.vy * 4.5 * dt + q.lift * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
    }
    for (final b in bits.list) {
      pvy[b] = b.vy;
    }
    bits.update(dt);
    for (final b in bits.list) {
      if ((pvy[b] ?? 0.0) > 60.0 && b.vy <= 0.0) {
        for (var i = 0; i < 2; i++) {
          kicks.add(
            _Puff(
              x: b.x,
              y: -1.0,
              vx: r.sign() * r.range(8.0, 22.0),
              vy: -r.range(3.0, 10.0),
              r: r.range(1.2, 2.0),
              life: 0.4,
              max: 0.4,
              t0: 0.0,
              lift: 6.0,
            ),
          );
        }
        pvy[b] = 0.0;
      }
    }
    for (final q in kicks) {
      q.life -= dt;
      q.vx -= q.vx * 4.0 * dt;
      q.vy -= q.vy * 4.0 * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
    }
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    for (final q in [...puffs, ...kicks]) {
      final k = q.life / q.max;
      if (t < q.t0 || k <= 0.0) continue;
      final rad = q.r * (0.7 + (1.0 - k) * 0.85);
      final a =
          math.pow(k, 1.25).toDouble() * math.min(1.0, (t - q.t0) / 0.03);
      final col = mix(dust, warm, clamp(1.0 - (t - 0.03) / 0.25) * 0.55);
      p.discShaded(
        q.x,
        q.y,
        rad,
        color: (_, _) => col,
        alpha: (d, _) => 0.58 * a * (1.0 - d * d * 0.75),
      );
      p.discShaded(
        q.x - rad * 0.22,
        q.y - rad * 0.32,
        rad * 0.58,
        color: (_, _) => mix(col, kWhite, 0.55),
        alpha: (d, _) => 0.48 * a * (1.0 - d * d),
      );
    }

    for (final b in bits.list) {
      rock(p, b, rockPts[b]!, st);
    }

    if (t < 0.058) {
      final f = t < 0.025 ? 0 : 1;
      final r0 = f != 0 ? 13.5 : 11.5;
      p.shade(
        x - r0 * 1.4,
        y - r0 * 1.4,
        x + r0 * 1.4,
        y + r0 * 1.4,
        (px, py, _) {
          final dx = px - x;
          final dy = (py - y) * (f != 0 ? 1.25 : 1.1);
          final d = hypot(dx, dy);
          final ro = _lump(r0, math.atan2(dy, dx), ph + f * 0.6);
          if (d > ro) return null;
          final q = d / ro;
          if (f == 0) {
            return q < 0.55 ? kWhite : (q < 0.86 ? c[5] : c[4]);
          }
          return q < 0.3
              ? kWhite
              : (q < 0.72 ? c[5] : (q < 0.9 ? c[4] : c[3]));
        },
      );
    }

    for (final w in wedges) {
      final u = t - w.t0;
      if (u < 0.0 || u > w.out + w.back) continue;
      final s = u < w.out
          ? Ease.outCubic(u / w.out)
          : 1.0 - Ease.inQuad((u - w.out) / w.back);
      final l = w.len * s;
      if (l < 1.5) continue;
      final ca = math.cos(w.a);
      final sa = math.sin(w.a);
      final r0 = w.r0 + 2.0 * s;
      final hw = (w.w * (0.6 + 0.4 * s)) / 2.0;
      final tipX = x + ca * r0;
      final tipY = y + sa * r0;
      final endX = x + ca * (r0 + l);
      final endY = y + sa * (r0 + l);
      final nx = -sa * hw;
      final ny = ca * hw;
      List<(double, double)> wedge(double g) => [
            (tipX - ca * g, tipY - sa * g),
            (
              endX + nx * (1.0 + g * 0.45) + ca * g,
              endY + ny * (1.0 + g * 0.45) + sa * g,
            ),
            (
              endX - nx * (1.0 + g * 0.45) + ca * g,
              endY - ny * (1.0 + g * 0.45) + sa * g,
            ),
          ];
      p.poly(wedge(1.0), c[1]);
      p.poly(wedge(0.0), u < w.out + 0.02 ? kWhite : c[5]);
    }

    final pop = math.exp(-t / 0.06);
    if (pop > 0.02) {
      p.glow(x, y, 28.0, warm, 0.5 * pop);
    }
    lights.draw(p);
  }
}
