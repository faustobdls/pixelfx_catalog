import 'package:pixelfx_core/pixelfx_core.dart';

import '../arcane/magic_circle_cast.dart';
import '../fire/meteor.dart';

const double _bolt = 1.52;
const double _hit = 2.05;
const double _tx = 170.0;

const Pose _chant = Pose(
  turn: 1.1,
  crouch: 1,
  fx: -1,
  fy: -26,
  bx: 2,
  by: -26,
  armsFront: true,
  hy: 1,
  ffx: -3,
  fbx: 4,
);

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

final Pose _point = kReady.copyWith(
  crouch: 3,
  lean: 5,
  fx: 17,
  fy: -37,
  bx: -6,
  by: -24,
  ffx: 12,
  fbx: -9,
  toeB: true,
);

const Pose _flinch = Pose(
  turn: 0.9,
  x: -3,
  crouch: 6,
  lean: -4,
  fx: -4,
  fy: -36,
  bx: 5,
  by: -33,
  ffx: 4,
  fbx: -4,
);

final SimulatedEffect meteorCallMove = SimulatedEffect(
  meta: const EffectMeta(
    id: 'moves/meteor-call',
    name: 'Meteor call',
    desc:
        'A long chant: a circle draws itself round him, it flares, he points, and a burning rock comes down on the target and flattens the scene.',
    kind: AssetKind.move,
    category: 'moves',
    tags: ['move', 'fire', 'spell', 'meteor', 'ultimate', 'one-shot'],
    size: (380, 240),
    origin: (92, 212),
    duration: _hit - 0.62 + 5.0,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'seed': 1},
  ),
  act: ActSpec(
    target: const TargetSpec(x: _tx),
    poses: [
      const PoseKey(-0.34, kReady),
      const PoseKey(0.0, _chant),
      PoseKey(0.75, _chant.copyWith(crouch: 2)),
      const PoseKey(1.4, _up),
      PoseKey(_bolt - 0.02, _up.copyWith(y: -1)),
      PoseKey(_bolt, _point, PoseEase.snap),
      PoseKey(_hit - 0.02, _point.copyWith(crouch: 3)),
      const PoseKey(_hit, _flinch, PoseEase.snap),
      PoseKey(_hit + 0.9, _flinch.copyWith(crouch: 3, lean: -2)),
      PoseKey(_hit + 1.7, kReady.copyWith(x: 0)),
      const PoseKey(_hit + 4.3, kReady),
    ],
    hits: const [
      HitSpec(t: _bolt, stop: 0.06, shake: 0.16, amp: 2, target: false),
      HitSpec(
        t: _hit,
        stop: 0.22,
        shake: 0.55,
        amp: 4,
        push: 3.8,
        straw: 44,
        skin: 'char',
      ),
      HitSpec(
        t: _hit + 3.9,
        push: 0,
        straw: 0,
        flash: 0,
        clearSkin: true,
      ),
    ],
  ),
  onCreate: chain([
    ChainCue(fx: magicCircleCastEffect, t: 0.0),
    ChainCue(fx: meteorEffect, t: _hit - 0.62, x: _tx),
  ]),
);
