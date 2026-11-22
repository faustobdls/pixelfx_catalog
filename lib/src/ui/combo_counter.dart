import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ui_lib.dart';

const double _hit = 0.1;
const double _beat = 0.5;
const double _out = 1.1;
const double _bs = 4.0;
const double _ls = 2.0;
const double _base = 12.0;

void _speedLines(Painter p, List<int> c, double t, double k, int dir) {
  if (k <= 0.02) return;
  final f = (t * 30.0).floor();
  for (var i = 0; i < 18; i++) {
    if (rand(f, i, 3) > k) continue;
    final y = ((rand(f, i, 1) - 0.5) * 60.0 + 0.5).floor();
    final len = 16.0 + rand(f, i, 2) * 50.0;
    final x = (rand(f, i, 4) - 0.5) * 190.0;
    final x0 = math.max(-100.0, x - len / 2.0);
    final x1 = math.min(100.0, x + len / 2.0);
    p.lineShaded(
      x0,
      y,
      x1,
      y,
      color: (u) {
        final d = dir > 0 ? u : 1.0 - u;
        return d > 0.75 ? kWhite : (d > 0.35 ? c[6] : c[4]);
      },
      alpha: (u) => (dir > 0 ? u : 1.0 - u) < 0.25 ? 0.6 : 1.0,
    );
  }
}

class _ComboCounterSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final int seed;
  final int shadowCol;
  late final Particles ps;
  final Lights lights = Lights();
  late final SpelledWord big;
  late final SpelledWord lab;
  late final double w;
  late final double x0;
  late final List<(double, double)> spikes;

  double t = 0.0;
  bool hit = false;
  bool out = false;

  _ComboCounterSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed),
        seed = o.seed,
        shadowCol = scaleColor(fit(o.palette, 8)[0], 0.5) {
    ps = Particles(rng: r, sparks: [c[7], c[6], c[5], c[3]]);
    big = spell('x${(o.numOpt('count', 5) + 0.5).floor()}');
    lab = spell(o.strOpt('label', 'COMBO'));
    w = big.w * _bs + 4.0 + lab.w * _ls;
    x0 = -w / 2.0;
    spikes = List<(double, double)>.generate(
      10,
      (i) => ((i / 10.0) * tau + r.range(-0.15, 0.15), r.range(14.0, 24.0)),
    );
  }

  double _xAt(double time) {
    final tc = math.max(0.0, time);
    if (tc < _hit) return -32.0 * math.pow(1.0 - tc / _hit, 2);
    if (tc < _out) {
      return 7.0 * math.exp(-(tc - _hit) * 18.0) * math.sin((tc - _hit) * 34.0);
    }
    final u = seg(tc, _out, _out + 0.2);
    return u < 0.3
        ? -4.0 * Ease.outQuad(u / 0.3)
        : -4.0 + 24.0 * Ease.inQuad((u - 0.3) / 0.7);
  }

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    if (!hit && t >= _hit) {
      hit = true;
      lights.add(0, 0, 70, c[5], 0.7, 0.4);
      lights.add(-20, 0, 34, kWhite, 0.8, 0.1);
      for (var i = 0; i < 26; i++) {
        final an = r.range(-1.2, 1.2) + (r.chance(0.3) ? math.pi : 0.0);
        final sp = r.range(120.0, 300.0);
        ps.spawn(
          P.spark,
          r.range(-20.0, 20.0),
          r.range(-8.0, 8.0),
          math.cos(an) * sp,
          math.sin(an) * sp * 0.6 - 20.0,
          r.range(0.12, 0.3),
        );
      }
    }
    if (t > _beat && t < _out && r.chance(0.1)) {
      final x = x0 + r.range(0.0, big.w * _bs);
      final y = _base - r.range(0.0, 30.0);
      ps.spawn(
        P.star,
        x,
        y,
        r.range(-10.0, 10.0),
        -r.range(5.0, 20.0),
        r.range(0.25, 0.45),
        r.pick([c[7], c[6]]),
        r.chance(0.3) ? 1.6 : 0.6,
      );
    }
    if (!out && t >= _out + 0.06) {
      out = true;
      for (var i = 0; i < 10; i++) {
        ps.spawn(
          P.mote,
          r.range(-50.0, 30.0),
          r.range(-14.0, 10.0),
          r.range(220.0, 320.0),
          r.range(-10.0, 10.0),
          r.range(0.06, 0.14),
          r.pick([c[7], c[6]]),
          1.0,
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final (sx, sy) = shake(t, 3.0, _hit, 0.25, seed);
    final speedK = t < _hit
        ? 1.0
        : (t < _out
            ? math.max(0.0, 1.0 - (t - _hit) / 0.35) * 0.9
            : seg(t, _out + 0.04, _out + 0.12) *
                (1.0 - seg(t, _out + 0.18, _out + 0.3)));
    _speedLines(p, c, t, speedK, t >= _out ? -1 : 1);

    final hk = t - _hit;
    if (hk >= 0.0 && hk < 0.07) {
      final cx = x0 + (big.w * _bs) / 2.0;
      final k = hk < 0.035 ? 1.0 : 1.3;
      for (final (an, len) in spikes) {
        final ca = math.cos(an) * 1.4;
        final sa = math.sin(an);
        if (k == 1.0) {
          p.beamShaded(
            cx,
            0,
            cx + ca * len,
            sa * len,
            3,
            color: (u, _) => u < 0.5 ? kWhite : c[6],
          );
        } else {
          p.line(
            cx + ca * len * 0.5,
            sa * len * 0.5,
            cx + ca * len * k,
            sa * len * k,
            c[5],
          );
        }
      }
    }

    final rk = (t - _hit) / 0.32;
    if (rk > 0.0 && rk < 1.0) {
      final rRing = 20.0 + 34.0 * Ease.outCubic(rk);
      p.ellipseShaded(
        sx,
        sy,
        rRing * 1.5,
        rRing * 0.75,
        color: (_, _) => rk < 0.3 ? kWhite : c[5],
        alpha: (d, _) => d > 1.0 - 1.5 / (rRing * 0.75) ? 1.25 - rk : 0.0,
      );
    }

    ps.draw(p);

    final x = _xAt(t);
    final moving = t < _hit || t > _out + 0.06;
    final stretch = moving ? (t < _hit ? 1.22 : 1.12) : 1.0;
    final pulse = math.exp(-math.pow((t - _beat) / 0.05, 2));
    final flash =
        ((t >= _hit && t < _hit + 0.07) || pulse > 0.6) ? 1.0 : 0.0;
    final a = t > _out
        ? 1.0 - seg(t, _out + 0.08, _out + 0.2)
        : (t < 0.035 ? 0.5 : 1.0);

    List<WordLetter> layout(double dx, double dy, double letterFlash) {
      final bs = _bs * (1.0 + 0.12 * pulse);
      final items = <WordLetter>[];
      final bx = x0 + dx - (big.w * _bs * (stretch - 1.0)) / 2.0;
      final by = _base - 7.0 * bs + dy;
      for (final l in big.letters) {
        if (l.g != null) {
          items.add(WordLetter(
            g: l.g!,
            x: bx + l.x * _bs * stretch,
            y: by,
            sx: _bs * stretch,
            sy: bs,
            slant: 1.0,
            flash: letterFlash,
            a: a,
          ));
        }
      }
      final lx = x0 + dx + big.w * _bs * stretch + 4.0;
      for (final l in lab.letters) {
        if (l.g != null) {
          items.add(WordLetter(
            g: l.g!,
            x: lx + l.x * _ls * stretch,
            y: _base - 7.0 * _ls + dy,
            sx: _ls * stretch,
            sy: _ls,
            slant: 0.5,
            flash: letterFlash,
            a: a,
          ));
        }
      }
      return items;
    }

    if (moving && a > 0.0) {
      for (final (lag, col) in [(0.03, c[2]), (0.015, c[3])]) {
        final items = layout(_xAt(t - (t < _hit ? lag : -lag)) + sx, 0.0, 0.0);
        drawWord(
          p,
          items,
          WordStyle(fill: [col], edge: col, under: col, outline: 0),
        );
      }
    }

    if (a > 0.0) {
      final sh = seg(t, 0.62, 0.86);
      final items = layout(x + sx, sy.toDouble(), flash);
      drawWord(
        p,
        items,
        WordStyle(
          fill: [c[4], c[5], c[6], c[7]],
          edge: kWhite,
          under: c[3],
          outline: c[0],
          ow: 2,
          shadow: shadowCol,
          shine: (sh > 0.0 && sh < 1.0) ? x0 - 10.0 + (w + 24.0) * sh : null,
          shineY: _base - 28.0,
          glint: c[6],
        ),
      );
      final bk = seg(t, _hit + 0.1, _hit + 0.2) * (t > _out ? 0.0 : 1.0);
      if (bk > 0.0) {
        final bw = w * bk;
        final left = 1.0 - seg(t, _hit + 0.2, _out);
        final bx = x0 + x + sx;
        final by = _base + 5.0 + sy;
        p.rect(bx - 1.0, by - 1.0, bw + 2.0, 4, c[0]);
        p.rect(bx, by, bw, 2, c[1]);
        if (left > 0.0) {
          p.rect(bx, by, bw * left, 2, c[5]);
          p.rect(bx, by, bw * left, 1, c[6]);
          p.px(bx + bw * left - 1.0, by, kWhite);
        }
      }
    }

    p.glow(
      sx - 20,
      0,
      60,
      c[4],
      0.2 * a +
          (t >= _hit && t < _hit + 0.15 ? 0.5 * (1.0 - (t - _hit) / 0.15) : 0.0) +
          0.25 * pulse,
    );
    final g = (t - 0.86) / 0.22;
    if (g > 0.0 && g < 1.0) {
      sparkle(
        p,
        x0 + w - 2.0,
        _base - 14.0,
        6.0 * math.sin(g * math.pi),
        c[7],
        c[5],
        0.5,
      );
    }
    lights.draw(p);
  }
}

final SimulatedEffect comboCounterEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ui/combo-counter',
    name: 'Combo counter',
    desc:
        'x5 COMBO rockets in on streaming speed lines, smearing, and slams to a stop: a white flash, a ring, sparks; it pulses while a timer bar drains, then whooshes out.',
    category: 'ui',
    tags: ['ui', 'combo', 'counter', 'combat', 'text', 'one-shot'],
    size: (208, 100),
    origin: (104, 50),
    duration: 1.45,
    loop: false,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#1a0516',
        '#3d0a33',
        '#701560',
        '#b0228f',
        '#f53cd1',
        '#ff86e6',
        '#ffd2f6',
        '#ffffff',
      ],
      'count': 5,
      'label': 'COMBO',
      'seed': 6,
    },
  ),
  onCreate: _ComboCounterSim.new,
);
