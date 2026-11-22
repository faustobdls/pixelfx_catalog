import 'package:pixelfx_core/pixelfx_core.dart';

import '../holy/smite.dart';

const double _bolt = 0.47;
const double _tx = 118.0;

const Pose _up = Pose(
  turn: 1.15,
  crouch: -1,
  fx: -7,
  fy: -44,
  bx: 8,
  by: -44,
  ffx: -3,
  fbx: 4,
);

final Pose _down = kReady.copyWith(
  crouch: 5,
  lean: 5,
  fx: 17,
  fy: -29,
  bx: 13,
  by: -25,
  ffx: 12,
  fbx: -10,
  toeB: true,
);

final SimulatedEffect holySmiteMove = SimulatedEffect(
  meta: const EffectMeta(
    id: 'moves/holy-smite',
    name: 'Holy smite',
    desc:
        'Both hands go up and a glint marks the target; he brings them down and a bolt of light drops like a hammer, leaving the target blanched.',
    kind: AssetKind.move,
    category: 'moves',
    tags: ['move', 'holy', 'spell', 'strike', 'one-shot'],
    size: (252, 182),
    origin: (42, 151),
    duration: 2.8,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'seed': 1},
  ),
  act: ActSpec(
    target: const TargetSpec(x: _tx),
    poses: [
      const PoseKey(-0.42, kReady),
      const PoseKey(-0.04, _up),
      PoseKey(_bolt - 0.01, _up.copyWith(y: -1)),
      PoseKey(_bolt, _down, PoseEase.snap),
      PoseKey(1.1, _down.copyWith(crouch: 3, lean: 3)),
      const PoseKey(1.7, kReady),
      const PoseKey(2.8, kReady),
    ],
    hits: const [
      HitSpec(
        t: _bolt,
        stop: 0.14,
        shake: 0.32,
        amp: 3,
        push: 2.8,
        straw: 24,
        skin: 'holy',
        y: -30,
      ),
      HitSpec(
        t: 2.3,
        push: 0,
        straw: 0,
        flash: 0,
        clearSkin: true,
      ),
    ],
    dust: const [
      DustSpec(t: _bolt, x: 14, n: 6, dir: 1),
    ],
  ),
  onCreate: chain([
    ChainCue(fx: smiteEffect, t: 0.0, x: _tx),
  ]),
);
