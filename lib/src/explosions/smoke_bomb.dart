import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'explosions_lib.dart';

const double _pop = 0.95;
const double _r0 = 4.0;
final List<int> _band = [hex('#3a1418'), hex('#7a2a24'), hex('#b84a34')];
final List<int> _grit = [hex('#5a4f6b'), hex('#3e3650'), hex('#776c88')];

class _Canister {
  double x, y, vx, vy, va, a;
  bool rest;
  _Canister({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.va,
    required this.a,
    required this.rest,
  });
}

void _stepCanister(
  _Canister c,
  double dt, [
  void Function(double x, double speed)? hit,
]) {
  if (c.rest) return;
  c.vy += 900.0 * dt;
  c.x += c.vx * dt;
  c.y += c.vy * dt;
  if (c.y >= -_r0 && c.vy > 0.0) {
    c.y = -_r0;
    if (c.vy > 80.0) {
      hit?.call(c.x, c.vy);
      c.vy = -c.vy * 0.38;
      c.vx *= 0.78;
    } else {
      c.vy = 0.0;
    }
  }
  if (c.vy == 0.0 && c.y >= -_r0 - 0.01) {
    c.vx -= c.vx * 3.0 * dt;
    if (c.vx.abs() < 2.0) {
      c.vx = 0.0;
      c.rest = true;
    }
  }
  c.a += (c.vy == 0.0 ? c.vx / _r0 : c.va) * dt;
}

class _SmokeLobe {
  final int kind;
  final double t0, d, r0, r1, f, wob;
  double vx, vh, x, h, age;
  bool on;

  _SmokeLobe({
    required this.kind,
    required this.t0,
    required this.vx,
    required this.vh,
    required this.d,
    required this.r0,
    required this.r1,
    required this.f,
    required this.wob,
  })  : on = false,
        x = 0.0,
        h = 0.0,
        age = 0.0;
}

class _SmokeBombSim extends BaseEffectSim {
  final EffectMeta meta;
  final List<int> c, k, sm;
  final List<Object> sparksOpt;
  final Rng r;
  final int oy;
  final double x0, x1, y0, y1;
  late final Particles ps;
  final Lights lights = Lights();
  late final _Canister can;
  late final List<_SmokeLobe> lobes;
  double t = 0.0;
  bool popped = false;

  _SmokeBombSim(this.meta, Map<String, Object?> o)
      : c = fit(o.palette, 7),
        k = fit(
          (o['canister'] as List<Object?>?)?.cast<Object>() ??
              const ['#16121e', '#2a2434', '#443c52', '#686078', '#9c94ac'],
          5,
        ),
        sparksOpt = ((o['sparks'] as List<Object?>?)?.cast<Object>()) ??
            const ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
        sm = [
          fit(o.palette, 7)[5],
          fit(o.palette, 7)[4],
          fit(o.palette, 7)[3],
          fit(o.palette, 7)[2],
          fit(o.palette, 7)[1],
        ],
        r = Rng(o.seed),
        oy = meta.origin.$2,
        x0 = -meta.origin.$1 + 3.0,
        x1 = meta.size.$1 - meta.origin.$1 - 3.0,
        y0 = -meta.origin.$2 + 3.0,
        y1 = meta.size.$2 - meta.origin.$2 - 3.0 {
    ps = Particles(rng: r, ground: (_) => 0.0, sparks: sparksOpt);
    final sim = _Canister(
      x: -70.0,
      y: -60.0,
      vx: 125.0,
      vy: -80.0,
      va: 7.0,
      a: 0.0,
      rest: false,
    );
    for (var i = 0; i < 2400 && !sim.rest; i++) {
      _stepCanister(sim, 1.0 / 240.0);
    }
    can = _Canister(
      x: -70.0 - sim.x,
      y: -60.0,
      vx: 125.0,
      vy: -80.0,
      va: 7.0,
      a: 0.0,
      rest: false,
    );
    const n = 52;
    const kinds = [0, 0, 1, 1, 2, 3];
    lobes = List.generate(n, (i) {
      final kind = kinds[i % 6];
      final side = r.sign();
      final ang = kind == 0 || kind == 3
          ? (side > 0 ? -r.range(0, 0.25) : math.pi + r.range(0, 0.25))
          : -math.pi / 2 + r.range(-0.6, 0.6);
      final sp = [
        r.range(70, 170),
        r.range(0, 25),
        r.range(45, 95),
        r.range(20, 60),
      ][kind];
      final r1 = [
        r.range(12, 17),
        r.range(16, 22),
        r.range(13, 18),
        r.range(14, 19),
      ][kind];
      final t0 = kind == 3
          ? _pop + r.range(0.45, 1.5)
          : _pop +
              0.6 * math.pow(i / (n - 1), 1.6).toDouble() +
              r.range(0, 0.03);
      return _SmokeLobe(
        kind: kind,
        t0: t0,
        vx: math.cos(ang) * sp,
        vh: -math.sin(ang) * sp,
        d: r.range(-1, 1),
        r0: r.range(5, 8),
        r1: r1,
        f: r.range(-0.45, 0.4),
        wob: r.range(0, tau),
      );
    }, growable: false);
  }

  (double, double) _fuseTip() => (
        can.x + math.sin(can.a) * (_r0 + 2.5),
        can.y - math.cos(can.a) * (_r0 + 2.5),
      );

  double _thin(_SmokeLobe b) => smooth(2.5 + b.f, 3.9 + b.f * 0.6, t);

  double _radius(_SmokeLobe b) =>
      (b.r0 + (b.r1 - b.r0) * (1.0 - math.exp(-b.age / 0.28))) *
      (1.0 + 0.05 * math.sin(t * 3.0 + b.wob)) *
      (1.0 + 0.35 * _thin(b));

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    _stepCanister(can, dt, (x, sp) {
      for (var i = 0; i < 3; i++) {
        ps.spawn(P.spark, x, -1.0, r.range(-70, 70), -r.range(40, 110),
            r.range(0.06, 0.14));
      }
      for (var i = 0; i < 3; i++) {
        ps.spawn(
          P.dust,
          x + r.range(-2, 2),
          -0.5,
          r.sign() * r.range(10, 40),
          -r.range(4, 14),
          r.range(0.3, 0.55),
          _grit[2],
          r.range(1.4, 2.4),
        );
      }
    });
    if (t < _pop) {
      final (fx, fy) = _fuseTip();
      final hurry = smooth(_pop - 0.4, _pop, t);
      if (r.chance((26.0 + 50.0 * hurry) * dt)) {
        ps.spawn(P.spark, fx, fy, r.range(-50, 50), -r.range(30, 100),
            r.range(0.08, 0.18));
      }
      if (r.chance(8.0 * dt)) {
        ps.spawn(P.vapour, fx, fy - 1.0, r.range(-4, 4), -r.range(10, 18),
            r.range(0.5, 0.8), c[5], r.range(1, 1.8));
      }
    } else if (!popped) {
      popped = true;
      lights.add(can.x, -9, 64, c[6], 0.75, 0.22);
      lights.add(can.x, -5, 22, kWhite, 0.7, 0.06);
      for (var i = 0; i < 30; i++) {
        final a = r.range(-math.pi - 0.35, 0.35);
        final sp = r.range(120, 300);
        ps.spawn(
          P.spark,
          can.x,
          -5.0,
          math.cos(a) * sp,
          math.sin(a) * sp - 40.0,
          r.range(0.15, 0.4),
        );
      }
      for (var i = 0; i < 26; i++) {
        final u = r.range(-1, 1);
        final a = -math.pi / 2 + u * 0.9;
        final sp = r.range(80, 220) * (1.0 - 0.35 * u.abs());
        ps.spawn(
          P.grit,
          can.x + u * 4.0,
          -1.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.9, 1.6),
          r.pick(_grit),
          r.chance(0.35) ? 2.0 : 1.0,
        );
      }
      can.vy = -95.0;
      can.vx = r.range(-25, 25);
      can.va = r.sign() * 9.0;
      can.rest = false;
    }
    final wind = 6.0 * smooth(1.8, 3.2, t);
    for (final b in lobes) {
      if (!b.on) {
        if (t < b.t0) continue;
        b.on = true;
        b.x = can.x + r.range(-2, 2);
        b.h = 1.0;
      }
      b.age += dt;
      b.vx -= b.vx * 2.4 * dt;
      final lift = switch (b.kind) {
        0 => 14.0 * smooth(0.7, 1.6, b.age),
        1 => 3.0 + 9.0 * smooth(0.8, 1.8, b.age),
        2 => 6.0 + 12.0 * smooth(0.3, 1.4, b.age),
        _ => 10.0 * smooth(0.8, 1.6, b.age),
      };
      b.vh += lift * dt;
      b.vh -= b.vh * 1.6 * dt;
      b.x += (b.vx + wind) * dt;
      b.h = math.max(0.0, b.h + b.vh * dt);
      final kVal = _thin(b);
      if (kVal > 0.12 && kVal < 0.85 && r.chance(1.8 * dt)) {
        final rad = _radius(b);
        final life = math.min(r.range(1, 1.6), meta.duration - 0.15 - t);
        if (life > 0.3) {
          ps.spawn(
            P.vapour,
            b.x + r.range(-rad, rad) * 0.5,
            -(b.h + rad * 1.4),
            wind + r.range(-6, 10),
            -r.range(8, 20),
            life,
            c[4],
            rad * r.range(0.3, 0.45),
          );
        }
      }
    }
    if (t > _pop + 0.5 && t < 4.1 && r.chance(4.0 * dt)) {
      ps.spawn(P.vapour, can.x, can.y - 3.0, r.range(-3, 3), -r.range(8, 16),
          r.range(0.6, 0.9), c[4], r.range(1.5, 2.5));
    }
    ps.update(dt);
    cullParticles(ps, x0, y0, x1, y1);
    fadeEdges(ps, x0, x1, 20.0, y1);
    lights.update(dt);
  }

  void _clouds(Painter p, bool back) {
    final on = [
      for (final b in lobes)
        if (b.on) b,
    ];
    if (on.isEmpty) return;
    var top = 0.0;
    for (final b in on) {
      top = math.min(top, -(b.h + _radius(b) * 1.92));
    }
    final filtered = [
      for (final b in on)
        if ((b.d < -0.35) == back) b,
    ]..sort((a, b) => a.d.compareTo(b.d));
    for (final b in filtered) {
      final rad = _radius(b);
      final y = -(b.h + rad * 0.92) + b.d * 2.5;
      final kVal = _thin(b);
      final a = math.min(1.0, b.age / 0.05) *
          math.pow(1.0 - kVal, 1.4).toDouble() *
          0.97 *
          (1.0 - smooth(-oy + 34.0, -oy + 6.0, y - rad));
      if (a <= 0.01) continue;
      final shade = (y - top) / math.max(20.0, -top) > 0.55 ? 1 : 0;
      lobe(
        p,
        b.x,
        y,
        rad,
        sm,
        sm,
        0.0,
        0.0,
        a,
        b.d,
        math.min(2, shade + (kVal > 0.6 ? 1 : 0)),
        1,
      );
    }
  }

  @override
  void drawBack(Painter p) {
    ps.draw(p, 'back');
    _clouds(p, true);
  }

  @override
  void draw(Painter p) {
    final fade = 1.0 - smooth(4.3, 4.8, t);
    if (fade > 0.0) _drawCanister(p, k, can, t < _pop, fade);
    if (t < _pop) {
      final (fx, fy) = _fuseTip();
      p.px(fx, fy, math.sin(t * 50.0) > 0.0 ? kWhite : hex(sparksOpt[1]));
      p.glow(fx, fy, 6, hex(sparksOpt[2]), 0.45 + 0.2 * math.sin(t * 37.0));
    }
    _clouds(p, false);
    ps.draw(p, 'front');
    final u = t - _pop;
    if (u >= 0.0 && u < 0.067) {
      p.circle(can.x, -5, 6.5, c[5]);
      p.circle(can.x, -5, 4.5, kWhite);
    }
    if (u >= 0.0 && u < 0.16) {
      flare(p, can.x, -5, 22.0 * (1.0 - u / 0.16), 1.0 - u / 0.16,
          [c[3], c[4], c[5], c[6]]);
    }
    if (u >= 0.0 && u < 0.35) {
      lightPool(p, can.x, 1, 50, 8, c[6], 0.5 * (1.0 - u / 0.35));
    }
    lights.draw(p);
  }
}

void _drawCanister(
    Painter p, List<int> k, _Canister c, bool live, double a) {
  final ca = math.cos(c.a);
  final sa = math.sin(c.a);
  p.shade(c.x - _r0 - 2, c.y - _r0 - 2, c.x + _r0 + 2, c.y + _r0 + 2,
      (px, py, out) {
    final dx = px - c.x;
    final dy = py - c.y;
    final d = hypot(dx, dy);
    if (d > _r0 + 1.0) return null;
    out.a = a;
    if (d > _r0) return kExplosionOutline;
    final v = -dx * sa + dy * ca;
    final lit = -(dx * 0.6 + dy * 0.8) / _r0;
    if (v.abs() < 0.9) {
      return _band[lit > 0.3 ? 2 : (lit > -0.4 ? 1 : 0)];
    }
    if (d < _r0 * 0.5 && lit > 0.45) return k[4];
    return k[lit > 0.5 ? 3 : (lit > 0.0 ? 2 : (lit > -0.5 ? 1 : 0))];
  });
  final cx = c.x + sa * _r0;
  final cy = c.y - ca * _r0;
  if (live) {
    p.line(cx, cy, cx + sa * 2.5, cy - ca * 2.5, hex('#8a6a48'), a);
  } else {
    p.dot(cx, cy, k[0], a);
  }
}

const EffectMeta _smokeBombMeta = EffectMeta(
  id: 'explosions/smoke-bomb',
  name: 'Smoke bomb',
  desc:
      'A round canister clinks down, fuse sparking, and pops: thick grey-violet smoke gushes out, rolls along the floor, billows into a cloud that hides all, then thins to wisps.',
  category: 'explosions',
  tags: ['smoke', 'smoke-bomb', 'ninja', 'vanish', 'escape', 'ground', 'one-shot'],
  size: (260, 176),
  origin: (130, 156),
  duration: 5,
  loop: false,
  fps: 30,
  bg: BackdropKind.ground,
  defaultOptions: {
    'palette': [
      '#0e0b14',
      '#1e1828',
      '#30283e',
      '#463c58',
      '#62567a',
      '#867a9e',
      '#aea4c4',
    ],
    'canister': ['#16121e', '#2a2434', '#443c52', '#686078', '#9c94ac'],
    'sparks': ['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d'],
    'seed': 3,
  },
);

final SimulatedEffect smokeBombEffect = SimulatedEffect(
  meta: _smokeBombMeta,
  onCreate: (o) => _SmokeBombSim(_smokeBombMeta, o),
);
