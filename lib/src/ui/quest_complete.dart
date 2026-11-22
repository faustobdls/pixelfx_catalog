import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ui_lib.dart';

const double _l = 66.0;
const double _bh = 8.0;
const double _open = 0.32;
const double _type = 0.2;
const double _step = 0.036;
const double _stamp = 0.95;
const double _sx = 64.0;
const double _sy = 4.0;
const double _popSeal = 2.0;
const double _roll = 2.08;
const double _duration = 2.6;

void _drawRibbon(
  Painter p,
  List<int> rb,
  List<int> g,
  double l,
  double tails,
) {
  if (l < 1.0) return;
  if (tails > 0.02) {
    for (final s in const [-1, 1]) {
      final drop = 6.0 * tails;
      final x0 = s * (l - 8.0);
      final x1 = s * (l + 16.0 * tails);
      p.shade(
        math.min(x0, x1) - 1.0,
        -_bh + drop - 1.0,
        math.max(x0, x1) + 1.0,
        _bh + drop + 1.0,
        (x, y, _) {
          final u = (x - x0) / (x1 - x0);
          final v = y - drop;
          if (u < 0.0 || u > 1.0 || v.abs() > _bh) return null;
          if (u > 1.0 - (0.3 * (_bh - v.abs())) / _bh) return null;
          final e = math.min(_bh - v.abs(), (1.0 - u) * (x1 - x0) * s);
          if (e < 1.0 || u < 0.02) return rb[0];
          return v < -_bh + 2.0 ? rb[3] : (v < 0.0 ? rb[2] : rb[1]);
        },
      );
      p.tri(
        s * (l - 8.0),
        _bh,
        s * (l - 1.0),
        _bh,
        s * (l - 8.0),
        _bh + drop,
        rb[0],
      );
    }
  }

  p.shade(-l - 1.0, -_bh - 1.0, l + 1.0, _bh + 1.0, (x, y, _) {
    final ax = x.abs();
    final v = y;
    if (ax > l || v.abs() > _bh) return null;
    final e = math.min(l - ax, _bh - v.abs());
    if (e < 1.0) return rb[0];
    if (v < -_bh + 2.0) return rb[5];
    if (v > _bh - 2.0) return rb[1];
    if (((v + _bh - 2.5).abs() < 0.5 || (v - _bh + 3.5).abs() < 0.5) &&
        (x + 0.5).floor() % 3 != 0 &&
        ax < l - 3.0) {
      return g[3];
    }
    return v < -1.0 ? rb[4] : rb[3];
  });

  if (tails < 0.02) {
    for (final s in const [-1, 1]) {
      final rx = (s * l + 0.5).floor();
      p.rect(rx - 2, -_bh - 2.0, 4, _bh * 2.0 + 4.0, rb[0]);
      p.rect(rx - 1, -_bh - 1.0, 1, _bh * 2.0 + 2.0, rb[4]);
      p.rect(rx, -_bh - 1.0, 1, _bh * 2.0 + 2.0, rb[2]);
      p.px(rx - 1, -_bh - 1.0, rb[6]);
    }
  }
}

void _drawSeal(
  Painter p,
  List<int> g,
  double x,
  double y,
  double r,
  double sx,
  double sy,
  bool white,
  double k,
) {
  final m = r * 1.25 + 2.0;
  p.shade(x - m * sx, y - m * sy, x + m * sx, y + m * sy, (px, py, _) {
    final dx = (px - x) / sx;
    final dy = (py - y) / sy;
    final d = hypot(dx, dy);
    final an = math.atan2(dy, dx);
    final edge = r * (1.0 + 0.09 * math.cos(an * 14.0));
    if (d > edge) return null;
    if (white) return edge - d < 1.0 ? g[5] : kWhite;
    if (edge - d < 1.0) return g[0];
    final l = -(dx * 0.6 + dy * 0.8) / r;
    if (edge - d < 3.0) return l > 0.3 ? g[6] : (l > -0.3 ? g[5] : g[3]);
    if ((d - r * 0.66).abs() < 0.5) return l > 0.0 ? g[3] : g[2];
    return l > 0.45 ? g[7] : (l > 0.1 ? g[6] : (l > -0.35 ? g[5] : g[4]));
  });
  if (white || k <= 0.0) return;

  final p0 = (x - 5.0 * sx, y);
  final p1 = (x - 1.5 * sx, y + 3.5 * sy);
  final p2 = (x + 5.5 * sx, y - 4.5 * sy);
  final len1 = hypot(p1.$1 - p0.$1, p1.$2 - p0.$2);
  final len2 = hypot(p2.$1 - p1.$1, p2.$2 - p1.$2);
  final done = k * (len1 + len2);
  final segs = [
    (p0, p1, math.min(1.0, done / len1)),
    (p1, p2, clamp((done - len1) / len2)),
  ];
  for (final (w, col) in [(4.2, g[0]), (2.4, kWhite)]) {
    for (final (a, b, u) in segs) {
      if (u > 0.0) {
        p.beam(
          a.$1,
          a.$2,
          a.$1 + (b.$1 - a.$1) * u,
          a.$2 + (b.$2 - a.$2) * u,
          w,
          col,
        );
      }
    }
  }
}

class _SatSparkle {
  final double x;
  final double y;
  final double t0;
  final double dur;
  final double l;

  const _SatSparkle(this.x, this.y, this.t0, this.dur, this.l);
}

class _QuestCompleteSim extends BaseEffectSim {
  final List<int> g;
  final List<int> rb;
  final Rng r;
  final int seed;
  late final Particles ps;
  final Lights lights = Lights();
  late final double tx;
  static const double _ts = 2.0;
  static const double _ty = -5.0;
  static const double _end = _duration - 0.05;
  late final List<SpelledLetter> glyphs;
  late final List<_SatSparkle> sats;

  double t = 0.0;
  bool stamped = false;
  bool popped = false;

  _QuestCompleteSim(Map<String, Object?> o)
      : g = fit(o.palette, 8),
        rb = fit(o.rampOpt('ribbon'), 7),
        r = Rng(o.seed),
        seed = o.seed {
    ps = Particles(rng: r, sparks: [g[7], g[6], g[5], g[3]]);
    final word = spell(o.strOpt('text', 'QUEST COMPLETE'), PixelFontKind.mini);
    final tw = word.w * _ts;
    tx = -tw / 2.0 - 4.0;
    glyphs = [
      for (final lt in word.letters)
        if (lt.g != null) lt,
    ];
    sats = List<_SatSparkle>.generate(
      7,
      (i) => _SatSparkle(
        (i / 6.0 - 0.5) * 140.0 + r.range(-6.0, 6.0),
        (i % 2 != 0 ? 1.0 : -1.0) * r.range(15.0, 22.0),
        _stamp + 0.12 + i * 0.12 + r.range(0.0, 0.04),
        r.range(0.3, 0.45),
        r.range(3.0, 6.0),
      ),
    );
  }

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    if (!stamped && t >= _stamp) {
      stamped = true;
      lights.add(_sx, _sy, 40, g[5], 0.7, 0.35);
      lights.add(_sx, _sy, 18, kWhite, 0.7, 0.1);
      for (var i = 0; i < 12; i++) {
        final an = (i / 12.0) * tau + r.range(-0.2, 0.2);
        final sp = r.range(40.0, 80.0) * (math.cos(an) > 0.0 ? 0.6 : 1.0);
        ps.spawn(
          P.star,
          _sx + math.cos(an) * 11.0,
          _sy + math.sin(an) * 11.0,
          math.cos(an) * sp,
          math.sin(an) * sp * 0.7,
          r.range(0.25, 0.45),
          r.pick([g[7], g[6], g[5]]),
          i % 3 != 0 ? 0.6 : r.range(1.2, 1.8),
        );
      }
    }

    if (t > _stamp && t < _popSeal && r.chance(0.08)) {
      ps.spawn(
        P.star,
        r.range(-_l, _l),
        r.range(-_bh, _bh),
        r.range(-5.0, 5.0),
        -r.range(8.0, 20.0),
        math.min(r.range(0.4, 0.8), _end - t),
        r.pick([g[6], g[5]]),
        0.6,
      );
    }

    if (!popped && t >= _popSeal + 0.05) {
      popped = true;
      lights.add(_sx, _sy, 30, g[6], 0.6, 0.2);
      for (var i = 0; i < 8; i++) {
        final an = r.range(0.0, tau);
        final sp = r.range(40.0, 90.0);
        ps.spawn(
          P.star,
          _sx + math.cos(an) * 6.0,
          _sy + math.sin(an) * 6.0,
          math.cos(an) * sp,
          math.sin(an) * sp,
          math.min(r.range(0.25, 0.4), _end - t),
          r.pick([g[7], g[6]]),
          i % 2 != 0 ? 0.6 : 1.5,
        );
      }
    }

    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final (jx, jy) = shake(t, 2.0, _stamp, 0.18, seed);
    final l = _l *
        (t < _roll
            ? Ease.outCubic(seg(t, 0.0, _open))
            : 1.0 - Ease.inCubic(seg(t, _roll, _roll + 0.26)));
    final tails = seg(t, _open - 0.02, _open + 0.12) * (t < _roll ? 1.0 : 0.0);
    final sh = seg(t, 1.2, 1.5);
    final shine = (sh > 0.0 && sh < 1.0)
        ? -_l - 10.0 + (2.0 * _l + 20.0) * sh
        : null;
    _drawRibbon(p, rb, g, l, Ease.outBack(tails, 2.0));

    if (shine != null) {
      for (var y = -_bh.toInt() + 1; y < _bh; y++) {
        final x = shine + (y + _bh) * 0.6;
        if (x.abs() < l - 2.0) {
          p.px(x, y, rb[6]);
          p.px(x + 1.0, y, rb[5]);
        }
      }
    }

    final items = <WordLetter>[];
    for (var i = 0; i < glyphs.length; i++) {
      final lt = glyphs[i];
      final u = t - (_type + i * _step);
      final x = tx + lt.x * _ts + jx;
      if (u < 0.0 || (x + lt.w).abs() > l - 3.0) continue;
      final s = u < 0.035 ? 2.6 : _ts;
      items.add(WordLetter(
        g: lt.g!,
        x: x - ((s - _ts) * lt.w) / 2.0,
        y: _ty + jy - ((s - _ts) * 5.0) / 2.0,
        sx: s,
        sy: s,
        flash: u < 0.07 ? 1.0 : 0.0,
      ));
    }
    drawWord(
      p,
      items,
      WordStyle(
        fill: [g[4], g[5], g[6], g[7]],
        edge: kWhite,
        under: g[3],
        outline: rb[0],
        shadow: rb[1],
      ),
    );

    final dk = seg(t, _stamp - 0.12, _stamp);
    final pk = t - _popSeal;
    if (dk > 0.0 && pk < 0.08) {
      final fall = 1.0 - Ease.inQuad(dk);
      final sq = math.exp(-(t - _stamp) * 30.0) * (t >= _stamp ? 1.0 : 0.0);
      final s = 1.0 + 0.8 * fall;
      var sx = s * (1.0 + 0.2 * sq);
      var sy = s * (1.0 - 0.2 * sq);
      if (pk > 0.0) {
        sx = sy = 1.0 + 0.3 * (pk / 0.08);
      }
      final white = (t >= _stamp && t < _stamp + 0.05) || pk > 0.0;
      if (dk < 1.0) {
        p.ellipse(_sx, _sy + 12.0, 10.0 * (1.0 - 0.3 * fall), 2, rb[0], 0.5 * dk);
      }
      _drawSeal(
        p,
        g,
        _sx + jx,
        _sy - 14.0 * fall + jy,
        11.0,
        sx,
        sy,
        white,
        seg(t, _stamp + 0.08, _stamp + 0.24),
      );
      p.glow(_sx, _sy, 22, g[5], 0.3 + (white ? 0.4 : 0.0));
    }

    final rk = (t - _stamp) / 0.3;
    final rr = 12.0 + 13.0 * Ease.outCubic(rk);
    if (rk > 0.0 && rk < 1.0) {
      p.ellipseShaded(
        _sx,
        _sy,
        rr * 1.15,
        rr,
        color: (_, _) => rk < 0.3 ? kWhite : g[5],
        alpha: (d, _) => d > 1.0 - 1.4 / rr ? 1.2 - rk : 0.0,
      );
    }

    for (final s in sats) {
      final u = (t - s.t0) / s.dur;
      if (u > 0.0 && u < 1.0) {
        sparkle(
          p,
          s.x,
          s.y,
          s.l * math.pow(math.sin(u * math.pi), 0.7),
          g[6],
          g[5],
          0.5,
        );
      }
    }

    ps.draw(p);
    p.glow(
      0,
      0,
      76,
      g[4],
      0.2 * seg(t, 0.2, 0.5) * (1.0 - seg(t, _roll, _roll + 0.2)),
    );
    lights.draw(p);
  }
}

final SimulatedEffect questCompleteEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ui/quest-complete',
    name: 'Quest complete',
    desc:
        'A stitched ribbon unrolls from the middle, QUEST COMPLETE types on letter by letter, a gold seal stamps down and ticks, stars pop; then it all rolls away.',
    category: 'ui',
    tags: ['ui', 'quest', 'banner', 'reward', 'text', 'one-shot'],
    size: (204, 92),
    origin: (102, 46),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#2a1405',
        '#5c3008',
        '#9a5a0e',
        '#d48e18',
        '#f5b92c',
        '#ffde5e',
        '#fff4bc',
        '#ffffff',
      ],
      'ribbon': [
        '#1e0608',
        '#45101a',
        '#7a1a26',
        '#ad2632',
        '#d8433f',
        '#f27a5e',
        '#ffb79a',
      ],
      'text': 'QUEST COMPLETE',
      'seed': 8,
    },
  ),
  onCreate: _QuestCompleteSim.new,
);
