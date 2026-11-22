import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'projectiles_lib.dart';

const _homingMissileMeta = EffectMeta(
  id: 'projectiles/homing-missile',
  name: 'Homing missile',
  desc:
      'A missile kicks off, arcs up, rolls over and dives onto its target (the origin), its smoke trail left hanging in the air, and hits in a fiery blast of flame, sparks and rocks.',
  category: 'projectiles',
  tags: [
    'projectile',
    'missile',
    'rocket',
    'homing',
    'smoke',
    'explosion',
    'one-shot',
  ],
  size: (248, 140),
  origin: (160, 120),
  duration: 3.8,
  loop: false,
  fps: 30,
  bg: BackdropKind.ground,
  defaultOptions: {
    'palette': [
      '#4a1712',
      '#8a1f17',
      '#c9281f',
      '#f2561d',
      '#ff8a2a',
      '#ffc23d',
      '#ffe26b',
      '#fff3a6',
      '#ffffff',
    ],
    'metal': ['#25243a', '#3e4058', '#61667f', '#8e97b0', '#c4cce0'],
    'smoke': [
      '#26222e',
      '#3b3644',
      '#544e5e',
      '#6f6979',
      '#8c8596',
      '#aca5b5',
      '#cbc4d2',
    ],
    'stone': '#4a3f69',
    'seed': 8,
  },
);

const _fly = 1.15;
const _path = [
  (-130.0, -22.0),
  (-114.0, -110.0),
  (-30.0, -120.0),
  (0.0, 0.0),
];

(double, double) _pathAt(double u) {
  final v = 1 - u;
  final a = v * v * v;
  final b = 3 * v * v * u;
  final c = 3 * v * u * u;
  final d = u * u * u;
  return (
    a * _path[0].$1 + b * _path[1].$1 + c * _path[2].$1 + d * _path[3].$1,
    a * _path[0].$2 + b * _path[1].$2 + c * _path[2].$2 + d * _path[3].$2,
  );
}

double _heading(double u) {
  final v = 1 - u;
  final dx = 3 * v * v * (_path[1].$1 - _path[0].$1) +
      6 * v * u * (_path[2].$1 - _path[1].$1) +
      3 * u * u * (_path[3].$1 - _path[2].$1);
  final dy = 3 * v * v * (_path[1].$2 - _path[0].$2) +
      6 * v * u * (_path[2].$2 - _path[1].$2) +
      3 * u * u * (_path[3].$2 - _path[2].$2);
  return math.atan2(dy, dx);
}

double _progress(double t) => math.pow(clamp(t / _fly), 1.45).toDouble();

const _missile = [
  'ff..........',
  '.fhhhhhhhre.',
  'nmmmmmmmmrrw',
  '.fsssssssrd.',
  'ff..........',
];

final PixelEffect homingMissileEffect = SimulatedEffect(
  meta: _homingMissileMeta,
  onCreate: _HomingMissileSim.new,
);

class _HomingMissileSim extends BaseEffectSim {
  _HomingMissileSim(Map<String, Object?> o)
      : f = fit(o.palette, 9),
        m = fit(o.rampOpt('metal'), 5),
        sm = fit(o.rampOpt('smoke'), 7),
        r = Rng(o.seed) {
    final st = hex(o.strOpt('stone', '#4a3f69'));
    stoneLight = mix(scaleColor(st, 1.35), kWhite, 0.08);
    stoneBody = st;
    stoneShade = scaleColor(st, 0.64);
    stoneDust = mix(scaleColor(st, 1.2), hex('#968c96'), 0.3);
    ps = Particles(
      rng: r,
      ground: (_) => 0,
      sparks: [f[7], f[6], f[4], f[3]],
    );
    smoke = Smoke(r);
    rocks = Bits(ground: (_) => 0);
    lights = Lights();
    pal = {
      'f': m[1],
      'h': m[4],
      'm': m[3],
      's': m[1],
      'n': m[0],
      'r': f[2],
      'e': f[3],
      'd': f[1],
      'w': kWhite,
    };
    lights.add(_path[0].$1, _path[0].$2, 30, f[4], 0.7, 0.25);
    for (var i = 0; i < 6; i++) {
      smoke.add(SmokePuff(
        x: _path[0].$1 + 2,
        y: _path[0].$2 + 2,
        vx: r.range(-30, 20),
        vy: r.range(-10, 15),
        r0: 2,
        r1: r.range(5, 7.5),
        life: r.range(1.2, 1.8),
        a: 0.6,
        warm: 1,
        rise: 8,
      ));
    }
  }

  final List<int> f;
  final List<int> m;
  final List<int> sm;
  final Rng r;
  late final int stoneLight;
  late final int stoneBody;
  late final int stoneShade;
  late final int stoneDust;
  late final Particles ps;
  late final Smoke smoke;
  late final Bits rocks;
  late final Lights lights;
  late final Map<String, int> pal;
  final Set<DebrisBit> _dusted = Set<DebrisBit>.identity();

  double t = 0;
  double emit = 0;
  bool hit = false;

  void _blast() {
    const y = -6.0;
    lights.add(0, y - 2, 52, hex('#ffb060'), 0.8, 0.8);
    lights.add(0, y - 2, 30, kWhite, 0.75, 0.1);
    for (var i = 0; i < 26; i++) {
      final a = r.range(0, tau);
      final d = r.range(0, 6);
      final sp = r.range(30, 170);
      ps.spawn(
        P.fire,
        math.cos(a) * d,
        y + math.sin(a) * d,
        math.cos(a) * sp,
        math.sin(a) * sp * 0.75 - 40,
        r.range(0.45, 0.95),
        0,
        r.range(3.2, 6.5),
      );
    }
    for (var i = 0; i < 5; i++) {
      ps.spawn(
        P.fire,
        r.range(-3, 3),
        y,
        r.range(-10, 10),
        -r.range(90, 150),
        r.range(0.7, 1.1),
        0,
        r.range(4, 5.5),
        r.range(0, 0.08),
      );
    }
    for (var i = 0; i < 70; i++) {
      final a = r.range(math.pi + 0.12, tau - 0.12);
      final sp = r.range(110, 280);
      ps.spawn(
        P.spark,
        0,
        y,
        math.cos(a) * sp,
        math.sin(a) * sp - 40,
        r.range(0.2, 0.65),
      );
    }
    for (var i = 0; i < 22; i++) {
      final a = r.range(math.pi, tau);
      final sp = r.range(30, 110);
      ps.spawn(
        P.ember,
        math.cos(a) * 4,
        y + math.sin(a) * 4,
        math.cos(a) * sp,
        math.sin(a) * sp - 50,
        r.range(0.9, 1.6),
        f[4],
      );
    }
    for (var i = 0; i < 16; i++) {
      rocks.add(DebrisBit(
        kind: B.chunk,
        x: r.range(-5, 5),
        y: -2,
        vx: r.range(-110, 110),
        vy: -r.range(140, 290),
        g: 1,
        drag: 0.4,
        bounce: 0.3,
        life: r.range(1.5, 2.2),
        a: r.range(0, tau),
        va: r.range(-16, 16),
        s: r.intRange(1, 2).toDouble(),
      ));
    }
    for (var i = 0; i < 60; i++) {
      final u = r.range(-1, 1);
      final a = -math.pi / 2 + u * 0.55;
      final sp = r.range(80, 220) * (1 - 0.4 * u.abs());
      ps.spawn(
        P.grit,
        u * 4,
        -1,
        math.cos(a) * sp,
        math.sin(a) * sp,
        r.range(1, 1.8),
        r.pick([stoneLight, stoneBody, stoneBody, stoneShade]),
        r.chance(0.4) ? 2 : 1,
      );
    }
    for (var i = 0; i < 18; i++) {
      final a = r.range(math.pi * 1.15, math.pi * 1.85);
      final sp = r.range(20, 90);
      smoke.add(SmokePuff(
        x: math.cos(a) * 4,
        y: y + math.sin(a) * 4,
        vx: math.cos(a) * sp * 0.7,
        vy: math.sin(a) * sp - 45 * (i / 18),
        r0: 3,
        r1: r.range(8, 14),
        life: r.range(1.7, 2.2),
        a: 0.62,
        b: 0.88,
        warm: 1,
        rise: 30 + i * 2,
        drag: 1.8,
        delay: r.range(0.05, 0.35),
      ));
    }
    for (var i = 0; i < 12; i++) {
      final s = r.sign();
      smoke.add(SmokePuff(
        x: s * r.range(0, 6),
        y: -3,
        vx: s * r.range(60, 150),
        vy: -r.range(3, 12),
        r0: 2.5,
        r1: r.range(6, 9),
        life: r.range(1.1, 1.7),
        a: 0.5,
        b: 0.75,
        warm: 0.3,
        rise: 6,
        drag: 3,
      ));
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _fly) {
      final u = _progress(t);
      final (x, y) = _pathAt(u);
      final h = _heading(u);
      final cx = math.cos(h);
      final cy = math.sin(h);
      final (px, py) = _pathAt(_progress(math.max(0.0, t - dt)));
      for (emit += hypot(x - px, y - py) / 1.5; emit > 1; emit--) {
        final frac =
            (emit - 1) / math.max(1e-6, hypot(x - px, y - py) / 1.5);
        final ex = x + (px - x) * frac;
        final ey = y + (py - y) * frac;
        smoke.add(SmokePuff(
          x: ex - cx * 7 + r.range(-0.6, 0.6),
          y: ey - cy * 7 + r.range(-0.6, 0.6),
          vx: -cx * r.range(10, 30) + r.range(-6, 6),
          vy: -cy * r.range(10, 30) + r.range(-6, 6),
          r0: 1.4,
          r1: r.range(3.5, 6),
          life: r.range(1.5, 2.3),
          a: 0.5,
          b: 0.9,
          warm: 0.8,
          rise: 4,
          drag: 3,
          grow: 1.2,
        ));
      }
      if (r.chance(0.35)) {
        final a = h + math.pi + r.range(-0.5, 0.5);
        final sp = r.range(40, 140);
        ps.spawn(
          P.spark,
          x - cx * 7,
          y - cy * 7,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.15, 0.35),
        );
      }
    } else if (!hit) {
      hit = true;
      _blast();
    }
    for (final b in rocks.list) {
      if (b.rest && _dusted.add(b)) {
        for (var i = 0; i < 2; i++) {
          ps.spawn(
            P.dust,
            b.x + r.range(-1, 1),
            -0.5,
            r.sign() * r.range(8, 30),
            -r.range(2, 14),
            r.range(0.3, 0.6),
            stoneDust,
            r.range(1.2, 2.2),
          );
        }
      }
    }
    ps.update(dt);
    smoke.update(dt);
    rocks.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    if (hit) {
      final k = t - _fly;
      final fade =
          1 - smooth(_homingMissileMeta.duration - 1, _homingMissileMeta.duration - 0.2, t);
      final rx = 16 * math.min(1.0, k / 0.06);
      for (var y = 0; y <= 2; y++) {
        for (var x = (-rx).floor(); x <= rx.ceil(); x++) {
          final d = hypot((x + 0.5) / rx, (y + 0.5) / 4);
          if (d > 1) continue;
          final tVal = math.pow(clamp(1 - k / 1.4), 1.4) * (1.25 - d) -
              rand(x * 31 + y, 3) * 0.35;
          p.dot(
            x.toDouble(),
            y.toDouble(),
            tVal > 0.06
                ? f[math.max(1, math.min(8, (tVal * 8 + 0.5).floor()))]
                : d < 0.5
                    ? hex('#0d0a12')
                    : hex('#17121d'),
            fade,
          );
        }
      }
      final q = k / 0.45;
      if (q < 1) {
        band(
          p,
          0,
          0.5,
          60 * (1 - math.pow(1 - q, 3)).toDouble(),
          0.16,
          math.max(1.0, 4 * (1 - q)),
          1.15 - q,
          [stoneBody, stoneLight, f[4], f[7]],
          keep: (g) => math.sin(g) < 0,
        );
      }
    }
  }

  @override
  void draw(Painter p) {
    final list = smoke.puffs();
    cloud(
      p,
      list,
      sm,
      [
        sm[0],
        mix(f[1], sm[1], 0.5),
        mix(f[2], sm[2], 0.4),
        f[3],
        f[4],
        f[6],
        f[7],
      ],
      dens: 1.4,
      max: 0.82,
      lit: 1.4,
    );
    if (hit) {
      final q = (t - _fly) / 0.45;
      if (q < 1) {
        band(
          p,
          0,
          0.5,
          60 * (1 - math.pow(1 - q, 3)).toDouble(),
          0.16,
          math.max(1.0, 4 * (1 - q)),
          1.15 - q,
          [stoneBody, stoneLight, f[4], f[7]],
          keep: (g) => math.sin(g) >= 0,
        );
      }
    }
    for (final b in rocks.list) {
      final rVal = 0.6 + b.s * 0.75;
      final fade = math.min(1.0, b.life / 0.5);
      final lx = math.cos(b.a) * rVal * 0.4;
      final ly = math.sin(b.a) * rVal * 0.4;
      p.shade(
        b.x - rVal - 1,
        b.y - rVal - 1,
        b.x + rVal + 1,
        b.y + rVal + 1,
        (x, y, out) {
          final dx = x - b.x;
          final dy = y - b.y;
          final d = hypot(dx * 1.15, dy);
          if (d > rVal + 0.9) return null;
          final lit = dx * lx + dy * ly;
          out.c = d > rVal
              ? hex('#1a1422')
              : lit < -0.4
                  ? stoneLight
                  : lit > 0.6
                      ? stoneShade
                      : stoneBody;
          out.a = fade;
          return null;
        },
      );
    }
    ps.draw(p);
    if (t < _fly) {
      final u = _progress(t);
      final (x, y) = _pathAt(u);
      final h = _heading(u);
      final cx = math.cos(h);
      final cy = math.sin(h);
      final fr = (t * 30).floor();
      final j = 5 + 3 * rand(fr, 7);
      for (var d = 0.0; d <= j; d += 0.5) {
        final v = d / j;
        final c = v < 0.3
            ? kWhite
            : v < 0.6
                ? f[6]
                : f[4];
        p.dot(x - cx * (6.5 + d), y - cy * (6.5 + d), c);
        if (v < 0.5) {
          p.dot(
            x - cx * (6.5 + d) - cy * 0.8,
            y - cy * (6.5 + d) + cx * 0.8,
            f[5],
          );
        }
      }
      turnSprite(p, _missile, pal, x, y, h, 6, 2.5);
      p.glow(x - cx * 8, y - cy * 8, 18, f[4], 0.5);
      p.glow(x - cx * 7, y - cy * 7, 6, f[7], 0.5);
    }
    final k = t - _fly;
    if (k >= 0 && k < 0.07) {
      final rVal = 14 * (0.8 + 0.2 * (1 - k / 0.07));
      p.circle(0, -6, rVal + 1.2, f[3]);
      p.circle(0, -6, rVal, k < 0.035 ? f[7] : f[6]);
      p.circle(0, -6, rVal * 0.6, k < 0.035 ? kWhite : f[7]);
    }
    if (k >= 0 && k < 0.3) {
      final rr = 8 + 30 * (1 - math.pow(1 - k / 0.3, 3));
      p.ringShaded(
        0,
        -6,
        rr,
        math.max(1.0, 2.5 * (1 - k / 0.3) + 0.4),
        color: (_, _) => f[5],
        alpha: (_, ang) => (-6 + math.sin(ang) * rr > 0
            ? 0.0
            : math.min(1.0, (1 - k / 0.3) * 1.6)),
      );
    }
    lights.draw(p);
  }
}
