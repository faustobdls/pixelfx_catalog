import 'package:pixelfx_core/pixelfx_core.dart';

import '../impacts/hit_spark.dart';
import '../projectiles/arrow.dart';

const double _loose = 0.56;
const double _fly = 0.24;
const double _hit = _loose + _fly;
const double _tx = 180.0;
const double _speed = (_tx - 30.0) / _fly;

final Pose _rest = kReady.copyWith(
  weapon: 'bow',
  sa: -0.4,
  fx: 12,
  fy: -20,
  bx: 6,
  by: -17,
);

final Pose _aim = _rest.copyWith(
  crouch: 3,
  lean: 1,
  fx: 18,
  fy: -28,
  sa: 0,
  bx: 10,
  by: -27,
  nocked: true,
  ffx: 11,
  fbx: -9,
);

final Pose _drawn = _aim.copyWith(
  crouch: 4,
  lean: -2,
  fx: 18,
  bx: -3,
  by: -29,
  pull: true,
);

final Pose _loosed = _aim.copyWith(
  crouch: 3,
  lean: 2,
  fx: 19,
  fy: -28,
  bx: -9,
  by: -32,
  nocked: false,
  pull: false,
);

final SimulatedEffect arrowShotMove = SimulatedEffect(
  meta: const EffectMeta(
    id: 'moves/arrow-shot',
    name: 'Arrow shot',
    desc:
        'He raises the bow, draws to his cheek, holds his breath and looses: the string snaps forward, the arrow crosses the floor and thuds home.',
    kind: AssetKind.move,
    category: 'moves',
    tags: ['move', 'bow', 'arrow', 'projectile', 'ranged', 'one-shot'],
    size: (300, 74),
    origin: (38, 66),
    duration: 1.9,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'seed': 1},
  ),
  act: ActSpec(
    target: const TargetSpec(x: _tx),
    poses: [
      PoseKey(-0.44, _rest),
      PoseKey(-0.14, _aim),
      PoseKey(0.16, _drawn),
      PoseKey(_loose, _drawn.copyWith(crouch: 4)),
      PoseKey(_loose + 0.002, _loosed, PoseEase.snap),
      PoseKey(1.1, _loosed.copyWith(bx: -6, by: -25)),
      PoseKey(1.6, _rest),
      PoseKey(1.9, _rest),
    ],
    hits: const [
      HitSpec(
        t: _hit,
        stop: 0.07,
        shake: 0.12,
        amp: 2,
        push: 2.2,
        straw: 14,
        y: -28,
      ),
    ],
  ),
  onCreate: chain([
    ChainCue(
      fx: arrowEffect,
      t: _loose,
      until: _hit,
      x: (double t) => 30.0 + (t - _loose) * _speed,
      y: -28.0,
    ),
    ChainCue(
      fx: hitSparkEffect,
      t: _hit,
      x: _tx - 10.0,
      options: const {'height': 30},
    ),
  ]),
);
