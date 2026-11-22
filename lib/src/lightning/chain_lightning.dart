// The hop timing, the link shapes that re-strike every other frame, the glowing nodes and the crawling arcs
// follow Sprite Fusion's open-source lightning (https://www.spritefusion.com/pixel-art-vfx/lightning),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'lightning_lib.dart';

final Pose _aim = kReady.copyWith(
  x: -6,
  crouch: 4,
  lean: 4,
  fx: 16,
  fy: -16,
  bx: -6,
  by: -23,
  ffx: 11,
  fbx: -9,
);

final Pose _back = kReady.copyWith(
  x: -6,
  crouch: 4,
  lean: -3,
  fx: -5,
  fy: -32,
  bx: 8,
  by: -24,
  armsFront: true,
  ffx: 9,
  fbx: -7,
);

HitSpec _zap(int at, double t, [double stop = 0.03]) => HitSpec(
      t: t,
      at: at,
      stop: stop,
      push: 1.2,
      straw: 6,
      skin: 'shock',
      shiver: 0.7,
      y: -22,
    );

final ActSpec _act = ActSpec(
  targets: const [
    TargetSpec(x: 58),
    TargetSpec(x: 104),
    TargetSpec(x: 150),
  ],
  poses: [
    PoseKey(-0.46, kReady.copyWith(x: -6)),
    PoseKey(-0.22, _back),
    PoseKey(0.0, _back.copyWith(crouch: 5)),
    PoseKey(0.04, _aim, PoseEase.snap),
    PoseKey(0.7, _aim.copyWith(crouch: 3)),
    PoseKey(1.35, _aim.copyWith(crouch: 3, fy: -18)),
    PoseKey(1.8, kReady.copyWith(x: -6)),
  ],
  hits: [
    _zap(0, 0.05),
    _zap(1, 0.14),
    HitSpec(
      t: 0.23,
      at: 2,
      stop: 0.07,
      push: 1.2,
      straw: 6,
      skin: 'shock',
      shiver: 0.7,
      y: -22,
      shake: 0.14,
      amp: 1,
    ),
    const HitSpec(t: 1.35, push: 0, straw: 0, flash: 0, clearSkin: true),
  ],
);

const Point2 _hand = (10.0, -16.0);
const List<Point2> _hops = [(58.0, -22.0), (104.0, -30.0), (150.0, -19.0)];
const double _wind = 0.12;
const double _leap = 0.05;
const double _gap = 0.075;
const double _hold = 0.78;
const double _break = 0.16;
final int _ash = hex('#5b5566');

double _on(int i) => _wind + i * _gap + _leap;
double _off(int i) => _hold + i * 0.05;

double _level(int i, double t) {
  final a = t - _on(i);
  if (a < 0.0) return 0.0;
  final double hum;
  if (a < 0.1) {
    final idx = (a * 30.0).floor();
    hum = idx < 3 ? const [1.0, 0.55, 1.0][idx] : 1.0;
  } else {
    hum = 0.78 +
        0.22 * math.sin(t * 61.0 + i) * math.sin(t * 23.0 + i * 2.0);
  }
  final b = t - _off(i);
  if (b < 0.0) return hum;
  if (b < _break) {
    return hum *
        (1.0 - b / _break) *
        ((b * 60.0).floor() % 3 == 1 ? 0.5 : 1.0);
  }
  return 0.0;
}

class _ChainLightningSim extends BaseEffectSim {
  final List<int> c;
  final int seed;
  final Rng r;
  late final Particles ps;
  late final Particles hot;
  final Lights lights = Lights();
  late final List<Point2> pts;
  final List<bool> hit = List<bool>.filled(_hops.length, false);
  final List<bool> popped = List<bool>.filled(_hops.length, false);
  late final List<double> groundX;
  double t = 0.0;

  _ChainLightningSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        seed = o.seed,
        r = Rng(o.seed) {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: (o['sparks'] as List).cast<Object>(),
    );
    hot = Particles(rng: r, ground: (_) => 0.0);
    pts = [_hand, ..._hops];
    groundX = [for (final (x, _) in _hops) x + r.range(-5.0, 5.0)];
  }

  BoltTree _shape(int i, int f, [int salt = 0]) {
    final q = rng(seed, 31 + salt, i, f);
    final (x0, y0) = pts[i];
    final (x1, y1) = pts[i + 1];
    final l = hypot(x1 - x0, y1 - y0);
    return bowed(q, x0, y0, x1, y1, -l * q.range(0.05, 0.15), 0.2, 0.08);
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t < _wind && r.chance(70.0 * dt)) {
      final a = r.range(0.0, tau);
      final d = r.range(10.0, 24.0);
      final life = r.range(0.06, 0.1);
      final v = (d * 3.0) / (math.exp(3.0 * life) - 1.0);
      ps.spawn(
        P.streak,
        _hand.$1 + math.cos(a) * d,
        _hand.$2 + math.sin(a) * d,
        -math.cos(a) * v,
        -math.sin(a) * v,
        life,
        r.chance(0.5) ? c[6] : c[5],
      );
    }
    for (var i = 0; i < _hops.length; i++) {
      final (x, y) = _hops[i];
      if (!hit[i] && t >= _on(i)) {
        hit[i] = true;
        final (px, py) = pts[i];
        final dir = math.atan2(y - py, x - px);
        lights.add(x, y, 56, c[4], 0.85, 0.22);
        lights.add(x, y, 16, kWhite, 0.7, 0.08);
        if (i == 0) lights.add(_hand.$1, _hand.$2, 40, c[4], 0.6, 0.15);
        for (var j = 0; j < 18; j++) {
          final a = r.chance(0.6)
              ? dir + r.range(-1.1, 1.1)
              : r.range(0.0, tau);
          final sp = r.range(70.0, 230.0);
          ps.spawn(
            P.spark,
            x,
            y,
            math.cos(a) * sp,
            math.sin(a) * sp - 40.0,
            r.range(0.15, 0.4),
          );
        }
        for (var j = 0; j < 5; j++) {
          hot.spawn(
            P.spark,
            x + r.range(-2.0, 2.0),
            y + 2.0,
            r.range(-50.0, 50.0),
            r.range(-60.0, 20.0),
            r.range(0.5, 0.9),
          );
        }
        ps.spawn(
          P.star,
          x + r.range(-4.0, 4.0),
          y - r.range(3.0, 7.0),
          0.0,
          -6.0,
          r.range(0.25, 0.4),
          c[6],
          r.range(1.5, 2.5),
        );
        for (var j = 0; j < 2; j++) {
          ps.spawn(
            P.smoke,
            x + r.range(-4.0, 4.0),
            y + r.range(-2.0, 3.0),
            r.range(-6.0, 6.0),
            -r.range(8.0, 16.0),
            r.range(0.7, 1.0),
            mix(_ash, c[2], 0.35),
            r.range(2.0, 3.5),
            r.range(0.1, 0.25),
          );
        }
      }
      if (hit[i] && t < _off(i)) {
        if (r.chance(9.0 * dt)) {
          final u = r.next();
          final (x0, y0) = pts[i];
          ps.spawn(
            P.spark,
            lerp(x0, x, u),
            lerp(y0, y, u) - 2.0,
            r.range(-60.0, 60.0),
            r.range(-90.0, 20.0),
            r.range(0.1, 0.25),
          );
        }
        if (r.chance(7.0 * dt)) {
          ps.spawn(
            P.spark,
            groundX[i],
            -1.0,
            r.range(-70.0, 70.0),
            -r.range(40.0, 140.0),
            r.range(0.12, 0.3),
          );
        }
        if (r.chance(2.0 * dt)) {
          hot.spawn(
            P.spark,
            x + r.range(-3.0, 3.0),
            y + 3.0,
            r.range(-30.0, 30.0),
            r.range(-30.0, 10.0),
            r.range(0.5, 0.8),
          );
        }
      }
      if (!popped[i] && t >= _off(i) + _break) {
        popped[i] = true;
        for (var j = 0; j < 7; j++) {
          final a = r.range(0.0, tau);
          final sp = r.range(40.0, 140.0);
          ps.spawn(
            P.spark,
            x,
            y,
            math.cos(a) * sp,
            math.sin(a) * sp - 30.0,
            r.range(0.12, 0.3),
          );
        }
        ps.spawn(
          P.smoke,
          x,
          y,
          r.range(-4.0, 4.0),
          -r.range(10.0, 16.0),
          r.range(0.55, 0.7),
          mix(_ash, c[2], 0.35),
          r.range(2.5, 3.5),
        );
        lights.add(x, y, 30, c[4], 0.5, 0.12);
      }
    }
    ps.update(dt);
    hot.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    for (var i = 0; i < _hops.length; i++) {
      final a = t - _on(i);
      if (a < 0.0) continue;
      final t0 = math.min(1.0, a / 0.2) *
          math.pow(clamp(1.0 - (t - _off(i)) / 0.7), 1.3).toDouble() *
          0.9;
      lightningScorch(p, groundX[i], 0, 7, t0, 1.0 - smooth(1.35, 1.75, t));
    }
    ps.draw(p, 'back');
    hot.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final f = (t * 30.0 + 1e-4).floor();
    final f2 = f >> 1;
    final kh = t < _wind ? t / _wind : _level(0, t);
    if (kh > 0.02) {
      final rad = (1.2 + 1.6 * kh + math.sin(t * 53.0) * 0.4) *
          math.min(1.0, kh * 1.5);
      p.circle(_hand.$1, _hand.$2, rad + 1.2, c[4]);
      p.circle(_hand.$1, _hand.$2, rad, c[6]);
      p.circle(_hand.$1, _hand.$2, rad * 0.5, kWhite);
      p.glow(_hand.$1, _hand.$2, 18, c[4], 0.6 * kh);
      if (t > _wind * 0.5) {
        final r2 = rng(seed, 5, f);
        final a = r2.range(0.0, tau);
        final d = r2.range(4.0, 8.0);
        crackle(
          p,
          zigzag(
            r2,
            _hand.$1,
            _hand.$2,
            _hand.$1 + math.cos(a) * d,
            _hand.$2 + math.sin(a) * d,
            0.4,
            0.3,
          ),
          0.6 * kh,
          c,
          0.3,
        );
      }
    }
    for (var i = 0; i < _hops.length; i++) {
      final (x, y) = _hops[i];
      final t0 = _wind + i * _gap;
      if (t >= t0 && t < _on(i)) {
        final u = Ease.outQuad((t - t0) / _leap);
        final b = _shape(i, -1);
        final trunk = BoltTree([b.paths[0]]);
        boltStrokeWith(p, trunk, 1.0, c, s: 0.75, upTo: u);
        final tp = b.paths[0].pts;
        final (hx, hy) =
            tp[math.min(tp.length - 1, (u * (tp.length - 1)).floor())];
        p.circle(hx, hy, 2, kWhite);
        p.glow(hx, hy, 16, c[5], 0.7);
      }
      final k = _level(i, t);
      if (k > 0.0) {
        boltStroke(p, _shape(i, f2), k, c, 0.75);
      } else if (t >= _off(i) + _break && t < _off(i) + _break + 0.35) {
        final g = 1.0 - (t - _off(i) - _break) / 0.35;
        final b = _shape(i, ((_off(i) + _break) * 15.0).floor());
        traceBolt(p, b.paths[0].pts, g > 0.5 ? c[4] : c[2], g * 0.9);
      }
      final a = t - _on(i);
      if (a >= 0.0 && a < 0.09) {
        final q = a / 0.09;
        p.circle(x, y, 6.0 * (1.0 - q) + 1.5, c[5]);
        p.circle(x, y, 5.0 * (1.0 - q), kWhite);
        sparkle(p, x, y, jsRound(10.0 * (1.0 - q)).toDouble(), c[6], c[4], 0.6);
      }
      if (k > 0.05) {
        final rad = (2.6 + math.sin(t * 47.0 + i) * 0.7) * k;
        p.circle(x, y, rad + 1.5, c[2]);
        p.circle(x, y, rad + 0.7, c[5]);
        p.circle(x, y, rad * 0.6, kWhite);
        p.glow(x, y, 26, c[4], 0.6 * k);
        p.glow(x, y, 8, c[6], 0.5 * k);
        final r2 = rng(seed, 11, i, f);
        final arcN = t - _on(i) < 0.12 ? 2 : 1;
        for (var j = 0; j < arcN; j++) {
          final a0 = r2.range(0.0, tau);
          final a1 = a0 + r2.sign() * r2.range(0.5, 1.0);
          final d0 = r2.range(4.0, 6.0);
          final d1 = r2.range(5.0, 8.0);
          crackle(
            p,
            zigzag(
              r2,
              x + math.cos(a0) * d0,
              y + math.sin(a0) * d0,
              x + math.cos(a1) * d1,
              y + math.sin(a1) * d1,
              0.35,
              0.0,
            ),
            r2.range(0.45, 0.7) * k,
            c,
            0.25,
          );
        }
        if (r2.next() < 0.3 * k) {
          final gx = groundX[i] + r2.range(-3.0, 3.0);
          crackle(
            p,
            zigzag(r2, x + r2.range(-2.0, 2.0), y + 3.0, gx, -0.5, 0.3, 0.35),
            0.75 * k,
            c,
            0.35,
          );
          p.glow(gx, -1, 12, c[5], 0.5 * k);
          p.px(gx, -1, kWhite);
        }
      }
    }
    ps.draw(p, 'front');
    hot.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect chainLightningEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'lightning/chain-lightning',
    name: 'Chain lightning',
    desc:
        "A bolt leaps from the caster's hand through three targets in turn; each flashes, sparks and grounds itself to the floor while the arcs between them flicker, then the chain snaps.",
    category: 'lightning',
    tags: [
      'lightning',
      'electric',
      'chain',
      'spell',
      'combat',
      'directional',
      'one-shot',
    ],
    size: (248, 104),
    origin: (40, 82),
    duration: 1.8,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': voltPalette,
      'sparks': plasmaSparks,
      'seed': 3,
    },
  ),
  act: _act,
  onCreate: (o) => _ChainLightningSim(o),
);
