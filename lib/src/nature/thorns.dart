// The wave (spikes punching up one after another, each bigger, with overshoot, a white frame, a burst of debris
// and glints, a line running along the floor ahead of them) is adapted from Sprite Fusion's open-source ice
// spikes (https://www.spritefusion.com/pixel-art-vfx/ice), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'nature_lib.dart';

const double _rise = 0.11;
const double _sink = 0.36;
const double _dur = 2.4;

class _Thorn {
  final double x;
  final double h;
  final double w;
  final double lean;
  final double hook;
  final double at;
  final double sink;
  final int seed;
  bool up = false;
  bool down = false;

  _Thorn({
    required this.x,
    required this.h,
    required this.w,
    required this.lean,
    required this.hook,
    required this.at,
    required this.sink,
    required this.seed,
  });
}

class _Chip {
  double x;
  double y;
  double vx;
  double vy;
  double a;
  double va;
  final double s;
  final List<Point2> pts;
  double life;

  _Chip({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.a,
    required this.va,
    required this.s,
    required this.pts,
    required this.life,
  });
}

void _drawThorn(
  Painter p,
  _Thorn s,
  double h,
  List<int> c, {
  bool white = false,
  double base = 0.0,
  double a = 1.0,
}) {
  if (h < 1.5) return;
  final x = s.x;
  final w = s.w;
  final hook = s.hook;
  final lean = s.lean;
  double cx(double u) => x + lean * u + hook * math.pow(u, 2.4);
  double hw(double u) => (w / 2) * math.pow(1 - u, 0.9) + 0.25;
  bool inside(int px, int py) {
    final u = (base - (py + 0.5)) / h;
    if (u < 0 || u > 1 || py + 0.5 > 0) return false;
    final cVal = cx(u);
    final fx = px + 0.5;
    return (fx - cVal).abs() <= hw(u);
  }

  final x0 = (x - w - 6).floor();
  final x1 = (x + w / 2 + lean.abs() + hook.abs() + 2).ceil();
  final yEnd = math.min(0, base.ceil());
  for (var py = (base - h).floor() - 1; py <= yEnd; py++) {
    for (var px = x0; px <= x1; px++) {
      if (!inside(px, py)) {
        if (py <= 0 &&
            (inside(px - 1, py) ||
                inside(px + 1, py) ||
                inside(px, py + 1) ||
                inside(px, py - 1))) {
          p.dot(px, py, c[0], a);
        }
        continue;
      }
      if (white) {
        p.px(px, py, kWhite);
        continue;
      }
      final u = (base - (py + 0.5)) / h;
      final cVal = cx(u);
      final rVal = hw(u);
      final q = (px + 0.5 - (cVal - rVal)) / (2 * rVal);
      var i = q < 0
          ? 4
          : q < 0.16
              ? 6
              : q < 0.36
                  ? 5
                  : q < 0.46
                      ? 7
                      : q < 0.7
                          ? 4
                          : q < 0.86
                              ? 3
                              : 2;
      if (u > 0.86) i = q < 0.6 ? 7 : 5;
      if (i < 7 &&
          i > 2 &&
          rand(px, ((py + 0.5 - base) / 3).floor(), s.seed) < 0.12) {
        i -= 1;
      }
      p.px(px, py, c[i]);
    }
  }
  if (!white && h > 14) {
    const u0 = 0.34;
    const u1 = 0.46;
    final y0 = base - u0 * h;
    final y1 = base - u1 * h;
    final e0 = cx(u0) - hw(u0);
    final e1 = cx(u1) - hw(u1);
    final l = w * 0.45;
    if (y0 <= 0) {
      p.tri(e0 + 0.5, y0, e1 + 0.5, y1, e1 - l, y1 - l * 0.7, c[3]);
      p.line(e1, y1, e1 - l, y1 - l * 0.7, c[6]);
      p.px(e1 - l, y1 - l * 0.7, c[7]);
      p.line(e0, y0 + 1, e1 - l + 1, y1 - l * 0.7 + 1, c[0]);
    }
  }
}

class _ThornsSim extends BaseEffectSim {
  final List<int> c;
  final List<int> g;
  final List<int> s;
  final Rng r;
  final Particles ps;
  final Lights lights;
  final List<_Chip> chips = [];
  final List<_Thorn> list;
  final double reach;

  double t = 0.0;

  _ThornsSim._({
    required this.c,
    required this.g,
    required this.s,
    required this.r,
    required this.ps,
    required this.lights,
    required this.list,
    required this.reach,
  });

  factory _ThornsSim(Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final g = fit(o.rampOpt('glow'), 4);
    final s = fit(o.rampOpt('soil'), 8);
    final r = Rng(o.seed);
    double floorFn(double _) => 0.0;
    final n = math.max(2, o.intOpt('count', 6));
    final ps = Particles(
      rng: r,
      ground: floorFn,
      sparks: [g[3], g[2], g[1], g[0]],
    );
    final lights = Lights();
    final list = List.generate(n, (i) {
      final k = i / (n - 1);
      final h = 12 + 36 * k + r.range(-1.5, 1.5);
      return _Thorn(
        x: 10 + i * (104 / (n - 1)) + r.range(-3, 3),
        h: h,
        w: 6 + 9 * k,
        lean: r.range(-1, 1.5) + k * 2,
        hook: h * r.range(0.14, 0.22),
        at: 0.12 + i * 0.075,
        sink: 1.45 + i * 0.06,
        seed: r.intRange(1, 999),
      );
    });
    final reach = list[n - 1].x + 8;
    return _ThornsSim._(
      c: c,
      g: g,
      s: s,
      r: r,
      ps: ps,
      lights: lights,
      list: list,
      reach: reach,
    );
  }

  void _chip(double x, double sp, int nn) {
    for (var i = 0; i < nn; i++) {
      final a = -math.pi / 2 + r.range(-1.1, 1.1);
      final v = r.range(60, 210) * sp;
      chips.add(_Chip(
        x: x + r.range(-3, 3),
        y: -1,
        vx: math.cos(a) * v,
        vy: math.sin(a) * v,
        a: r.range(0, tau),
        va: r.range(-15, 15),
        s: r.range(1.3, 2.6) * math.sqrt(sp),
        pts: stoneShape(r),
        life: math.min(r.range(0.7, 1.1), _dur - 0.05 - t),
      ));
    }
  }

  double _grown(_Thorn th) =>
      t < th.at ? 0.0 : Ease.outBack(clamp((t - th.at) / _rise), 2.4);

  double _sunk(_Thorn th) => smooth(th.sink, th.sink + _sink, t);

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final f = math.min(1.0, dt * 120);
    for (final th in list) {
      final k = th.h / 48;
      if (!th.up && t >= th.at) {
        th.up = true;
        lights.add(th.x, -th.h * 0.5, 18 + 18 * k, kWhite, 0.45, 0.08);
        lights.add(th.x, -th.h * 0.4, 26 + 26 * k, g[2], 0.45, 0.4);
        _chip(th.x, 0.6 + 0.6 * k, 3 + (5 * k + 0.5).floor());
        for (var i = 0; i < 10 + 18 * k; i++) {
          final a = -math.pi / 2 + r.range(-1, 1);
          final v = r.range(60, 230) * (0.6 + 0.6 * k);
          ps.spawn(
            P.grit,
            th.x + r.range(-th.w / 3, th.w / 3),
            -1,
            math.cos(a) * v,
            math.sin(a) * v,
            r.range(0.6, 1.1),
            r.pick([s[5], s[4], s[3]]),
            r.chance(0.3) ? 2 : 1,
          );
        }
        for (var i = 0; i < 3 + 5 * k; i++) {
          ps.spawn(
            P.smoke,
            th.x + r.range(-4, 4),
            -r.range(1, 4),
            r.sign() * r.range(20, 80),
            -r.range(5, 25),
            r.range(0.7, 1.2),
            s[5],
            r.range(3, 5.5) * (0.6 + 0.5 * k),
            0,
            0,
          );
        }
        for (var i = 0; i < 2 + 3 * k; i++) {
          ps.spawn(
            P.star,
            th.x + th.hook * 0.8 + r.range(-3, 3),
            -th.h * r.range(0.5, 1),
            r.range(-10, 10),
            -r.range(5, 20),
            r.range(0.3, 0.6),
            g[3],
            r.range(0.8, 2),
            r.range(0, 0.12),
          );
        }
        for (var i = 0; i < 4; i++) {
          ps.spawn(
            P.mote,
            th.x + r.range(-3, 3),
            -r.range(2, th.h * 0.6),
            r.range(-20, 20),
            -r.range(30, 70),
            r.range(0.4, 0.8),
            g[3],
            0.7,
          );
        }
      }
      if (!th.down && t >= th.sink) {
        th.down = true;
        _chip(th.x, 0.35, 2 + (2 * k + 0.5).floor());
        for (var i = 0; i < 3 + 3 * k; i++) {
          ps.spawn(
            P.dust,
            th.x + r.range(-th.w / 2, th.w / 2),
            -r.range(0, 3),
            r.sign() * r.range(15, 50),
            -r.range(2, 10),
            math.min(r.range(0.4, 0.7), _dur - 0.05 - t),
            s[5],
            r.range(2, 4),
          );
        }
      }
      if (th.up && !th.down && t > th.at + 0.2 && r.chance(0.05 * f)) {
        ps.spawn(
          P.star,
          th.x + th.lean * 0.5 - th.w * 0.15,
          -th.h * r.range(0.3, 0.8),
          0,
          -3,
          r.range(0.25, 0.45),
          c[7],
          r.range(0.8, 1.8),
        );
      }
    }
    for (var i = chips.length - 1; i >= 0; i--) {
      final ch = chips[i];
      if ((ch.life -= dt) <= 0) {
        chips.removeAt(i);
        continue;
      }
      ch.vy += 950 * dt;
      ch.x += ch.vx * dt;
      ch.y += ch.vy * dt;
      ch.a += ch.va * dt;
      if (ch.y > 0 && ch.vy > 0) {
        if (ch.vy > 120) {
          ch.y = 0;
          ch.vy *= -0.3;
          ch.vx *= 0.6;
          ch.va *= 0.5;
        } else {
          ch.y = 0;
          ch.vy = 0;
          ch.vx = 0;
          ch.va = 0;
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final run = Ease.outCubic(clamp((t - 0.04) / 0.5)) * reach;
    final fade = 1 - smooth(1.9, 2.3, t);
    for (var x = -2; x <= run; x++) {
      final hot = clamp(1 - (run - x) / 18) * (1 - smooth(0.6, 1.2, t));
      final h = rand(x, 31);
      p.dot(x, 0, hot > 0.4 ? g[3] : (hot > 0.1 ? g[2] : s[0]), fade);
      if (h < 0.5) p.dot(x, 1, s[1], fade * 0.8);
      if (h < 0.15) p.dot(x, -1, s[4], fade);
      if (hot > 0.3 && (x & 3) == 0) p.glow(x, 0, 6, g[2], 0.3 * hot);
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    for (final th in list) {
      final gr = _grown(th);
      final k = _sunk(th);
      if (gr <= 0 || k >= 1) continue;
      _drawThorn(
        p,
        th,
        th.h * gr,
        c,
        white: t - th.at < 0.035,
        base: k * th.h * 1.05,
      );
      if (t - th.at < 0.3) {
        p.glow(
          th.x,
          -th.h * 0.5 * gr,
          th.h * 0.6 + 6,
          g[2],
          0.35 * (1 - (t - th.at) / 0.3),
        );
      }
      final lk = clamp((t - th.at - 0.04) / 0.18) * (1 - k);
      final lw = th.w * 0.5;
      if (lk > 0.05) {
        for (final (sd, a0, sz)
            in const [(-1, -2.5, 1.0), (1, -0.55, 0.9), (-1, -1.9, 0.7)]) {
          final la = a0 + sd * 0.25 * (1 - lk) + math.sin(t * 4 + th.x) * 0.06;
          final l = (5 + th.w * 0.45) * sz * lk;
          drawLeaf(
            p,
            th.x + sd * lw + math.cos(la) * l * 0.5,
            -1 + math.sin(la) * l * 0.5,
            l,
            1.4 + th.w * 0.1 * sz,
            la,
            0.35,
            [g[0], g[1], g[2], g[3]],
          );
        }
      }
      p.glow(th.x, -2, th.w + 6, g[2], 0.18 * lk);
    }
    for (final ch in chips) {
      drawRock(
        p,
        ch.x,
        ch.y,
        ch.s,
        ch.a,
        ch.pts,
        s,
        math.min(1.0, ch.life / 0.25),
      );
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final PixelEffect thorns = SimulatedEffect(
  meta: const EffectMeta(
    id: 'nature/thorns',
    name: 'Thorns',
    desc:
        'A seam races along the floor and hooked thorns punch up out of it one after another, each bigger than the last, in bursts of dirt and green light; they hold, then sink.',
    category: 'nature',
    tags: [
      'nature',
      'thorns',
      'plant',
      'spikes',
      'ground',
      'attack',
      'one-shot',
    ],
    size: (232, 92),
    origin: (48, 78),
    duration: 2.4,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#160c0e',
        '#2e1418',
        '#4e2224',
        '#743a30',
        '#9a5a3e',
        '#c08458',
        '#e2b484',
        '#fbe8c8',
      ],
      'glow': ['#123818', '#2f7a2a', '#6cb83a', '#c8f070'],
      'soil': [
        '#120c0c',
        '#251917',
        '#3b2a24',
        '#553d31',
        '#715440',
        '#8f6e52',
        '#b8966e',
        '#e6d0a8',
      ],
      'count': 6,
      'seed': 8,
    },
  ),
  onCreate: _ThornsSim.new,
);
