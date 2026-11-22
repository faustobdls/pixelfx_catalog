// pixelfx_catalog: Complete 244-effect official catalog ported 1:1 from patch-gg/pixelfx
// implementing `PixelFxExtension`.

import 'package:pixelfx_core/pixelfx_core.dart';

import 'arcane.dart';
import 'critters.dart';
import 'explosions.dart';
import 'fire.dart';
import 'holy.dart';
import 'ice.dart';
import 'impacts.dart';
import 'lightning.dart';
import 'melee.dart';
import 'moves.dart';
import 'nature.dart';
import 'pickups.dart';
import 'projectiles.dart';
import 'scifi.dart';
import 'shadow.dart';
import 'spawn.dart';
import 'src/categories.dart';
import 'status.dart';
import 'transitions.dart';
import 'ui.dart';
import 'water.dart';
import 'weather.dart';

export 'arcane.dart'
    show
        arcaneBeamEffect,
        arcaneEffects,
        arcaneMissilesEffect,
        arcaneOrbEffect,
        blinkInEffect,
        blinkOutEffect,
        magicCircleCastEffect,
        manaBurstEffect,
        portalEffect,
        runeCircleEffect,
        spellChargeEffect,
        starFallEffect,
        timeStopEffect;
export 'critters.dart'
    show
        batEffect,
        birdEffect,
        butterflyEffect,
        crittersEffects,
        eyeballEffect,
        fishSchoolEffect,
        flyingSkullEffect,
        frogEffect,
        ghostEffect,
        jellyfishEffect,
        slimeEffect,
        snakeEffect,
        wispEffect;
export 'explosions.dart'
    show
        barrelExplosionEffect,
        bigExplosionEffect,
        cartoonPowEffect,
        dirtExplosionEffect,
        explosionsEffects,
        fireworkBurstEffect,
        fireworkRocketEffect,
        grenadeEffect,
        implosionEffect,
        nukeEffect,
        plasmaExplosionEffect,
        smallExplosionEffect,
        smokeBombEffect;
export 'fire.dart'
    show
        brazierEffect,
        campfireEffect,
        candleEffect,
        fireBreathEffect,
        fireEffects,
        fireRingEffect,
        fireTornadoEffect,
        fireballEffect,
        flamePillarEffect,
        flamethrowerEffect,
        meteorEffect,
        spiritFlameEffect,
        torchEffect;
export 'holy.dart'
    show
        blessingEffect,
        divineShieldEffect,
        featherBurstEffect,
        haloEffect,
        healAoeEffect,
        healEffect,
        holyEffects,
        holyPillarEffect,
        resurrectionEffect,
        smiteEffect,
        sunburstEffect;
export 'ice.dart'
    show
        blizzardVortexEffect,
        freezeEffect,
        frostBreathEffect,
        frostNovaEffect,
        iceCrystalEffect,
        iceEffects,
        iceLanceEffect,
        iceShatterEffect,
        iceSpikesEffect,
        icicleFallEffect,
        snowflakeBurstEffect;
export 'impacts.dart'
    show
        bluntHitEffect,
        bulletImpactEffect,
        critHitEffect,
        groundSlamEffect,
        heavyLandingEffect,
        hitFlashEffect,
        hitSparkEffect,
        impactFrameEffect,
        impactsEffects,
        parryEffect,
        ricochetEffect,
        shieldBlockEffect;
export 'lightning.dart'
    show
        ballLightningEffect,
        chainLightningEffect,
        chargeUpEffect,
        electrifiedEffect,
        lightningEffects,
        lightningStrikeEffect,
        plasmaBallEffect,
        sparkArcEffect,
        stormCloudEffect,
        teslaCoilEffect,
        thunderclapEffect,
        zapHitEffect;
export 'melee.dart'
    show
        clawSwipeEffect,
        daggerFlurryEffect,
        doubleSlashEffect,
        hammerSmashEffect,
        heavyCleaveEffect,
        meleeEffects,
        scytheReapEffect,
        spearSweepEffect,
        spinSlashEffect,
        swordSlashEffect,
        thrustEffect,
        uppercutEffect,
        whipCrackEffect;
export 'moves.dart'
    show
        arrowShotMove,
        dashStrikeMove,
        earthStompMove,
        fireballThrowMove,
        groundPoundMove,
        holySmiteMove,
        iceLanceThrowMove,
        lightningCallMove,
        meteorCallMove,
        movesEffects,
        pistolShotsMove,
        rocketLauncherMove,
        swordComboMove;
export 'nature.dart'
    show
        acidSplash,
        boulder,
        earthSpike,
        healingBloom,
        leafStorm,
        natureEffects,
        poisonCloud,
        quake,
        rootSnare,
        sporeBurst,
        thorns,
        tornado,
        toxicPuddle,
        vineWhip;
export 'pickups.dart'
    show
        chestOpenEffect,
        coinSpinEffect,
        collectBurstEffect,
        crystalShardEffect,
        gemSpinEffect,
        heartPickupEffect,
        keyGlintEffect,
        lootBeamEffect,
        pickupsEffects,
        potionEffect,
        powerStarEffect,
        xpOrbEffect;
export 'projectiles.dart'
    show
        arrowEffect,
        bulletTracerEffect,
        cannonballEffect,
        energyDiscEffect,
        flareEffect,
        homingMissileEffect,
        laserBoltEffect,
        magicMissileEffect,
        muzzlePistolEffect,
        muzzleShotgunEffect,
        muzzleSmgEffect,
        plasmaShotEffect,
        projectilesEffects,
        rocketEffect;
export 'scifi.dart'
    show
        empBlastEffect,
        energyCoreEffect,
        forceFieldEffect,
        glitchEffect,
        hologramEffect,
        jetpackEffect,
        laserGridEffect,
        scannerEffect,
        scifiEffects,
        teleporterPadEffect,
        tractorBeamEffect,
        warpInEffect,
        warpOutEffect;
export 'shadow.dart'
    show
        blackHoleEffect,
        curseEffect,
        darkExplosionEffect,
        eclipseEffect,
        graspingHandsEffect,
        hexSigilEffect,
        lifeStealEffect,
        necroSkullsEffect,
        shadowEffects,
        shadowFlamesEffect,
        shadowTendrilsEffect,
        soulDrainEffect,
        voidOrbEffect;
export 'showcase.dart';
export 'spawn.dart'
    show
        coinDropEffect,
        disintegrateEffect,
        dissolveBurnEffect,
        eggHatchEffect,
        poofEffect,
        respawnBeamEffect,
        shatterDeathEffect,
        soulRiseEffect,
        spawnEffects,
        spawnPortalEffect,
        summonRiseEffect;
export 'src/categories.dart' show catalogCategories;
export 'status.dart'
    show
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
        statusEffects,
        stunnedEffect;
export 'transitions.dart'
    show
        blindsEffect,
        burnAwayEffect,
        crtOffEffect,
        diamondWipeEffect,
        glitchWipeEffect,
        irisEffect,
        pixelDissolveEffect,
        shatterWipeEffect,
        slashWipeEffect,
        starIrisEffect,
        transitionsEffects;
export 'ui.dart'
    show
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
        uiEffects;
export 'water.dart'
    show
        bubblesEffect,
        dripEffect,
        fountainEffect,
        geyserEffect,
        rainSplashEffect,
        ripplesEffect,
        splashEffect,
        waterEffects,
        waterJetEffect,
        waterOrbEffect,
        waterfallEffect,
        waveCrashEffect,
        whirlpoolEffect;
export 'weather.dart'
    show
        auroraEffect,
        blizzardEffect,
        cherryBlossomsEffect,
        cloudsEffect,
        fallingLeavesEffect,
        firefliesEffect,
        fogEffect,
        godRaysEffect,
        rainEffect,
        shootingStarsEffect,
        snowEffect,
        stormEffect,
        weatherEffects;

/// All 244 effects across all 21 categories, sorted lexicographically by `meta.id`.
final List<PixelEffect> catalogEffects = List<PixelEffect>.unmodifiable(
  <PixelEffect>[
    ...arcaneEffects,
    ...crittersEffects,
    ...explosionsEffects,
    ...fireEffects,
    ...holyEffects,
    ...iceEffects,
    ...impactsEffects,
    ...lightningEffects,
    ...meleeEffects,
    ...movesEffects,
    ...natureEffects,
    ...pickupsEffects,
    ...projectilesEffects,
    ...scifiEffects,
    ...shadowEffects,
    ...spawnEffects,
    ...statusEffects,
    ...transitionsEffects,
    ...uiEffects,
    ...waterEffects,
    ...weatherEffects,
  ]..sort((a, b) => a.meta.id.compareTo(b.meta.id)),
);

/// Official Pixelfx 244-effect catalog extension.
class PixelFxCatalogExtension extends PixelFxExtension {
  PixelFxCatalogExtension();

  @override
  ExtensionManifest get manifest => const ExtensionManifest(
        id: 'pixelfx.catalog',
        name: 'Pixelfx Official Catalog',
        version: '0.2.0-dev',
        description:
            'Complete 244-effect Pixelfx catalog across 21 categories: dual-buffer procedural pixel VFX, acted moves, pickups, critters, weather loops, and transitions ported 1:1 from patch-gg/pixelfx.',
        author: 'Patch / Sprite Fusion / Hollow Crown / Fausto BDLS',
        tags: ['official', 'catalog', 'vfx', 'moves', 'critters', 'weather'],
      );

  @override
  List<CategoryMeta> get categories => catalogCategories;

  @override
  List<PixelAsset> get assets => List<PixelAsset>.unmodifiable(catalogEffects);
}

/// Create a [PixelFxRegistry] pre-populated with [PixelFxCatalogExtension].
PixelFxRegistry createDefaultRegistry() {
  final registry = PixelFxRegistry();
  registry.register(PixelFxCatalogExtension());
  return registry;
}
