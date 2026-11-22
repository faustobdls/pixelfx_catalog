import 'package:pixelfx_core/pixelfx_core.dart';

import 'src/holy/blessing.dart';
import 'src/holy/divine_shield.dart';
import 'src/holy/feather_burst.dart';
import 'src/holy/halo.dart';
import 'src/holy/heal.dart';
import 'src/holy/heal_aoe.dart';
import 'src/holy/holy_pillar.dart';
import 'src/holy/resurrection.dart';
import 'src/holy/smite.dart';
import 'src/holy/sunburst.dart';

export 'src/holy/blessing.dart' show blessingEffect;
export 'src/holy/divine_shield.dart' show divineShieldEffect;
export 'src/holy/feather_burst.dart' show featherBurstEffect;
export 'src/holy/halo.dart' show haloEffect;
export 'src/holy/heal.dart' show healEffect;
export 'src/holy/heal_aoe.dart' show healAoeEffect;
export 'src/holy/holy_lib.dart';
export 'src/holy/holy_pillar.dart' show holyPillarEffect;
export 'src/holy/resurrection.dart' show resurrectionEffect;
export 'src/holy/smite.dart' show smiteEffect;
export 'src/holy/sunburst.dart' show sunburstEffect;

/// All 10 effects in the `holy` category, sorted alphabetically by `meta.id`.
final List<PixelEffect> holyEffects = [
  blessingEffect,
  divineShieldEffect,
  featherBurstEffect,
  haloEffect,
  healEffect,
  healAoeEffect,
  holyPillarEffect,
  resurrectionEffect,
  smiteEffect,
  sunburstEffect,
];
