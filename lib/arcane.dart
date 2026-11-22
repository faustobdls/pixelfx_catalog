import 'package:pixelfx_core/pixelfx_core.dart';

import 'src/arcane/arcane_beam.dart';
import 'src/arcane/arcane_missiles.dart';
import 'src/arcane/arcane_orb.dart';
import 'src/arcane/blink_in.dart';
import 'src/arcane/blink_out.dart';
import 'src/arcane/magic_circle_cast.dart';
import 'src/arcane/mana_burst.dart';
import 'src/arcane/portal.dart';
import 'src/arcane/rune_circle.dart';
import 'src/arcane/spell_charge.dart';
import 'src/arcane/star_fall.dart';
import 'src/arcane/time_stop.dart';

export 'src/arcane/arcane_beam.dart' show arcaneBeamEffect;
export 'src/arcane/arcane_lib.dart';
export 'src/arcane/arcane_missiles.dart' show arcaneMissilesEffect;
export 'src/arcane/arcane_orb.dart' show arcaneOrbEffect;
export 'src/arcane/blink_in.dart' show blinkInEffect;
export 'src/arcane/blink_out.dart' show blinkOutEffect;
export 'src/arcane/magic_circle_cast.dart' show magicCircleCastEffect;
export 'src/arcane/mana_burst.dart' show manaBurstEffect;
export 'src/arcane/portal.dart' show portalEffect;
export 'src/arcane/rune_circle.dart' show runeCircleEffect;
export 'src/arcane/spell_charge.dart' show spellChargeEffect;
export 'src/arcane/star_fall.dart' show starFallEffect;
export 'src/arcane/time_stop.dart' show timeStopEffect;

final List<PixelEffect> arcaneEffects = [
  arcaneBeamEffect,
  arcaneMissilesEffect,
  arcaneOrbEffect,
  blinkInEffect,
  blinkOutEffect,
  magicCircleCastEffect,
  manaBurstEffect,
  portalEffect,
  runeCircleEffect,
  spellChargeEffect,
  starFallEffect,
  timeStopEffect,
];
