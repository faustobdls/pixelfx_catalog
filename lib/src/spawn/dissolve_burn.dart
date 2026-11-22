import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'spawn_lib.dart';

const Pose _writhe = Pose(
  turn: 1,
  crouch: 2,
  fx: -13,
  fy: -35,
  bx: 13,
  by: -26,
  ffx: -3,
  fbx: 4,
);

const double _ignite = 0.15;
const double _burn = 1.9;
final List<int> _char = [hex('#100908'), hex('#22130e'), hex('#3a2016')];

final PixelEffect dissolveBurnEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'spawn/dissolve-burn',
    name: 'Dissolve burn',
    desc:
        'An ember seam lights at the feet and climbs the body: above it the body scorches and smoulders, at it flames lick up, below it there\'s only falling ash, embers and smoke.',
    category: 'spawn',
    tags: [
      'spawn',
      'death',
      'burn',
      'fire',
      'ash',
      'dissolve',
      'embers',
      'one-shot',
    ],
    size: (96, 112),
    origin: (48, 100),
    duration: 3.6,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#2a0e08',
        '#5a1a0c',
        '#a8320f',
        '#e8601a',
        '#ff9a2e',
        '#ffd25a',
        '#fff3c0',
        '#ffffff',
      ],
      'ash': ['#2a2428', '#4a4248', '#6e6670'],
      'seed': 16,
    },
  ),
  act: const ActSpec(
    onBody: true,
    poses: [
      PoseKey(-0.16, kReady),
      PoseKey(
        0.4,
        Pose(turn: 1, crouch: 2, fx: -9, fy: -22, bx: 10, by: -22, ffx: -3, fbx: 4),
      ),
      PoseKey(0.8, _writhe),
      PoseKey(
        1.2,
        Pose(
          turn: 1,
          crouch: 2,
          lean: 2,
          fx: -13,
          fy: -26,
          bx: 13,
          by: -36,
          ffx: -3,
          fbx: 4,
        ),
      ),
      PoseKey(
        1.6,
        Pose(
          turn: 1,
          crouch: 2,
          lean: -2,
          fx: -13,
          fy: -36,
          bx: 13,
          by: -26,
          ffx: -3,
          fbx: 4,
        ),
      ),
      PoseKey(
        2.1,
        Pose(
          turn: 1,
          crouch: 5,
          lean: 2,
          fx: -8,
          fy: -38,
          bx: 9,
          by: -38,
          ffx: -3,
          fbx: 4,
        ),
      ),
      PoseKey(
        3.6,
        Pose(
          turn: 1,
          crouch: 6,
          lean: 2,
          fx: -8,
          fy: -36,
          bx: 9,
          by: -36,
          ffx: -3,
          fbx: 4,
        ),
      ),
    ],
  ),
  onActorAlpha: (_, _) => 0.0,
  onCreate: (o) => _DissolveBurnSim(o),
);

class _Tongue {
  const _Tongue({required this.x, required this.h, required this.s});

  final double x;
  final double h;
  final int s;
}

class _DissolveBurnSim extends BaseEffectSim {
  _DissolveBurnSim(Map<String, Object?> o) {
    cRamp = fit(o.palette, 8);
    aRamp = fit(o.rampOpt('ash'), 3);
    rng = Rng(o.seed);
    body = bodyOf(o.actor, cRamp);
    h = body.h;
    for (final b in body.list) {
      b.key =
          (body.h - 1 - b.my) / h +
          0.08 * (rand(b.mx, b.my, 3) - 0.5) +
          0.06 * noise(b.mx * 0.35, 4) -
          (b.edge ? 0.02 : 0);
      b.gone = false;
    }
    ps = Particles(
      rng: rng,
      ground: (_) => 0,
      sparks: [cRamp[6], cRamp[5], cRamp[4], cRamp[3]],
    );
    lights = Lights();
    tongues = List.generate(
      6,
      (i) => _Tongue(
        x: -9 + i * 3.6 + rand(i, 1) * 1.5,
        h: 6 + rand(i, 2) * 6,
        s: i * 13,
      ),
    );
  }

  late final List<int> cRamp;
  late final List<int> aRamp;
  late final Rng rng;
  late final BodyData body;
  late final int h;
  late final Particles ps;
  late final Lights lights;
  late final List<_Tongue> tongues;
  double t = 0;

  double _front(double t) =>
      -0.04 + 1.1 * Ease.inOutSine(clamp((t - _ignite) / _burn));

  double _left(double a, double b) =>
      math.max(0.05, math.min(rng.range(a, b), 3.6 - 0.1 - t));

  void _tongue(Painter p, double x, double y, double hVal, int n) {
    final layers = [
      (1.0, 1.0, cRamp[3]),
      (0.7, 0.8, cRamp[4]),
      (0.45, 0.6, cRamp[5]),
      (0.25, 0.35, cRamp[6]),
    ];
    for (final (lw, lh, c) in layers) {
      final hh = hVal * lh;
      for (var r = 0; r <= hh; r++) {
        final u = r / math.max(1.0, hh);
        final half =
            1.8 * lw * math.pow(1 - u, 0.9) + noise(t * 9 + r * 0.5, n) * 0.4;
        final cxr = x + noise(t * 4 + r * 0.25, n + 7) * u * 1.6;
        if (half < 0.3) continue;
        final x0 = (cxr - half + 0.5).floor();
        final x1 = (cxr + half + 0.5).floor();
        final py = (y - r + 0.5).floor();
        for (var px = x0; px <= x1; px++) {
          p.px(px, py, c);
        }
      }
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    final f = _front(t);
    for (final b in body.list) {
      if (b.gone || b.key >= f) continue;
      b.gone = true;
      final r = rng.next();
      if (r < 0.2) {
        if (b.y > -7) {
          ps.spawn(
            P.grit,
            b.x.toDouble(),
            b.y.toDouble(),
            rng.range(-12, 12),
            rng.range(-20, 0),
            _left(0.6, 1.2),
            rng.pick(aRamp),
            1,
          );
        } else {
          ps.spawn(
            P.flake,
            b.x.toDouble(),
            b.y.toDouble(),
            rng.range(-10, 10),
            rng.range(-8, 4),
            _left(0.5, math.min(1.5, -b.y / 18)),
            rng.pick(aRamp),
            rng.chance(0.2) ? 1.4 : 1.0,
          );
        }
      } else if (r < 0.32) {
        ps.spawn(
          P.ember,
          b.x.toDouble(),
          b.y.toDouble(),
          rng.range(-12, 12),
          -rng.range(15, 45),
          _left(0.6, 1.4),
          cRamp[5],
          rng.range(1, 1.6),
        );
      } else if (r < 0.46) {
        ps.spawn(
          P.fire,
          b.x.toDouble(),
          b.y.toDouble(),
          rng.range(-6, 6),
          -rng.range(14, 30),
          rng.range(0.2, 0.42),
          0,
          rng.range(1.2, 2.2),
          0,
          rng.chance(0.5) ? PF.smokes : 0,
        );
      } else if (r < 0.5) {
        ps.spawn(
          P.smoke,
          b.x.toDouble(),
          (b.y - 2).toDouble(),
          rng.range(-5, 5),
          -rng.range(14, 26),
          _left(1.2, 2),
          mix(aRamp[1], cRamp[1], 0.3),
          rng.range(2, 3.4),
        );
      }
    }
    if (t >= _ignite && t - dt < _ignite) {
      lights.add(0, -4, 34, cRamp[4], 0.8, 0.4);
      for (var i = 0; i < 10; i++) {
        ps.spawn(
          P.spark,
          rng.range(-8, 8),
          -1,
          rng.range(-80, 80),
          -rng.range(40, 150),
          rng.range(0.2, 0.5),
        );
      }
    }
    if (f > 0 && f < 1.02) {
      final fy = body.y + (1 - clamp(f)) * h;
      if (rng.chance(0.34)) {
        ps.spawn(
          P.smoke,
          rng.range(-7, 7),
          fy - 5,
          rng.range(-6, 6),
          -rng.range(16, 30),
          _left(1.4, 2.4),
          mix(aRamp[1], cRamp[3], 0.35),
          rng.range(2.6, 4.2),
        );
      }
      if (rng.chance(0.5)) {
        ps.spawn(
          P.fire,
          rng.range(-9, 9),
          fy,
          rng.range(-6, 6),
          -rng.range(18, 34),
          rng.range(0.18, 0.36),
          0,
          rng.range(1.2, 2.4),
          0,
          rng.chance(0.35) ? PF.smokes : 0,
        );
      }
      if (rng.chance(0.15)) {
        ps.spawn(
          P.ember,
          rng.range(-9, 9),
          fy,
          rng.range(-15, 15),
          -rng.range(30, 70),
          _left(0.8, 1.6),
          cRamp[5],
          1.4,
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k =
        smooth(0, _ignite + 0.2, t) *
        (1 - smooth(_ignite + _burn * 0.6, _ignite + _burn + 0.4, t));
    if (k > 0) p.glow(0, -1, 30, cRamp[4], 0.3 * k);
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    final f = _front(t);
    final fr = (t * 30).floor();
    for (final b in body.list) {
      if (b.gone) continue;
      final d = b.key - f;
      final int c;
      if (d < 0.025) {
        c = rand(b.mx, b.my, fr) < 0.35 ? kWhite : cRamp[6];
      } else if (d < 0.05) {
        c = rand(b.mx, b.my, fr + 7) < 0.5 ? cRamp[5] : cRamp[4];
      } else if (d < 0.11) {
        c = rand(b.mx, b.my, 13) < 0.15 && rand(b.mx, fr, 2) < 0.6
            ? cRamp[3]
            : _char[d < 0.075 ? 0 : 1];
      } else if (d < 0.16) {
        c = mix(b.c, _char[2], 0.6);
      } else if (d < 0.26) {
        c = mix(b.c, cRamp[2], 0.18);
      } else {
        c = b.c;
      }
      p.px(b.x, b.y, c);
    }
    if (f > -0.02 && f < 1.05) {
      final fy = body.y + (1 - clamp(f)) * h;
      final k = 1 - smooth(0.95, 1.05, f);
      for (final g in tongues) {
        final row = (fy - body.y + 0.5).floor();
        final mx = (g.x - body.x + 0.5).floor();
        if (!body.on(mx, math.min(h - 1, math.max(0, row)))) continue;
        final hh =
            g.h *
            k *
            (0.6 + 0.6 * (noise(t * 2.6 + g.s, g.s) * 0.5 + 0.5)) *
            smooth(-0.02, 0.06, f);
        if (hh >= 1) _tongue(p, g.x, fy + 1, hh, g.s);
      }
      final fl = 0.85 + 0.15 * noise(t * 11, 9);
      p.glowLine(-11, fy, 11, fy, 9, cRamp[4], 0.45 * k);
      p.glow(0, fy - 6, 56, cRamp[4], 0.38 * k * fl);
      p.glow(0, fy - 2, 18, cRamp[5], 0.28 * k * fl);
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}
