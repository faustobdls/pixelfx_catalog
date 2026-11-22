import 'package:pixelfx_core/pixelfx_core.dart';

import 'src/explosions/barrel_explosion.dart';
import 'src/explosions/big_explosion.dart';
import 'src/explosions/cartoon_pow.dart';
import 'src/explosions/dirt_explosion.dart';
import 'src/explosions/firework_burst.dart';
import 'src/explosions/firework_rocket.dart';
import 'src/explosions/grenade.dart';
import 'src/explosions/implosion.dart';
import 'src/explosions/nuke.dart';
import 'src/explosions/plasma_explosion.dart';
import 'src/explosions/small_explosion.dart';
import 'src/explosions/smoke_bomb.dart';

export 'src/explosions/barrel_explosion.dart' show barrelExplosionEffect;
export 'src/explosions/big_explosion.dart' show bigExplosionEffect;
export 'src/explosions/cartoon_pow.dart' show cartoonPowEffect;
export 'src/explosions/dirt_explosion.dart' show dirtExplosionEffect;
export 'src/explosions/explosions_lib.dart';
export 'src/explosions/firework_burst.dart' show fireworkBurstEffect;
export 'src/explosions/firework_rocket.dart' show fireworkRocketEffect;
export 'src/explosions/grenade.dart' show grenadeEffect;
export 'src/explosions/implosion.dart' show implosionEffect;
export 'src/explosions/nuke.dart' show nukeEffect;
export 'src/explosions/plasma_explosion.dart' show plasmaExplosionEffect;
export 'src/explosions/small_explosion.dart' show smallExplosionEffect;
export 'src/explosions/smoke_bomb.dart' show smokeBombEffect;

final List<PixelEffect> explosionsEffects = [
  barrelExplosionEffect,
  bigExplosionEffect,
  cartoonPowEffect,
  dirtExplosionEffect,
  fireworkBurstEffect,
  fireworkRocketEffect,
  grenadeEffect,
  implosionEffect,
  nukeEffect,
  plasmaExplosionEffect,
  smallExplosionEffect,
  smokeBombEffect,
];
