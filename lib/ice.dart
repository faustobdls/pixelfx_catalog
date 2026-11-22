import 'package:pixelfx_core/pixelfx_core.dart';

import 'src/ice/blizzard_vortex.dart';
import 'src/ice/freeze.dart';
import 'src/ice/frost_breath.dart';
import 'src/ice/frost_nova.dart';
import 'src/ice/ice_crystal.dart';
import 'src/ice/ice_lance.dart';
import 'src/ice/ice_shatter.dart';
import 'src/ice/ice_spikes.dart';
import 'src/ice/icicle_fall.dart';
import 'src/ice/snowflake_burst.dart';

export 'src/ice/blizzard_vortex.dart' show blizzardVortexEffect;
export 'src/ice/freeze.dart' show freezeEffect;
export 'src/ice/frost_breath.dart' show frostBreathEffect;
export 'src/ice/frost_nova.dart' show frostNovaEffect;
export 'src/ice/ice_crystal.dart' show iceCrystalEffect;
export 'src/ice/ice_lance.dart' show iceLanceEffect;
export 'src/ice/ice_lib.dart';
export 'src/ice/ice_shatter.dart' show iceShatterEffect;
export 'src/ice/ice_spikes.dart' show iceSpikesEffect;
export 'src/ice/icicle_fall.dart' show icicleFallEffect;
export 'src/ice/snowflake_burst.dart' show snowflakeBurstEffect;

final List<PixelEffect> iceEffects = [
  blizzardVortexEffect,
  freezeEffect,
  frostBreathEffect,
  frostNovaEffect,
  iceCrystalEffect,
  iceLanceEffect,
  iceShatterEffect,
  iceSpikesEffect,
  icicleFallEffect,
  snowflakeBurstEffect,
];
