// Shared by the melee effects: swings on a tilted circle (the smear, its dotted trace), floor cracks, rocks.
// The crescent and trace recipe is adapted from Sprite Fusion's open-source slash
// (https://www.spritefusion.com/pixel-art-vfx/slash), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

/// A swing: a circle of radius [r] around ([cx], [cy]), squashed to [sy] across its plane.
class Swing {
  final double cx;
  final double cy;
  final double r;
  final double sy;
  final double rot;
  final double a0;
  final double dir;
  final double k;
  final double span;
  final double w;
  final double t0;
  final double sweep;
  final double hold;
  final double trail;
  final List<int> ramp;
  double hot;
  final bool lens;

  Swing({
    this.cx = 0.0,
    this.cy = 0.0,
    this.r = 30.0,
    this.sy = 1.0,
    this.rot = 0.0,
    this.a0 = 0.0,
    this.dir = 1.0,
    this.k = 0.0,
    this.span = 0.0,
    this.w = 0.0,
    this.t0 = 0.0,
    this.sweep = 0.0,
    this.hold = 0.0,
    this.trail = 0.0,
    this.ramp = const [],
    this.hot = 0.0,
    this.lens = false,
  });

  Swing copyWith({
    double? cx,
    double? cy,
    double? r,
    double? sy,
    double? rot,
    double? a0,
    double? dir,
    double? k,
    double? span,
    double? w,
    double? t0,
    double? sweep,
    double? hold,
    double? trail,
    List<int>? ramp,
    double? hot,
    bool? lens,
  }) =>
      Swing(
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        r: r ?? this.r,
        sy: sy ?? this.sy,
        rot: rot ?? this.rot,
        a0: a0 ?? this.a0,
        dir: dir ?? this.dir,
        k: k ?? this.k,
        span: span ?? this.span,
        w: w ?? this.w,
        t0: t0 ?? this.t0,
        sweep: sweep ?? this.sweep,
        hold: hold ?? this.hold,
        trail: trail ?? this.trail,
        ramp: ramp ?? this.ramp,
        hot: hot ?? this.hot,
        lens: lens ?? this.lens,
      );
}

typedef SwingPoint = ({double x, double y, double dx, double dy, double a});

/// A swing on radius [r] whose arc passes through ([x], [y]) heading along angle [th].
Swing through(
  double x,
  double y,
  double th,
  double dir,
  double r,
  double span, {
  double at = 0.55,
  double sy = 1.0,
  double rot = 0.0,
  double k = 0.0,
  double w = 0.0,
  double t0 = 0.0,
  double sweep = 0.0,
  double hold = 0.0,
  double trail = 0.0,
  List<int> ramp = const [],
  double hot = 0.0,
  bool lens = false,
}) {
  final a = th - (dir * math.pi) / 2.0;
  return Swing(
    cx: x - math.cos(a) * r,
    cy: y - math.sin(a) * r,
    r: r,
    sy: sy,
    rot: rot,
    a0: a - dir * span * at,
    dir: dir,
    k: k,
    span: span,
    w: w,
    t0: t0,
    sweep: sweep,
    hold: hold,
    trail: trail,
    ramp: ramp,
    hot: hot,
    lens: lens,
  );
}

/// The screen point at plane radius [r], [u] radians along the swing.
Point2 onSwing(Swing s, double r, double u) {
  final a = s.a0 + s.dir * u;
  final lx = math.cos(a) * r;
  final ly = math.sin(a) * r * s.sy - s.k * (s.r - r);
  final c = math.cos(s.rot);
  final n = math.sin(s.rot);
  return (s.cx + lx * c - ly * n, s.cy + lx * n + ly * c);
}

/// The on-screen unit direction the swing travels at [u], and the in-plane angle there.
SwingPoint swingTravel(Swing s, double u) {
  final (x0, y0) = onSwing(s, s.r, u);
  final (x1, y1) = onSwing(s, s.r, u + 0.01);
  final rawL = hypot(x1 - x0, y1 - y0);
  final l = rawL == 0.0 ? 1.0 : rawL;
  return (x: x0, y: y0, dx: (x1 - x0) / l, dy: (y1 - y0) / l, a: s.a0 + s.dir * u);
}

/// The plane radius and angle under a screen point (inverts [onSwing], cone included).
(double, double) plane(Swing s, double x, double y) {
  final c = math.cos(s.rot);
  final n = math.sin(s.rot);
  final dx = x - s.cx;
  final dy = y - s.cy;
  final lx = dx * c + dy * n;
  final ly = -dx * n + dy * c;
  if (s.k == 0.0) {
    return (hypot(lx, ly / s.sy), math.atan2(ly / s.sy, lx));
  }
  final m = ly + s.k * s.r;
  final a = s.sy * s.sy - s.k * s.k;
  final b = 2.0 * m * s.k;
  final cc = lx * lx * s.sy * s.sy + m * m;
  final r = (-b + math.sqrt(b * b + 4.0 * a * cc)) / (2.0 * a);
  return (r, math.atan2((m - s.k * r) / s.sy, lx));
}

/// Shade a swing's band from [u0] to [u1].
void smear(
  Painter p,
  Swing s,
  double u0,
  double u1,
  double wMax,
  void Function(double u, double r, ShadeOut out, double a) fn, {
  int half = 0,
  double pad = 1.0,
}) {
  if (u1 - u0 < 0.005) return;
  final c = math.cos(s.rot);
  final n = math.sin(s.rot);
  final a = s.r + pad + 1.0;
  final bn = a * s.sy + s.k * (wMax + 2.0);
  final hx = hypot(a * c, bn * n) + 1.0;
  final hy = hypot(a * n, bn * c) + 1.0;
  final rIn = s.r - wMax - 1.0;
  final over = n.abs() * a + s.k * (wMax + 2.0) + 2.0;
  final y0 = half > 0 ? s.cy - over : s.cy - hy;
  final y1 = half < 0 ? s.cy + over : s.cy + hy;
  p.shade(s.cx - hx, y0, s.cx + hx, y1, (x, y, out) {
    final (r, ang) = plane(s, x, y);
    if (r > s.r + pad || r < rIn) return null;
    if (half != 0 && (math.sin(ang) < 0 ? -1 : 1) != half) return null;
    var u = (s.dir * (ang - s.a0)).remainder(tau);
    if (u < 0.0) u += tau;
    while (u < u0) {
      u += tau;
    }
    if (u > u1) return null;
    fn(u, r, out, ang);
    return null;
  });
}

/// Dots along a swing at plane radius [r] from [u0] to [u1].
void trace(
  Painter p,
  Swing s,
  double r,
  double u0,
  double u1,
  int c,
  double a, {
  int Function(double u)? cFn,
  double Function(double u)? aFn,
  int half = 0,
  double step = 0.6,
}) {
  final du = step / math.max(4.0, r);
  for (var u = u0; u <= u1; u += du) {
    final g = s.a0 + s.dir * u;
    if (half != 0 && (math.sin(g) < 0 ? -1 : 1) != half) continue;
    final (x, y) = onSwing(s, r, u);
    final k = aFn != null ? aFn(u) : a;
    if (k > 0.0) p.dot(x, y, cFn != null ? cFn(u) : c, k);
  }
}

/// Glow riding a swing from [u0] to [u1].
void glowAlong(
  Painter p,
  Swing s,
  double r,
  double u0,
  double u1,
  double rad,
  int c,
  double k, {
  double Function(double u)? kFn,
  int half = 0,
  double step = 0.35,
}) {
  for (var u = u0; u <= u1; u += step) {
    final g = s.a0 + s.dir * u;
    if (half != 0 && (math.sin(g) < 0 ? -1 : 1) != half) continue;
    final (x, y) = onSwing(s, r, u);
    final kk = kFn != null ? kFn(u) : k;
    if (kk > 0.004) p.glow(x, y, rad, c, kk);
  }
}

/// A slash crescent along swing [s] (Sprite Fusion's recipe).
void slash(Painter p, Swing s, double t, [int half = 0]) {
  final u = t - s.t0;
  if (u < 0.0) return;
  final rampList = s.ramp;
  final n = rampList.length;
  final life = s.sweep + s.hold + s.trail;
  final hot = s.hot;
  final head = Ease.outExpo(clamp(u / s.sweep));
  final tail = smooth(s.sweep + s.hold, life, u);
  final age = clamp(u / life);
  final uEnd = s.span * head;
  final tStart = s.span * tail;
  final wMax = s.w * (1.0 - tail * 0.55);
  if (tail < 1.0 && uEnd - tStart > 0.01) {
    smear(p, s, tStart, uEnd, wMax, (uu, r, out, _) {
      final v = (uu - tStart) / (uEnd - tStart);
      final sinTerm = math.max(
        0.0,
        math.sin(math.pi * math.pow(v, s.lens ? 1.0 : 2.2)),
      );
      final w = wMax * math.pow(sinTerm, s.lens ? 0.75 : 0.6);
      if (w < 0.35) return;
      final q = (s.r - r) / w;
      if (q < 0.0 || q > 1.0) return;
      final ci = (q < 0.22 && age < 0.5) || q < hot * 0.7
          ? 0
          : (q * (n - 1) * 0.75 + age * 2.4 - v * 0.8 + 0.4 - hot * 3.0 + 0.5)
              .floor();
      out.c = rampList[n - 1 - clampInt(ci, 0, n - 1)];
      out.a = math.min(1.0, v / (s.lens ? 0.1 : 0.4));
    }, half: half);
    glowAlong(
      p,
      s,
      s.r - wMax * 0.4,
      tStart,
      uEnd,
      5.0 + wMax,
      rampList[n - 3],
      0.0,
      kFn: (uu) =>
          (0.22 + hot * 0.3) * (1.0 - age) * ((uu - tStart) / (uEnd - tStart)),
      half: half,
      step: 0.3,
    );
  }
  final th = 0.7 * (1.0 - clamp((u - s.sweep - s.hold) / (s.trail + 0.2)));
  if (tail > 0.02 && th > 0.0) {
    trace(
      p,
      s,
      s.r - 0.5,
      0.0,
      tStart,
      rampList[2],
      0.0,
      aFn: (uu) => th * (0.4 + 0.6 * uu / s.span),
      half: half,
    );
  }
}

/// Where a slash's edge ends up, and which way it's travelling there.
SwingPoint slashEnd(Swing s) => swingTravel(s.copyWith(r: s.r - s.w * 0.3), s.span);

/// Shavings flung off a slash's edge, outward from its circle.
void shavings(
  Particles ps,
  Rng r,
  Swing s,
  int n,
  List<int> colors, [
  double from = 0.3,
]) {
  for (var i = 0; i < n; i++) {
    final (x, y) = onSwing(s, s.r, s.span * r.range(from, 1.0));
    final ox = x - s.cx;
    final oy = y - s.cy;
    final rawL = hypot(ox, oy);
    final l = rawL == 0.0 ? 1.0 : rawL;
    final sp = r.range(30.0, 100.0);
    ps.spawn(
      P.mote,
      x,
      y,
      (ox / l) * sp,
      math.min(25.0, (oy / l) * sp) - 10.0,
      r.range(0.25, 0.55),
      r.pick(colors),
      0.6,
    );
  }
}

class StoneColors {
  final int light;
  final int body;
  final int shade;
  final int dust;
  final int dark;

  const StoneColors({
    required this.light,
    required this.body,
    required this.shade,
    required this.dust,
    required this.dark,
  });
}

/// Stone shades for rocks, grit and dust from one body color.
StoneColors stone(Object col) {
  final c = col is int ? col : hex(col as String);
  return StoneColors(
    light: mix(scaleColor(c, 1.35), kWhite, 0.08),
    body: c,
    shade: scaleColor(c, 0.64),
    dust: mix(scaleColor(c, 1.2), rgb(150, 140, 150), 0.3),
    dark: scaleColor(c, 0.42),
  );
}

final int _kOutline = hex('#1a1422');

/// A tumbling rock (a Bits CHUNK): a lit side, a shaded side, an outline, fading at the end of its life.
void rock(Painter p, DebrisBit b, StoneColors st) {
  final r = 0.6 + b.s * 0.75;
  final fade = math.min(1.0, b.life / 0.5);
  final lx = math.cos(b.a) * r * 0.4;
  final ly = math.sin(b.a) * r * 0.4;
  p.shade(b.x - r - 1.0, b.y - r - 1.0, b.x + r + 1.0, b.y + r + 1.0, (x, y, out) {
    final dx = x - b.x;
    final dy = y - b.y;
    final d = hypot(dx * 1.15, dy);
    if (d > r + 0.9) return null;
    final lit = dx * lx + dy * ly;
    out.c = d > r
        ? _kOutline
        : lit < -0.4
            ? st.light
            : lit > 0.6
                ? st.shade
                : st.body;
    out.a = fade;
    return null;
  });
}

class CrackLine {
  final List<Point2> pts;
  final double at;
  final bool fork;

  const CrackLine({required this.pts, required this.at, required this.fork});
}

/// Jagged cracks splitting the floor from [x0].
List<CrackLine> cracks(
  Rng r,
  double x0,
  int n,
  double reach, [
  double depth = 7.0,
  double bias = 0.3,
]) {
  final out = <CrackLine>[];
  for (var i = 0; i < n; i++) {
    final side = r.chance(0.5 + bias * 0.5) ? 1.0 : -1.0;
    final l = reach * r.range(0.45, 1.0) * (i < 2 ? 1.0 : 0.7);
    final pts = <Point2>[(x0 + side * r.range(0.0, 1.5), 0.0)];
    var x = pts[0].$1;
    var y = 0.0;
    while ((x - x0).abs() < l && y < depth) {
      x += side * r.range(1.5, 3.5);
      y = math.min(
        depth,
        math.max(0.0, y + r.range(-0.6, 1.6) * ((x - x0).abs() > 3.0 ? 1.0 : 0.3)),
      );
      pts.add(((x + 0.5).floorToDouble(), (y + 0.5).floorToDouble()));
      if (r.chance(0.18) && pts.length > 3 && y < depth - 2.0) {
        final f = <Point2>[((x + 0.5).floorToDouble(), (y + 0.5).floorToDouble())];
        var fx = x;
        var fy = y;
        for (var j = r.intRange(1, 3); j > 0; j--) {
          fx += side * r.range(1.0, 3.0);
          fy += r.range(0.8, 2.0);
          f.add((
            (fx + 0.5).floorToDouble(),
            (math.min(depth + 1.0, fy) + 0.5).floorToDouble(),
          ));
        }
        out.add(CrackLine(pts: f, at: (x - x0).abs() / reach, fork: true));
      }
    }
    out.add(CrackLine(pts: pts, at: 0.0, fork: false));
  }
  return out;
}

typedef Spike = ({double a, double len, double w});

/// An impact star (after Sprite Fusion's impact): tapered spikes around ([x], [y]).
void star(
  Painter p,
  double x,
  double y,
  List<Spike> spikes,
  double sc,
  double th,
  int core,
  int body,
  int inner,
  int rim,
) {
  for (final pass in const [0, 1, 2]) {
    for (final s in spikes) {
      final c = math.cos(s.a);
      final sn = math.sin(s.a);
      final l = s.len * sc;
      for (var d = 0.0; d <= l; d += 0.5) {
        final hw0 = s.w * th * (1.0 - d / l) * math.min(1.0, 0.5 + d / 3.0);
        final hw = pass == 0
            ? hw0 + 0.8
            : pass == 1
                ? hw0
                : hw0 * 0.45;
        if (pass == 2 && d > l * 0.55) break;
        for (var o = -hw; o <= hw; o += 0.5) {
          p.px(
            x + c * d - sn * o,
            y + sn * d + c * o,
            pass == 0
                ? rim
                : pass == 1
                    ? (d < l * 0.35 ? inner : body)
                    : core,
          );
        }
      }
    }
  }
  final r = 2.4 * sc * math.sqrt(th);
  p.circle(x, y, r + 0.8, inner);
  p.circle(x, y, r, core);
}

/// A thin arc flying out from ([x], [y]).
void sliver(
  Painter p,
  double x,
  double y,
  double a,
  double r,
  double arc,
  int c,
  double k,
) {
  final n = (r * arc * 2.2).ceil();
  for (var j = 0; j <= n; j++) {
    final u = j / n - 0.5;
    final th = a + u * arc;
    final w = 1.4 * (1.0 - u.abs() * 2.0);
    for (var o = -w * 0.5; o <= w * 0.5 + 0.01; o += 0.5) {
      p.dot(x + math.cos(th) * (r + o), y + math.sin(th) * (r + o), c, k);
    }
  }
}

/// Part of a polyline: the first [len] px of it.
void along(
  List<Point2> pts,
  double len,
  void Function(double x0, double y0, double x1, double y1, double d) fn,
) {
  var d = 0.0;
  for (var i = 1; i < pts.length && d < len; i++) {
    final (x0, y0) = pts[i - 1];
    final (x1, y1) = pts[i];
    final l = hypot(x1 - x0, y1 - y0);
    final f = math.min(1.0, (len - d) / l);
    fn(x0, y0, x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, d);
    d += l;
  }
}
