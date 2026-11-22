import 'package:pixelfx_core/pixelfx_core.dart';

import 'arcane.dart';
import 'critters.dart';
import 'explosions.dart';
import 'fire.dart';
import 'ice.dart';
import 'lightning.dart';
import 'melee.dart';
import 'moves.dart';
import 'pickups.dart';
import 'status.dart';
import 'transitions.dart';
import 'ui.dart';
import 'water.dart';
import 'weather.dart';

export 'arcane.dart' show spellChargeEffect;
export 'critters.dart' show slimeEffect;
export 'explosions.dart' show smallExplosionEffect;
export 'fire.dart' show fireballEffect, torchEffect;
export 'ice.dart' show frostNovaEffect;
export 'lightning.dart' show lightningStrikeEffect;
export 'melee.dart' show swordSlashEffect;
export 'moves.dart' show fireballThrowMove;
export 'pickups.dart' show coinSpinEffect;
export 'status.dart' show frozenEffect;
export 'transitions.dart' show pixelDissolveEffect;
export 'ui.dart' show levelUpEffect;
export 'water.dart' show waterfallEffect;
export 'weather.dart' show rainEffect;

/// Wave 0 Showcase Pack: 15 signature effects spanning pure/simulated VFX, acts, moves, UI, pickups,
/// weather loops, full-screen transitions, and procedural critters.
final List<PixelEffect> showcaseEffects = [
  torchEffect,
  fireballEffect,
  spellChargeEffect,
  smallExplosionEffect,
  swordSlashEffect,
  frostNovaEffect,
  frozenEffect,
  lightningStrikeEffect,
  waterfallEffect,
  levelUpEffect,
  coinSpinEffect,
  rainEffect,
  pixelDissolveEffect,
  slimeEffect,
  fireballThrowMove,
];
