import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import '../explosions/small_explosion.dart';
import '../projectiles/muzzle_shotgun.dart';
import '../projectiles/rocket.dart';

const double _fire = 0.6;
const double _fly = 0.56;
const double _hit = _fire + _fly;
const double _tx = 200.0;
const double _my = -21.0;
const double _mx = 34.0;

final Pose _rest = kReady.copyWith(
  weapon: 'launcher',
  two: true,
  sa: -1,
  fx: 9,
  fy: -19,
);

final Pose _kneel = kReady.copyWith(
  weapon: 'launcher',
  two: true,
  sa: 0,
  fx: 9,
  fy: -17,
  crouch: 6,
  lean: 2,
  ffx: 12,
  fbx: -9,
);

final Pose _kicked = _kneel.copyWith(
  x: -6,
  sa: -0.12,
  fx: 4,
  fy: -19,
  lean: -4,
  crouch: 5,
);

final SimulatedEffect rocketLauncherMove = SimulatedEffect(
  meta: const EffectMeta(
    id: 'moves/rocket-launcher',
    name: 'Rocket launcher',
    desc:
        'He drops to one knee, shoulders the tube and fires: the kick shoves him back along the floor, the rocket crawls out on its jet and the target goes up.',
    kind: AssetKind.move,
    category: 'moves',
    tags: ['move', 'gun', 'rocket', 'projectile', 'explosion', 'one-shot'],
    size: (480, 244),
    origin: (178, 198),
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
      PoseKey(-0.52, _rest),
      PoseKey(-0.18, _kneel),
      PoseKey(_fire - 0.001, _kneel.copyWith(crouch: 7)),
      PoseKey(_fire, _kicked, PoseEase.snap),
      PoseKey(_fire + 0.36, _kneel.copyWith(x: -6)),
      PoseKey(_hit + 0.9, _kneel.copyWith(x: -6, crouch: 5, lean: 1)),
      PoseKey(_hit + 1.5, _rest.copyWith(x: -3)),
      PoseKey(_hit + 2.2, _rest.copyWith(x: 0)),
      PoseKey(_hit + 5.4, _rest),
    ],
    hits: const [
      HitSpec(t: _fire, stop: 0.06, shake: 0.22, amp: 2, target: false),
      HitSpec(
        t: _hit,
        stop: 0.2,
        shake: 0.45,
        amp: 4,
        push: 3.8,
        straw: 44,
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
      DustSpec(t: _fire, x: -16, n: 10, dir: -1),
    ],
  ),
  onCreate: chain([
    ChainCue(
      fx: muzzleShotgunEffect,
      t: _fire,
      x: _mx,
      options: const {'height': -_my},
    ),
    ChainCue(
      fx: rocketEffect,
      t: _fire,
      until: _hit,
      x: (double t) =>
          _mx +
          10.0 +
          math.pow(t - _fire, 1.5) * ((_tx - _mx - 16.0) / math.pow(_fly, 1.5)),
      y: _my,
    ),
    ChainCue(fx: smallExplosionEffect, t: _hit, x: _tx),
  ]),
);
