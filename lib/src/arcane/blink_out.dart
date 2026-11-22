// The blink (a crackling outline as it gathers, a white flash, the silhouette squeezed into a line, a ring on the
// floor, a fading afterimage) is adapted from Sprite Fusion's open-source blink
// (https://www.spritefusion.com/pixel-art-vfx/movement), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'arcane_lib.dart';

const double _out = 0.32;
const double _squeeze = 0.12;
const double _collapse = 0.08;
const double _pop = _out + _squeeze + _collapse;

const Pose _inPose = Pose(
  turn: 1,
  crouch: 4,
  fx: -2,
  fy: -25,
  bx: 2,
  by: -25,
  armsFront: true,
  ffx: 0,
  fbx: 2,
);

class _BlinkOutSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final ActorDefinition actor;
  final Uint8List sh;
  late final Particles ps;
  final Lights lights = Lights();
  late final double mx;
  late final double my;
  late final List<int> cols;
  double t = 0.0;
  bool out = false;
  bool popped = false;

  _BlinkOutSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed),
        actor = o.actor,
        sh = actorShades(o.actor) {
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[4]],
    );
    mx = actor.x + actor.w / 2.0;
    my = actor.y + actor.h * 0.55;
    cols = [kWhite, c[6], c[6], c[5], c[4]];
  }

  bool _inside(int x, int y) =>
      x >= 0 &&
      y >= 0 &&
      x < actor.w &&
      y < actor.h &&
      actor.mask.data[y * actor.w + x] != 0;

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _out - 0.04 && r.chance(0.7)) {
      final a = r.range(0.0, tau);
      final d = r.range(22.0, 44.0);
      final life = r.range(0.12, 0.18);
      final v = (d * 3.0) / (math.exp(3.0 * life) - 1.0);
      final x = mx + math.cos(a) * d;
      final y = math.min(-2.0, my + math.sin(a) * d);
      final rawL = hypot(x - mx, y - my);
      final l = rawL == 0.0 ? 1.0 : rawL;
      ps.spawn(
        P.streak,
        x,
        y,
        ((mx - x) / l) * v,
        ((my - y) / l) * v,
        life,
        r.chance(0.5) ? c[6] : c[5],
      );
    }
    if (!out && t >= _out) {
      out = true;
      lights.add(mx, my - 6.0, 54, c[5], 0.9, 0.3);
      lights.add(mx, my, 26, kWhite, 0.8, 0.1);
    }
    if (!popped && t >= _pop) {
      popped = true;
      lights.add(mx, my - 6.0, 58, c[5], 0.9, 0.35);
      lights.add(mx, my, 24, kWhite, 0.9, 0.08);
      for (var i = 0; i < 110; i++) {
        final y = actor.y + r.range(2.0, actor.h - 2.0);
        final s = r.sign();
        ps.spawn(
          P.ember,
          mx + r.range(-1.0, 1.0),
          y,
          s * r.range(25.0, 105.0),
          r.range(-70.0, 10.0),
          r.range(0.5, 0.95),
          r.pick(cols),
          r.chance(0.3) ? 2.0 : 1.0,
        );
      }
      for (var i = 0; i < 18; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(80.0, 240.0);
        ps.spawn(
          P.spark,
          mx,
          my,
          math.cos(a) * sp,
          math.sin(a) * sp - 40.0,
          r.range(0.2, 0.5),
        );
      }
      for (var i = 0; i < 14; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(20.0, 110.0);
        ps.spawn(
          i.isOdd ? P.star : P.mote,
          mx,
          my,
          math.cos(a) * sp,
          math.sin(a) * sp * 0.8 - 20.0,
          r.range(0.4, 0.9),
          r.pick([kWhite, c[6], c[5]]),
          r.range(0.8, 1.8),
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    if (t > _pop && t < _pop + 0.6) {
      final k = 0.5 * (1.0 - (t - _pop) / 0.6);
      for (var y = 0; y < actor.h; y++) {
        for (var x = 0; x < actor.w; x++) {
          final v = sh[y * actor.w + x];
          if (v != 0) {
            p.blend(actor.x + x, actor.y + y, v == 1 ? c[3] : c[4], k);
          }
        }
      }
    }
    final k = (t - _pop) / 0.5;
    if (k >= 0.0 && k < 1.0) {
      band(
        p,
        0,
        0,
        4.0 + 30.0 * Ease.outCubic(k),
        0.2,
        math.max(1.0, 3.0 * (1.0 - k)),
        1.15 - k,
        [c[3], c[5], c[6], kWhite],
        keep: (g) => math.sin(g) < 0.0,
        hot: k < 0.25,
      );
    }
    if (t < _pop + 0.3) {
      p.glow(0, -1, 26, c[5],
          0.3 * (t < _out ? t / _out : 1.0 - clamp((t - _pop) / 0.3)));
    }
  }

  @override
  void draw(Painter p) {
    final f = (t * 30.0).floor();
    if (t < _out) {
      final k = t / _out;
      for (var y = 0; y < actor.h; y++) {
        for (var x = 0; x < actor.w; x++) {
          if (_inside(x, y)) {
            p.light(
              actor.x + x,
              actor.y + y,
              c[6],
              k * k * (sh[y * actor.w + x] == 1 ? 0.3 : 0.75),
            );
          } else if ((_inside(x - 1, y) ||
                  _inside(x + 1, y) ||
                  _inside(x, y - 1) ||
                  _inside(x, y + 1)) &&
              rand(x, y, f) < 0.25 + 0.65 * k) {
            p.px(
              actor.x + x,
              actor.y + y,
              k > 0.6 && rand(x, y, 7) < 0.5 ? kWhite : c[6],
            );
          }
        }
      }
      p.glow(mx, my, 30, c[5], 0.5 * k);
    } else if (t < _out + 0.05) {
      squeezed(p, actor, sh, 1.0, kWhite, c[6]);
      p.glow(mx, my, 40, c[5], 0.8);
    } else if (t < _out + _squeeze) {
      final q = Ease.inCubic((t - _out - 0.05) / (_squeeze - 0.05));
      squeezed(p, actor, sh, 1.0 - q, kWhite, c[6]);
      p.glow(mx, my, 34, c[5], 0.8);
    } else if (t < _pop) {
      final q = (t - _out - _squeeze) / _collapse;
      final hh = (actor.h / 2.0 + 2.0) * (1.0 - Ease.inQuad(q));
      for (var y = -hh - 3.0; y <= hh + 3.0; y++) {
        p.dot(mx, my + y, y.abs() < hh ? kWhite : c[6],
            y.abs() < hh ? 1.0 : 0.7);
      }
      if (hh > 4.0) {
        for (var y = -hh * 0.7; y <= hh * 0.7; y++) {
          p.dot(mx - 1.0, my + y, c[5], 0.6);
          p.dot(mx + 1.0, my + y, c[5], 0.6);
        }
      }
      p.glow(mx, my, 30, c[5], 0.9);
      p.glow(mx, my, 8, kWhite, 0.5);
    }
    if (t >= _pop && t < _pop + 0.22) {
      final q = (t - _pop) / 0.22;
      flare(p, mx, my, 22.0 * math.pow(1.0 - q, 1.5) + 2.0, 1.0 - q, c);
      if (q < 0.3) p.circle(mx, my, 4.0 * (1.0 - q / 0.3) + 1.0, kWhite);
    }
    final k = (t - _pop) / 0.5;
    if (k >= 0.0 && k < 1.0) {
      band(
        p,
        0,
        0,
        4.0 + 30.0 * Ease.outCubic(k),
        0.2,
        math.max(1.0, 3.0 * (1.0 - k)),
        1.15 - k,
        [c[3], c[5], c[6], kWhite],
        keep: (g) => math.sin(g) >= 0.0,
        hot: k < 0.25,
      );
    }
    if (t > _pop && t < _pop + 0.3) {
      sparkle(p, mx, my - 1.0, 3.0, c[6], c[5], 0.3 * (1.0 - (t - _pop) / 0.3));
    }
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect blinkOutEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'arcane/blink-out',
    name: 'Blink out',
    desc:
        'The caster crackles with gathering light, flashes white, squeezes into a line of light that collapses and pops away in sparks.',
    category: 'arcane',
    tags: ['arcane', 'blink', 'teleport', 'vanish', 'movement', 'magic', 'one-shot'],
    size: (136, 96),
    origin: (68, 80),
    duration: 1.6,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'palette': Pal.arcane, 'seed': 11},
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      const PoseKey(-0.36, kReady),
      const PoseKey(-0.1, _inPose),
      PoseKey(0.2, _inPose.copyWith(crouch: 5)),
      PoseKey(0.32, _inPose.copyWith(crouch: 0), PoseEase.snap),
      PoseKey(1.6, _inPose.copyWith(crouch: 0)),
    ],
  ),
  onActorAlpha: (t, _) => t < _out ? 1.0 : 0.0,
  onCreate: (o) => _BlinkOutSim(o),
);
