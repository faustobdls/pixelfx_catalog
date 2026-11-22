// pixelfx_catalog: Official Wave 0 Showcase Pack of 15 curated pixel effects & moves
// implementing `PixelFxExtension`.

import 'package:pixelfx_core/pixelfx_core.dart';

import 'showcase.dart';
import 'src/categories.dart';

export 'showcase.dart';
export 'src/categories.dart' show catalogCategories;

/// Official Pixelfx Wave 0 Showcase catalog extension.
class PixelFxCatalogExtension extends PixelFxExtension {
  PixelFxCatalogExtension();

  @override
  ExtensionManifest get manifest => const ExtensionManifest(
        id: 'pixelfx.catalog',
        name: 'Pixelfx Official Catalog',
        version: '0.1.0',
        description:
            'Wave 0 Showcase Pack: 15 curated dual-buffer procedural pixel VFX, acted moves, pickups, critters, weather loops, and transitions ported 1:1 from patch-gg/pixelfx.',
        author: 'Patch / Sprite Fusion / Hollow Crown / Fausto BDLS',
        tags: ['official', 'showcase', 'vfx', 'moves', 'critters', 'weather'],
      );

  @override
  List<CategoryMeta> get categories => catalogCategories;

  @override
  List<PixelAsset> get assets => List<PixelAsset>.unmodifiable(showcaseEffects);
}

/// Create a [PixelFxRegistry] pre-populated with [PixelFxCatalogExtension].
PixelFxRegistry createDefaultRegistry() {
  final registry = PixelFxRegistry();
  registry.register(PixelFxCatalogExtension());
  return registry;
}
