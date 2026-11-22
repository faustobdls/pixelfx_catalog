## 0.1.0

- Initial release: complete 1:1 port of all 244 upstream effects across all 21 categories (`arcane`, `critters`, `explosions`, `fire`, `holy`, `ice`, `impacts`, `lightning`, `melee`, `moves`, `nature`, `pickups`, `projectiles`, `scifi`, `shadow`, `spawn`, `status`, `transitions`, `ui`, `water`, `weather`), exposed via `PixelFxCatalogExtension`, `catalogEffects`, `showcaseEffects`, and `createDefaultRegistry()`.
- Includes full parity verification fixes for RNG draw order, symmetric `Math.round` rounding, color ramps, and dissolve behavior, plus standalone GitHub Actions CI & pub.dev OIDC publishing workflows.
