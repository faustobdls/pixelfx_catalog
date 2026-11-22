import 'package:pixelfx_catalog/pixelfx_catalog.dart';
import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:test/test.dart';

void main() {
  group('pixelfx_catalog Wave 0 Showcase', () {
    test('registers all 15 effects and 21 categories', () {
      final registry = createDefaultRegistry();
      expect(registry.categories.length, 21);
      expect(registry.assets.length, 15);
      expect(showcaseEffects.length, 15);

      const expectedIds = [
        'fire/torch',
        'fire/fireball',
        'arcane/spell-charge',
        'explosions/small-explosion',
        'melee/sword-slash',
        'ice/frost-nova',
        'status/frozen',
        'lightning/lightning-strike',
        'water/waterfall',
        'ui/level-up',
        'pickups/coin-spin',
        'weather/rain',
        'transitions/pixel-dissolve',
        'critters/slime',
        'moves/fireball-throw',
      ];
      for (final id in expectedIds) {
        expect(registry.getEffect(id), isNotNull, reason: 'Missing $id');
      }
    });

    test('all 15 effects render deterministically and survive a 4-step palette', () {
      final shortPalette = ['#141024', '#5a3c8c', '#c8a0f0', '#ffffff'];

      for (final fx in showcaseEffects) {
        final m = fx.meta;
        final frameA = createFrame(m.width, m.height);
        final frameB = createFrame(m.width, m.height);
        final instA = createFx(fx, {'x': m.originX, 'y': m.originY});
        final instB = createFx(fx, {'x': m.originX, 'y': m.originY});
        final instShort = createFx(fx, {
          'x': m.originX,
          'y': m.originY,
          'palette': shortPalette,
        });

        final steps = (m.duration * 10).round().clamp(4, 30);
        final dt = m.duration / steps;
        var paintedAny = false;
        for (var i = 0; i <= steps; i++) {
          if (i > 0) {
            instA.update(dt);
            instB.update(dt);
            instShort.update(dt);
          }
          instA.draw(clearFrame(frameA));
          instB.draw(clearFrame(frameB));
          instShort.draw(createFrame(m.width, m.height));

          expect(frameA.color, orderedEquals(frameB.color),
              reason: '${m.id} non-deterministic color at step $i');
          expect(frameA.light, orderedEquals(frameB.light),
              reason: '${m.id} non-deterministic light at step $i');

          for (final c in frameA.color) {
            if ((c >>> 24) != 0) {
              paintedAny = true;
              break;
            }
          }
        }
        expect(paintedAny, isTrue, reason: '${m.id} rendered no color pixels');
      }
    });

    test('acted effects run to completion or valid loop state', () {
      final registry = createDefaultRegistry();
      final acted = showcaseEffects.where((e) => e.act != null).toList();
      expect(acted.length, greaterThanOrEqualTo(5));

      for (final fx in acted) {
        final bounds = registry.actBoundsFor(fx);
        expect(bounds.x1 - bounds.x0, greaterThan(0));
        expect(bounds.y1 - bounds.y0, greaterThan(0));

        final act = registry.createActFor(fx, {'x': 120, 'y': 160});
        final frame = createFrame(320, 240);
        for (var i = 0; i < 600 && !act.done; i++) {
          act.update(1 / 30);
          if (i % 4 == 0) act.draw(clearFrame(frame));
        }
        if (!fx.meta.loop) {
          expect(act.done, isTrue, reason: '${fx.meta.id} act did not finish');
        }
      }
    });
  });
}
