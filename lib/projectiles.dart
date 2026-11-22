import 'package:pixelfx_core/pixelfx_core.dart';

import 'src/projectiles/arrow.dart';
import 'src/projectiles/bullet_tracer.dart';
import 'src/projectiles/cannonball.dart';
import 'src/projectiles/energy_disc.dart';
import 'src/projectiles/flare.dart';
import 'src/projectiles/homing_missile.dart';
import 'src/projectiles/laser_bolt.dart';
import 'src/projectiles/magic_missile.dart';
import 'src/projectiles/muzzle_pistol.dart';
import 'src/projectiles/muzzle_shotgun.dart';
import 'src/projectiles/muzzle_smg.dart';
import 'src/projectiles/plasma_shot.dart';
import 'src/projectiles/rocket.dart';

export 'src/projectiles/arrow.dart';
export 'src/projectiles/bullet_tracer.dart';
export 'src/projectiles/cannonball.dart';
export 'src/projectiles/energy_disc.dart';
export 'src/projectiles/flare.dart';
export 'src/projectiles/homing_missile.dart';
export 'src/projectiles/laser_bolt.dart';
export 'src/projectiles/magic_missile.dart';
export 'src/projectiles/muzzle_pistol.dart';
export 'src/projectiles/muzzle_shotgun.dart';
export 'src/projectiles/muzzle_smg.dart';
export 'src/projectiles/plasma_shot.dart';
export 'src/projectiles/projectiles_lib.dart';
export 'src/projectiles/rocket.dart';

/// All effects in the `projectiles` category, sorted lexicographically by id.
final List<PixelEffect> projectilesEffects = [
  arrowEffect,
  bulletTracerEffect,
  cannonballEffect,
  energyDiscEffect,
  flareEffect,
  homingMissileEffect,
  laserBoltEffect,
  magicMissileEffect,
  muzzlePistolEffect,
  muzzleShotgunEffect,
  muzzleSmgEffect,
  plasmaShotEffect,
  rocketEffect,
];
