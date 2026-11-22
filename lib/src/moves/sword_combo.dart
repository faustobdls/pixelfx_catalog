import 'package:pixelfx_core/pixelfx_core.dart';

import '../melee/double_slash.dart';
import '../melee/heavy_cleave.dart';
import '../melee/sword_slash.dart';

const double _a = 0.0;
const double _b = 0.5;
const double _c = 1.04;
const double _step = 10.0;
const double _finish = _c + 0.335;

List<PoseKey> _until(List<PoseKey> keys, double t) =>
    [for (final k in keys) if (k.t <= t) k];

final Pose _stand = kReady.copyWith(
  weapon: 'sword',
  fx: 11,
  fy: -15,
  sa: 0.38,
);

final SimulatedEffect swordComboMove = SimulatedEffect(
  meta: const EffectMeta(
    id: 'moves/sword-combo',
    name: 'Sword combo',
    desc:
        'Three strokes walking forward: a slash, a crossing double cut, and a two-handed cleave into the floor that throws the target about.',
    kind: AssetKind.move,
    category: 'moves',
    tags: ['move', 'melee', 'sword', 'combo', 'one-shot'],
    size: (264, 150),
    origin: (72, 130),
    duration: _finish + 1.6,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'seed': 1},
  ),
  act: ActSpec(
    target: const TargetSpec(x: 118),
    poses: [
      ...shiftKeys(_until(swordSlashEffect.act!.poses, 0.3), _a),
      ...shiftKeys(
        _until(doubleSlashEffect.act!.poses, 0.27)
            .where((k) => k.t >= -0.14)
            .toList(),
        _b,
        dx: _step,
      ),
      ...shiftKeys(
        heavyCleaveEffect.act!.poses.where((k) => k.t >= -0.3).toList(),
        _c,
        dx: _step * 2,
        over: const Pose(weapon: 'sword'),
      ),
      PoseKey(_finish + 1.6, _stand.copyWith(x: _step * 2 - 4)),
    ],
    hits: [
      ...shiftHits(swordSlashEffect.act!.hits, _a),
      ...shiftHits(doubleSlashEffect.act!.hits, _b),
      ...shiftHits(heavyCleaveEffect.act!.hits, _c),
    ],
    dust: [
      for (final d in swordSlashEffect.act!.dust)
        DustSpec(t: d.t + _a, x: d.x, n: d.n, dir: d.dir, color: d.color),
      for (final d in heavyCleaveEffect.act!.dust)
        DustSpec(
          t: d.t + _c,
          x: d.x + _step * 2,
          n: d.n,
          dir: d.dir,
          color: d.color,
        ),
    ],
  ),
  onCreate: chain([
    ChainCue(fx: swordSlashEffect, t: _a),
    ChainCue(fx: doubleSlashEffect, t: _b, x: _step),
    ChainCue(fx: heavyCleaveEffect, t: _c, x: _step * 2),
  ]),
);
