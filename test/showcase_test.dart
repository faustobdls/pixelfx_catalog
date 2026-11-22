import 'package:pixelfx_catalog/pixelfx_catalog.dart';
import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:test/test.dart';

void main() {
  group('pixelfx_catalog Full Catalog & Showcase', () {
    test('registers all 244 effects across 21 categories and preserves showcase', () {
      final registry = createDefaultRegistry();
      expect(registry.categories.length, 21);
      expect(registry.assets.length, 244);
      expect(catalogEffects.length, 244);
      expect(showcaseEffects.length, 15);

      final ids = catalogEffects.map((e) => e.meta.id).toList();
      expect(ids.toSet().length, 244);
      final sorted = [...ids]..sort();
      expect(ids, orderedEquals(sorted));

      for (final fx in showcaseEffects) {
        expect(registry.getEffect(fx.meta.id), isNotNull,
            reason: 'Missing showcase ${fx.meta.id}');
      }
      for (final fx in catalogEffects) {
        expect(registry.getEffect(fx.meta.id), isNotNull,
            reason: 'Missing ${fx.meta.id}');
      }
      for (final cat in registry.categories) {
        expect(
          catalogEffects.where((e) => e.meta.category == cat.id),
          isNotEmpty,
          reason: 'Empty category ${cat.id}',
        );
      }
    });

    test('all 244 effects render deterministically and survive a 4-step palette', () {
      final shortPalette = ['#141024', '#5a3c8c', '#c8a0f0', '#ffffff'];

      for (final fx in catalogEffects) {
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

    test('all acted effects run to completion or valid loop state', () {
      final registry = createDefaultRegistry();
      final acted = catalogEffects.where((e) => e.act != null).toList();
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
