// The flash and flare, the bolts and their flicker, the plasma spray, the scorch where bolts land and the dust
// thrown along the floor follow Sprite Fusion's open-source lightning and explosion
// (https://www.spritefusion.com/pixel-art-vfx/lightning), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'lightning_lib.dart';

const Pose _wide = Pose(
  turn: 1.15,
  crouch: 5,
  lean: -1,
  fx: -15,
  fy: -33,
  bx: 15,
  by: -33,
  ffx: -7,
  fbx: 8,
);

const Pose _clapPose = Pose(
  turn: 1.15,
  y: -2,
  crouch: 0,
  fx: -1,
  fy: -45,
  bx: 1,
  by: -45,
  ffx: -3,
  ffy: -5,
  fbx: 4,
  fby: -5,
);

final ActSpec _act = ActSpec(
  onBody: true,
  follow: 0.0,
  target: const TargetSpec(x: 104),
  poses: [
    const PoseKey(-0.46, kReady),
    const PoseKey(-0.18, _wide),
    PoseKey(0.08, _wide.copyWith(crouch: 6)),
    const PoseKey(0.12, _clapPose, PoseEase.snap),
    PoseKey(0.55, _clapPose.copyWith(y: 0, ffy: -4, fby: -4, crouch: 1)),
    const PoseKey(
      1.05,
      Pose(
        turn: 1,
        crouch: 3,
        fx: -10,
        fy: -28,
        bx: 11,
        by: -28,
        ffx: -4,
        fbx: 5,
      ),
    ),
    const PoseKey(1.7, kReady),
  ],
  hits: const [
    HitSpec(t: 0.12, stop: 0.13, shake: 0.3, amp: 3, target: false),
    HitSpec(
      t: 0.42,
      push: 2,
      straw: 14,
      y: -8,
      skin: 'shock',
      shiver: 0.5,
    ),
    HitSpec(t: 1.2, push: 0, straw: 0, flash: 0, clearSkin: true),
  ],
);

const double _clap = 0.12;
const double _cy = -22.0;
const List<double> _bk = [1.0, 0.7, 0.95, 0.5, 0.8, 0.3];
final int _dust = hex('#6e6382');
final List<int> _stone =
    ['#655b7a', '#4a4263', '#342d45'].map(hex).toList(growable: false);
final int _ash = hex('#5b5566');

class _ThunderBolt {
  final bool down;
  final double x1;
  final double y1;
  final double t0;
  const _ThunderBolt(this.down, this.x1, this.y1, this.t0);
}

class _ThunderclapSim extends BaseEffectSim {
  final List<int> c;
  final int seed;
  final double reach;
  final Rng r;
  late final Particles ps;
  late final Particles hot;
  final Lights lights = Lights();
  late final List<_ThunderBolt> bolts;
  late final List<bool> landed;
  ActorDefinition actor;
  double t = 0.0;
  bool clapped = false;

  _ThunderclapSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        seed = o.seed,
        reach = o.numOpt('reach', 104.0),
        r = Rng(o.seed),
        actor = o['actor'] as ActorDefinition {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: (o['sparks'] as List).cast<Object>(),
    );
    hot = Particles(rng: r, ground: (_) => 0.0);
    bolts = List.generate(8, (i) {
      final down = i % 2 == 0;
      final side = i % 4 < 2 ? -1 : 1;
      final a = down
          ? (side > 0
              ? r.range(0.35, 0.75)
              : math.pi - r.range(0.35, 0.75))
          : (side > 0
              ? -r.range(0.15, 1.2)
              : math.pi + r.range(0.15, 1.2));
      final l = down ? -_cy / math.sin(a) : r.range(40.0, 62.0);
      final x1 = math.cos(a) * l;
      final y1 = down ? 0.0 : _cy + math.sin(a) * l;
      return _ThunderBolt(down, x1, y1, _clap + r.range(0.0, 0.06));
    });
    landed = List<bool>.filled(bolts.length, false);
  }

  double _front(double time) => time < _clap
      ? 0.0
      : 8.0 + (reach - 8.0) * Ease.outCubic(clamp((time - _clap) / 0.5));

  @override
  void update(double dt, Map<String, Object?> opts) {
    final nextActor = opts['actor'] as ActorDefinition?;
    if (nextActor != null) actor = nextActor;
    t += dt;
    if (t < _clap && r.chance(60.0 * dt)) {
      final a = r.range(0.0, tau);
      final d = r.range(16.0, 30.0);
      final life = r.range(0.07, 0.1);
      final v = (d * 3.0) / (math.exp(3.0 * life) - 1.0);
      ps.spawn(
        P.streak,
        math.cos(a) * d,
        _cy + math.sin(a) * d * 0.8,
        -math.cos(a) * v,
        -math.sin(a) * v * 0.8,
        life,
        r.chance(0.5) ? c[6] : c[5],
      );
    }
    if (t >= _clap && !clapped) {
      clapped = true;
      lights.add(0, _cy - 10, 100, c[4], 0.65, 0.45);
      lights.add(0, _cy, 26, kWhite, 0.5, 0.07);
      for (var i = 0; i < 64; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(170.0, 380.0) * (math.sin(a) > 0.4 ? 0.5 : 1.0);
        ps.spawn(
          P.spark,
          math.cos(a) * 6.0,
          _cy + math.sin(a) * 6.0,
          math.cos(a) * sp,
          math.sin(a) * sp - 40.0,
          r.range(0.2, 0.55),
        );
      }
      for (var i = 0; i < 8; i++) {
        ps.spawn(
          P.smoke,
          r.range(-8.0, 8.0),
          _cy + r.range(-6.0, 6.0),
          r.range(-25.0, 25.0),
          -r.range(10.0, 30.0),
          r.range(0.8, 1.3),
          mix(_ash, c[4], 0.3),
          r.range(4.0, 7.0),
          r.range(0.05, 0.2),
        );
      }
    }
    for (var i = 0; i < bolts.length; i++) {
      final b = bolts[i];
      if (b.down && !landed[i] && t >= b.t0) {
        landed[i] = true;
        lights.add(b.x1, -4, 46, c[4], 0.7, 0.25);
        for (var j = 0; j < 12; j++) {
          final a = -math.pi / 2.0 + r.range(-1.2, 1.2);
          final sp = r.range(70.0, 240.0);
          ps.spawn(
            P.spark,
            b.x1,
            -1.0,
            math.cos(a) * sp,
            math.sin(a) * sp,
            r.range(0.2, 0.5),
          );
        }
        for (var j = 0; j < 5; j++) {
          hot.spawn(
            P.spark,
            b.x1 + r.range(-2.0, 2.0),
            -1.0,
            r.range(-80.0, 80.0),
            -r.range(60.0, 180.0),
            r.range(0.4, 0.8),
          );
        }
      }
    }
    final fr = _front(t);
    if (t > _clap && t < _clap + 0.5) {
      for (final s in const [-1, 1]) {
        if (r.chance(70.0 * dt)) {
          ps.spawn(
            P.smoke,
            s * fr + r.range(-3.0, 3.0),
            -r.range(1.0, 4.0),
            s * r.range(10.0, 40.0),
            -r.range(5.0, 20.0),
            r.range(0.6, 1.1),
            _dust,
            r.range(3.0, 6.0) * (1.0 - 0.4 * (fr / reach)),
            0.0,
            PF.big,
          );
        }
        if (r.chance(50.0 * dt)) {
          ps.spawn(
            P.grit,
            s * fr,
            -1.0,
            s * r.range(10.0, 60.0),
            -r.range(60.0, 180.0),
            r.range(0.8, 1.3),
            r.pick(_stone),
            r.chance(0.3) ? 2.0 : 1.0,
          );
        }
      }
    }
    ps.update(dt);
    hot.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    for (final b in bolts) {
      if (b.down && t >= b.t0) {
        lightningScorch(
          p,
          b.x1,
          0.0,
          9.0,
          math.pow(clamp(1.0 - (t - b.t0) / 1.1), 1.3).toDouble(),
          1.0 - smooth(1.4, 1.85, t),
        );
      }
    }
    final u = (t - _clap) / 0.5;
    if (u > 0.0 && u < 1.0) {
      band(
        p,
        0.0,
        0.5,
        _front(t),
        0.18,
        math.max(2.0, 16.0 * (1.0 - u)),
        1.25 - u,
        [c[1], c[2], c[4], c[6]],
        keep: (g) => math.sin(g) < 0.0,
        hot: u < 0.15,
      );
    }
    ps.draw(p, 'back');
    hot.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final f = (t * 30.0 + 1e-4).floor();
    final u = (t - _clap) / 0.5;
    final aDef = actor;
    final a = t - _clap;
    if (a >= 0.0 && a < 0.07) {
      p.mask(aDef.mask, aDef.x, aDef.y, a < 0.035 ? kWhite : c[6]);
    }
    if (a >= 0.0 && a < 0.2) {
      final q = a / 0.2;
      flare(
        p,
        0.0,
        _cy,
        44.0 * math.pow(1.0 - q, 1.4).toDouble(),
        1.0 - q,
        c,
      );
      if (q < 0.35) p.circle(0, _cy, 10.0 * (1.0 - q * 2.0) + 2.0, kWhite);
      p.glow(0, _cy, 44, c[5], 0.32 * (1.0 - q));
    }
    for (var i = 0; i < bolts.length; i++) {
      final b = bolts[i];
      final ba = ((t - b.t0) * 30.0 + 1e-4).floor();
      if (t < b.t0 || ba >= _bk.length) continue;
      final rr = rng(seed, 3, i, ba >> 1);
      boltStrokeWith(
        p,
        zigzag(rr, 0.0, _cy, b.x1, b.y1, 0.25, b.down ? 0.5 : 0.8),
        _bk[ba],
        c,
        s: ba == 0 ? 1.0 : 0.8,
        hero: ba == 0,
      );
      if (b.down) {
        p.circle(b.x1, -1, 3.0 * _bk[ba] + 1.0, c[5]);
        p.px(b.x1, -1, kWhite);
        p.glow(b.x1, -3, 20, c[5], 0.5 * _bk[ba]);
      } else if (ba < 2) {
        sparkle(p, b.x1, b.y1, 4, c[6], c[4], 0.4);
      }
    }
    if (u > 0.0 && u < 1.0) {
      band(
        p,
        0.0,
        0.5,
        _front(t),
        0.18,
        math.max(2.0, 16.0 * (1.0 - u)),
        1.25 - u,
        [c[1], c[2], c[4], c[6]],
        keep: (g) => math.sin(g) >= 0.0,
        hot: u < 0.15,
      );
      for (final s in const [-1, 1]) {
        p.glow(s * _front(t), -3, 28, c[4], 0.45 * (1.0 - u));
      }
      final ua = (t - _clap) / 0.26;
      final ra = 8.0 + 60.0 * Ease.outCubic(ua);
      if (ua < 1.0) {
        p.ringShaded(
          0,
          _cy,
          ra,
          math.max(1.0, 2.0 * (1.0 - ua)),
          color: (_, _) => ua < 0.25 ? c[5] : (ua < 0.6 ? c[4] : c[3]),
          alpha: (_, g) =>
              _cy + math.sin(g) * ra > -1.0 ? 0.0 : 0.85 - 0.85 * ua,
        );
      }
    }
    if (a > 0.2 && a < 0.9) {
      final rr = rng(seed, 9, f);
      final k = 1.0 - (a - 0.2) / 0.7;
      if (rr.next() < 0.8) {
        final x0 = rr.range(-14.0, 14.0);
        final y0 = rr.range(-34.0, -4.0);
        final b = rr.range(0.0, tau);
        final l = rr.range(6.0, 13.0);
        crackle(
          p,
          zigzag(rr, x0, y0, x0 + math.cos(b) * l, y0 + math.sin(b) * l,
              0.4, 0.3),
          0.85 * k + 0.1,
          c,
          0.35,
        );
      }
    }
    ps.draw(p, 'front');
    hot.draw(p, 'front');
    lights.draw(p);
  }
}

final SimulatedEffect thunderclapEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'lightning/thunderclap',
    name: 'Thunderclap',
    desc:
        'A thunderclap round the caster: a white flash, forked bolts burst out and stab the floor, a heavy shock ring tears across the ground raising dust and grit, sparks streak away.',
    category: 'lightning',
    tags: [
      'lightning',
      'electric',
      'nova',
      'aoe',
      'spell',
      'shockwave',
      'one-shot',
    ],
    size: (288, 156),
    origin: (144, 124),
    duration: 1.9,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': voltPalette,
      'sparks': plasmaSparks,
      'reach': 104,
      'seed': 6,
    },
  ),
  act: _act,
  onCreate: (o) => _ThunderclapSim(o),
);
