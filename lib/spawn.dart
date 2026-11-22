import 'package:pixelfx_core/pixelfx_core.dart';

import 'src/spawn/coin_drop.dart';
import 'src/spawn/disintegrate.dart';
import 'src/spawn/dissolve_burn.dart';
import 'src/spawn/egg_hatch.dart';
import 'src/spawn/poof.dart';
import 'src/spawn/respawn_beam.dart';
import 'src/spawn/shatter_death.dart';
import 'src/spawn/soul_rise.dart';
import 'src/spawn/spawn_portal.dart';
import 'src/spawn/summon_rise.dart';

export 'src/spawn/coin_drop.dart';
export 'src/spawn/disintegrate.dart';
export 'src/spawn/dissolve_burn.dart';
export 'src/spawn/egg_hatch.dart';
export 'src/spawn/poof.dart';
export 'src/spawn/respawn_beam.dart';
export 'src/spawn/shatter_death.dart';
export 'src/spawn/soul_rise.dart';
export 'src/spawn/spawn_lib.dart';
export 'src/spawn/spawn_portal.dart';
export 'src/spawn/summon_rise.dart';

final List<PixelEffect> spawnEffects = [
  coinDropEffect,
  disintegrateEffect,
  dissolveBurnEffect,
  eggHatchEffect,
  poofEffect,
  respawnBeamEffect,
  shatterDeathEffect,
  soulRiseEffect,
  spawnPortalEffect,
  summonRiseEffect,
];
