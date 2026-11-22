import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ui_lib.dart';

const double _step = 0.62;
const double _r = 30.0;
const double _top = -math.pi / 2.0;

double _drawTimer(
  Painter p,
  List<int> c,
  double x,
  double y,
  double f,
  bool flash,
  double t,
) {
  p.ringShaded(
    x,
    y,
    _r + 4.0,
    8.0,
    color: (v, _) => (v < 0.13 || v > 0.87) ? c[0] : c[1],
  );
  for (var j = 0; j < 40; j++) {
    final an = (j / 40.0) * tau + t * 0.6;
    p.dot(
      x + math.cos(an) * (_r - 6.0),
      y + math.sin(an) * (_r - 6.0),
      j % 5 != 0 ? c[2] : c[4],
      1.0,
    );
  }
  final head = _top + tau * (1.0 - f);
  for (var i = 0; i < 12; i++) {
    final an = _top + (i * tau) / 12.0;
    final lit = an >= head - 1e-6 || f >= 0.999;
    final near = (an - head).abs() < 0.2 && f < 0.999;
    final ca = math.cos(an);
    final sa = math.sin(an);
    p.line(
      x + ca * (_r + 6.0),
      y + sa * (_r + 6.0),
      x + ca * (_r + 8.0),
      y + sa * (_r + 8.0),
      (flash || near) ? kWhite : (lit ? c[5] : c[2]),
    );
  }
  if (f <= 0.002) return head;
  p.arcShaded(
    x,
    y,
    _r + 2.0,
    head,
    _top + tau,
    width: (_) => 5.0,
    color: (u, v) {
      final d = u * tau * f;
      if (flash || d < 0.1) return kWhite;
      if (d < 0.32) return v > 0.5 ? kWhite : c[6];
      return v > 0.75
          ? c[6]
          : (v > 0.4 ? c[5] : (v > 0.15 ? c[4] : c[3]));
    },
  );
  for (var an = head + 0.25; an < _top + tau; an += 0.55) {
    p.glow(
      x + math.cos(an) * (_r - 0.5),
      y + math.sin(an) * (_r - 0.5),
      9,
      c[4],
      0.12,
    );
  }
  final hx = x + math.cos(head) * (_r - 0.5);
  final hy = y + math.sin(head) * (_r - 0.5);
  p.glow(hx, hy, 14, c[5], 0.5);
  if (!flash) {
    sparkle(
      p,
      hx,
      hy,
      2.0 + 1.5 * (0.5 + 0.5 * math.sin(t * 40.0)),
      c[6],
      c[5],
      0.4,
    );
  }
  return head;
}

class _CountdownSim extends BaseEffectSim {
  final List<int> c;
  final List<int> g;
  final Rng rg;
  final int seed;
  final int cShadow;
  final int gShadow;
  late final int n;
  late final Particles ps;
  late final Particles gs;
  final Lights lights = Lights();
  late final double go;
  late final double out;
  static const double _end = 3.1 - 0.05;
  late final List<SpelledWord> digits;
  late final SpelledWord word;
  late final List<(double a, double l)> rays;

  double t = 0.0;
  int beat = -1;
  bool went = false;
  bool popped = false;

  _CountdownSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        g = fit(o.rampOpt('go'), 8),
        rg = Rng(o.seed),
        seed = o.seed,
        cShadow = scaleColor(fit(o.palette, 8)[0], 0.5),
        gShadow = scaleColor(fit(o.rampOpt('go'), 8)[0], 0.5) {
    n = clampInt((o.numOpt('from', 3) + 0.5).floor(), 1, 3);
    ps = Particles(rng: rg, sparks: [c[7], c[6], c[5], c[3]]);
    gs = Particles(rng: rg, sparks: [g[7], g[6], g[5], g[3]]);
    go = n * _step;
    out = go + 0.78;
    digits = List<SpelledWord>.generate(n, (i) => spell('${n - i}'));
    word = spell(o.strOpt('word', 'GO!'));
    rays = List<(double, double)>.generate(
      18,
      (i) => (
        (i / 18.0) * tau + rg.range(-0.06, 0.06),
        i % 2 != 0 ? rg.range(10.0, 16.0) : rg.range(22.0, 30.0),
      ),
    );
  }

  double _sizeAt(double u, double base, double big) =>
      base + big * math.exp(-u * 26.0) * math.cos(u * 38.0);

  double _reach(double v, double d) =>
      v <= d * 2.2 ? 9.0 : -math.log(1.0 - (d * 2.2) / v) / 2.2;

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    final i = (t / _step).floor();
    if (t < go && i != beat) {
      beat = i;
      lights.add(0, 0, 54, c[5], 0.6, 0.35);
      for (var j = 0; j < 14; j++) {
        final an = (j / 14.0) * tau + rg.range(-0.1, 0.1);
        final sp = rg.range(90.0, 200.0);
        ps.spawn(
          P.spark,
          math.cos(an) * (_r + 2.0),
          math.sin(an) * (_r + 2.0),
          math.cos(an) * sp,
          math.sin(an) * sp,
          math.min(rg.range(0.12, 0.3), _reach(sp, 26.0)),
        );
      }
    }

    if (t < go) {
      final k = t.remainder(_step) / _step;
      final f = 1.0 - seg(k, 0.06, 0.97);
      final head = _top + tau * (1.0 - f);
      if (f > 0.01 && f < 0.99 && rg.chance(0.7)) {
        final hx = math.cos(head) * _r;
        final hy = math.sin(head) * _r;
        final tx = -math.sin(head);
        final ty = math.cos(head);
        final outDir = rg.range(-0.4, 1.0);
        final sp = rg.range(60.0, 150.0);
        ps.spawn(
          P.spark,
          hx,
          hy,
          (-tx * 0.8 + math.cos(head) * outDir) * sp,
          (-ty * 0.8 + math.sin(head) * outDir) * sp - 20.0,
          rg.range(0.12, 0.28),
        );
        if (rg.chance(0.15)) {
          ps.spawn(
            P.ember,
            hx,
            hy,
            math.cos(head) * rg.range(5.0, 20.0),
            math.sin(head) * rg.range(5.0, 20.0),
            rg.range(0.4, 0.8),
            c[5],
            1.0,
          );
        }
      }
    }

    if (!went && t >= go) {
      went = true;
      lights.add(0, 0, 70, kWhite, 0.9, 0.18);
      lights.add(0, 0, 64, g[5], 0.7, 0.8);
      for (var j = 0; j < 36; j++) {
        final an = rg.range(0.0, tau);
        final sp = rg.range(120.0, 300.0);
        gs.spawn(
          P.spark,
          math.cos(an) * _r,
          math.sin(an) * _r,
          math.cos(an) * sp,
          math.sin(an) * sp - 40.0,
          math.min(rg.range(0.18, 0.36), _reach(sp, 24.0)),
        );
      }
      for (var j = 0; j < 18; j++) {
        final an = rg.range(0.0, tau);
        final sp = rg.range(30.0, 80.0);
        final r0 = rg.range(10.0, 28.0);
        gs.spawn(
          P.star,
          math.cos(an) * r0,
          math.sin(an) * r0,
          math.cos(an) * sp,
          math.sin(an) * sp - 10.0,
          rg.range(0.5, 1.0),
          rg.pick([g[7], g[6], g[5]]),
          rg.chance(0.4) ? rg.range(1.5, 2.5) : 0.6,
        );
      }
    }

    if (t > go + 0.2 && t < out - 0.1 && rg.chance(0.12)) {
      final an = rg.range(0.0, tau);
      final r0 = rg.range(30.0, 46.0);
      gs.spawn(
        P.star,
        math.cos(an) * r0,
        math.sin(an) * r0 * 0.8,
        0.0,
        -rg.range(4.0, 12.0),
        rg.range(0.3, 0.6),
        rg.pick([g[7], g[6]]),
        rg.chance(0.3) ? 1.6 : 0.6,
      );
    }

    if (!popped && t >= out + 0.05) {
      popped = true;
      lights.add(0, 0, 40, g[6], 0.6, 0.25);
      for (var j = 0; j < 14; j++) {
        final an = (j / 14.0) * tau + rg.range(-0.15, 0.15);
        final sp = rg.range(60.0, 130.0);
        gs.spawn(
          P.star,
          math.cos(an) * 12.0,
          math.sin(an) * 8.0,
          math.cos(an) * sp,
          math.sin(an) * sp * 0.8 - 10.0,
          math.min(rg.range(0.3, 0.45), _end - t),
          rg.pick([g[7], g[6], g[5]]),
          j % 3 != 0 ? 0.6 : rg.range(1.3, 2.0),
        );
      }
    }

    ps.update(dt);
    gs.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    if (t < go) {
      final i = (t / _step).floor();
      final u = t - i * _step;
      final k = u / _step;
      final (sx, sy) = shake(t, 3.0, i * _step, 0.22, seed + i);
      final f = 1.0 - seg(k, 0.06, 0.97);
      final flash = u < 0.07;
      final rk = u / 0.3;
      if (rk < 1.0) {
        p.ring(
          sx,
          sy,
          _r + 6.0 + 22.0 * Ease.outCubic(rk),
          1.5 * (1.0 - rk) + 1.0,
          rk < 0.3 ? kWhite : c[5],
          1.3 * (1.0 - rk),
        );
      }
      _drawTimer(p, c, sx.toDouble(), sy.toDouble(), f, flash, t);
      if (u < 0.035) {
        p.circle(sx, sy, _r - 3.0, kWhite);
      } else if (u < 0.07) {
        p.ring(sx, sy, _r - 3.0, 3, c[6]);
      }
      final s = _sizeAt(u, 5.0, 2.0);
      final d = digits[i];
      final w = d.w * s;
      final h = 7.0 * s;
      final x0 = sx - w / 2.0;
      final y0 = sy - h / 2.0;
      final items = [
        for (final l in d.letters)
          if (l.g != null)
            WordLetter(
              g: l.g!,
              x: x0 + l.x * s,
              y: y0,
              sx: s,
              sy: s,
              flash: u < 0.035 ? 1.0 : (u < 0.07 ? 0.4 : 0.0),
            ),
      ];
      drawWord(
        p,
        items,
        WordStyle(
          fill: [c[4], c[5], c[6], c[7]],
          edge: kWhite,
          under: c[3],
          outline: c[0],
          ow: 2,
          shadow: cShadow,
        ),
      );
      p.glow(sx, sy, 30, c[4], 0.22 + (u < 0.12 ? 0.6 * (1.0 - u / 0.12) : 0.0));
      p.glow(sx, sy, _r + 8.0, c[3], 0.2 * (1.0 - k) + 0.08);
    } else {
      final u = t - go;
      final (sx, sy) = shake(t, 4.0, go, 0.3, seed + 9);
      final bk = u / 0.4;
      if (bk < 1.0) {
        final rRing = _r + 4.0 + 30.0 * Ease.outCubic(bk);
        final w = math.max(1.0, 7.0 * (1.0 - bk));
        p.ringShaded(
          0,
          0,
          rRing,
          w,
          color: (v, _) => (bk < 0.2 || v > 0.6) ? kWhite : g[6],
          alpha: (_, _) => 1.4 * (1.0 - bk),
        );
        p.glowRing(0, 0, rRing - w / 2.0, 8, g[5], 0.5 * (1.0 - bk));
      }
      final ik = (u - 0.05) / 0.3;
      if (ik > 0.0 && ik < 1.0) {
        p.ring(0, 0, _r + 22.0 * Ease.outCubic(ik), 1, g[5], 1.2 * (1.0 - ik));
      }
      final rk = Ease.outExpo(clamp(u / 0.18)) *
          (1.0 - Ease.inQuad(seg(t, out - 0.25, out + 0.05)));
      if (rk > 0.02) {
        for (final (rayA, rayL) in rays) {
          final an = rayA + u * 0.35;
          final ca = math.cos(an);
          final sa = math.sin(an);
          final r0 = 1.0 / math.sqrt(math.pow(ca / 40.0, 2) + math.pow(sa / 23.0, 2)) +
              3.0 * rk;
          final r1 = r0 + rayL * 0.7 * rk;
          p.lineShaded(
            ca * r0,
            sa * r0,
            ca * r1,
            sa * r1,
            color: (q) => q < 0.3 ? kWhite : (q < 0.65 ? g[6] : g[5]),
            alpha: (q) => q < 0.6 ? 1.3 : (1.3 * (1.0 - q)) / 0.4,
          );
        }
      }

      final pu = (t - out) / 0.06;
      if (pu < 1.0) {
        var s = _sizeAt(u, 5.0, 3.5);
        var flash = u < 0.035 ? 1.0 : (u < 0.07 ? 0.4 : 0.0);
        final throb =
            math.max(0.0, math.sin((u - 0.25) * 9.0)) * smooth(0.25, 0.35, u);
        if (pu > 0.0) {
          s = 5.0 * (1.0 + 0.25 * pu);
          flash = 1.0;
        }
        final w = word.w * s;
        final h = 7.0 * s;
        final x0 = sx - w / 2.0;
        final y0 = sy - h / 2.0;
        final items = [
          for (final l in word.letters)
            if (l.g != null)
              WordLetter(
                g: l.g!,
                x: x0 + l.x * s,
                y: y0,
                sx: s,
                sy: s,
                slant: 1.0,
                flash: flash,
              ),
        ];
        final sh = seg(u, 0.32, 0.56);
        final shine = (sh > 0.0 && sh < 1.0)
            ? x0 - 8.0 + (w + 22.0) * Ease.inOutSine(sh)
            : null;
        drawWord(
          p,
          items,
          WordStyle(
            fill: [g[4], g[5], g[6], g[7]],
            edge: kWhite,
            under: g[3],
            outline: g[0],
            ow: 2,
            shadow: gShadow,
            shine: shine,
            shineY: y0,
            glint: g[6],
          ),
        );
        p.glow(
          sx,
          sy,
          46,
          g[5],
          0.25 + 0.15 * throb + (u < 0.12 ? 0.7 * (1.0 - u / 0.12) : 0.0),
        );
      } else {
        final k = (t - out - 0.06) / 0.22;
        if (k > 0.0 && k < 1.0) {
          p.ring(
            0,
            0,
            8.0 + 26.0 * Ease.outCubic(k),
            1,
            k < 0.4 ? kWhite : g[6],
            1.3 * (1.0 - k),
          );
        }
      }
    }

    ps.draw(p);
    gs.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect countdownEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ui/countdown',
    name: 'Countdown',
    desc:
        '3, 2, 1 slam into a timer ring that drains like a burning fuse, throwing sparks; then GO! bursts out as the ring blows into a shockwave with rays.',
    category: 'ui',
    tags: ['ui', 'countdown', 'start', 'timer', 'text', 'one-shot'],
    size: (152, 136),
    origin: (76, 68),
    duration: 3.1,
    loop: false,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#0a1030',
        '#142a66',
        '#1f4fae',
        '#2f86e6',
        '#5cc4ff',
        '#a8e8ff',
        '#e6fbff',
        '#ffffff',
      ],
      'go': [
        '#0b2410',
        '#16501c',
        '#22882a',
        '#3cc23a',
        '#7ee84c',
        '#c4ff8a',
        '#f0ffd6',
        '#ffffff',
      ],
      'from': 3,
      'word': 'GO!',
      'seed': 5,
    },
  ),
  onCreate: _CountdownSim.new,
);
