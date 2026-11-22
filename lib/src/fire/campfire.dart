// The tongue, lick, flame-puff, smoke and ember recipe is adapted from Sprite Fusion's open-source fire
// (https://www.spritefusion.com/pixel-art-vfx/fire), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'fire_lib.dart';

const double _d = 3.0;
final FireNoiseFn _nl = noiseFor(_d);
final int _smoke1 = hex('#5b5566');
final List<int> _ash = [hex('#2a2530'), hex('#4a4350'), hex('#6b6270')];

const List<(double x0, double y0, double x1, double y1, double r)> _logs = [
  (-19.0, 2.0, 15.0, -12.0, 3.4),
  (19.0, 2.0, -15.0, -12.0, 3.4),
];
const double _cross = 0.56;

const List<TongueSpec> _tongues = [
  (-7.5, -7.0, 0.42, 1.8, 1),
  (7.5, -7.0, 0.46, 1.8, 1),
  (-3.0, -9.0, 0.78, 2.0, 1),
  (3.2, -9.0, 0.82, 2.0, 1),
  (-12.0, -3.0, 0.14, 1.3, 0),
  (12.5, -3.0, 0.16, 1.3, 0),
  (-9.5, -4.5, 0.3, 1.9, 0),
  (9.5, -4.5, 0.34, 1.9, 0),
  (-5.0, -6.0, 0.6, 2.6, 0),
  (5.2, -6.0, 0.66, 2.6, 0),
  (0.0, -7.0, 1.0, 3.4, 0),
];

class _CampTongue {
  final double dx, y, h, w, env;
  final int back, n;
  _CampTongue(this.dx, this.y, this.h, this.w, this.back, this.env, this.n);
}

class _SmokeSeed {
  final double x, y, vx, vy, life, s;
  _SmokeSeed(this.x, this.y, this.vx, this.vy, this.life, this.s);
}

class _PuffSeed {
  final int i;
  final double fire, sl, ox, oy, vx, vy, s, f;
  final bool smokes;
  _PuffSeed(this.i, this.fire, this.smokes, this.sl, this.ox, this.oy, this.vx,
      this.vy, this.s, this.f);
}

class _WoodPuffSeed {
  final double x, y, vx, vy, life, s, f;
  _WoodPuffSeed(this.x, this.y, this.vx, this.vy, this.life, this.s, this.f);
}

class _LickSeed {
  final int i;
  final double vx, vy, s;
  _LickSeed(this.i, this.vx, this.vy, this.s);
}

class _PopSeed {
  final double x, y;
  final int n, seed;
  _PopSeed(this.x, this.y, this.n, this.seed);
}

class _EmberSeed {
  final double x, y, vx, vy, life, s, a, b;
  _EmberSeed(
      this.x, this.y, this.vx, this.vy, this.life, this.s, this.a, this.b);
}

void _log(
  Painter p,
  (double, double, double, double, double) l,
  List<int> w,
  List<int> h,
  double u0,
  double u1,
  double t,
  int s,
) {
  final (x0, y0, x1, y1, r) = l;
  final dx = x1 - x0;
  final dy = y1 - y0;
  final len = hypot(dx, dy);
  final ax = dx / len;
  final ay = dy / len;
  var nx = -ay;
  var ny = ax;
  if (ny < 0.0) {
    nx = -nx;
    ny = -ny;
  }
  final rim = 1.0 - 1.05 / r;
  p.shade(
    math.min(x0, x1) - r - 1.0,
    math.min(y0, y1) - r - 1.0,
    math.max(x0, x1) + r + 1.0,
    math.max(y0, y1) + r + 1.0,
    (x, y, out) {
      final along = (x - x0) * ax + (y - y0) * ay;
      final u = along / len;
      final sv = ((x - x0) * nx + (y - y0) * ny) / r;
      if (u < u0 || u > u1 || sv.abs() > 1.0) return null;
      final burnAmt = clamp(1.2 - x.abs() / 8.0);
      final lane = (sv * r * 0.85 + 0.5).floor();
      final run = rand((along / 3.0).floor(), lane, s);
      if (sv.abs() > rim || along > len - 1.0) {
        return sv < 0.0 && burnAmt > 0.4 ? h[7] : w[0];
      }
      if (burnAmt > 0.35 && lane < 2) {
        if (run < 0.55 && lane > -2) {
          final g = 0.5 +
              0.5 *
                  math.sin((t / _d) * math.pi * 6.0 +
                      rand((along / 2.0).floor(), lane, s + 1) * 6.3);
          out.k = 0.3 * burnAmt * g;
          return g > 0.72 ? h[3] : (g > 0.4 ? h[4] : h[5]);
        }
        return lane < -1 ? w[1] : w[0];
      }
      if (lane <= -2) return run < 0.25 ? w[2] : mix(w[3], h[4], 0.45 * burnAmt);
      if (lane == -1) return run < 0.45 ? w[1] : w[2];
      if (lane == 0) return run < 0.2 ? w[1] : w[2];
      return run < 0.4 ? w[0] : w[1];
    },
  );
  if (u0 <= 0.0) {
    p.ellipseShaded(
      x0,
      y0,
      r * 0.62,
      r + 0.2,
      color: (double d, double _) => d > 0.78
          ? w[0]
          : d > 0.56
              ? w[5]
              : d > 0.32
                  ? w[4]
                  : w[3],
    );
  }
}

void _coals(Painter p, List<int> w, List<int> h, double t, int s) {
  p.shade(-15.0, -3.0, 15.0, 2.0, (x, y, out) {
    final dx = x / 14.0;
    final dy = (y + 0.3) / 2.2;
    final d = dx * dx + dy * dy;
    if (d > 1.0) return null;
    final hVal = rand((x / 2.0).floor(), y.floor(), s + 20);
    if (d > 0.55 && hVal < 0.55) {
      return _ash[hVal < 0.15 ? 2 : (hVal < 0.32 ? 1 : 0)];
    }
    if (hVal > 0.5) {
      final g =
          (0.5 + 0.5 * math.sin((t / _d) * math.pi * 4.0 + hVal * 40.0)) *
              (1.1 - d);
      out.k = 0.35 * g;
      return g > 0.7
          ? h[2]
          : g > 0.5
              ? h[3]
              : g > 0.3
                  ? h[4]
                  : h[5];
    }
    return hVal > 0.3 ? w[1] : w[0];
  });
}

final PureEffect campfireEffect = PureEffect(
  meta: const EffectMeta(
    id: 'fire/campfire',
    name: 'Campfire',
    desc:
        'Crossed logs on a bed of coals and a lively fire: tongues that lick and leap, popping sparks, embers drifting up, smoke curling off, a warm pool of light.',
    category: 'fire',
    tags: ['fire', 'campfire', 'prop', 'light', 'smoke', 'ambient', 'loop'],
    size: (128, 128),
    origin: (64, 112),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#4a1712', '#8a1f17', '#c9281f', '#f2561d',
        '#ff8a2a', '#ffc23d', '#ffe26b', '#fff3a6', '#ffffff',
      ],
      'wood': ['#0e080a', '#24130f', '#3b2216', '#5a3520', '#8a5a34', '#b9884f'],
      'height': 22,
      'seed': 3,
    },
  ),
  onDraw: (p, t, o) {
    final f = fit(o.palette, 9);
    final h = hotFirst(f);
    final w = fit(o.rampOpt('wood'), 6);
    final s = o.seed;
    final r = Rng(s);
    final hc = o.numOpt('height', 22.0);
    double n(double rate, [int sd = 0, double off = 0.0]) =>
        _nl(t, rate, sd, off);
    double fla(double tt) =>
        0.74 + 0.16 * _nl(tt, 7.3, s + 1) + 0.1 * _nl(tt, 19.0, s + 2);
    final fl = fla(t);
    final glowCol = mix(mix(h[3], h[4], 0.5), kWhite, 0.25);
    final smokeCol = mix(_smoke1, h[6], 0.25);
    final sparks = [h[1], h[2], h[4], h[5]];
    final emb = [h[1], h[2], h[4], h[6]];

    final ttList = [
      for (var i = 0; i < _tongues.length; i++)
        _CampTongue(
          _tongues[i].$1 + r.range(-0.4, 0.4),
          _tongues[i].$2,
          3.0 + hc * _tongues[i].$3 * r.range(0.92, 1.08),
          _tongues[i].$4 * r.range(0.9, 1.1),
          _tongues[i].$5,
          _tongues[i].$3,
          (s * 7 + i) * 13,
        ),
    ];

    double lean(double tt) => _nl(tt, 0.67, s + 90) * 0.12;

    double heightAt(int i, double tt) {
      final td = ttList[i];
      final leap = math.max(0.0, _nl(tt, 2.6, td.n + 70) - 0.55) * 1.4;
      return (td.h + 0.25 * td.h * _nl(tt, 3.3, td.n) + td.h * leap) *
          (0.9 + 0.1 * fla(tt));
    }

    double sweep(int i, double tt, double hVal) =>
        _nl(tt, 2.2, ttList[i].n + 40) * (1.0 + hVal * 0.08) +
        lean(tt) * hVal * 0.9 -
        clamp(ttList[i].dx * 0.3, -2.5, 2.5);

    (double, double, double) tip(int i, double tt) {
      final hVal = heightAt(i, tt);
      return (
        ttList[i].dx + sweep(i, tt, hVal) * 0.85,
        ttList[i].y - hVal * 0.88 + 3.0,
        hVal,
      );
    }

    void tongueAt(int i) {
      final td = ttList[i];
      final hVal = heightAt(i, t);
      flameTongue(
        p,
        td.dx,
        td.y,
        hVal,
        td.w,
        sweep(i, t, hVal),
        n,
        td.n,
        h,
        layers: td.back != 0
            ? fireBackLayers
            : (td.w > 2.2 ? fireBigLayers : fireLayers),
        jit: 0.5,
        wob: 1.1 + hVal * 0.04,
      );
    }

    looped<_SmokeSeed>(
      t,
      _d,
      48,
      s + 300,
      (r, _) {
        final sx = r.range(-5.0, 5.0);
        final sy = -hc * 0.8 - r.range(0.0, 8.0);
        final vx = r.range(-2.0, 2.0);
        final vy = -r.range(10.0, 17.0);
        final life = r.range(2.0, 2.9);
        return (_SmokeSeed(sx, sy, vx, vy, life, r.range(2.4, 3.8)), life);
      },
      (q, age, _) {
        final (x, y, _, _) =
            drift(q.x, q.y, q.vx, q.vy, age, 4.0, -20.0, 1.6, 1.0);
        smokePuff(
          p,
          x + _nl(t - age, 0.8, s + 60) * (2.0 + 3.0 * age),
          y,
          1.0 - age / q.life,
          q.s,
          smokeCol,
        );
      },
    );

    final puffs = <(double, double, double, double, double)>[];
    looped<_PuffSeed>(
      t,
      _d,
      ttList.length * 24,
      s + 200,
      (r, j) {
        final i = j % ttList.length;
        final fire = r.range(0.14, 0.3);
        final smokes = r.chance(0.45);
        return (
          _PuffSeed(
            i,
            fire,
            smokes,
            r.range(0.8, 1.4),
            r.range(-1.0, 1.0),
            r.range(0.0, 4.0),
            r.range(-4.0, 4.0),
            -r.range(15.0, 30.0),
            r.range(0.8, 1.6) * (0.8 + 0.6 * ttList[i].env),
            r.next(),
          ),
          fire + (smokes ? 1.4 : 0.0),
        );
      },
      (q, age, _) {
        final (tx, ty, _) = tip(q.i, t - age);
        final (x, y, vx, vy) = drift(
          tx + q.ox,
          ty + q.oy,
          q.vx,
          q.vy,
          math.min(age, q.fire),
          0.0,
          -95.0,
          5.0,
          3.2,
        );
        if (age < q.fire) {
          puffs.add((x, y, 1.0 - age / q.fire, q.s, q.f));
          return;
        }
        if (age - q.fire > q.sl) return;
        final (sx, sy, _, _) = drift(
          x,
          y,
          vx * 0.6,
          vy * 0.6 - 6.0,
          age - q.fire,
          2.0,
          -16.0,
          1.6,
          1.2,
        );
        smokePuff(p, sx, sy, 1.0 - (age - q.fire) / q.sl, q.s * 0.7, 0);
      },
    );

    _coals(p, w, h, t, s);
    for (final l in _logs) {
      _log(p, l, w, h, _cross, 1.0, t, s + 11);
    }
    for (var i = 0; i < ttList.length; i++) {
      if (ttList[i].back != 0) tongueAt(i);
    }

    looped<_WoodPuffSeed>(
      t,
      _d,
      90,
      s + 210,
      (r, _) {
        final px = r.range(-10.0, 10.0);
        final py = -r.range(3.0, 8.0);
        final vx = r.range(-5.0, 5.0);
        final vy = -r.range(20.0, 40.0);
        final life = r.range(0.16, 0.3);
        return (_WoodPuffSeed(px, py, vx, vy, life, r.range(1.0, 1.8), r.next()), life);
      },
      (q, age, _) {
        final (x, y, _, _) =
            drift(q.x, q.y, q.vx, q.vy, age, 0.0, -95.0, 5.0, 3.2);
        firePuff(p, x, y, 1.0 - age / q.life, q.s, q.f, h);
      },
    );

    for (var i = 0; i < ttList.length; i++) {
      if (ttList[i].back == 0) tongueAt(i);
    }

    looped<_LickSeed>(
      t,
      _d,
      ttList.length * 12,
      s + 220,
      (r, j) {
        final idx = j % ttList.length;
        return (
          _LickSeed(
            idx,
            r.range(-3.0, 3.0),
            -r.range(12.0, 22.0),
            r.range(0.9, 1.6) * (0.8 + 0.5 * ttList[idx].env),
          ),
          0.26,
        );
      },
      (q, age, _) {
        final (tx, ty, _) = tip(q.i, t - age);
        lick(
          p,
          tx + q.vx * age,
          ty - 2.0 + q.vy * age,
          1.0 - age / 0.26,
          q.s,
          h,
        );
      },
    );

    for (final (px, py, k, sz, fVal) in puffs) {
      firePuff(p, px, py, k, sz, fVal, h);
    }
    for (final l in _logs) {
      _log(p, l, w, h, 0.0, _cross, t, s + 11);
    }

    looped<_PopSeed>(
      t,
      _d,
      4,
      s + 400,
      (r, _) => (
        _PopSeed(
          r.range(-9.0, 9.0),
          -r.range(4.0, 9.0),
          r.intRange(3, 5),
          r.intRange(0, 1000000),
        ),
        0.7,
      ),
      (q, age, _) {
        if (age < 0.08) {
          p.px(q.x, q.y, kWhite);
          p.glow(q.x, q.y, 12, h[1], 0.7 * (1.0 - age / 0.08));
        }
        final pr = Rng(q.seed);
        for (var j = 0; j < q.n; j++) {
          final a = -math.pi / 2.0 + pr.range(-0.8, 0.8);
          final sp = pr.range(110.0, 220.0);
          final life = pr.range(0.25, 0.6);
          if (age >= life) continue;
          final (x, y, vx, vy) = sparkAt(
              q.x, q.y, math.cos(a) * sp, math.sin(a) * sp, age, 0.0);
          sparkLine(p, x, y, vx, vy, 1.0 - age / life, sparks);
        }
      },
    );

    looped<_EmberSeed>(
      t,
      _d,
      36,
      s + 500,
      (r, _) {
        final px = r.range(-7.0, 7.0);
        final py = -r.range(8.0, 18.0);
        final vx = r.range(-15.0, 15.0);
        final vy = -r.range(25.0, 60.0);
        final life = r.range(1.1, 2.5);
        return (
          _EmberSeed(
            px,
            py,
            vx,
            vy,
            life,
            r.chance(0.15) ? 2.0 : r.range(1.0, 1.6),
            r.range(0.0, 6.3),
            r.range(0.0, 6.3),
          ),
          life,
        );
      },
      (q, age, _) {
        final (x, y, _, _) =
            drift(q.x, q.y, q.vx, q.vy, age, 0.0, -30.0, 1.6, 1.6);
        emberDot(
          p,
          x + 7.0 * (math.sin(age * 2.3 + q.a) - math.sin(q.a)),
          y + 2.0 * (math.sin(age * 3.0 + q.b) - math.sin(q.b)),
          1.0 - age / q.life,
          q.s,
          emb,
          age * 40.0 + q.a,
        );
      },
    );

    final br = 0.92 + 0.08 * n(0.67, s + 3);
    final lx = lean(t) * 12.0;
    p.glow(lx, -8, 74 * br * (0.9 + 0.1 * fl), glowCol, 0.3 * fl);
    for (final (gx, gy, gk) in const [
      (-6.0, -17.0, 0.85),
      (0.0, -21.0, 1.0),
      (6.0, -17.0, 0.85),
    ]) {
      p.glow(gx + lx, gy, 46 * br, glowCol, 0.3 * gk * fl);
      p.glow(gx * 0.6, gy + 13.0, 15, h[2], 0.16 * gk * fl);
    }
    p.glow(0, -3, 9, h[0], 0.16 * fl);
    floorLight(p, 0, 0.5, 48, 8, glowCol, 0.3 * fl);
  },
);
