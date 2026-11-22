import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ui_lib.dart';

const double _fold = 0.92;
const double _tagOut = 0.98;
const double _pop = 1.06;
const double _sx = 1.3;
const double _ns = 4.0;
const double _ny = 5.0;

class _Tip {
  final double len;
  final double dip;
  const _Tip(this.len, this.dip);
}

class _SpeedLine {
  final double a;
  final double r;
  final double len;
  const _SpeedLine(this.a, this.r, this.len);
}

void _starburst(
  Painter p,
  List<int> c,
  double cx,
  double cy,
  double radius,
  double rot,
  List<_Tip> tips,
  double heat,
  int boil, [
  double a = 1.0,
]) {
  if (radius < 2.0 || a <= 0.0) return;
  final n = tips.length;
  final v = <(double, double)>[];
  for (var i = 0; i < n * 2; i++) {
    final an = rot + (i * math.pi) / n;
    final r = radius *
        (i % 2 != 0
            ? 0.6 + tips[i >> 1].dip
            : tips[i >> 1].len * (1.0 + 0.14 * (rand(boil, i) - 0.5)));
    v.add((math.cos(an) * r, math.sin(an) * r));
  }
  final step = math.pi / n;
  double edge(double dx, double dy) {
    var ang = math.atan2(dy, dx) - rot;
    ang -= (ang / tau).floorToDouble() * tau;
    final i = math.min(v.length - 1, (ang / step).floor());
    final (x0, y0) = v[i];
    final (x1, y1) = v[(i + 1) % v.length];
    final ex = x1 - x0;
    final ey = y1 - y0;
    final den = dx * ey - dy * ex;
    return den.abs() < 1e-9 ? hypot(x0, y0) : (x0 * ey - y0 * ex) / den;
  }

  final m = radius * 1.15 + 2.0;
  final rampCols = [kWhite, c[6], c[5], c[4], c[3], c[2]];
  p.shade(cx - m * _sx, cy - m, cx + m * _sx, cy + m, (x, y, out) {
    final dx = (x - cx) / _sx;
    final dy = y - cy;
    final d = hypot(dx, dy);
    if (d < 0.01) return kWhite;
    final l = edge(dx / d, dy / d);
    final gap = (l - d) * (1.0 + 0.3 * (dx / d).abs());
    final q = d / l;
    if (gap < 0.0) return null;
    out.a = a;
    if (heat > 0.85) return gap < 1.0 ? c[6] : kWhite;
    if (gap < 1.0) return c[1];
    if (gap < 2.2) return heat > 0.3 ? kWhite : c[6];
    if (gap < 3.4) return heat > 0.3 ? c[6] : c[5];
    if (gap >= 6.0 && gap < 7.0) return heat > 0.5 ? kWhite : c[4];
    final an = math.atan2(dy, dx) - rot;
    final sp = (((an / tau) * n + 0.5).remainder(1.0) - 0.5).abs() *
        (tau / n) *
        d;
    if (sp < 0.6 && q > 0.25) {
      return heat > 0.5 ? kWhite : (q > 0.6 ? c[5] : c[4]);
    }
    final i = (((q > 0.72 ? 3.0 : (q > 0.45 ? 4.0 : 5.0)) - heat * 5.0) + 0.5)
        .floor();
    return i <= 0 ? kWhite : rampCols[math.min(5, i)];
  });
}

void _drawTag(
  Painter p,
  List<int> c,
  double x,
  double y,
  double w,
  double h,
  double lean,
) {
  p.shade(x - 1.0, y - 1.0, x + w + lean + 1.0, y + h + 1.0, (px, py, _) {
    final lx = px - x - lean * ((y + h - py) / h);
    if (py < y || py > y + h || lx < 0.0 || lx > w) return null;
    if (lx < 1.0 || lx > w - 1.0 || py < y + 1.0 || py > y + h - 1.0) {
      return c[0];
    }
    return py < y + 2.0 ? c[4] : (py < y + h * 0.55 ? c[3] : c[2]);
  });
}

void _speedLines(Painter p, List<int> c, double t, List<_SpeedLine> lines) {
  final k = t / 0.24;
  if (k <= 0.0 || k >= 1.0) return;
  for (final l in lines) {
    final r0 = l.r * (1.0 + 0.5 * Ease.outExpo(k));
    final r1 = r0 + l.len * (1.0 - k) + 2.0;
    final ca = math.cos(l.a) * 1.2;
    final sa = math.sin(l.a) * 0.92;
    p.lineShaded(
      ca * r0,
      sa * r0,
      ca * r1,
      sa * r1,
      color: (u) => (u > 0.5 || k < 0.3) ? kWhite : c[6],
    );
  }
}

class _CritNumberSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final int seed;
  final int shadowCol;
  late final Particles ps;
  final Bits bits = Bits();
  final Lights lights = Lights();
  late final SpelledWord numWord;
  late final SpelledWord lab;
  late final List<_Tip> tips;
  late final List<_SpeedLine> lines;
  static const double _end = 1.5 - 0.05;
  static final List<int> _whiteTagCols = List<int>.filled(5, kWhite);

  double t = 0.0;
  bool slammed = false;
  bool stamped = false;
  bool popped = false;
  bool tagGone = false;

  _CritNumberSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed),
        seed = o.seed,
        shadowCol = scaleColor(fit(o.palette, 8)[0], 0.5) {
    ps = Particles(rng: r, sparks: [c[7], c[6], c[5], c[3]]);
    numWord = spell(o.strOpt('text', '128!'));
    lab = spell(o.strOpt('label', 'CRIT'), PixelFontKind.mini);
    tips = List<_Tip>.generate(
      13,
      (_) => _Tip(r.range(0.86, 1.12), r.range(-0.06, 0.06)),
    );
    lines = List<_SpeedLine>.generate(
      18,
      (i) => _SpeedLine(
        (i / 18.0) * tau + r.range(-0.1, 0.1),
        r.range(31.0, 34.0),
        r.range(8.0, 15.0),
      ),
    );
  }

  double _reach(double v, double d) =>
      v <= d * 2.2 ? 9.0 : -math.log(1.0 - (d * 2.2) / v) / 2.2;

  void _spawnStar(
    double x,
    double y,
    double vx,
    double vy,
    double life,
    int col,
    double size,
  ) {
    ps.spawn(P.star, x, y, vx, vy, math.min(life, _end - t), col, size);
  }

  double _sizeAt(double time) =>
      _ns + 3.0 * math.exp(-time * 26.0) * math.cos(time * 38.0);

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    if (!slammed) {
      slammed = true;
      lights.add(0, 0, 70, kWhite, 0.9, 0.16);
      lights.add(0, 0, 60, c[4], 0.45, 0.5);
      for (var i = 0; i < 30; i++) {
        final an = r.range(0.0, tau);
        final sp = r.range(140.0, 300.0);
        ps.spawn(
          P.spark,
          math.cos(an) * 8.0,
          math.sin(an) * 6.0,
          math.cos(an) * sp * 1.15,
          math.sin(an) * sp - 40.0,
          math.min(r.range(0.12, 0.32), _reach(sp * 1.15, 40.0)),
        );
      }
      for (var i = 0; i < 10; i++) {
        final an = r.range(0.0, tau);
        final sp = r.range(90.0, 170.0);
        bits.add(DebrisBit(
          kind: B.shard,
          x: math.cos(an) * 10.0,
          y: math.sin(an) * 7.0,
          vx: math.cos(an) * sp * 1.15,
          vy: math.sin(an) * sp - 60.0,
          g: 0.35,
          drag: 1.6,
          life: math.min(r.range(0.3, 0.5), _end - t),
          a: r.range(0.0, tau),
          va: r.range(-24.0, 24.0),
          s: r.range(2.0, 3.5),
          c: r.pick([c[7], c[6], c[5]]),
        ));
      }
    }

    if (!stamped && t >= 0.09) {
      stamped = true;
      lights.add(-4, -20, 30, c[6], 0.5, 0.2);
      for (var i = 0; i < 6; i++) {
        ps.spawn(
          P.star,
          -4.0 + r.range(-16.0, 16.0),
          -20.0 + r.range(-4.0, 4.0),
          r.range(-40.0, 40.0),
          r.range(-30.0, 10.0),
          r.range(0.2, 0.4),
          c[6],
          r.range(0.5, 1.4),
        );
      }
    }

    if (!tagGone && t >= _tagOut) {
      tagGone = true;
      for (var i = 0; i < 6; i++) {
        _spawnStar(
          -10.0 + r.range(-16.0, 16.0),
          -14.0 + r.range(-5.0, 5.0),
          r.range(-50.0, 50.0),
          -r.range(10.0, 60.0),
          r.range(0.25, 0.4),
          r.pick([c[7], c[6]]),
          i != 0 ? 0.6 : 1.6,
        );
      }
    }

    if (t > 0.3 && t < _fold - 0.1 && r.chance(0.07)) {
      final an = r.range(0.0, tau);
      final sp = r.range(70.0, 150.0);
      ps.spawn(
        P.spark,
        math.cos(an) * 30.0 * _sx,
        math.sin(an) * 30.0,
        math.cos(an) * sp,
        math.sin(an) * sp - 30.0,
        math.min(r.range(0.12, 0.26), _reach(sp, 14.0)),
      );
    }

    if (t > 0.12 && t < _fold && r.chance(0.16)) {
      final an = r.range(0.0, tau);
      final rad = r.range(14.0, 28.0);
      ps.spawn(
        P.ember,
        math.cos(an) * rad * _sx,
        math.sin(an) * rad,
        r.range(-10.0, 10.0),
        -r.range(15.0, 40.0),
        math.min(r.range(0.5, 0.9), _end - t),
        c[5],
        r.range(1.0, 2.0),
      );
    }

    if (!popped && t >= _pop + 0.05) {
      popped = true;
      lights.add(0, 0, 44, c[6], 0.7, 0.25);
      for (var i = 0; i < 14; i++) {
        final an = (i / 14.0) * tau + r.range(-0.15, 0.15);
        final sp = r.range(60.0, 130.0);
        ps.spawn(
          P.star,
          math.cos(an) * 10.0 * _sx,
          math.sin(an) * 7.0,
          math.cos(an) * sp * _sx,
          math.sin(an) * sp - 10.0,
          math.min(r.range(0.3, 0.42), _end - t),
          r.pick([c[7], c[6], c[5]]),
          i % 3 != 0 ? 0.6 : r.range(1.3, 2.2),
        );
      }
      for (var i = 0; i < 8; i++) {
        final an = r.range(0.0, tau);
        final sp = r.range(120.0, 240.0);
        ps.spawn(
          P.spark,
          math.cos(an) * 6.0,
          math.sin(an) * 4.0,
          math.cos(an) * sp,
          math.sin(an) * sp - 30.0,
          math.min(
            math.min(r.range(0.15, 0.3), _end - t),
            _reach(sp, 40.0),
          ),
        );
      }
    }

    ps.update(dt);
    bits.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final (sx, sy) = shake(t, 4.0, 0.0, 0.32, seed);
    final (lx, ly) = shake(t, 2.0, 0.09, 0.15, seed + 3);
    final grow = t < 0.04 ? 1.25 : 1.0 + 0.1 * math.exp(-(t - 0.04) * 14.0);
    final fold = 1.0 - Ease.inBack(seg(t, _fold - 0.12, _fold), 2.4);
    final heat = t < 0.035 ? 1.0 : clamp(1.0 - (t - 0.035) / 0.12);
    final breathe = 1.0 + 0.04 * math.sin(t * 16.0);
    if (fold > 0.02) {
      _starburst(
        p,
        c,
        sx.toDouble(),
        sy.toDouble(),
        31.0 * grow * fold * breathe,
        -math.pi / 2.0 + 0.25 * t,
        tips,
        heat,
        t < 0.2 ? 0 : (t * 10.0).floor(),
      );
    }
    _speedLines(p, c, t, lines);
    final rk = t / 0.26;
    final rr = 30.0 + 22.0 * Ease.outCubic(rk);
    if (rk > 0.0 && rk < 1.0) {
      p.ellipseShaded(
        0,
        0,
        rr * _sx,
        rr,
        color: (_, _) => rk < 0.35 ? kWhite : c[6],
        alpha: (d, _) => d > 1.0 - 1.6 / rr ? 1.2 - rk : 0.0,
      );
    }
    bits.draw(p);
    ps.draw(p);

    final s = _sizeAt(t);
    var sxN = s;
    var syN = s;
    var flash = t < 0.035 ? 1.0 : (t < 0.07 ? 0.5 : 0.0);
    final pu = (t - _pop) / 0.05;
    if (pu >= 1.0) {
      final k = (t - _pop - 0.05) / 0.22;
      if (k > 0.0 && k < 1.0) {
        final rkPop = 6.0 + 22.0 * Ease.outCubic(k);
        p.ellipseShaded(
          0,
          0,
          rkPop * _sx,
          rkPop,
          color: (_, _) => k < 0.4 ? kWhite : c[6],
          alpha: (d, _) => d > 1.0 - 1.5 / rkPop ? 1.3 - k : 0.0,
        );
      }
    } else {
      final sq = seg(t, _pop - 0.07, _pop);
      if (sq > 0.0 && pu <= 0.0) {
        sxN = _ns * (1.0 + 0.14 * sq);
        syN = _ns * (1.0 - 0.12 * sq);
      }
      if (pu > 0.0) {
        sxN = syN = _ns * (1.0 + 0.25 * pu);
        flash = 1.0;
      }
      final w = numWord.w * sxN;
      final h = 7.0 * syN;
      final x0 = sx - w / 2.0 - 3.0;
      final y0 = sy + _ny - h / 2.0 - 3.0 * smooth(0.15, _fold, t);
      final items = [
        for (final l in numWord.letters)
          if (l.g != null)
            WordLetter(
              g: l.g!,
              x: x0 + l.x * sxN,
              y: y0,
              sx: sxN,
              sy: syN,
              slant: 1.0,
              flash: flash,
            ),
      ];
      final sh = seg(t, 0.36, 0.6);
      final shine = (sh > 0.0 && sh < 1.0)
          ? x0 - 10.0 + (w + 26.0) * Ease.inOutSine(sh)
          : null;
      drawWord(
        p,
        items,
        WordStyle(
          fill: [c[5], c[6], c[6], c[7]],
          edge: kWhite,
          under: c[4],
          outline: c[0],
          ow: 2,
          shadow: shadowCol,
          shine: shine,
          shineY: y0,
          glint: c[5],
        ),
      );
      if (shine != null && shine > x0 && shine < x0 + w) {
        p.glowLine(shine, y0, shine + 0.6 * h, y0 + h, 8, c[6], 0.3);
      }
      final lk = t - 0.06;
      final lo = seg(t, _tagOut - 0.05, _tagOut);
      if (lk > 0.0 && t < _tagOut) {
        final ls = lk < 0.035
            ? 3.0
            : (lk < 0.07 ? 1.8 : 2.0 * (1.0 + 0.15 * lo));
        final lw = lab.w * ls;
        final lh = 5.0 * ls;
        final lxo = sx + lx - 8.0 - lw / 2.0;
        final lyo = y0 - 3.0 - lh + ly - 2.0 * lo;
        _drawTag(
          p,
          lo > 0.5 ? _whiteTagCols : c,
          lxo - 4.0,
          lyo - 3.0,
          lw + 8.0,
          lh + 5.0,
          3.0,
        );
        final lit = [
          for (final l in lab.letters)
            if (l.g != null)
              WordLetter(
                g: l.g!,
                x: lxo + 1.0 + l.x * ls,
                y: lyo,
                sx: ls,
                sy: ls,
                slant: 0.5,
                flash: lk < 0.035 ? 1.0 : 0.0,
              ),
        ];
        drawWord(
          p,
          lit,
          WordStyle(
            fill: [c[6], c[7], c[7]],
            edge: kWhite,
            under: c[5],
            outline: 0,
            shadow: c[1],
          ),
        );
      }
      final g = (t - 0.6) / 0.24;
      if (g > 0.0 && g < 1.0) {
        sparkle(
          p,
          x0 + w - 2.0,
          y0 + 1.0,
          6.0 * math.sin(g * math.pi),
          c[6],
          c[5],
          0.6,
        );
      }
    }

    final hold = smooth(0.0, 0.1, t) * (1.0 - smooth(_fold - 0.1, _pop + 0.1, t));
    p.glow(sx, sy, 56, c[4], 0.14 * hold * (1.0 + 0.2 * math.sin(t * 16.0)));
    if (t < 0.12) p.glow(0, 0, 64, kWhite, 0.8 * (1.0 - t / 0.12));
    lights.draw(p);
  }
}

final SimulatedEffect critNumberEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ui/crit-number',
    name: 'Crit number',
    desc:
        'CRIT 128! slams in huge and white over a jagged starburst with a hard shake and speed lines, cools to fire, holds with a shine, then pops into sparks.',
    category: 'ui',
    tags: ['ui', 'critical', 'damage', 'number', 'combat', 'text', 'one-shot'],
    size: (152, 120),
    origin: (76, 60),
    duration: 1.5,
    loop: false,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#2a0710',
        '#5e0f16',
        '#a3191c',
        '#e0401c',
        '#ff7b22',
        '#ffb93b',
        '#ffe68a',
        '#ffffff',
      ],
      'text': '128!',
      'label': 'CRIT',
      'seed': 3,
    },
  ),
  onCreate: _CritNumberSim.new,
);
