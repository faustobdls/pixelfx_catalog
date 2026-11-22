// The ground's part (grit thrown up that bounces and settles, stones that tumble and kick up dust where they land,
// dust rolling out along the floor and climbing) is adapted from Sprite Fusion's open-source explosion
// (https://www.spritefusion.com/pixel-art-vfx/explosion), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'nature_lib.dart';

const List<double> _jolts = [0.06, 0.5, 0.92];
const double _close = 2.2;
const double _dur = 3.1;

class _Slab {
  final double x;
  double y = 0.0;
  double vy = 0.0;
  double a = 0.0;
  double va = 0.0;
  bool rest = true;
  final double s;
  final int side;
  final List<Point2> pts;

  _Slab({
    required this.x,
    required this.s,
    required this.side,
    required this.pts,
  });
}

class _QuakeSim extends BaseEffectSim {
  final List<int> s;
  final List<int> g;
  final Rng r;
  final double reach;
  final int dust;
  final int dust2;
  final Particles ps;
  final Bits bits;
  final Lights lights;
  final List<Point2> rift;
  final List<_Slab> slabs;

  double t = 0.0;
  int j = 0;

  _QuakeSim._({
    required this.s,
    required this.g,
    required this.r,
    required this.reach,
    required this.dust,
    required this.dust2,
    required this.ps,
    required this.bits,
    required this.lights,
    required this.rift,
    required this.slabs,
  });

  factory _QuakeSim(Map<String, Object?> o) {
    final s = fit(o.palette, 8);
    final g = fit(o.rampOpt('glow'), 5);
    final r = Rng(o.seed);
    double floorFn(double _) => 0.0;
    final reach = o.numOpt('reach', 118.0);
    final dust = mix(s[6], hex('#8c8494'), 0.4);
    final dust2 = mix(s[5], hex('#6c6474'), 0.35);
    final ps = Particles(
      rng: r,
      ground: floorFn,
      sparks: [g[4], g[3], g[2], g[1]],
    );
    final bits = Bits(ground: floorFn);
    final lights = Lights();
    final rift = <Point2>[];
    for (var x = -reach; x <= reach; x += r.range(2.5, 5)) {
      rift.add((x, r.intRange(0, 2).toDouble()));
    }
    final slabs = <_Slab>[];
    for (var x = -reach + 8; x < reach - 6; x += r.range(12, 17)) {
      slabs.add(_Slab(
        x: x + r.range(-2, 2),
        s: r.range(4.5, 6),
        side: r.sign(),
        pts: const [(-1, -0.38), (1, -0.42), (1.02, 0.4), (-0.98, 0.38)],
      ));
    }
    return _QuakeSim._(
      s: s,
      g: g,
      r: r,
      reach: reach,
      dust: dust,
      dust2: dust2,
      ps: ps,
      bits: bits,
      lights: lights,
      rift: rift,
      slabs: slabs,
    );
  }

  double _open() =>
      Ease.outCubic(clamp((t - _jolts[0]) / 0.45)) *
      reach *
      (0.55 + 0.45 * smooth(_jolts[1], _jolts[1] + 0.3, t));

  double _gap(double x) =>
      (1 - smooth(_close, _close + 0.5, t)) *
      (1 + 2.6 * (1 - x.abs() / reach)) *
      (0.6 + 0.4 * smooth(_jolts[1], _jolts[2] + 0.2, t));

  double _heat() =>
      smooth(0, 0.3, t) *
      (1 - smooth(1.4, _close + 0.3, t)) *
      (0.8 + 0.2 * math.sin(t * 17));

  double _shake() {
    var acc = 0.0;
    for (var i = 0; i < _jolts.length; i++) {
      final tj = _jolts[i];
      if (t > tj) {
        acc +=
            math.exp(-(t - tj) * 9) * math.sin((t - tj) * 80) * (1.6 - i * 0.3);
      }
    }
    return acc;
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final f = math.min(1.0, dt * 120);
    while (j < _jolts.length && t >= _jolts[j]) {
      final k = 1 - j * 0.2;
      final l = _open() + 10;
      j++;
      lights.add(0, -2, 60, g[2], 0.5 * k, 0.5);
      lights.add(0, -2, 26, kWhite, 0.4 * k, 0.07);
      for (final sl in slabs) {
        final d = sl.x.abs() / reach;
        if (sl.x.abs() > l || r.chance(0.25 + d * 0.3)) continue;
        sl.rest = false;
        sl.vy = -r.range(70, 170) * k * (1 - d * 0.5);
        sl.va = sl.side * r.range(3, 8);
      }
      for (var i = 0; i < 70 * k; i++) {
        final x = r.range(-l, l);
        final a = -math.pi / 2 + r.range(-0.6, 0.6);
        final sp = r.range(40, 200) * k;
        ps.spawn(
          P.grit,
          x,
          -1,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.6, 1.2),
          r.pick([s[7], s[6], s[5], s[4]]),
          r.chance(0.35) ? 2 : 1,
        );
      }
      for (var i = 0; i < 8 * k; i++) {
        final x = r.range(-l, l) * 0.8;
        final a = -math.pi / 2 + r.range(-0.9, 0.9);
        final sp = r.range(100, 230) * k;
        bits.add(RockBit(
          kind: B.chunk,
          x: x,
          y: -2,
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp,
          g: 1,
          drag: 0.5,
          bounce: 0.3,
          life: math.min(r.range(1.1, 1.6), _dur - 0.1 - t),
          a: r.range(0, tau),
          va: r.range(-14, 14),
          s: r.range(1.6, 3.2),
          pts: stoneShape(r),
        ));
      }
      for (var i = 0; i < 14 * k; i++) {
        final x = r.range(-l, l) * 0.9;
        ps.spawn(
          P.smoke,
          x,
          -r.range(1, 4),
          r.range(-40, 40),
          -r.range(15, 55) * k,
          r.range(1, 1.7),
          r.chance(0.5) ? dust : dust2,
          r.range(4, 7) * k,
          r.range(0, 0.15),
          PF.big,
        );
      }
      for (var i = 0; i < 10 * k; i++) {
        final x = r.range(-l, l) * 0.7;
        final a = -math.pi / 2 + r.range(-1, 1);
        final sp = r.range(120, 300);
        ps.spawn(
          P.spark,
          x,
          -1,
          math.cos(a) * sp,
          math.sin(a) * sp,
          r.range(0.12, 0.3),
        );
      }
    }
    if (t > _jolts[0] && t < _close && r.chance(0.3 * f)) {
      final x = r.range(-1, 1) * _open();
      ps.spawn(
        P.grit,
        x,
        -1,
        r.range(-20, 20),
        -r.range(20, 70),
        r.range(0.5, 0.8),
        r.pick([s[6], s[5]]),
        1,
      );
      if (r.chance(0.3)) {
        ps.spawn(
          P.ember,
          x,
          -1,
          r.range(-10, 10),
          -r.range(20, 45),
          math.min(r.range(0.6, 1.2), _dur - 0.1 - t),
          g[3],
          1,
        );
      }
      if (r.chance(0.25)) {
        ps.spawn(
          P.dust,
          x,
          -1,
          r.range(-15, 15),
          -r.range(4, 14),
          r.range(0.5, 0.8),
          dust2,
          r.range(2, 3.5),
        );
      }
    }
    for (final sl in slabs) {
      if (sl.rest) continue;
      sl.vy += 950 * dt;
      sl.y += sl.vy * dt;
      sl.a += sl.va * dt;
      if (sl.y >= 0 && sl.vy > 0) {
        sl.y = 0;
        sl.a = clamp(sl.a, -0.45, 0.45);
        if (sl.vy > 160) {
          sl.vy *= -0.25;
          sl.va *= -0.4;
        } else {
          sl.rest = true;
          for (var i = 0; i < 3; i++) {
            ps.spawn(
              P.dust,
              sl.x + r.range(-5, 5),
              -0.5,
              r.sign() * r.range(10, 40),
              -r.range(2, 12),
              r.range(0.4, 0.7),
              dust2,
              r.range(1.5, 3),
            );
          }
        }
      }
    }
    bits.update(dt);
    for (final b in bits.list) {
      if (b is RockBit && b.rest && !b.dusted) {
        b.dusted = true;
        ps.spawn(
          P.dust,
          b.x,
          -0.5,
          r.sign() * r.range(8, 30),
          -r.range(2, 10),
          math.min(r.range(0.3, 0.6), _dur - 0.1 - t),
          dust2,
          r.range(1.3, 2.4),
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final l = _open();
    final hk = _heat();
    final jx = _shake();
    final fade = 1 - smooth(_close + 0.3, _close + 0.7, t);
    if (t > _jolts[0]) {
      for (var i = 1; i < rift.length; i++) {
        final (x0, d0) = rift[i - 1];
        final (x1, d1) = rift[i];
        if (x0.abs() > l) continue;
        for (var x = x0.ceil(); x < x1; x++) {
          final u = (x - x0) / (x1 - x0);
          final d = (d0 + (d1 - d0) * u + 0.5).floor();
          final w = _gap(x.toDouble());
          final px = x + jx;
          if (w < 0.4) {
            p.dot(px, d, s[1], fade);
            continue;
          }
          p.dot(px, d - 1, s[6], fade);
          final deep = rand((x / 3).floor(), 41) + (w - 1.5) * 0.35;
          final hot = hk * clamp(deep - 0.35, 0, 1) * 1.6;
          for (var y = 0; y < w; y++) {
            p.dot(
              px,
              d + y,
              y > w / 2 - 1 && hot > 0.25
                  ? (hot > 0.9 && rand(x, (t * 12).floor()) < 0.6
                      ? g[3]
                      : g[2])
                  : y > w / 2 - 1 && hot > 0.08
                      ? g[1]
                      : s[0],
              fade,
            );
          }
          p.dot(px, d + w.ceil(), s[2], fade);
        }
        if (i % 3 == 0 && hk > 0) {
          p.glow(
            x1 + jx,
            d1 + 1,
            9,
            g[2],
            0.35 * hk * (1 - x1.abs() / (reach * 1.2)),
          );
        }
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final jx = _shake();
    final sink = smooth(_close, _close + 0.6, t);
    for (final sl in slabs) {
      if (!(sl.rest && sl.a == 0 && sl.y == 0) && sink < 1) {
        drawRock(
          p,
          sl.x + jx,
          sl.y - 1.5 + sink * 4,
          sl.s,
          sl.a,
          sl.pts,
          s,
          1 - sink,
        );
      }
    }
    for (final b in bits.list) {
      if (b is RockBit) {
        drawRock(p, b.x, b.y, b.s, b.a, b.pts, s, math.min(1.0, b.life / 0.4));
      }
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final PixelEffect quake = SimulatedEffect(
  meta: const EffectMeta(
    id: 'nature/quake',
    name: 'Quake',
    desc:
        'The ground jolts three times: a rift tears out along the floor glowing deep inside, slabs of floor heave up and drop back askew, pebbles hop and dust bursts out of the split.',
    category: 'nature',
    tags: ['nature', 'earth', 'quake', 'rift', 'aoe', 'ground', 'one-shot'],
    size: (288, 104),
    origin: (144, 88),
    duration: 3.1,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#0e0c14',
        '#1a1724',
        '#211d2d',
        '#2b2639',
        '#3a3450',
        '#4a4263',
        '#6a6088',
        '#8e86a8',
      ],
      'glow': ['#4a1a0c', '#a8401a', '#ff8a2a', '#ffd27a', '#fff4d0'],
      'reach': 118,
      'seed': 12,
    },
  ),
  onCreate: _QuakeSim.new,
);
