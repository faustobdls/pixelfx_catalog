import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'spawn_lib.dart';

const Pose _slump = Pose(
  crouch: 8,
  lean: 6,
  hy: 2,
  fx: 7,
  fy: -9,
  bx: 11,
  by: -9,
  ffx: 9,
  fbx: -8,
);

const double _leave = 0.35;
const double _top = 2.05;
const double _gone = 2.55;
const double _duration = 3.2;
final int _shadow = hex('#0c0f1e');

final PixelEffect soulRiseEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'spawn/soul-rise',
    name: 'Soul rise',
    desc:
        'The body\'s outline flares and dims, then a pale glowing copy of it lifts out, stretching as its legs melt into a rippling wisp, shedding motes until it thins into light.',
    category: 'spawn',
    tags: [
      'spawn',
      'death',
      'soul',
      'ghost',
      'spirit',
      'rise',
      'light',
      'one-shot',
    ],
    size: (96, 140),
    origin: (48, 126),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#101a33',
        '#1f3563',
        '#35609e',
        '#5c96d4',
        '#94c8f0',
        '#d2f0ff',
        '#ffffff',
      ],
      'height': 50,
      'seed': 27,
    },
  ),
  act: const ActSpec(
    onBody: true,
    follow: 0,
    poses: [
      PoseKey(-0.2, kReady),
      PoseKey(
        0.3,
        Pose(
          turn: 1,
          crouch: 2,
          hy: -1,
          fx: -10,
          fy: -24,
          bx: 11,
          by: -24,
          ffx: -3,
          fbx: 4,
        ),
      ),
      PoseKey(
        0.7,
        Pose(
          turn: 0.7,
          crouch: 4,
          lean: 3,
          hy: 1,
          fx: 2,
          fy: -14,
          bx: 8,
          by: -14,
          ffx: 4,
          fbx: -3,
        ),
      ),
      PoseKey(1.1, _slump),
      PoseKey(2.7, _slump),
      PoseKey(
        3.2,
        Pose(
          crouch: 7,
          lean: 6,
          hy: 2,
          fx: 7,
          fy: -9,
          bx: 11,
          by: -9,
          ffx: 9,
          fbx: -8,
        ),
      ),
    ],
    dust: [DustSpec(t: 1.1, x: 0, n: 5)],
  ),
  onActorAlpha: (_, _) => 1.0,
  onCreate: (o) => _SoulRiseSim(o),
);

class _SoulRiseSim extends BaseEffectSim {
  _SoulRiseSim(Map<String, Object?> o) {
    cRamp = fit(o.palette, 7);
    rng = Rng(o.seed);
    heightOpt = o.numOpt('height', 50);
    body = bodyOf(o.actor, cRamp);
    rim = rimOf(body);
    w = body.w;
    hh = body.h;
    waist = (hh * 0.6 + 0.5).floor();
    toneAt = Int8List(w * hh)..fillRange(0, w * hh, -1);
    for (final b in body.list) {
      final tVal = b.edge ? 6 : 3 + math.min<int>(2, (luma(b.c) * 3.6).floor());
      toneAt[b.my * w + b.mx] = tVal;
    }
    ps = Particles(
      rng: rng,
      ground: (_) => 0,
      sparks: [kWhite, cRamp[5], cRamp[4], cRamp[3]],
    );
    lights = Lights();
  }

  late final List<int> cRamp;
  late final Rng rng;
  late final double heightOpt;
  late final BodyData body;
  late final List<RimCell> rim;
  late final int w;
  late final int hh;
  late final int waist;
  late final Int8List toneAt;
  late final Particles ps;
  late final Lights lights;
  double t = 0;
  bool left = false;

  double _lift() =>
      heightOpt * Ease.inOutSine(clamp((t - _leave) / (_top - _leave)));

  double _stretch() =>
      1 + 0.22 * Ease.inOutSine(clamp((t - _leave) / (_top - _leave)));

  double _sway(num row) =>
      math.sin(t * 3 - row * 0.12) * 2.2 * smooth(_leave, _leave + 0.5, t);

  double _melt() => smooth(_leave + 0.1, _leave + 0.9, t);

  double _thin() => smooth(_top - 0.25, _gone, t);

  void _ring(Painter p, bool near) {
    final k = (t - _leave) / 0.5;
    if (k > 0 && k < 1) {
      band(
        p,
        0,
        0,
        6 + 26 * Ease.outCubic(k),
        0.18,
        math.max(1.0, 3 * (1 - k)),
        1.15 - k,
        cRamp,
        keep: (double g) => (math.sin(g) >= 0) == near,
        hot: k < 0.12,
      );
    }
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    if (!left && t >= _leave) {
      left = true;
      lights.add(0, -20, 50, cRamp[4], 0.85, 0.55);
      lights.add(0, -20, 24, kWhite, 0.8, 0.12);
      for (var i = 0; i < 10; i++) {
        final c = rng.pick(rim);
        ps.spawn(
          P.star,
          c.x.toDouble(),
          c.y.toDouble(),
          rng.range(-20, 20),
          -rng.range(20, 60),
          rng.range(0.4, 0.8),
          rng.pick([kWhite, cRamp[5]]),
          rng.range(0.8, 1.8),
        );
      }
    }
    if (t > _leave && t < _gone) {
      final s = _stretch();
      final y0 = body.y * s - _lift();
      final th = _thin();
      final count = th > 0 ? 3 : 1;
      for (var n = 0; n < count; n++) {
        if (!rng.chance(th > 0 ? 0.9 : 0.5)) continue;
        final c = rng.pick(rim);
        final row = c.my;
        if (row / hh < 1 - th * 1.1 - 0.05 && th > 0) continue;
        final x = c.x * (1 - 0.12 * (s - 1) * 4) + _sway(row);
        final y = y0 + c.my * s;
        final life = math.min(
          rng.range(0.5, 1.1),
          math.min(_duration - 0.1 - t, (y + 120) / 60),
        );
        if (life > 0.1) {
          ps.spawn(
            rng.chance(0.7) ? P.mote : P.star,
            x,
            y,
            rng.range(-12, 12),
            -rng.range(25, 60),
            life,
            rng.pick([kWhite, cRamp[5], cRamp[5], cRamp[4]]),
            rng.range(0.5, 1),
          );
        }
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    final k = smooth(0, _leave, t) * (1 - smooth(_leave + 0.4, _top, t));
    if (k > 0) p.glow(0, -1, 26, cRamp[4], 0.3 * k);
    _ring(p, false);
  }

  @override
  void draw(Painter p) {
    if (t < _leave + 0.3) {
      final k = t < _leave ? t / _leave : 1 - (t - _leave) / 0.3;
      final fr = (t * 30).floor();
      for (final c in rim) {
        if (rand(c.mx, c.my, fr) < 0.25 + 0.7 * k) {
          p.px(c.x, c.y, k > 0.7 ? kWhite : cRamp[5]);
        }
      }
      p.glow(0, -19, 26, cRamp[4], 0.45 * k);
    }
    final dim =
        smooth(_leave, _leave + 0.6, t) * (1 - smooth(_gone, _duration - 0.1, t));
    if (dim > 0) {
      for (final b in body.list) {
        p.blend(b.x, b.y, _shadow, 0.45 * dim);
      }
    }
    _ring(p, true);
    if (t < _leave || t > _gone + 0.1) {
      ps.draw(p);
      lights.draw(p);
      return;
    }

    final s = _stretch();
    final lVal = _lift();
    final m = _melt();
    final th = _thin();
    final top = body.y * s - lVal;
    final sx = 1 - 0.12 * (s - 1) * 4;
    final tail = (10 * m + 0.5).floor();
    final y1 = top + (hh + tail) * s;
    final fadeIn = clamp((t - _leave) / 0.15);

    for (var y = top.floor(); y <= y1.ceil(); y++) {
      final my = ((y + 0.5 - top) / s).floor();
      if (my < 0) continue;
      final k = my >= waist ? (my - waist + 1) / (hh - waist + tail) : 0.0;
      final narrow = 1 - k * m * 0.95;
      if (narrow <= 0.05) continue;
      final cx = _sway(my) + math.sin(my * 0.7 - t * 8) * 2 * k * m;
      final a = (my >= waist ? 1 - k * 0.45 : 1.0) * fadeIn;
      for (var x = (cx - w / 2 - 4).floor(); x <= (cx + w / 2 + 4).ceil(); x++) {
        final mx = ((x + 0.5 - cx) / (sx * narrow) - body.x).floor();
        if (th > 0 &&
            my / (hh + tail) > 1 - th * 1.25 + 0.25 * rand(mx, my, 5) - 0.1) {
          continue;
        }
        final int ti;
        if (my < hh) {
          if (mx < 0 || mx >= w) continue;
          ti = toneAt[my * w + mx];
          if (ti < 0) continue;
        } else {
          final wTail = (1 - (my - hh) / math.max(1, tail)) * 3.2 * m;
          final d = (x + 0.5 - cx).abs();
          if (d > wTail) continue;
          ti = d > wTail - 1 ? 5 : 4;
        }
        if (t < _leave + 0.07) {
          p.px(x, y, ti >= 6 ? cRamp[5] : kWhite);
        } else if (ti >= 5) {
          p.dot(x.toDouble(), y.toDouble(), ti >= 6 ? kWhite : cRamp[5], math.min(1.0, a * 1.3));
        } else {
          p.blend(x, y, cRamp[ti], a * 0.7);
        }
      }
    }

    final cy = top + hh * s * 0.45;
    p.glow(_sway(10), cy, 30, cRamp[4], 0.42 * fadeIn * (1 - th));
    p.glow(_sway(10), cy - 6, 14, cRamp[5], 0.3 * fadeIn * (1 - th));
    ps.draw(p);
    lights.draw(p);
  }
}
