import 'package:pixelfx_core/pixelfx_core.dart';

import 'src/pickups/chest_open.dart';
import 'src/pickups/coin_spin.dart';
import 'src/pickups/collect_burst.dart';
import 'src/pickups/crystal_shard.dart';
import 'src/pickups/gem_spin.dart';
import 'src/pickups/heart_pickup.dart';
import 'src/pickups/key_glint.dart';
import 'src/pickups/loot_beam.dart';
import 'src/pickups/potion.dart';
import 'src/pickups/power_star.dart';
import 'src/pickups/xp_orb.dart';

export 'src/pickups/chest_open.dart' show chestOpenEffect;
export 'src/pickups/coin_spin.dart' show coinSpinEffect;
export 'src/pickups/collect_burst.dart' show collectBurstEffect;
export 'src/pickups/crystal_shard.dart' show crystalShardEffect;
export 'src/pickups/gem_spin.dart' show gemSpinEffect;
export 'src/pickups/heart_pickup.dart' show heartPickupEffect;
export 'src/pickups/key_glint.dart' show keyGlintEffect;
export 'src/pickups/loot_beam.dart' show lootBeamEffect;
export 'src/pickups/pickups_lib.dart';
export 'src/pickups/potion.dart' show potionEffect;
export 'src/pickups/power_star.dart' show powerStarEffect;
export 'src/pickups/xp_orb.dart' show xpOrbEffect;

final List<PixelEffect> pickupsEffects = [
  chestOpenEffect,
  coinSpinEffect,
  collectBurstEffect,
  crystalShardEffect,
  gemSpinEffect,
  heartPickupEffect,
  keyGlintEffect,
  lootBeamEffect,
  potionEffect,
  powerStarEffect,
  xpOrbEffect,
];
