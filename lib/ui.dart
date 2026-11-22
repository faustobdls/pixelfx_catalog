import 'package:pixelfx_core/pixelfx_core.dart';

import 'src/ui/achievement.dart';
import 'src/ui/coin_collect.dart';
import 'src/ui/combo_counter.dart';
import 'src/ui/confetti.dart';
import 'src/ui/countdown.dart';
import 'src/ui/crit_number.dart';
import 'src/ui/damage_number.dart';
import 'src/ui/exclamation.dart';
import 'src/ui/health_bar_hit.dart';
import 'src/ui/heart_lost.dart';
import 'src/ui/level_up.dart';
import 'src/ui/quest_complete.dart';

export 'src/ui/achievement.dart' show achievementEffect;
export 'src/ui/coin_collect.dart' show coinCollectEffect;
export 'src/ui/combo_counter.dart' show comboCounterEffect;
export 'src/ui/confetti.dart' show confettiEffect;
export 'src/ui/countdown.dart' show countdownEffect;
export 'src/ui/crit_number.dart' show critNumberEffect;
export 'src/ui/damage_number.dart' show damageNumberEffect;
export 'src/ui/exclamation.dart' show exclamationEffect;
export 'src/ui/health_bar_hit.dart' show healthBarHitEffect;
export 'src/ui/heart_lost.dart' show heartLostEffect;
export 'src/ui/level_up.dart' show levelUpEffect;
export 'src/ui/quest_complete.dart' show questCompleteEffect;
export 'src/ui/ui_lib.dart';

final List<PixelEffect> uiEffects = [
  achievementEffect,
  coinCollectEffect,
  comboCounterEffect,
  confettiEffect,
  countdownEffect,
  critNumberEffect,
  damageNumberEffect,
  exclamationEffect,
  healthBarHitEffect,
  heartLostEffect,
  levelUpEffect,
  questCompleteEffect,
];
