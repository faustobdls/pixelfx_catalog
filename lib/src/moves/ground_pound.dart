import 'package:pixelfx_core/pixelfx_core.dart';

import '../impacts/ground_slam.dart';

const double _land = 0.62;
const double _tx = 80.0;

final Pose _coil = kReady.copyWith(
  crouch: 8,
  lean: 4,
  fx: -6,
  fy: -14,
  bx: 3,
  by: -14,
  ffx: 8,
  fbx: -8,
);

const Pose _air = Pose(
  turn: 0.8,
  crouch: -1,
  fx: -9,
  fy: -44,
  bx: 10,
  by: -44,
  ffx: 6,
  ffy: -8,
  fbx: -3,
  fby: -3,
  toeB: true,
);

final Pose _top = _air.copyWith(
  y: -62,
  fx: -10,
  fy: -20,
  bx: 11,
  by: -20,
  ffx: 7,
  ffy: -10,
  fbx: -4,
  fby: -10,
);

const Pose _down = Pose(
  turn: 0.8,
  y: -8,
  crouch: 0,
  fx: -5,
  fy: -40,
  bx: 6,
  by: -40,
  ffx: 3,
  ffy: -3,
  fbx: -3,
  fby: -3,
  ghost: 1,
);

const Pose _hero = Pose(
  y: 0,
  crouch: 8,
  lean: 5,
  fx: 13,
  fy: -8,
  bx: -6,
  by: -23,
  ffx: 11,
  fbx: -10,
);

final SimulatedEffect groundPoundMove = SimulatedEffect(
  meta: const EffectMeta(
    id: 'moves/ground-pound',
    name: 'Ground pound',
    desc:
        'He coils, leaps out of frame height, hangs, and comes down like a rock: the floor cracks, shock waves race out and throw the target about as they pass.',
    kind: AssetKind.move,
    category: 'moves',
    tags: ['move', 'impact', 'jump', 'landing', 'shockwave', 'one-shot'],
    size: (304, 204),
    origin: (152, 168),
    duration: _land + 3.2,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'seed': 1},
  ),
  act: ActSpec(
    target: const TargetSpec(x: _tx),
    poses: [
      const PoseKey(-0.5, kReady),
      PoseKey(-0.16, _coil),
      PoseKey(0.0, _coil.copyWith(crouch: 7)),
      PoseKey(0.03, _air.copyWith(y: -10, ghost: 1), PoseEase.snap),
      PoseKey(0.26, _top.copyWith(y: -60), PoseEase.out),
      PoseKey(0.42, _top),
      PoseKey(_land - 0.005, _down.copyWith(y: -4), PoseEase.inEase),
      const PoseKey(_land, _hero, PoseEase.snap),
      PoseKey(_land + 0.8, _hero.copyWith(crouch: 6)),
      PoseKey(
        _land + 1.3,
        _hero.copyWith(crouch: 5, lean: 3, fx: 13, fy: -15, bx: -5, by: -20),
      ),
      const PoseKey(_land + 1.8, kReady),
      const PoseKey(_land + 3.2, kReady),
    ],
    hits: const [
      HitSpec(t: _land, stop: 0.2, shake: 0.5, amp: 4, target: false),
      HitSpec(t: _land + 0.14, stop: 0.04, push: 3, straw: 26, y: -8),
      HitSpec(
        t: _land + 0.44,
        push: -1.6,
        straw: 8,
        y: -8,
        flash: 0,
      ),
    ],
    dust: const [
      DustSpec(t: 0.03, x: 0, n: 8),
    ],
  ),
  onCreate: chain([
    ChainCue(fx: groundSlamEffect, t: _land),
  ]),
);
