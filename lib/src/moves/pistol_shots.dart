import 'package:pixelfx_core/pixelfx_core.dart';

import '../impacts/hit_spark.dart';
import '../projectiles/bullet_tracer.dart';
import '../projectiles/muzzle_pistol.dart';

const List<double> _shots = [0.14, 0.42, 0.7];
const double _fly = 0.12;
const double _tx = 180.0;
const double _by = -32.0;
const double _mx = 28.0;

final Pose _rest = kReady.copyWith(
  weapon: 'pistol',
  sa: 0.9,
  fx: 10,
  fy: -17,
  bx: 7,
  by: -16,
);

final Pose _aim = _rest.copyWith(
  crouch: 3,
  lean: 2,
  fx: 18,
  fy: -28,
  sa: 0,
  bx: 12,
  by: -25,
  ffx: 11,
  fbx: -9,
);

final Pose _kick = _aim.copyWith(
  lean: 0,
  fx: 16,
  fy: -33,
  sa: -0.45,
  by: -28,
);

final SimulatedEffect pistolShotsMove = SimulatedEffect(
  meta: const EffectMeta(
    id: 'moves/pistol-shots',
    name: 'Pistol shots',
    desc:
        'Three aimed shots: the gun kicks up each time and settles, tracers cross the floor, and the target staggers under each hit.',
    kind: AssetKind.move,
    category: 'moves',
    tags: ['move', 'gun', 'pistol', 'projectile', 'ranged', 'one-shot'],
    size: (378, 76),
    origin: (111, 72),
    duration: 2.6,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'seed': 1},
  ),
  act: ActSpec(
    target: const TargetSpec(x: _tx),
    poses: [
      PoseKey(-0.36, _rest),
      PoseKey(-0.06, _aim),
      for (final t in _shots) ...[
        PoseKey(t, _aim),
        PoseKey(t + 0.001, _kick, PoseEase.snap),
        PoseKey(t + 0.14, _aim),
      ],
      PoseKey(1.2, _aim.copyWith(crouch: 1)),
      PoseKey(1.7, _rest),
      PoseKey(2.6, _rest),
    ],
    hits: [
      for (var i = 0; i < _shots.length; i++)
        HitSpec(
          t: _shots[i] + _fly,
          stop: i == 2 ? 0.08 : 0.04,
          shake: 0.1,
          amp: 1.0 + (i == 2 ? 1.0 : 0.0),
          push: i.isOdd ? -1.8 : 2.0,
          straw: 10,
          y: -30,
        ),
    ],
  ),
  onCreate: chain([
    for (final t in _shots) ...[
      ChainCue(
        fx: muzzlePistolEffect,
        t: t,
        x: _mx,
        options: const {'height': -_by},
      ),
      ChainCue(
        fx: bulletTracerEffect,
        t: t,
        until: t + _fly,
        x: (double u) => _mx + 4.0 + (u - t) * ((_tx - _mx - 14.0) / _fly),
        y: _by,
      ),
      ChainCue(
        fx: hitSparkEffect,
        t: t + _fly,
        x: _tx - 10.0,
        options: const {'height': 28},
      ),
    ],
  ]),
);
