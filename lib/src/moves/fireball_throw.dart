import 'package:pixelfx_core/pixelfx_core.dart';

import '../arcane/spell_charge.dart';
import '../explosions/small_explosion.dart';
import '../fire/fireball.dart';

const double _throw = 0.95;
const double _fly = 0.46;
const double _hit = _throw + _fly;
const double _speed = 340.0;
const double _tx = 190.0;

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
  fy: -22,
  bx: -6,
  by: -24,
  ffx: 13,
  fbx: -10,
  toeB: true,
);

const Pose _flinch = Pose(
  turn: 0.9,
  x: 7,
  crouch: 5,
  lean: -3,
  fx: -4,
  fy: -36,
  bx: 5,
  by: -33,
  ffx: 4,
  fbx: -4,
);

final SimulatedEffect fireballThrowMove = SimulatedEffect(
  meta: const EffectMeta(
    id: 'moves/fireball-throw',
    name: 'Fireball throw',
    desc:
        'He gathers fire in his hand, leans back and hurls it: the ball flies, the target takes it in a blast and comes out charred.',
    kind: AssetKind.move,
    category: 'moves',
    tags: ['move', 'fire', 'spell', 'projectile', 'explosion', 'one-shot'],
    size: (356, 244),
    origin: (64, 198),
    duration: _hit + 5.4,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'seed': 1},
  ),
  act: ActSpec(
    target: const TargetSpec(x: _tx),
    poses: [
      PoseKey(-0.42, kReady.copyWith(x: -3)),
      PoseKey(0.08, _hold),
      PoseKey(0.5, _hold),
      PoseKey(_throw - 0.03,
          _hold.copyWith(crouch: 5, lean: -2, fx: 17, bx: 5, by: -20)),
      PoseKey(_throw, _thrown, PoseEase.snap),
      PoseKey(_hit - 0.02, _thrown.copyWith(crouch: 3, lean: 4)),
      const PoseKey(_hit, _flinch, PoseEase.snap),
      PoseKey(_hit + 0.7, _flinch.copyWith(crouch: 3, lean: -2)),
      PoseKey(_hit + 1.4, kReady.copyWith(x: 4)),
      PoseKey(_hit + 2.1, kReady.copyWith(x: -3)),
      PoseKey(_hit + 5.4, kReady.copyWith(x: -3)),
    ],
    hits: const [
      HitSpec(
        t: _hit,
        stop: 0.18,
        shake: 0.38,
        amp: 3,
        push: 3.4,
        straw: 34,
        skin: 'char',
      ),
      HitSpec(
        t: _hit + 4.8,
        push: 0,
        straw: 0,
        flash: 0,
        clearSkin: true,
      ),
    ],
    dust: const [
      DustSpec(t: _throw, x: 13, n: 7, dir: 1),
    ],
  ),
  onCreate: chain([
    ChainCue(
      fx: spellChargeEffect,
      t: 0.08,
      until: _throw,
      options: const {'palette': Pal.fire},
    ),
    ChainCue(
      fx: fireballEffect,
      t: _throw,
      until: _hit,
      x: (double t) => 28.0 + (t - _throw) * _speed,
      y: -22.0,
    ),
    ChainCue(
      fx: smallExplosionEffect,
      t: _hit,
      x: _tx,
    ),
  ]),
);
