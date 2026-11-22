import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'holy_lib.dart';

const double _top = -148.0;
const double _sy = 0.38;
const double _mark = 0.42;
const double _hit = 0.54;
const double _len = 44.0;
final int _outline = hex('#1a1422');

// A chip of stone: lit side, shaded side, outline.
void _chip(Painter p, DebrisBit b, List<int> st) {
  final r = 0.6 + b.s * 0.7;
  final fade = math.min(1.0, b.life / 0.5);
  final lx = math.cos(b.a) * r * 0.4;
  final ly = math.sin(b.a) * r * 0.4;
  p.shade(b.x - r - 1.0, b.y - r - 1.0, b.x + r + 1.0, b.y + r + 1.0,
      (x, y, out) {
    final dx = x - b.x;
    final dy = y - b.y;
    final d = hypot(dx * 1.2, dy);
    if (d > r + 0.9) return null;
    final lit = dx * lx + dy * ly;
    out.c = d > r
        ? _outline
        : (lit < -0.3 ? st[3] : (lit > 0.5 ? st[1] : st[2]));
    out.a = fade;
    return null;
  });
}

class _Crack {
  final List<(double, double)> pts;
  final List<(double, double)>? fork;
  final double l;
  final double cool;

  const _Crack(this.pts, this.fork, this.l, this.cool);
}

class _SmiteSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  late final List<int> st;
  late final int dust;
  late final Particles ps;
  final Bits chips = Bits(ground: (_) => 0.0);
  final Lights lights = Lights();
  late final List<_Crack> cracks;
  double t = 0.0;
  bool hit = false;

  _SmiteSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed) {
    final s0 = hex(o['stone'] ?? '#5a5066');
    st = [
      scaleColor(s0, 0.5),
      scaleColor(s0, 0.75),
      s0,
      mix(scaleColor(s0, 1.4), kWhite, 0.1),
    ];
    dust = mix(s0, hex('#8a8094'), 0.4);
    ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[3]],
    );

    cracks = List.generate(7, (i) {
      final a = 0.12 + (i / 6.0) * (math.pi - 0.24) + r.range(-0.12, 0.12);
      final l = r.range(30.0, 54.0) * (math.sin(a).abs() > 0.7 ? 0.6 : 1.0);
      final pts = bolt(r, 0.0, 0.0, math.cos(a) * l, math.sin(a) * l,
              jag: 0.28, depth: 4)
          .map((pt) => (pt.$1, pt.$2 * _sy))
          .toList(growable: false);
      List<(double, double)>? fork;
      if (pts.length > 6) {
        final mid = (pts.length * 0.5).floor();
        final (fx0, fy0) = pts[mid];
        final s1 = r.sign();
        final s2 = r.sign();
        fork = bolt(
          r,
          fx0,
          fy0,
          fx0 + math.cos(a + s1 * 0.7) * l * 0.35,
          fy0 + math.sin(a + s2 * 0.7) * l * 0.35 * _sy,
          jag: 0.3,
          depth: 3,
        );
      }
      final cool = r.range(1.6, 2.1);
      return _Crack(pts, fork, l, cool);
    }, growable: false);
  }

  double _tipY(double tt) =>
      lerp(_top - 6.0, 0.0, Ease.inCubic(seg(tt, _mark, _hit)));

  void _hammer(Painter p) {
    if (t < _mark || t >= _hit + 0.06) return;
    final y1 = t >= _hit ? 0.0 : _tipY(t);
    final y0 = math.max(
      _top + 5.0,
      y1 - _len * (t >= _hit ? 1.0 - (t - _hit) / 0.06 : 1.0),
    );
    final white = t >= _hit;
    if (y1 < _top + 12.0) return;
    for (final (dx, k) in const [(-5, 0.6), (-2, 0.9), (2, 0.8), (5, 0.5)]) {
      if (y0 > _top + 2.0) {
        p.lineShaded(
          dx,
          math.max(_top, y0 - 70.0),
          dx,
          y0,
          color: (u) => u > 0.7 ? c[6] : c[4],
          alpha: (u) => u * k,
        );
      }
    }
    if (y1 - 3.0 > y0) {
      p.beamShaded(
        0,
        y0,
        0,
        y1 - 3.0,
        9,
        color: (_, v) => white || v < 0.35 ? kWhite : (v < 0.7 ? c[6] : c[5]),
      );
    }
    p.beamShaded(
      0,
      y1 - 6.0,
      0,
      y1 - 1.0,
      13,
      color: (_, v) => v < 0.6 || white ? kWhite : c[6],
    );
    p.glowLine(0, y0 + 10.0, 0, y1, 16, c[5], 0.6);
    p.glow(0, y1 - 4.0, math.min(22.0, y1 - _top - 6.0), kWhite, 0.5);
  }

  void _crack(Painter p) {
    if (t < _hit) return;
    final grow = Ease.outCubic(seg(t, _hit, _hit + 0.1));
    for (final cr in cracks) {
      final paths = cr.fork != null ? [cr.pts, cr.fork!] : [cr.pts];
      for (final path in paths) {
        final isMain = identical(path, cr.pts);
        final n = math.max(1, holyRound((path.length - 1) * grow));
        for (var i = 0; i < n; i++) {
          final (x0, y0) = path[i];
          final (x1, y1) = path[i + 1];
          final d = hypot(x0, y0 / _sy) / cr.l;
          final heat = clamp(1.0 - (t - _hit) / cr.cool - d * 0.5);
          if (heat <= 0.0) continue;
          final col = heat > 0.85
              ? kWhite
              : (heat > 0.65
                  ? c[6]
                  : (heat > 0.45
                      ? c[5]
                      : (heat > 0.3 ? c[4] : (heat > 0.18 ? c[3] : c[2]))));
          final a = heat < 0.12 ? heat / 0.12 : 1.0;
          p.line(x0, y0, x1, y1, col, a);
          if (d < 0.45 && isMain) {
            p.line(x0, y0 + 1.0, x1, y1 + 1.0, heat > 0.5 ? c[4] : c[2], a);
          }
          if (i.isEven) p.glow(x0, y0, 10, c[4], 0.45 * heat);
        }
      }
    }
    final h = clamp(1.0 - (t - _hit) / 1.6);
    if (h > 0.0) {
      oval(
        p,
        0,
        0,
        5,
        1.6,
        h > 0.6 ? kWhite : (h > 0.3 ? c[5] : c[3]),
        math.min(1.0, h * 3.0),
      );
      p.glow(0, 0, 18, c[4], 0.45 * h);
    }
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    if (t < _mark && r.chance(0.25)) {
      final sx = r.range(-10.0, 10.0);
      final sy = -r.range(0.0, 18.0);
      final vy = -r.range(4.0, 12.0);
      final life = r.range(0.2, 0.4);
      final col = r.chance(0.5) ? kWhite : c[6];
      final size = r.range(0.5, 1.2);
      ps.spawn(P.star, sx, sy, 0.0, vy, life, col, size);
    }
    // Sparks shed off the sides of the falling hammer.
    if (t > _mark && t < _hit && _tipY(t) > _top + 50.0 && r.chance(0.6)) {
      final sign = r.sign();
      final sx = sign * r.range(4.0, 7.0);
      final sy = _tipY(t) - r.range(4.0, 30.0);
      final vx = r.range(-20.0, 20.0);
      final vy = -r.range(10.0, 40.0);
      final life = r.range(0.15, 0.3);
      ps.spawn(P.mote, sx, sy, vx, vy, life, c[6], 0.7);
    }
    if (!hit && t >= _hit) {
      hit = true;
      lights.add(0, -24, 92, c[5], 1.0, 0.6);
      lights.add(0, -8, 40, kWhite, 0.9, 0.12);
      for (var i = 0; i < 60; i++) {
        final a = -math.pi / 2.0 + r.range(-1.25, 1.25);
        final sp = r.range(110.0, 280.0);
        final sx = r.range(-3.0, 3.0);
        final life = r.range(0.25, 0.75);
        ps.spawn(
          P.spark,
          sx,
          -2.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          life,
        );
      }
      for (var i = 0; i < 16; i++) {
        final a = -math.pi / 2.0 + r.range(-1.0, 1.0);
        final sp = r.range(60.0, 160.0);
        final sx = r.range(-4.0, 4.0);
        final life = r.range(0.4, 0.9);
        final col = r.chance(0.5) ? kWhite : c[6];
        final size = r.range(0.8, 2.4);
        ps.spawn(
          P.star,
          sx,
          -4.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          life,
          col,
          size,
        );
      }
      for (var i = 0; i < 14; i++) {
        final a = -math.pi / 2.0 + r.range(-1.2, 1.2);
        final sp = r.range(90.0, 230.0);
        final bx = r.range(-5.0, 5.0);
        final life = r.range(1.2, 1.8);
        final ba = r.range(0.0, tau);
        final va = r.range(-14.0, 14.0);
        final s = r.intRange(1, 3).toDouble();
        chips.add(DebrisBit(
          kind: B.chunk,
          x: bx,
          y: -2.0,
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp,
          g: 1.0,
          drag: 0.4,
          bounce: 0.35,
          life: life,
          a: ba,
          va: va,
          s: s,
        ));
      }
      for (var i = 0; i < 34; i++) {
        final a = -math.pi / 2.0 + r.range(-1.0, 1.0);
        final sp = r.range(60.0, 220.0);
        final sx = r.range(-4.0, 4.0);
        final life = r.range(0.9, 1.5);
        final col = r.pick(st.sublist(1));
        final size = r.chance(0.4) ? 2.0 : 1.0;
        ps.spawn(
          P.grit,
          sx,
          -1.0,
          math.cos(a) * sp,
          math.sin(a) * sp,
          life,
          col,
          size,
        );
      }
      for (var i = 0; i < 9; i++) {
        final s = r.sign();
        final sx = s * r.range(2.0, 10.0);
        final sy = -r.range(1.0, 4.0);
        final vx = s * r.range(50.0, 130.0);
        final vy = -r.range(2.0, 12.0);
        final life = r.range(0.7, 1.2);
        final size = r.range(3.5, 6.0);
        final delay = r.range(0.0, 0.06);
        ps.spawn(
          P.smoke,
          sx,
          sy,
          vx,
          vy,
          life,
          mix(dust, c[4], 0.18),
          size,
          delay,
          PF.big,
        );
      }
      for (var i = 0; i < 4; i++) {
        final sx = r.range(-4.0, 4.0);
        final sy = -r.range(2.0, 8.0);
        final vx = r.range(-8.0, 8.0);
        final vy = -r.range(20.0, 45.0);
        final life = r.range(1.2, 1.8);
        final size = r.range(4.0, 6.0);
        final delay = r.range(0.05, 0.3);
        ps.spawn(
          P.smoke,
          sx,
          sy,
          vx,
          vy,
          life,
          mix(dust, c[5], 0.25),
          size,
          delay,
        );
      }
    }
    // The cracks spit embers while they're hot.
    if (t > _hit && t < _hit + 1.3 && r.chance(0.5)) {
      final cr = r.pick(cracks);
      final q = r.pick(cr.pts);
      if (r.chance(0.75)) {
        final vx = r.range(-8.0, 8.0);
        final vy = -r.range(15.0, 35.0);
        final life = r.range(0.5, 0.9);
        ps.spawn(P.ember, q.$1, q.$2 - 1.0, vx, vy, life, c[5]);
      } else {
        final vy = -r.range(4.0, 12.0);
        final life = r.range(0.3, 0.6);
        final col = r.chance(0.5) ? kWhite : c[6];
        final size = r.range(0.8, 1.8);
        ps.spawn(P.star, q.$1, q.$2 - 2.0, 0.0, vy, life, col, size);
      }
    }
    chips.update(dt);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _crack(p);
    ps.draw(p, 'back');
    final k = seg(t, _hit, _hit + 0.42);
    if (t >= _hit && k < 1.0) {
      band(
        p,
        0,
        0,
        6.0 + 84.0 * Ease.outCubic(k),
        _sy * 0.8,
        math.max(1.0, 5.0 * (1.0 - k)),
        1.15 - k,
        c.sublist(3),
        keep: farHalf,
        hot: k < 0.12,
      );
    }
  }

  @override
  void draw(Painter p) {
    // The mark: a glint on the floor and a ring closing on it.
    if (t < _hit) {
      final u = seg(t, 0.0, _mark);
      final k = smooth(0.0, 0.08, t);
      final spin = t * 3.0;
      final rr = lerp(26.0, 8.0, Ease.inOutCubic(u));
      ovalShaded(
        p,
        0,
        0,
        rr,
        rr * _sy,
        color: (g) => math.sin(g * 4.0 + spin) > 0.0 ? kWhite : c[5],
        alpha: (_) => k * (0.65 + 0.35 * math.sin(t * 40.0)),
      );
      oval(p, 0, 1, rr, rr * _sy, c[3], k * 0.6, (g) => math.sin(g) > 0.0);
      final lVal = (3.0 + 8.0 * Ease.outBack(clamp(t / 0.2), 2.0)) *
          (t > _mark ? 1.0 + 0.6 * seg(t, _mark, _hit) : 1.0);
      for (var i = 0; i < 4; i++) {
        final a = spin * 0.3 + (i * math.pi) / 2.0;
        final len = i.isOdd ? lVal * 0.6 : lVal;
        p.lineShaded(
          0,
          -2,
          math.cos(a) * len,
          -2.0 + math.sin(a) * len,
          color: (v) => v < 0.4 ? kWhite : c[5],
          alpha: (v) => 1.2 - v,
        );
      }
      p.px(0, -2, kWhite);
      p.glow(0, -2, 14.0 + 10.0 * u, c[5], 0.5 * k);
      p.glowLine(0, _top + 6.0, 0, -2, 5, c[4], 0.12 * u);
    }
    _hammer(p);
    // The bolt's afterimage: a thread of light from the sky to the mark, thinning out.
    final ai = seg(t, _hit + 0.04, _hit + 0.55);
    if (t > _hit + 0.04 && ai < 1.0) {
      final w = 1.0 + 4.0 * math.pow(1.0 - ai, 2).toDouble();
      p.beamShaded(
        0,
        _top + 4.0,
        0,
        -4,
        w,
        color: (_, v) => v < 0.5 ? kWhite : c[5],
        alpha: (u, _) => (0.3 + 0.7 * u) * (1.0 - ai * 0.5),
      );
      p.glowLine(0, _top + 16.0, 0, -6, 10, c[5], 0.4 * (1.0 - ai));
    }
    final k = seg(t, _hit, _hit + 0.42);
    if (t >= _hit && k < 1.0) {
      band(
        p,
        0,
        0,
        6.0 + 84.0 * Ease.outCubic(k),
        _sy * 0.8,
        math.max(1.0, 5.0 * (1.0 - k)),
        1.15 - k,
        c.sublist(3),
        keep: nearHalf,
        hot: k < 0.12,
      );
    }
    // The air shock: a dome of light thrown up over the hit.
    final d = seg(t, _hit, _hit + 0.28);
    if (t >= _hit && d < 1.0) {
      final rad = 8.0 + 40.0 * Ease.outCubic(d);
      p.arcShaded(
        0,
        0,
        rad,
        math.pi,
        tau,
        width: (_) => math.max(1.0, 3.0 * (1.0 - d)),
        color: (_, v) => d < 0.2 || v > 0.6 ? kWhite : c[5],
        alpha: (_, _) => 1.1 - d,
      );
      for (var g = math.pi * 1.1; g < tau - 0.2; g += 0.5) {
        p.glow(math.cos(g) * rad, math.sin(g) * rad, 8, c[5], 0.3 * (1.0 - d));
      }
    }
    // The white hero frame.
    if (t >= _hit && t < _hit + 0.07) {
      p.circle(0, -6, 16, kWhite);
      p.circle(0, -6, 19, c[6], 0.6);
    }
    for (final b in chips.list) {
      _chip(p, b, st);
    }
    ps.draw(p, 'front');
    if (t >= _hit && t < _hit + 0.25) {
      sparkle(
        p,
        0,
        -8,
        16.0 * (1.0 - (t - _hit) / 0.25),
        kWhite,
        c[5],
        0.7,
      );
    }
    lights.draw(p);
  }
}

final SimulatedEffect smiteEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'holy/smite',
    name: 'Smite',
    desc:
        'A glint marks the spot, then a bolt of light drops like a hammer: a white flash, a shockwave over the floor, stone chips flying and cracks that glow and cool.',
    category: 'holy',
    tags: ['holy', 'smite', 'strike', 'impact', 'light', 'ground', 'one-shot'],
    size: (224, 176),
    origin: (112, 148),
    duration: 2.8,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': kHolyGold, 'stone': '#5a5066', 'seed': 9},
  ),
  onCreate: (o) => _SmiteSim(o),
);
