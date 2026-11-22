import 'package:pixelfx_core/pixelfx_core.dart';

import '../arcane/spell_charge.dart';
import '../ice/ice_lance.dart';
import '../ice/snowflake_burst.dart';

const double _throw = 0.8;
const double _fly = 0.34;
const double _hit = _throw + _fly;
const double _tx = 170.0;
const double _speed = (_tx - 34.0) / _fly;

final Pose _hold = kReady.copyWith(
  x: -3,
  crouch: 4,
  lean: 2,
  fx: 18,
  fy: -22,
  bx: 11,
  by: -17,
  ffx: 10,
  fbx: -8,
);

final Pose _thrown = kReady.copyWith(
  x: 9,
  crouch: 4,
  lean: 6,
  fx: 19,
  fy: -24,
  bx: -6,
  by: -24,
  ffx: 13,
  fbx: -10,
  toeB: true,
);

final SimulatedEffect iceLanceThrowMove = SimulatedEffect(
  meta: const EffectMeta(
    id: 'moves/ice-lance-throw',
    name: 'Ice lance throw',
    desc:
        'Frost gathers into a spear in his hand, he throws it like a javelin, and the target ices over in a burst of snowflakes and shivers.',
    kind: AssetKind.move,
    category: 'moves',
    tags: ['move', 'ice', 'spell', 'projectile', 'one-shot'],
    size: (310, 136),
    origin: (86, 134),
    duration: _hit + 3.2,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'seed': 1},
  ),
  act: ActSpec(
    target: const TargetSpec(x: _tx),
    poses: [
      PoseKey(-0.4, kReady.copyWith(x: -3)),
      PoseKey(0.06, _hold),
      PoseKey(_throw - 0.2, _hold),
      PoseKey(
        _throw - 0.03,
        _hold.copyWith(crouch: 5, lean: -2, fx: 17, bx: 5, by: -20),
      ),
      PoseKey(_throw, _thrown, PoseEase.snap),
      PoseKey(_hit + 0.3, _thrown.copyWith(crouch: 3, lean: 4)),
      PoseKey(_hit + 0.9, kReady.copyWith(x: -3)),
      PoseKey(_hit + 3.2, kReady.copyWith(x: -3)),
    ],
    hits: const [
      HitSpec(
        t: _hit,
        stop: 0.13,
        shake: 0.2,
        amp: 2,
        push: 2.4,
        straw: 12,
        skin: 'ice',
        shiver: 1.4,
        y: -26,
      ),
      HitSpec(
        t: 2.75,
        push: 0.3,
        straw: 0,
        flash: 0,
        clearSkin: true,
      ),
    ],
    dust: const [
      DustSpec(t: _throw, x: 13, n: 6, dir: 1, color: '#d8f2ff'),
    ],
  ),
  onCreate: chain([
    ChainCue(
      fx: spellChargeEffect,
      t: 0.06,
      until: _throw,
      options: const {'palette': Pal.ice},
    ),
    ChainCue(
      fx: iceLanceEffect,
      t: _throw,
      until: _hit,
      x: (double t) => 34.0 + (t - _throw) * _speed,
      y: -24.0,
    ),
    ChainCue(
      fx: snowflakeBurstEffect,
      t: _hit,
      x: _tx,
      y: -26.0,
    ),
  ]),
);
