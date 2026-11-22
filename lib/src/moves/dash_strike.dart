import 'package:pixelfx_core/pixelfx_core.dart';

import '../impacts/crit_hit.dart';
import '../melee/sword_slash.dart';

const double _cut = 0.16;
const double _hit = _cut + 0.06;
const double _at = 116.0;
const double _tx = 176.0;

final Pose _guard = kReady.copyWith(
  weapon: 'sword',
  fx: 12,
  fy: -21,
  sa: -0.85,
);

final Pose _low = _guard.copyWith(
  crouch: 6,
  lean: 6,
  fx: -3,
  fy: -17,
  sa: 3.05,
  bx: 9,
  by: -23,
  ffx: 11,
  fbx: -10,
);

final Pose _cock = _guard.copyWith(
  x: _at - 4,
  crouch: 3,
  lean: -2,
  fx: -7,
  fy: -35,
  sa: -2.65,
  bx: 9,
  by: -25,
  armsFront: true,
  ffx: 9,
  fbx: -7,
);

final Pose _cutPose = _guard.copyWith(
  x: _at,
  crouch: 2,
  lean: 3,
  fx: 16,
  fy: -37,
  sa: -1.45,
  bx: -7,
  by: -24,
  ffx: 11,
  fbx: -10,
);

final Pose _down = _guard.copyWith(
  x: _at + 2,
  crouch: 5,
  lean: 5,
  fx: 20,
  fy: -21,
  sa: 0.62,
  bx: -9,
  by: -24,
  ffx: 13,
  fbx: -10,
  toeB: true,
);

final Pose _hop = _guard.copyWith(
  y: -14,
  crouch: 0,
  lean: -3,
  fx: 13,
  fy: -31,
  sa: -0.9,
  bx: -8,
  by: -28,
  ffx: 6,
  ffy: -8,
  fbx: -6,
  fby: -6,
  ghost: 1,
);

final SimulatedEffect dashStrikeMove = SimulatedEffect(
  meta: const EffectMeta(
    id: 'moves/dash-strike',
    name: 'Dash strike',
    desc:
        "A crouch, then he's across the floor in a blur of after-images and already cutting: a critical hit, a beat, and he hops back to where he started.",
    kind: AssetKind.move,
    category: 'moves',
    tags: ['move', 'melee', 'sword', 'dash', 'crit', 'one-shot'],
    size: (372, 156),
    origin: (66, 136),
    duration: 2.3,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'seed': 1},
  ),
  act: ActSpec(
    target: const TargetSpec(x: _tx),
    poses: [
      PoseKey(-0.5, _guard.copyWith(x: 0)),
      PoseKey(-0.16, _low.copyWith(x: -2)),
      PoseKey(-0.01, _low.copyWith(x: -3, crouch: 6)),
      PoseKey(0.0, _low.copyWith(x: 8, ghost: 1), PoseEase.snap),
      PoseKey(0.14, _low.copyWith(x: _at - 6, ghost: 1), PoseEase.line),
      PoseKey(0.145, _cock, PoseEase.snap),
      PoseKey(_cut, _cutPose, PoseEase.snap),
      PoseKey(_hit, _down, PoseEase.snap),
      PoseKey(0.75, _down.copyWith(crouch: 4, lean: 4)),
      PoseKey(1.25, _guard.copyWith(x: _at + 2)),
      PoseKey(
        1.32,
        _guard.copyWith(x: _at + 2, crouch: 5, lean: -2),
        PoseEase.snap,
      ),
      PoseKey(1.4, _hop.copyWith(x: _at - 28), PoseEase.snap),
      PoseKey(1.6, _hop.copyWith(x: 22, y: -18), PoseEase.line),
      PoseKey(1.74, _guard.copyWith(x: 0, y: 0, crouch: 5), PoseEase.line),
      PoseKey(2.2, _guard.copyWith(x: 0)),
    ],
    hits: const [
      HitSpec(t: _hit, stop: 0.17, shake: 0.26, amp: 3, push: 3.4, straw: 32),
    ],
    dust: const [
      DustSpec(t: 0.0, x: 0, n: 8, dir: -1),
      DustSpec(t: 0.14, x: _at - 6, n: 7),
      DustSpec(t: 1.74, x: 0, n: 6),
    ],
  ),
  onCreate: chain([
    ChainCue(fx: swordSlashEffect, t: _cut, x: _at),
    ChainCue(
      fx: critHitEffect,
      t: _hit,
      x: _tx - 10.0,
      options: const {'height': 28},
    ),
  ]),
);
