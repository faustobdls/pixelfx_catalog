// The beam (banded across, pulses running down it, sine strands that brighten in front, a source flare with
// spinning rays, an end flare spraying rays and sparks) is adapted from Sprite Fusion's open-source energy beam
// (https://www.spritefusion.com/pixel-art-vfx/energy), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'arcane_lib.dart';

const double _d = 1.2;
const double _hx = 15.0;
const double _hy = -24.0;
const double _l = 168.0;
const double _w = 6.0;

final Pose _aim = kReady.copyWith(
  x: -3,
  crouch: 4,
  lean: 4,
  fx: 18,
  fy: -24,
  bx: 13,
  by: -20,
  ffx: 11,
  fbx: -9,
  toeB: true,
);

final Pose _pull = kReady.copyWith(
  x: -3,
  crouch: 4,
  lean: -3,
  fx: 1,
  fy: -20,
  bx: 4,
  by: -22,
  ffx: 9,
  fbx: -7,
);

final PureEffect arcaneBeamEffect = PureEffect(
  meta: const EffectMeta(
    id: 'arcane/arcane-beam',
    name: 'Arcane beam',
    desc:
        'A beam fires right from the hand: a white core, strands twisting round it, pulses running down it, a flaring source and an end that sprays sparks.',
    category: 'arcane',
    tags: ['arcane', 'beam', 'laser', 'ray', 'magic', 'directional', 'loop'],
    size: (264, 100),
    origin: (26, 84),
    duration: _d,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'palette': Pal.arcane, 'seed': 10},
  ),
  act: ActSpec(
    target: const TargetSpec(x: 186),
    poses: [
      PoseKey(-0.62, kReady.copyWith(x: -3)),
      PoseKey(-0.3, _pull),
      PoseKey(-0.04, _pull.copyWith(crouch: 5, lean: -4)),
      PoseKey(0.0, _aim.copyWith(crouch: 3), PoseEase.snap),
      PoseKey(0.3, _aim),
      PoseKey(0.6, _aim.copyWith(crouch: 5, lean: 3)),
      PoseKey(0.9, _aim),
      PoseKey(1.2, _aim.copyWith(crouch: 3)),
    ],
    hits: const [
      HitSpec(t: 0.1, push: 0.5, straw: 3, flash: 0.02, y: -24),
      HitSpec(t: 0.7, push: 0.5, straw: 3, flash: 0.02, y: -24),
    ],
    dust: const [
      DustSpec(t: 0.0, x: -10, n: 5, dir: -1),
    ],
  ),
  onDraw: (p, t, o) {
    final c = fit(o.palette, 8);
    final ph = t / _d;
    final s = o.seed;
    const ex = _hx + _l;

    // the body, built across from a white core out to a dithered violet edge, wobbling and pulsing as it goes
    final lvCols = [kWhite, c[6], c[5], c[4], c[3], c[2]];
    for (var d = 0.0; d <= _l; d += 0.5) {
      final x = _hx + d;
      final w = _w *
          (1.0 + 0.12 * math.sin(d * 0.35 - ph * tau * 8.0)) *
          math.min(1.0, (d + 3.0) / 7.0);
      final pulse = fract(d * 0.025 - ph * 4.0) < 0.07 ? 1 : 0;
      for (var q0 = -w * 1.3; q0 <= w * 1.3; q0 += 0.5) {
        final q = q0.abs() / w;
        final y = _hy + q0;
        var lv = q < 0.2
            ? 0
            : q < 0.4
                ? 1
                : q < 0.62
                    ? 2
                    : q < 0.85
                        ? 3
                        : q < 1.0
                            ? 4
                            : 5;
        lv = math.max(0, lv - pulse);
        if (lv == 5 && arcaneBayer(x, y) > (1.3 - q) / 0.3) continue;
        p.px(x, y, lvCols[lv]);
      }
      // three strands twisting round it: bright on the near side, gone behind
      for (var st = 0; st < 3; st++) {
        final a = d * 0.17 - ph * tau * 6.0 + (st * tau) / 3.0;
        final off = math.sin(a) * w * 1.05;
        if (math.cos(a) > -0.15) {
          p.dot(x, _hy + off, math.cos(a) > 0.55 ? kWhite : c[6]);
        }
      }
      if (((d * 2.0 + 0.5).floor() & 11) == 0) {
        p.glow(x, _hy, w * 2.2 + 4.0, c[5], 0.2);
      }
    }

    // the source: a flickering flare with spinning rays at the hand
    final fr = 4.2 + math.sin(ph * tau * 10.0) * 0.6;
    for (var i = 0; i < 4; i++) {
      final a = ph * tau * 2.5 + (i * tau) / 4.0;
      final l = 7.0 + 3.0 * math.sin(ph * tau * 6.0 + i);
      p.lineShaded(
        _hx,
        _hy,
        _hx + math.cos(a) * l,
        _hy + math.sin(a) * l,
        color: (u) => u < 0.5 ? kWhite : c[6],
        alpha: (u) => u < 0.6 ? 1.0 : 1.6 - u,
      );
    }
    p.circle(_hx, _hy, fr + 1.5, c[4]);
    p.circle(_hx, _hy, fr, c[6]);
    p.circle(_hx, _hy, fr * 0.6, kWhite);
    p.glow(_hx, _hy, 32, c[5], 0.8);
    // energy drawn into the hand
    cycleFixed(t, _d, 10, s * 3 + 1, 0.18, (age, life, r, _) {
      final a = r.range(0.0, tau);
      final dd = 16.0 * (1.0 - age / life) + 3.0;
      final x = _hx + math.cos(a) * dd;
      final y = _hy + math.sin(a) * dd;
      p.dot(x, y, age / life > 0.6 ? kWhite : c[6]);
    });

    // the end: a hot flare spraying rays, rings shocking out, sparks thrown back and falling
    final ir = 5.0 + math.sin(ph * tau * 12.0) * 0.8;
    for (var i = 0; i < 7; i++) {
      final a = math.pi + (i - 3) * 0.36;
      final l = 8.0 + 8.0 * loopNoise(ph, 4.0, s * 7 + i).abs();
      p.lineShaded(
        ex,
        _hy,
        ex + math.cos(a) * l,
        _hy + math.sin(a) * l,
        color: (u) => u < 0.4 ? kWhite : (i.isOdd ? c[5] : c[6]),
        alpha: (u) => u < 0.6 ? 1.0 : 1.6 - u,
      );
    }
    for (var k = 0; k < 3; k++) {
      final q = fract(ph * 3.0 + k / 3.0);
      p.ring(
        ex,
        _hy,
        3.0 + 15.0 * Ease.outCubic(q),
        math.max(1.0, 2.0 * (1.0 - q)),
        q < 0.25 ? kWhite : c[5],
        1.1 - q,
      );
    }
    p.circle(ex, _hy, ir + 1.5, c[4]);
    p.circle(ex, _hy, ir, c[6]);
    p.circle(ex, _hy, ir * 0.55, kWhite);
    p.glow(ex, _hy, 40, c[5], 0.9);
    p.glow(ex, _hy, 12, kWhite, 0.6);

    // a fountain of sparks thrown up and back off the end, arcing down
    cycle(t, _d, 220, s * 3 + 2, (g) => g.range(0.18, 0.5),
        (age, life, r, _) {
      final a = math.pi * 1.5 + r.range(-1.7, 0.45);
      final sp = r.range(70.0, 260.0);
      final vx = math.cos(a) * sp;
      final vy = math.sin(a) * sp - 30.0;
      final (x, y) = fly(ex, _hy, vx, vy, age, 480.0, 2.2);
      final (ux, uy) = flyV(vx, vy, age, 480.0, 2.2);
      final k = 1.0 - age / life;
      if (y > -1.0) return;
      final head = k > 0.6
          ? kWhite
          : k > 0.3
              ? c[6]
              : c[5];
      final rawSp2 = hypot(ux, uy);
      final sp2 = rawSp2 == 0.0 ? 1.0 : rawSp2;
      final len = math.min(8.0, 1.0 + sp2 * 0.022);
      p.lineShaded(
        x - (ux / sp2) * len,
        y - (uy / sp2) * len,
        x,
        y,
        color: (u) => u > 0.5 ? head : c[4],
      );
      p.glow(x, y, 3, head, 0.45 * k);
    });

    cycleFixed(t, _d, 6, s * 3 + 3, 0.3, (age, life, r, _) {
      final k = math.sin((age / life) * math.pi);
      sparkle(p, ex + r.range(-12.0, 4.0), _hy + r.range(-12.0, 12.0),
          1.0 + 2.5 * k, c[6], c[5], 0.4 * k);
    });

    // violet vapour lifting off the end
    cycle(t, _d, 7, s * 3 + 5, (g) => g.range(0.8, 1.2), (age, life, r, _) {
      final q = age / life;
      final x = ex + r.range(-8.0, 4.0) - q * 6.0;
      final y = _hy - 4.0 - q * r.range(14.0, 24.0);
      final rad = r.range(3.0, 5.0) * (0.7 + 0.8 * q);
      p.discShaded(
        x,
        y,
        rad,
        color: (_, _) => c[4],
        alpha: (dd, _) => 0.28 * math.sin(q * math.pi) * (1.0 - dd * dd),
      );
    });

    // motes shed along the beam
    cycle(t, _d, 16, s * 3 + 4, (g) => g.range(0.3, 0.6), (age, life, r, _) {
      final q = age / life;
      final x = _hx + r.range(10.0, _l - 10.0) + q * 20.0;
      final y = _hy + r.sign() * (_w + 1.0 + q * r.range(4.0, 10.0));
      mote(p, x, y, 40.0, (y - _hy) * 1.5, r.chance(0.5) ? c[6] : c[5], 0.6,
          1.0 - q, 0.3);
    });

    // the floor beneath catches the light
    p.glow(ex, -1, 30, c[5], 0.25);
    p.glow(_hx + _l / 2.0, -1, 60, c[4], 0.12);
  },
);
