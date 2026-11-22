import 'package:pixelfx_core/pixelfx_core.dart';

import 'src/moves/arrow_shot.dart';
import 'src/moves/dash_strike.dart';
import 'src/moves/earth_stomp.dart';
import 'src/moves/fireball_throw.dart';
import 'src/moves/ground_pound.dart';
import 'src/moves/holy_smite.dart';
import 'src/moves/ice_lance_throw.dart';
import 'src/moves/lightning_call.dart';
import 'src/moves/meteor_call.dart';
import 'src/moves/pistol_shots.dart';
import 'src/moves/rocket_launcher.dart';
import 'src/moves/sword_combo.dart';

export 'src/moves/arrow_shot.dart' show arrowShotMove;
export 'src/moves/dash_strike.dart' show dashStrikeMove;
export 'src/moves/earth_stomp.dart' show earthStompMove;
export 'src/moves/fireball_throw.dart' show fireballThrowMove;
export 'src/moves/ground_pound.dart' show groundPoundMove;
export 'src/moves/holy_smite.dart' show holySmiteMove;
export 'src/moves/ice_lance_throw.dart' show iceLanceThrowMove;
export 'src/moves/lightning_call.dart' show lightningCallMove;
export 'src/moves/meteor_call.dart' show meteorCallMove;
export 'src/moves/pistol_shots.dart' show pistolShotsMove;
export 'src/moves/rocket_launcher.dart' show rocketLauncherMove;
export 'src/moves/sword_combo.dart' show swordComboMove;

/// All 12 effects in the `moves` category, sorted lexicographically by `meta.id`.
final List<PixelEffect> movesEffects = [
  arrowShotMove,
  dashStrikeMove,
  earthStompMove,
  fireballThrowMove,
  groundPoundMove,
  holySmiteMove,
  iceLanceThrowMove,
  lightningCallMove,
  meteorCallMove,
  pistolShotsMove,
  rocketLauncherMove,
  swordComboMove,
];
