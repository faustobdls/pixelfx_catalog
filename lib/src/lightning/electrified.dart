// Arcs leaping between points of the silhouette's edge, re-struck every other frame, grounding to the floor, and
// the periodic jolt that throws sparks follow Sprite Fusion's open-source lightning crackle
// (https://www.spritefusion.com/pixel-art-vfx/lightning), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'lightning_lib.dart';

const Pose _tense = Pose(
  turn: 0.9,
  crouch: 3,
  fx: -8,
  fy: -17,
  bx: 9,
  by: -17,
  ffx: -3,
  fbx: 4,
);

const Pose _joltA = Pose(
  turn: 1.1,
  crouch: 0,
  y: -1,
  fx: -13,
  fy: -36,
  bx: 13,
  by: -17,
  ffx: -4,
  fbx: 5,
);

const Pose _joltB = Pose(
  turn: 0.7,
  crouch: 1,
  y: -1,
  fx: -13,
  fy: -16,
  bx: 13,
  by: -36,
  ffx: -4,
  fbx: 5,
);

const ActSpec _act = ActSpec(
  onBody: true,
  poses: [
    PoseKey(0.0, _tense),
    PoseKey(0.1, _joltA, PoseEase.snap),
    PoseKey(0.17, _joltB, PoseEase.snap),
    PoseKey(0.3, _tense, PoseEase.snap),
    PoseKey(0.733, _tense),
    PoseKey(0.733, _joltB, PoseEase.snap),
    PoseKey(0.8, _joltA, PoseEase.snap),
    PoseKey(0.93, _tense, PoseEase.snap),
    PoseKey(1.367, _tense),
    PoseKey(1.367, _joltA, PoseEase.snap),
    PoseKey(1.45, _joltB, PoseEase.snap),
    PoseKey(1.58, _tense, PoseEase.snap),
    PoseKey(2.0, _tense),
  ],
);

const int _fps = 30;
const int _n = 60;
const double _period = 2.0;
const List<(int f0, double k)> _jolts = [(3, 1.0), (22, 0.7), (41, 0.9)];

final Expando<List<Point2>> _edges = Expando<List<Point2>>();

List<Point2> _edgeOf(ActorDefinition a) {
  var e = _edges[a.mask];
  if (e != null) return e;
  final m = a.mask;
  bool on(int x, int y) =>
      x >= 0 && y >= 0 && x < m.w && y < m.h && m.data[y * m.w + x] != 0;
  e = <Point2>[];
  for (var y = 0; y < m.h; y++) {
    for (var x = 0; x < m.w; x++) {
      if (on(x, y) &&
          (!on(x - 1, y) || !on(x + 1, y) || !on(x, y - 1) || !on(x, y + 1))) {
        e.add((a.x + x + 0.5, a.y + y + 0.5));
      }
    }
  }
  _edges[a.mask] = e;
  return e;
}

({int a, double k})? _joltAt(int f) {
  for (final (f0, k) in _jolts) {
    if (f >= f0 && f < f0 + 3) return (a: f - f0, k: k);
  }
  return null;
}

final PureEffect electrifiedEffect = PureEffect(
  meta: const EffectMeta(
    id: 'lightning/electrified',
    name: 'Electrified',
    desc:
        'Current runs through a character: arcs crawl over and leap across the body, sparks spit off, the body flares to an electric silhouette on each jolt, and the feet ground out.',
    category: 'lightning',
    tags: ['lightning', 'electric', 'status', 'shock', 'stun', 'actor', 'loop'],
    size: (108, 92),
    origin: (54, 76),
    duration: 2.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': voltPalette,
      'sparks': plasmaSparks,
      'seed': 5,
    },
  ),
  act: _act,
  onDrawBack: (Painter p, double t, Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final a = o['actor'] as ActorDefinition;
    final f = (t * _fps + 1e-6).floor() % _n;
    final j = _joltAt(f);
    final r = rng(o.seed, 4, f);
    p.outline(
      a.mask,
      a.x,
      a.y,
      j != null ? c[4] : (r.next() < 0.5 ? c[2] : c[1]),
    );
    p.glow(0, -18, 30, c[3], j != null ? 0.55 * j.k : 0.16 + 0.1 * r.next());
    p.glow(0, -2, 22, c[4], 0.18);
  },
  onDraw: (Painter p, double t, Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final s = (o['sparks'] as List).cast<Object>().map(hex).toList(growable: false);
    final seed = o.seed;
    final a = o['actor'] as ActorDefinition;
    final e = _edgeOf(a);
    final f = (t * _fps + 1e-6).floor() % _n;
    final j = _joltAt(f);

    if (j != null) {
      final lift = const [1.1, 0.6, -0.2][j.a] * j.k;
      final rampCols = [c[1], c[2], c[3], c[4], c[5], c[6], c[7]];
      for (var y = 0; y < a.h; y++) {
        for (var x = 0; x < a.w; x++) {
          final col = a.pixels[y * a.w + x];
          if (col != 0) {
            p.px(
              a.x + x,
              a.y + y,
              rampCols[clampInt(jsRound(0.4 + luma(col) * 6.0 + lift), 0, 6)],
            );
          }
        }
      }
      p.glow(0, -19, 26, c[5], 0.5 * j.k * (1.0 - j.a / 3.0));
    }

    final r = rng(seed, 7, f >> 1);
    final n = 2 + (j != null ? 2 : r.intRange(0, 1));
    for (var i = 0; i < n; i++) {
      final ptA = r.pick(e);
      final ang = r.range(0.0, tau);
      final d = r.range(6.0, 14.0);
      var ptB = (ptA.$1 + math.cos(ang) * d, ptA.$2 + math.sin(ang) * d);
      for (var k = 0; k < 10; k++) {
        final ptC = r.pick(e);
        if (hypot(ptC.$1 - ptB.$1, ptC.$2 - ptB.$2) < 5.0 &&
            hypot(ptC.$1 - ptA.$1, ptC.$2 - ptA.$2) > 4.0) {
          ptB = ptC;
        }
      }
      final k = ((f & 1) != 0 ? 0.75 : 0.95) * r.range(0.6, 1.0);
      crackle(
        p,
        zigzag(rng(seed, 8, f, i), ptA.$1, ptA.$2, ptB.$1, ptB.$2, 0.42, 0.35),
        k,
        c,
        0.4,
      );
      for (final (ex, ey) in e) {
        if (hypot(ex - ptA.$1, ey - ptA.$2) < 3.5 ||
            hypot(ex - ptB.$1, ey - ptB.$2) < 3.0) {
          p.px(ex - 0.5, ey - 0.5, c[5]);
        }
      }
    }

    if (r.next() < (j != null ? 0.9 : 0.35)) {
      final sg = r.sign();
      final x0 = sg * r.range(3.0, 8.0);
      crackle(
        p,
        zigzag(rng(seed, 9, f), x0, -1.5, x0 + sg * r.range(5.0, 12.0), -0.5,
            0.45, 0.3),
        0.7,
        c,
        0.35,
      );
      p.glow(x0, -1, 10, c[5], 0.35);
    }

    for (final (f0, k) in _jolts) {
      final age = (((t - f0 / _fps) % _period) + _period) % _period;
      for (var i = 0; i < 9; i++) {
        final q = rng(seed, 21, f0, i);
        final life = q.range(0.18, 0.4);
        if (age >= life) continue;
        final (x0, y0) = e[(q.next() * e.length).floor()];
        final ang = math.atan2(y0 + 19.0, x0) + q.range(-0.7, 0.7);
        final sp = q.range(60.0, 150.0) * k;
        final (x, y, vx, vy) = lightningFlight(
          x0,
          y0,
          math.cos(ang) * sp,
          math.sin(ang) * sp - 30.0,
          age,
          floor: 0.0,
        );
        lightningSpark(p, x, y, vx, vy, 1.0 - age / life, s);
      }
    }

    cycle(t, _period, 8, seed + 3, (g) => g.range(0.15, 0.3), (age, life, q, _) {
      final (x0, y0) = e[(q.next() * e.length).floor()];
      final ang = math.atan2(y0 + 19.0, x0) + q.range(-0.6, 0.6);
      final sp = q.range(50.0, 110.0);
      final (x, y, vx, vy) = lightningFlight(
        x0,
        y0,
        math.cos(ang) * sp,
        math.sin(ang) * sp - 20.0,
        age,
        floor: 0.0,
      );
      lightningSpark(p, x, y, vx, vy, 1.0 - age / life, s);
    });
  },
);
