import 'package:pixelfx_core/pixelfx_core.dart';

import '../lightning/lightning_strike.dart';

const double _bolt = 0.76;
const double _tx = 130.0;

final Pose _up = kReady.copyWith(
  crouch: 1,
  lean: -2,
  fx: 2,
  fy: -44,
  bx: 8,
  by: -19,
  ffx: 7,
  fbx: -5,
);

final Pose _down = kReady.copyWith(
  crouch: 5,
  lean: 5,
  fx: 18,
  fy: -27,
  bx: -7,
  by: -24,
  ffx: 12,
  fbx: -10,
  toeB: true,
);

final SimulatedEffect lightningCallMove = SimulatedEffect(
  meta: const EffectMeta(
    id: 'moves/lightning-call',
    name: 'Lightning call',
    desc:
        'An arm goes up, a sigil lights under the target, and on the downswing a thick bolt comes down on it; the target jolts through the aftershocks.',
    kind: AssetKind.move,
    category: 'moves',
    tags: ['move', 'lightning', 'spell', 'strike', 'one-shot'],
    size: (290, 266),
    origin: (42, 231),
    duration: 3.0,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'seed': 1},
  ),
  act: ActSpec(
    target: const TargetSpec(x: _tx),
    poses: [
      const PoseKey(0.0, kReady),
      PoseKey(0.26, _up),
      PoseKey(_bolt - 0.04, _up.copyWith(y: -1, crouch: -1)),
      PoseKey(_bolt, _down, PoseEase.snap),
      PoseKey(1.4, _down.copyWith(crouch: 3, lean: 4)),
      const PoseKey(2.0, kReady),
      const PoseKey(3.0, kReady),
    ],
    hits: const [
      HitSpec(
        t: _bolt,
        stop: 0.14,
        shake: 0.32,
        amp: 3,
        push: 2.8,
        straw: 24,
        skin: 'shock',
        shiver: 1.2,
      ),
      HitSpec(t: 1.04, stop: 0.03, push: 1.2, straw: 8),
      HitSpec(t: 1.26, stop: 0.03, push: -1, straw: 6),
      HitSpec(
        t: 2.5,
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
    ChainCue(fx: lightningStrikeEffect, t: 0.0, x: _tx),
  ]),
);
