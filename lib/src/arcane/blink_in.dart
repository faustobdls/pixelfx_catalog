// The arrival (bits converging, a line of light that opens into the silhouette, a ring on the floor, a burst of
// stars) is adapted from Sprite Fusion's open-source blink (https://www.spritefusion.com/pixel-art-vfx/movement),
// MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'arcane_lib.dart';

const double _line = 0.26;
const double _grow = 0.1;
const double _open = 0.12;
const double _arrive = _line + _grow + _open;

const Pose _landed = Pose(
  crouch: 7,
  lean: 3,
  fx: 9,
  fy: -12,
  bx: 12,
  by: -12,
  ffx: 8,
  fbx: -6,
);

class _Bit {
  final double tx;
  final double ty;
  final double ox;
  final double oy;
  final double t0;
  final double t1;
  final double spin;
  final int c;

  const _Bit({
    required this.tx,
    required this.ty,
    required this.ox,
    required this.oy,
    required this.t0,
    required this.t1,
    required this.spin,
    required this.c,
  });
}

class _BlinkInSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final ActorDefinition actor;
  final Uint8List sh;
  late final Particles ps;
  final Lights lights = Lights();
  late final double mx;
  late final double my;
  late final List<int> cols;
  late final List<_Bit> bits;
  double t = 0.0;
  bool arrived = false;

  _BlinkInSim(Map<String, Object?> o)
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
    bits = List.generate(230, (_) {
      final a = r.range(0.0, tau);
      final d = r.range(16.0, 46.0);
      final ty = actor.y + r.range(3.0, actor.h - 2.0);
      var oy = math.sin(a) * d * 0.8 - 6.0;
      if (ty + oy > -2.0) oy = -oy.abs() - 2.0;
      return _Bit(
        tx: mx + r.range(-1.0, 1.0),
        ty: ty,
        ox: math.cos(a) * d,
        oy: oy,
        t0: r.range(0.0, 0.1),
        t1: _line + r.range(-0.02, _grow),
        spin: r.range(0.8, 1.8) * r.sign(),
        c: r.pick(cols),
      );
    }, growable: false);
  }

  bool _inside(int x, int y) =>
      x >= 0 &&
      y >= 0 &&
      x < actor.w &&
      y < actor.h &&
      actor.mask.data[y * actor.w + x] != 0;

  (double x, double y, double k) _at(_Bit b, double tt) {
    final k = clamp((tt - b.t0) / (b.t1 - b.t0));
    final e = Ease.outCubic(k);
    final rr = 1.0 - e;
    final sp = b.spin * rr * 1.2;
    final ox = b.ox * math.cos(sp) - b.oy * math.sin(sp);
    final oy = b.ox * math.sin(sp) + b.oy * math.cos(sp);
    return (b.tx + ox * rr, math.min(-1.0, b.ty + oy * rr), k);
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (t < _line && r.chance(0.6)) {
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
    if (!arrived && t >= _arrive) {
      arrived = true;
      lights.add(mx, my - 6.0, 56, c[5], 0.9, 0.35);
      lights.add(mx, my, 24, kWhite, 0.8, 0.1);
      for (var i = 0; i < 30; i++) {
        final a = r.range(0.0, tau);
        final sp = r.range(35.0, 110.0);
        ps.spawn(
          r.chance(0.6) ? P.star : P.mote,
          mx,
          my,
          math.cos(a) * sp,
          math.sin(a) * sp * 0.7 - 30.0,
          r.range(0.4, 0.85),
          r.pick(cols),
          r.range(0.6, 1.6),
        );
      }
      for (var i = 0; i < 12; i++) {
        final s = r.sign();
        ps.spawn(
          P.spark,
          mx + s * r.range(2.0, 8.0),
          -1.0,
          s * r.range(60.0, 180.0),
          -r.range(20.0, 110.0),
          r.range(0.2, 0.45),
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k = (t - _arrive + 0.03) / 0.5;
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
    p.glow(0, -1, 26, c[5],
        0.3 * (t < _arrive ? t / _arrive : 1.0 - clamp((t - _arrive) / 0.5)));
  }

  @override
  void draw(Painter p) {
    for (final b in bits) {
      if (t < b.t0 || t > b.t1 + 0.02) continue;
      final (x, y, k) = _at(b, t);
      p.dot(x, y, k > 0.75 ? kWhite : b.c, math.min(1.0, 0.35 + k * 2.0));
      if (k > 0.55) {
        final (px, py, _) = _at(b, t - 0.015);
        p.dot((x + px) / 2.0, (y + py) / 2.0, c[5], 0.8);
      }
      if (k > 0.8) p.glow(x, y, 3, c[6], 0.3);
    }
    if (t >= _line - 0.04 && t < _line) {
      final q = (t - _line + 0.04) / 0.04;
      sparkle(p, mx, my, 2.0 + 3.0 * q, c[6], c[5], 0.6);
    } else if (t >= _line && t < _line + _grow) {
      final q = Ease.outCubic((t - _line) / _grow);
      final hh = (actor.h / 2.0 + 3.0) * q;
      for (var y = -hh - 2.0; y <= hh + 2.0; y++) {
        p.dot(mx, my + y, y.abs() < hh ? kWhite : c[6],
            y.abs() < hh ? 1.0 : 0.7);
      }
      for (var y = -hh * 0.7; y <= hh * 0.7; y++) {
        p.dot(mx - 1.0, my + y, c[5], 0.6);
        p.dot(mx + 1.0, my + y, c[5], 0.6);
      }
      p.glow(mx, my, 30, c[5], 0.9);
      p.glow(mx, my, 8, kWhite, 0.5);
    } else if (t >= _line + _grow && t < _arrive) {
      final q = Ease.outCubic((t - _line - _grow) / _open);
      squeezed(p, actor, sh, q, kWhite, c[6]);
      p.glow(mx, my, 36, c[5], 0.8);
    } else if (t >= _arrive && t < _arrive + 0.42) {
      final k = 1.0 - (t - _arrive) / 0.42;
      final f = (t * 30.0).floor();
      if (k > 0.86) squeezed(p, actor, sh, 1.0, kWhite, c[6]);
      for (var y = 0; y < actor.h; y++) {
        for (var x = 0; x < actor.w; x++) {
          if (_inside(x, y)) {
            p.light(
              actor.x + x,
              actor.y + y,
              c[6],
              k * k * (sh[y * actor.w + x] == 1 ? 0.3 : 0.8),
            );
          } else if ((_inside(x - 1, y) ||
                  _inside(x + 1, y) ||
                  _inside(x, y - 1) ||
                  _inside(x, y + 1)) &&
              rand(x, y, f) < 0.85 * k) {
            p.px(
              actor.x + x,
              actor.y + y,
              k > 0.5 && rand(x, y, 7) < 0.5 ? kWhite : c[6],
            );
          }
        }
      }
      p.glow(mx, my, 34, c[5], 0.6 * k);
    }
    if (t >= _arrive && t < _arrive + 0.2) {
      final q = (t - _arrive) / 0.2;
      flare(p, mx, my - 4.0, 18.0 * math.pow(1.0 - q, 1.5) + 2.0, 1.0 - q, c);
    }
    final k = (t - _arrive + 0.03) / 0.5;
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
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect blinkInEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'arcane/blink-in',
    name: 'Blink in',
    desc:
        'Glittering bits spiral in to a point of light that opens into a line, then into a white silhouette that cools into the caster.',
    category: 'arcane',
    tags: ['arcane', 'blink', 'teleport', 'appear', 'movement', 'magic', 'one-shot'],
    size: (136, 96),
    origin: (68, 80),
    duration: 1.4,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {'palette': Pal.arcane, 'seed': 12},
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      const PoseKey(0.0, _landed),
      const PoseKey(0.48, _landed),
      PoseKey(0.56, _landed.copyWith(crouch: 6), PoseEase.snap),
      const PoseKey(0.95, kReady),
      const PoseKey(1.4, kReady),
    ],
    hits: const [
      HitSpec(t: 0.48, stop: 0.03, shake: 0.1, amp: 1),
    ],
    dust: const [
      DustSpec(t: 0.48, x: 0, n: 7),
    ],
  ),
  onActorAlpha: (t, _) => t < _arrive ? 0.0 : 1.0,
  onCreate: (o) => _BlinkInSim(o),
);
