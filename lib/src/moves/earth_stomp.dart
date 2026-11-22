import 'package:pixelfx_core/pixelfx_core.dart';

import '../nature/earth_spike.dart';

const double _stomp = 0.06;
const double _ram = _stomp + 0.43;
const double _tx = 112.0;

final Pose _knee = kReady.copyWith(
  crouch: 1,
  lean: -3,
  fx: 3,
  fy: -34,
  bx: 11,
  by: -30,
  ffx: 9,
  ffy: -15,
  fbx: -5,
);

final Pose _slam = kReady.copyWith(
  crouch: 7,
  lean: 3,
  fx: 14,
  fy: -14,
  bx: -5,
  by: -18,
  ffx: 11,
  fbx: -9,
);

final SimulatedEffect earthStompMove = SimulatedEffect(
  meta: const EffectMeta(
    id: 'moves/earth-stomp',
    name: 'Earth stomp',
    desc:
        'A knee comes up, the boot slams down, the floor heaves under the target and a stone spike rams up through it.',
    kind: AssetKind.move,
    category: 'moves',
    tags: ['move', 'earth', 'spell', 'stomp', 'one-shot'],
    size: (290, 142),
    origin: (50, 128),
    duration: _stomp + 3.4,
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
      PoseKey(-0.14, _knee),
      PoseKey(_stomp - 0.005, _knee.copyWith(ffy: -17)),
      PoseKey(_stomp, _slam, PoseEase.snap),
      PoseKey(_ram + 0.5, _slam.copyWith(crouch: 5)),
      const PoseKey(_ram + 1.1, kReady),
      const PoseKey(_stomp + 3.4, kReady),
    ],
    hits: const [
      HitSpec(t: _stomp, stop: 0.1, shake: 0.2, amp: 3, target: false),
      HitSpec(
        t: _ram,
        stop: 0.14,
        shake: 0.28,
        amp: 3,
        push: -3.2,
        straw: 30,
        y: -10,
      ),
    ],
    dust: const [
      DustSpec(t: _stomp, x: 11, n: 9),
    ],
  ),
  onCreate: chain([
    ChainCue(fx: earthSpike, t: _stomp, x: _tx),
  ]),
);
