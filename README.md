# pixelfx_catalog

Official 244-effect, 21-category procedural pixel-art VFX & acted-move catalog ported 1:1 from [`patch-gg/pixelfx`](https://github.com/patch-gg/pixelfx) to pure Dart on top of `pixelfx_core`.

Implements `PixelFxExtension` via `PixelFxCatalogExtension`, exposes the full `catalogEffects` list (`244` assets across `21` categories) plus `showcaseEffects` (`15` highlights), and provides `createDefaultRegistry()`.

## Usage

```dart
import 'package:pixelfx_catalog/pixelfx_catalog.dart';

final registry = createDefaultRegistry();
final slash = registry.getEffect('melee/sword-slash')!;
```
