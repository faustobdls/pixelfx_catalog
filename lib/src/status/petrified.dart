// The creeping front, the branching cracks and the burst of the body into chunks, grit and dust are
// adapted from Sprite Fusion's open-source ice freeze and shatter (https://www.spritefusion.com/pixel-art-vfx/ice),
// MIT License, Copyright (c) 2026 Hugo Duprez.
import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'status_lib.dart';

const double _creep = 0.95;
const double _crack = 1.75;
const double _shatter = 2.2;

const Pose _reach = Pose(
  lean: 3,
  crouch: 2,
  fx: 14,
  fy: -29,
  bx: -4,
  by: -22,
  ffx: 8,
  fbx: -7,
  toeB: true,
);

double _level(double t) => t >= _creep
    ? 1.2
    : 1.2 * smooth(0.0, _creep, t) + 0.025 * math.sin((t / _creep) * tau * 3.0);

class _StonePx {
  final int x;
  final int y;
  final double up;
  final int c;
  const _StonePx(this.x, this.y, this.up, this.c);
}

class _PetrifiedSim extends BaseEffectSim {
  final List<int> c;
  final ActorDefinition a;
  final ActorShape s;
  final int h;
  final int seed;
  final Rng r;
  late final Particles ps;
  late final Bits bits;
  late final Lights lights;
  late final List<_StonePx> stone;
  final List<List<(double x, double y)>> cracks = [];
  late final int ox;
  late final int oy;
  final Set<DebrisBit> _dusted = Set<DebrisBit>.identity();
  double t = 0.0;
  bool broke = false;
  bool settled = false;

  _PetrifiedSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        a = o.actor,
        s = actorShape(o.actor),
        h = actorShape(o.actor).h,
        seed = o.seed,
        r = Rng(o.seed) {
    double floorFn(double x) => 0.0;
    ps = Particles(rng: r, ground: floorFn, sparks: [c[7], c[6], c[5], c[4]]);
    bits = Bits(ground: floorFn);
    lights = Lights();

    stone = [
      for (final (x, y) in s.body)
        () {
          final tone = clamp((luma(colorAt(a, x, y)) - 0.06) / 0.78);
          final mottle = tileFbm(x * 0.32, y * 0.32, 0, 0, seed + 5, 2);
          var i = 1 + (tone * 4.6 + mottle * 1.1 + 0.5).floor();
          if (!s.on(x - 1, y) || !s.on(x, y - 1)) {
            i += 1;
          } else if (!s.on(x + 1, y) || !s.on(x, y + 1)) {
            i -= 1;
          }
          return _StonePx(x, y, 1.0 - (y + 0.5) / h, c[clampInt(i, 1, 6)]);
        }(),
    ];

    ox = (s.w * 0.55 + 0.5).floor();
    oy = (h * 0.42 + 0.5).floor();

    void walk(double x, double y, double ang, double len) {
      final pts = <(double, double)>[(x, y)];
      for (var step = 0; step < len; step++) {
        ang += r.range(-0.55, 0.55);
        x += math.cos(ang) * r.range(1.4, 2.4);
        y += math.sin(ang) * r.range(1.4, 2.4);
        if (!s.on(x.floor(), y.floor())) break;
        pts.add((x, y));
        if (pts.length > 3 && cracks.length < 16 && r.chance(0.14)) {
          walk(x, y, ang + r.sign() * r.range(0.6, 1.2), len / 2.0);
        }
      }
      cracks.add(pts);
    }

    for (var i = 0; i < 7; i++) {
      walk(
        ox.toDouble(),
        oy.toDouble(),
        (i / 7.0) * tau + r.range(-0.3, 0.3),
        14.0,
      );
    }
  }

  double _front(int mx) =>
      _level(t) + 0.06 * tileFbm(mx * 0.4, 0.5, 0, 0, seed, 2);

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _creep) {
      final rate = 60.0 * dt;
      for (var n = 0; n < rate; n++) {
        if (!r.chance(0.5)) continue;
        final (mx, my) = s.body[r.intRange(0, s.body.length - 1)];
        if ((1.0 - (my + 0.5) / h - _front(mx)).abs() > 0.04) continue;
        final x = a.x + mx + 0.5;
        final y = a.y + my.toDouble();
        final side = mx < s.w / 2.0 ? -1 : 1;
        ps.spawn(
          P.grit,
          x,
          y,
          side * r.range(15.0, 60.0),
          -r.range(30.0, 90.0),
          r.range(0.6, 1.1),
          r.pick([c[4], c[5], c[6]]),
          r.chance(0.3) ? 2.0 : 1.0,
        );
        if (r.chance(0.3)) {
          ps.spawn(
            P.dust,
            x + side * 2.0,
            y,
            side * r.range(10.0, 30.0),
            -r.range(4.0, 14.0),
            r.range(0.4, 0.7),
            c[4],
            r.range(1.5, 2.6),
          );
        }
        if (r.chance(0.25)) {
          ps.spawn(
            P.mote,
            x,
            y,
            side * r.range(40.0, 90.0),
            -r.range(20.0, 70.0),
            r.range(0.15, 0.3),
            c[7],
            0.5,
          );
        }
      }
    }

    if (!settled && t >= _creep) {
      settled = true;
      lights.add(0.0, a.y + h * 0.5, 34.0, c[6], 0.35, 0.3);
      for (var i = 0; i < 8; i++) {
        ps.spawn(
          P.dust,
          r.range(-8.0, 8.0),
          -r.range(0.0, 2.0),
          r.sign() * r.range(20.0, 50.0),
          -r.range(2.0, 10.0),
          r.range(0.6, 1.0),
          c[3],
          r.range(2.0, 3.5),
        );
      }
    }

    if (t > _creep + 0.2 && t < _shatter && r.chance(1.6 * dt)) {
      final (mx, my) = s.body[r.intRange(0, s.body.length - 1)];
      if (!s.on(mx, my + 1)) {
        ps.spawn(
          P.grit,
          a.x + mx + 0.5,
          a.y + my + 1.0,
          r.range(-8.0, 8.0),
          0.0,
          r.range(0.8, 1.2),
          c[3],
          1.0,
        );
      }
    }

    if (t >= _crack && t < _shatter && r.chance(12.0 * dt)) {
      final pts = r.pick(cracks);
      final (x, y) = pts[(r.next() * pts.length).floor()];
      ps.spawn(
        P.grit,
        a.x + x,
        a.y + y,
        r.range(-40.0, 40.0),
        -r.range(30.0, 80.0),
        r.range(0.5, 0.9),
        r.pick([c[5], c[6]]),
        1.0,
      );
    }

    if (!broke && t >= _shatter) {
      broke = true;
      lights.add(0.0, a.y + h * 0.45, 46.0, c[6], 0.7, 0.5);
      lights.add(0.0, a.y + h * 0.45, 30.0, kWhite, 0.7, 0.12);
      final cx = a.x + ox.toDouble();
      final cy = a.y + oy.toDouble();
      for (var i = 0; i < 18; i++) {
        final q = stone[r.intRange(0, stone.length - 1)];
        final x = a.x + q.x + 0.5;
        final y = a.y + q.y + 0.5;
        final dx = x - cx;
        final dy = y - cy;
        final rawD = hypot(dx, dy);
        final d = rawD == 0.0 ? 1.0 : rawD;
        final sp = r.range(35.0, 110.0);
        bits.add(DebrisBit(
          kind: B.chunk,
          x: x,
          y: y,
          vx: (dx / d) * sp,
          vy: (dy / d) * sp * 0.6 - r.range(60.0, 160.0),
          g: 1.0,
          drag: 0.4,
          bounce: 0.3,
          life: r.range(1.1, 1.5),
          a: r.range(0.0, tau),
          va: r.range(-14.0, 14.0),
          s: r.range(1.3, 2.8),
          rampColors: [c[0], c[2], c[3], c[5], c[6]],
        ));
      }
      for (final q in stone) {
        if (rand(q.x, q.y, 9) > 0.22) continue;
        final x = a.x + q.x + 0.5;
        final y = a.y + q.y + 0.5;
        final dx = x - cx;
        final dy = y - cy;
        final rawD = hypot(dx, dy);
        final d = rawD == 0.0 ? 1.0 : rawD;
        final sp = r.range(40.0, 130.0);
        ps.spawn(
          P.grit,
          x,
          y,
          (dx / d) * sp,
          (dy / d) * sp * 0.6 - r.range(40.0, 140.0),
          r.range(0.9, 1.4),
          q.c,
          r.chance(0.35) ? 2.0 : 1.0,
        );
      }
      for (var i = 0; i < 16; i++) {
        final an = -math.pi / 2.0 + r.range(-1.4, 1.4);
        final sp = r.range(50.0, 120.0);
        bits.add(DebrisBit(
          kind: B.shard,
          x: cx + r.range(-5.0, 5.0),
          y: cy + r.range(-8.0, 8.0),
          vx: math.cos(an) * sp,
          vy: math.sin(an) * sp,
          g: 0.8,
          drag: 0.6,
          bounce: 0.3,
          life: r.range(0.9, 1.4),
          a: r.range(0.0, tau),
          va: r.range(-18.0, 18.0),
          s: r.range(1.5, 3.0),
          c: r.pick([c[5], c[6], c[7]]),
        ));
      }
      for (var i = 0; i < 6; i++) {
        ps.spawn(
          P.star,
          cx + r.range(-12.0, 12.0),
          cy + r.range(-10.0, 14.0),
          r.range(-10.0, 10.0),
          -r.range(5.0, 20.0),
          r.range(0.4, 0.9),
          c[6],
          r.range(1.0, 2.2),
          r.range(0.05, 0.4),
        );
      }
      for (var i = 0; i < 12; i++) {
        final side = r.sign();
        ps.spawn(
          P.smoke,
          side * r.range(0.0, 8.0),
          -r.range(1.0, 6.0),
          side * r.range(20.0, 60.0),
          -r.range(4.0, 16.0),
          r.range(0.9, 1.4),
          c[4],
          r.range(2.4, 4.0),
          r.range(0.0, 0.08),
          0,
        );
      }
      for (var i = 0; i < 6; i++) {
        ps.spawn(
          P.smoke,
          r.range(-6.0, 6.0),
          a.y + h * r.range(0.3, 0.8),
          r.range(-20.0, 20.0),
          -r.range(10.0, 30.0),
          r.range(1.0, 1.5),
          c[3],
          r.range(3.0, 4.5),
          r.range(0.0, 0.1),
          0,
        );
      }
    }

    bits.update(dt);
    for (final b in bits.list) {
      if (b.rest && _dusted.add(b)) {
        ps.spawn(
          P.dust,
          b.x,
          -0.5,
          r.range(-20.0, 20.0),
          -r.range(2.0, 10.0),
          r.range(0.3, 0.6),
          c[3],
          r.range(1.2, 2.2),
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    if (t < _shatter) {
      final sh = t >= _crack
          ? (math.sin(t * 90.0) *
                      math.min(1.0, (t - _crack) / (_shatter - _crack)) *
                      1.2 +
                  0.5)
              .floor()
          : 0;
      final white = t > _shatter - 0.035;
      final ft = (t * 24.0).floor();
      for (final q in stone) {
        final f = _front(q.x);
        final d = f - q.up;
        if (d < 0.0) continue;
        final x = a.x + q.x + sh;
        final y = a.y + q.y;
        if (d < 0.035 && t < _creep) {
          p.px(x, y, rand(q.x, q.y, ft) < 0.5 ? c[7] : c[6]);
        } else if (d < 0.07 && t < _creep) {
          p.px(x, y, c[5]);
        } else {
          p.px(x, y, white ? kWhite : q.c);
        }
      }
      if (t < _creep) {
        for (var mx = 0; mx < s.w; mx += 2) {
          final my = ((1.0 - _front(mx)) * h).floor();
          if (s.on(mx, my)) p.glow(a.x + mx, a.y + my, 5, c[6], 0.18);
        }
      }
      if (t >= _crack) {
        final k = clamp((t - _crack) / 0.3);
        for (final pts in cracks) {
          final n = (pts.length * k).floor();
          for (var i = 0; i < n; i++) {
            final (x, y) = pts[i];
            final px = (a.x + x).floor() + sh;
            final py = (a.y + y).floor();
            final fresh = i > n - 3;
            p.px(px, py, fresh ? kWhite : c[0]);
            if (!fresh) p.px(px, py - 1, c[6]);
          }
        }
        p.glow(a.x + ox, a.y + oy, 12, c[6], 0.25 * k);
      }
    }
    bits.draw(p);
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect petrifiedEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'status/petrified',
    name: 'Petrified',
    desc:
        'Turned to stone: grey creeps up from the feet behind a crackling edge that spits grit, the statue holds, cracks run through it, and it bursts into tumbling chunks and dust.',
    category: 'status',
    tags: [
      'status', 'stone', 'petrify', 'petrified', 'debuff', 'death', 'one-shot',
    ],
    size: (120, 74),
    origin: (60, 64),
    duration: 3.8,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#16141c', '#2a2733', '#433f4d', '#5f5a6a',
        '#7d7889', '#a29dab', '#cdc8d2', '#f0edf3',
      ],
      'seed': 3,
    },
  ),
  act: const ActSpec(
    onBody: true,
    poses: [
      PoseKey(-0.16, kReady),
      PoseKey(
        0.08,
        Pose(turn: 0.9, lean: -1, crouch: 2, fx: -8, fy: -24, bx: 9, by: -24),
        PoseEase.snap,
      ),
      PoseKey(0.5, _reach),
      PoseKey(0.95, _reach),
      PoseKey(3.8, _reach),
    ],
    hits: [HitSpec(t: 2.2, stop: 0.08, shake: 0.24, amp: 2)],
  ),
  onActorAlpha: (t, _) => t < _creep ? 1.0 : 0.0,
  onCreate: (o) => _PetrifiedSim(o),
);
