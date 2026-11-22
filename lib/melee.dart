import 'package:pixelfx_core/pixelfx_core.dart';

import 'src/melee/claw_swipe.dart';
import 'src/melee/dagger_flurry.dart';
import 'src/melee/double_slash.dart';
import 'src/melee/hammer_smash.dart';
import 'src/melee/heavy_cleave.dart';
import 'src/melee/scythe_reap.dart';
import 'src/melee/spear_sweep.dart';
import 'src/melee/spin_slash.dart';
import 'src/melee/sword_slash.dart';
import 'src/melee/thrust.dart';
import 'src/melee/uppercut.dart';
import 'src/melee/whip_crack.dart';

export 'src/melee/claw_swipe.dart' show clawSwipeEffect;
export 'src/melee/dagger_flurry.dart' show daggerFlurryEffect;
export 'src/melee/double_slash.dart' show doubleSlashEffect;
export 'src/melee/hammer_smash.dart' show hammerSmashEffect;
export 'src/melee/heavy_cleave.dart' show heavyCleaveEffect;
export 'src/melee/melee_lib.dart';
export 'src/melee/scythe_reap.dart' show scytheReapEffect;
export 'src/melee/spear_sweep.dart' show spearSweepEffect;
export 'src/melee/spin_slash.dart' show spinSlashEffect;
export 'src/melee/sword_slash.dart' show swordSlashEffect;
export 'src/melee/thrust.dart' show thrustEffect;
export 'src/melee/uppercut.dart' show uppercutEffect;
export 'src/melee/whip_crack.dart' show whipCrackEffect;

final List<PixelEffect> meleeEffects = [
  clawSwipeEffect,
  daggerFlurryEffect,
  doubleSlashEffect,
  hammerSmashEffect,
  heavyCleaveEffect,
  scytheReapEffect,
  spearSweepEffect,
  spinSlashEffect,
  swordSlashEffect,
  thrustEffect,
  uppercutEffect,
  whipCrackEffect,
];
