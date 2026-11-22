import 'package:pixelfx_core/pixelfx_core.dart';

import 'src/status/bleeding.dart';
import 'src/status/burning.dart';
import 'src/status/charmed.dart';
import 'src/status/confused.dart';
import 'src/status/cursed.dart';
import 'src/status/frozen.dart';
import 'src/status/haste.dart';
import 'src/status/petrified.dart';
import 'src/status/poisoned.dart';
import 'src/status/rage.dart';
import 'src/status/sleep.dart';
import 'src/status/slowed.dart';
import 'src/status/stunned.dart';

export 'src/status/bleeding.dart' show bleedingEffect;
export 'src/status/burning.dart' show burningEffect;
export 'src/status/charmed.dart' show charmedEffect;
export 'src/status/confused.dart' show confusedEffect;
export 'src/status/cursed.dart' show cursedEffect;
export 'src/status/frozen.dart' show frozenEffect;
export 'src/status/haste.dart' show hasteEffect;
export 'src/status/petrified.dart' show petrifiedEffect;
export 'src/status/poisoned.dart' show poisonedEffect;
export 'src/status/rage.dart' show rageEffect;
export 'src/status/sleep.dart' show sleepEffect;
export 'src/status/slowed.dart' show slowedEffect;
export 'src/status/status_lib.dart';
export 'src/status/stunned.dart' show stunnedEffect;

final List<PixelEffect> statusEffects = [
  bleedingEffect,
  burningEffect,
  charmedEffect,
  confusedEffect,
  cursedEffect,
  frozenEffect,
  hasteEffect,
  petrifiedEffect,
  poisonedEffect,
  rageEffect,
  sleepEffect,
  slowedEffect,
  stunnedEffect,
];
