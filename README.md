# pixelfx_catalog

Official effect & acted-move catalog ported 1:1 from [`patch-gg/pixelfx`](https://github.com/patch-gg/pixelfx) to pure Dart on top of `pixelfx_core`.

Implements `PixelFxExtension` via `PixelFxCatalogExtension` and provides `createDefaultRegistry()`.

## Usage

```dart
import 'package:pixelfx_catalog/pixelfx_catalog.dart';

final registry = createDefaultRegistry();
final slash = registry.getEffect('melee/sword-slash')!;
```
