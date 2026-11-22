// The hold-then-break (it closes round the character, holds with glints, cracks, then bursts into tumbling
// pieces, mist and light) is adapted from Sprite Fusion's open-source ice freeze (https://www.spritefusion.com/pixel-art-vfx/ice),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'nature_lib.dart';

const double _sy = 0.34;
const double _cinch = 0.62;
const double _break = 1.75;
const int _np = 48;
const double _dur = 2.7;

const Pose _grab = Pose(
  turn: 0.9,
  crouch: 3,
  fx: -12,
  fy: -34,
  bx: 12,
  by: -28,
  ffx: -2,
  fbx: 3,
);

class _RootPt {
  final double x;
  final double y;
  final double z;
  final double s;

  const _RootPt(this.x, this.y, this.z, this.s);
}

class _Root {
  final double th0;
  final int dir;
  final double turns;
  final double r0;
  final double leg;
  final double h;
  final double at;
  final List<double> buds;
  bool burst = false;

  _Root({
    required this.th0,
    required this.dir,
    required this.turns,
    required this.r0,
    required this.leg,
    required this.h,
    required this.at,
    required this.buds,
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

List<_RootPt> _path(_Root r, double cinch) {
  final pts = <_RootPt>[];
  for (var i = 0; i <= _np; i++) {
    final s = i / _np;
    final th = r.th0 + r.dir * tau * r.turns * s;
    final rad = lerp(
      r.r0,
      r.leg - cinch * 1.6,
      Ease.outCubic(math.min(1.0, s * 3.5)),
    );
    pts.add(_RootPt(
      math.cos(th) * rad,
      -r.h * math.pow(s, 1.05) + math.sin(th) * rad * _sy,
      math.sin(th),
      s,
    ));
  }
  return pts;
}

void _drawRoot(
  Painter p,
  List<_RootPt> pts,
  double g,
  List<int> c,
  bool back,
  double a,
) {
  final n = (_np * g).floor();
  for (var i = 0; i < n; i++) {
    final ptA = pts[i];
    final ptB = pts[i + 1];
    final front = (ptA.z + ptB.z) / 2 >= 0;
    if (front == back) continue;
    final dx = ptB.x - ptA.x;
    final dy = ptB.y - ptA.y;
    final lRaw = hypot(dx, dy);
    final l = lRaw == 0.0 ? 1.0 : lRaw;
    final nx = -dy / l;
    final ny = dx / l;
    final up = nx * -0.6 + ny * -0.8 > 0 ? 1 : -1;
    final w = (1.4 + 3.6 * math.pow(1 - ptA.s, 0.8)) / 2 + 0.35;
    final dim = back ? 1 : 0;
    final y0 = (math.min(ptA.y, ptB.y) - w - 1).floor();
    final y1 = (math.max(ptA.y, ptB.y) + w + 1).ceil();
    final x0 = (math.min(ptA.x, ptB.x) - w - 1).floor();
    final x1 = (math.max(ptA.x, ptB.x) + w + 1).ceil();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (y > 0) continue;
        final px = x + 0.5 - ptA.x;
        final py = y + 0.5 - ptA.y;
        final u = (px * dx + py * dy) / (l * l);
        if (u < -0.2 || u > 1.2) continue;
        final d = px * nx + py * ny;
        if (d.abs() > w) continue;
        final side = d.sign * up;
        final q = d.abs() / w;
        var i2 = q > 0.72
            ? (side > 0 ? 7 : 1)
            : side > 0
                ? (q > 0.3 ? 6 : 5)
                : (q > 0.35 ? 2 : 3);
        if (q < 0.25 && rand((ptA.s * 40 + 0.5).floor(), 3) < 0.4) i2 = 4;
        p.dot(x, y, c[math.max(1, i2 - dim)], a);
      }
    }
    if (i % 7 == 3 && w > 1.2) {
      p.dot(
        ptA.x - nx * up * (w + 1),
        ptA.y - ny * up * (w + 1),
        c[2 - dim],
        a,
      );
    }
  }
}

class _RootSnareSim extends BaseEffectSim {
  final List<int> c;
  final List<int> g;
  final Rng r;
  final Particles ps;
  final Lights lights;
  final List<_Chip> chips = [];
  final List<_Root> roots;
  final List<List<Point2>> cracks;

  double t = 0.0;
  bool cinched = false;
  bool broken = false;

  _RootSnareSim._({
    required this.c,
    required this.g,
    required this.r,
    required this.ps,
    required this.lights,
    required this.roots,
    required this.cracks,
  });

  factory _RootSnareSim(Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final g = fit(o.rampOpt('glow'), 4);
    final r = Rng(o.seed);
    double floorFn(double _) => 0.0;
    final ps = Particles(
      rng: r,
      ground: floorFn,
      sparks: [g[3], g[2], g[1], g[0]],
    );
    final lights = Lights();
    final roots = List.generate(
      5,
      (i) => _Root(
        th0: (i / 5) * tau + r.range(-0.3, 0.3),
        dir: (i % 2) != 0 ? 1 : -1,
        turns: r.range(1.1, 1.6),
        r0: r.range(14, 19),
        leg: r.range(8, 10),
        h: r.range(13, 21),
        at: 0.16 + i * 0.07 + r.range(0, 0.04),
        buds: [r.range(0.35, 0.55), r.range(0.6, 0.85)],
      ),
    );
    final cracks = [
      floorCrack(r, -1, r.range(18, 26)),
      floorCrack(r, 1, r.range(18, 26)),
    ];
    return _RootSnareSim._(
      c: c,
      g: g,
      r: r,
      ps: ps,
      lights: lights,
      roots: roots,
      cracks: cracks,
    );
  }

  double _grow(_Root rt) => Ease.outCubic(clamp((t - rt.at) / 0.32));

  double _squeeze() =>
      smooth(_cinch - 0.03, _cinch + 0.05, t) *
      (1 - 0.4 * smooth(_cinch + 0.05, _cinch + 0.25, t));

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final f = math.min(1.0, dt * 120);
    if (t < 0.4 && r.chance(0.3 * f)) {
      final sd = r.sign();
      ps.spawn(
        P.grit,
        sd * r.range(4, 22),
        -1,
        r.range(-20, 20),
        -r.range(30, 90),
        r.range(0.5, 0.9),
        r.pick([c[5], c[4]]),
        1,
      );
    }
    for (final rt in roots) {
      if (!rt.burst && t >= rt.at) {
        rt.burst = true;
        final x = math.cos(rt.th0) * rt.r0;
        for (var i = 0; i < 4; i++) {
          chips.add(_Chip(
            x: x,
            y: -1,
            vx: r.range(-60, 60),
            vy: -r.range(60, 160),
            a: r.range(0, tau),
            va: r.range(-15, 15),
            s: r.range(1.2, 2),
            pts: stoneShape(r),
            life: r.range(0.6, 0.9),
          ));
        }
        for (var i = 0; i < 3; i++) {
          ps.spawn(
            P.dust,
            x,
            -1,
            r.range(-25, 25),
            -r.range(4, 18),
            r.range(0.4, 0.8),
            c[5],
            r.range(2, 3.5),
          );
        }
        lights.add(x, -4, 20, g[2], 0.35, 0.3);
      }
    }
    if (!cinched && t >= _cinch) {
      cinched = true;
      lights.add(0, -10, 40, g[3], 0.5, 0.3);
      lights.add(0, -10, 16, kWhite, 0.4, 0.06);
      for (var i = 0; i < 8; i++) {
        ps.spawn(
          P.dust,
          r.range(-12, 12),
          -r.range(0, 4),
          r.sign() * r.range(20, 60),
          -r.range(4, 14),
          r.range(0.5, 0.9),
          c[5],
          r.range(2, 3.5),
        );
      }
      for (var i = 0; i < 6; i++) {
        ps.spawn(
          P.star,
          r.range(-9, 9),
          -r.range(4, 20),
          0,
          -4,
          r.range(0.25, 0.5),
          g[3],
          r.range(0.8, 1.8),
          r.range(0, 0.1),
        );
      }
    }
    if (t > _cinch && t < _break && r.chance(0.06 * f)) {
      ps.spawn(
        P.mote,
        r.range(-9, 9),
        -r.range(3, 18),
        r.range(-6, 6),
        -r.range(14, 30),
        r.range(0.5, 0.9),
        g[3],
        0.6,
      );
    }
    if (!broken && t >= _break) {
      broken = true;
      lights.add(0, -10, 36, g[2], 0.4, 0.25);
      for (final rt in roots) {
        final pts = _path(rt, 1);
        for (var i = 2; i < _np; i += 4) {
          final q = pts[i];
          final w = 1.4 + 3.6 * math.pow(1 - q.s, 0.8);
          final dirX = q.x < 0 ? -1 : 1;
          chips.add(_Chip(
            x: q.x,
            y: math.min(q.y, -1.0),
            vx: dirX * r.range(25, 85) + q.x * 3,
            vy: -r.range(50, 150),
            a: r.range(0, tau),
            va: r.range(-10, 10),
            s: clamp(w * 0.75, 1.5, 3),
            pts: stoneShape(r),
            life: math.min(r.range(0.7, 0.95), _dur - 0.05 - t),
          ));
          if (i % 10 == 2) {
            ps.spawn(
              P.grit,
              q.x,
              math.min(q.y, -1.0),
              r.range(-40, 40),
              -r.range(20, 80),
              math.min(r.range(0.6, 0.9), _dur - 0.05 - t),
              r.pick([c[4], c[3], c[2]]),
              r.chance(0.3) ? 2 : 1,
            );
          }
        }
      }
      for (var i = 0; i < 10; i++) {
        ps.spawn(
          P.smoke,
          r.range(-12, 12),
          -r.range(2, 16),
          r.range(-25, 25),
          -r.range(5, 20),
          math.min(r.range(0.6, 0.9), _dur - 0.05 - t),
          c[5],
          r.range(3, 5),
          0,
          0,
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
        if (ch.vy > 110) {
          ch.y = 0;
          ch.vy *= -0.3;
          ch.vx *= 0.5;
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
    final open = Ease.outCubic(clamp(t / 0.25));
    final hot = smooth(0, 0.3, t) * (1 - smooth(0.5, 1.4, t));
    final fade = 1 - smooth(_dur - 0.6, _dur - 0.15, t);
    for (final cr in cracks) {
      final m = math.max(2, (cr.length * open).ceil());
      for (var k = 1; k < m; k++) {
        final (x0, y0) = cr[k - 1];
        final (x1, y1) = cr[k];
        p.line(x0, y0 + 1, x1, y1 + 1, c[0], fade);
        p.line(
          x0,
          y0,
          x1,
          y1,
          hot > 0.5 ? g[3] : (hot > 0.2 ? g[2] : c[1]),
          fade,
        );
        if (k % 2 == 0) p.glow(x1, y1, 6, g[2], 0.3 * hot);
      }
    }
    final hold = smooth(0.3, _cinch, t) *
        (1 - smooth(_break, _break + 0.3, t)) *
        (0.8 + 0.2 * math.sin(t * 8));
    if (hold > 0) {
      p.glow(0, -12, 30, g[2], 0.3 * hold);
      p.glow(0, -1, 22, g[3], 0.16 * hold);
    }
    if (t < _break) {
      for (final rt in roots) {
        if (t > rt.at) {
          _drawRoot(p, _path(rt, _squeeze()), _grow(rt), c, true, 1);
        }
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    if (t < _break) {
      for (final rt in roots) {
        if (t <= rt.at) continue;
        final pts = _path(rt, _squeeze());
        final gr = _grow(rt);
        _drawRoot(p, pts, gr, c, false, 1);
        for (final b in rt.buds) {
          final q = pts[(b * _np).floor()];
          final lk = clamp((t - _cinch - 0.1 - b * 0.2) / 0.25);
          if (b > gr || lk <= 0 || q.z < 0) continue;
          drawLeaf(
            p,
            q.x + 2,
            q.y - 2,
            5 * lk,
            1.6,
            -0.6 + math.sin(t * 5 + b * 9) * 0.2,
            0.3,
            [g[0], g[1], g[2], g[3]],
          );
        }
      }
      final e = t - _cinch;
      if (e > 0 && e < 0.12) {
        for (final (x, y) in const [(-8.0, -6.0), (8.0, -10.0), (-7.0, -15.0)]) {
          sparkle(p, x, y, 5 * (1 - e / 0.12), c[7], g[3], 0.4);
        }
      }
      final w = _break - t;
      if (w > 0 && w < 0.05) {
        for (final rt in roots) {
          for (final q in _path(rt, 1)) {
            if (q.z >= 0) p.px(q.x, q.y, kWhite);
          }
        }
      }
    }
    final bark = [c[0], c[1], c[2], c[2], c[3], c[4], c[5]];
    for (final ch in chips) {
      drawRock(
        p,
        ch.x,
        ch.y,
        ch.s,
        ch.a,
        ch.pts,
        bark,
        math.min(1.0, ch.life / 0.25),
      );
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final PixelEffect rootSnare = SimulatedEffect(
  meta: const EffectMeta(
    id: 'nature/root-snare',
    name: 'Root snare',
    desc:
        'The floor cracks and roots burst up round the character, spiralling round its legs; they cinch tight with a snap, hold, then crack and crumble into bark and dust.',
    category: 'nature',
    tags: [
      'nature',
      'roots',
      'plant',
      'snare',
      'root',
      'status',
      'actor',
      'one-shot',
    ],
    size: (128, 96),
    origin: (64, 78),
    duration: 2.7,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#140c08',
        '#2a1a10',
        '#46301e',
        '#64462a',
        '#86623a',
        '#a8824e',
        '#ccaa70',
        '#ecd6a0',
      ],
      'glow': ['#123818', '#2f7a2a', '#6cb83a', '#c8f070'],
      'seed': 7,
    },
  ),
  act: ActSpec(
    poses: [
      PoseKey(-0.24, kReady.merge(const Pose(ffx: -2, fbx: 3))),
      const PoseKey(
        0.3,
        Pose(
          turn: 0.9,
          lean: -1,
          crouch: 2,
          fx: -10,
          fy: -24,
          bx: 11,
          by: -24,
          ffx: -2,
          fbx: 3,
        ),
      ),
      const PoseKey(0.62, _grab, PoseEase.snap),
      PoseKey(0.86, _grab.merge(const Pose(lean: -3, fy: -37, by: -27))),
      PoseKey(1.1, _grab.merge(const Pose(lean: 3, fy: -27, by: -37))),
      PoseKey(1.34, _grab.merge(const Pose(lean: -3, fy: -37, by: -27))),
      PoseKey(1.58, _grab.merge(const Pose(lean: 3, fy: -27, by: -37))),
      PoseKey(1.75, _grab.merge(const Pose(crouch: 6))),
      const PoseKey(
        1.8,
        Pose(
          turn: 1.1,
          crouch: -1,
          y: -3,
          fx: -14,
          fy: -36,
          bx: 15,
          by: -36,
          ffx: -3,
          ffy: -6,
          fbx: 4,
          fby: -6,
        ),
        PoseEase.snap,
      ),
      PoseKey(2.05, kReady.merge(const Pose(y: 0, crouch: 5))),
      PoseKey(2.7, kReady.merge(const Pose(ffx: -2, fbx: 3))),
    ],
    hits: const [
      HitSpec(t: 0.62, stop: 0.05, shake: 0.1, amp: 1),
      HitSpec(t: 1.75, stop: 0.04, shake: 0.14, amp: 2),
    ],
  ),
  onCreate: _RootSnareSim.new,
);
