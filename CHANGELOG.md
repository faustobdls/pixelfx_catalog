## Unreleased

- Complete 1:1 port of all 244 upstream effects across all 21 categories (`arcane`, `critters`, `explosions`, `fire`, `holy`, `ice`, `impacts`, `lightning`, `melee`, `moves`, `nature`, `pickups`, `projectiles`, `scifi`, `shadow`, `spawn`, `status`, `transitions`, `ui`, `water`, `weather`), registered in `PixelFxCatalogExtension` and `catalogEffects` alongside `showcaseEffects`.
- Fix RNG draw-order, rounding (`Math.round` parity), ramp mapping, and particle parity bugs across `fire`, `impacts`, `explosions`, `lightning`, `moves`, `nature`, `pickups`, `status`, and `transitions`.
- Expand catalog tests to cover all 244 effects, 21 categories, and acted moves.
- Update standalone GitHub Actions CI & pub.dev OIDC publish workflows using `_ci_workspace` isolation.

## 0.1.0

- Initial Wave 0 Showcase release: 15 ported dual-buffer effects & acted moves across 14 active categories (`21` catalog categories defined via `PixelFxCatalogExtension`).
