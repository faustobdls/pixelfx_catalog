import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

final int kSoot = hex('#0d0a12');
final int kOutline = hex('#1a1422');
final double _light = math.atan2(-1.0, -1.0); // light comes from the top left

class StonePalette {
  final int light;
  final int body;
  final int shade;
  final int dust;
  final int lip;

  const StonePalette({
    required this.light,
    required this.body,
    required this.shade,
    required this.dust,
    required this.lip,
  });
}

/// Stone colors from one body color: light, body, shade, dust (lighter and greyer), lip (a lit broken edge).
StonePalette stone(Object c) {
  final col = hex(c);
  return StonePalette(
    light: mix(scaleColor(col, 1.35), kWhite, 0.08),
    body: col,
    shade: scaleColor(col, 0.64),
    dust: mix(scaleColor(col, 1.2), rgb(150, 140, 150), 0.3),
    lip: mix(scaleColor(col, 1.55), kWhite, 0.12),
  );
}

class ImpactSpike {
  final double a;
  double len;
  final double w;

  ImpactSpike({required this.a, required this.len, required this.w});
}

/// Spikes for a hit star: n of them round the circle, longer towards aim (fwd) and a little behind it (back).
/// len and w: (min, max) base length and root half-width; jag scales every other spike (short teeth between).
List<ImpactSpike> spikes(
  Rng r,
  int n,
  double aim, {
  (double, double) len = (7.0, 10.0),
  (double, double) w = (1.5, 2.1),
  double fwd = 1.8,
  double back = 0.6,
  double jag = 1.0,
  double jit = 0.18,
}) {
  return List<ImpactSpike>.generate(n, (i) {
    final a = aim + (i / n) * tau + r.range(-jit, jit);
    final cb = math.cos(a - aim);
    final odd = (i & 1) != 0;
    final l = r.range(len.$1, len.$2) *
        (1.0 +
            fwd * math.pow(math.max(0.0, cb), 3) +
            back * math.pow(math.max(0.0, -cb), 3)) *
        (odd ? jag : 1.0);
    return ImpactSpike(
      a: a,
      len: l,
      w: r.range(w.$1, w.$2) * (odd ? math.sqrt(jag) : 1.0),
    );
  });
}

/// A hit star: tapered spikes in three passes (a rim, a body that's paler near the root, a hot core) round a
/// hot heart. sc stretches the spikes, th thins them, cols [rim, body, inner, core], a dithers it out.
void star(
  Painter p,
  double x,
  double y,
  List<ImpactSpike> list,
  double sc,
  double th,
  List<int> cols, [
  double a = 1.0,
  double heart = 2.4,
]) {
  final rim = cols[0];
  final body = cols[1];
  final inner = cols[2];
  final core = cols[3];
  for (var pass = 0; pass < 3; pass++) {
    for (final s in list) {
      final c = math.cos(s.a);
      final sn = math.sin(s.a);
      final l = s.len * sc;
      for (var d = 0.0; d <= l; d += 0.5) {
        if (pass == 2 && d > l * 0.55) break;
        final hw0 = s.w * th * (1.0 - d / l) * math.min(1.0, 0.5 + d / 3.0);
        final hw = pass == 0 ? hw0 + 0.8 : (pass == 1 ? hw0 : hw0 * 0.45);
        final col = pass == 0
            ? rim
            : (pass == 1 ? (d < l * 0.35 ? inner : body) : core);
        for (var o = -hw; o <= hw; o += 0.5) {
          p.dot(x + c * d - sn * o, y + sn * d + c * o, col, a);
        }
      }
    }
  }
  final r = heart * sc * math.sqrt(th);
  p.circle(x, y, r + 0.8, inner, a);
  p.circle(x, y, r, core, a);
}

class RingSeg {
  final double a;
  final double gap;
  final double dr;
  final double w;

  const RingSeg({
    required this.a,
    required this.gap,
    required this.dr,
    this.w = 1.0,
  });
}

/// A ring that breaks into arcs: segs evenly round the ring. brk 0 draws a whole ring th thick; as brk grows each arc
/// shrinks, tapers at both ends into a crescent and drifts out at its own speed. c is the outer edge's color, c2 the
/// inner's; sy squashes it onto a plane; nothing is drawn below maxY (a floor).
void brokenRing(
  Painter p,
  double x,
  double y,
  double r,
  double th,
  List<RingSeg> segs,
  double brk,
  int c, [
  int? c2,
  double k = 1.0,
  double sy = 1.0,
  double maxY = double.infinity,
]) {
  if (r <= 0.0 || k <= 0.0) return;
  final inner = c2 ?? c;
  final full = tau / segs.length;
  for (final s in segs) {
    final span = full * (1.0 - s.gap * brk) + 0.02;
    final rr = r * (1.0 + s.dr * brk);
    final m = math.max(4, (rr * span * 1.8).ceil());
    for (var j = 0; j <= m; j++) {
      final u = j / m;
      final ang = s.a + (u - 0.5) * span;
      final w = math.max(
        0.5,
        th * s.w * (1.0 - brk * math.pow((2.0 * u - 1.0).abs(), 1.6)),
      );
      final ca = math.cos(ang);
      final sa = math.sin(ang);
      for (var o = -w / 2.0; o <= w / 2.0 + 0.01; o += 0.5) {
        if (y + sa * (rr + o) * sy < maxY) {
          p.dot(
            x + ca * (rr + o),
            y + sa * (rr + o) * sy,
            o > -0.26 ? c : inner,
            k,
          );
        }
      }
    }
  }
}

class CrackPoint {
  final double x;
  final double y;
  final double d;

  const CrackPoint(this.x, this.y, this.d);
}

class CrackLine {
  final List<CrackPoint> pts;
  final double len;
  final double t0;
  final List<List<CrackPoint>> kids;

  CrackLine({
    required this.pts,
    required this.len,
    required this.t0,
    required this.kids,
  });
}

// a jagged walk from (x, y) heading a for L px
List<CrackPoint> _walk(
  Rng r,
  double x,
  double y,
  double a,
  double l, {
  double jit = 0.55,
  double steer = 0.45,
  (double, double) step = (2.0, 4.0),
  double maxY = double.infinity,
  double d0 = 0.0,
}) {
  final pts = <CrackPoint>[CrackPoint(x, y, d0)];
  var d = 0.0;
  var cur = a;
  while (d < l - 0.01) {
    final s = math.min(l - d, r.range(step.$1, step.$2));
    cur += r.range(-jit, jit) + (a - cur) * steer;
    x += math.cos(cur) * s;
    y = clamp(y + math.sin(cur) * s, 0.5, maxY);
    d += s;
    pts.add(CrackPoint(x, y, d0 + d));
  }
  return pts;
}

/// Cracks in the floor face below (0, 0): n jagged lines, alternately left and right, mostly shallow, a few
/// diving steeply, some forked.
List<CrackLine> makeCracks(
  Rng r,
  int n, {
  (double, double) len = (14.0, 40.0),
  double dive = 0.85,
  double maxY = 22.0,
  double forks = 0.5,
  (double, double) x0 = (1.0, 5.0),
}) {
  final out = <CrackLine>[];
  for (var i = 0; i < n; i++) {
    final side = (i & 1) != 0 ? 1 : -1;
    final dip = 0.06 + math.pow(r.next(), 1.7) * dive;
    final l = r.range(len.$1, len.$2) * (1.0 - (0.5 * dip) / (dive + 0.06));
    final a = side > 0 ? dip : math.pi - dip;
    final pts = _walk(
      r,
      side * r.range(x0.$1, x0.$2),
      r.range(0.5, 1.5),
      a,
      l,
      maxY: maxY,
    );
    final c = CrackLine(
      pts: pts,
      len: l,
      t0: r.range(0.0, 0.035),
      kids: [],
    );
    for (var j = 2; j < pts.length - 1; j++) {
      if (r.chance(forks * 0.4)) {
        final fp = pts[j];
        c.kids.add(
          _walk(
            r,
            fp.x,
            fp.y,
            a + r.sign() * r.range(0.45, 1.0),
            r.range(3.0, 9.0) * (1.0 - (0.5 * j) / pts.length),
            maxY: maxY,
            d0: fp.d,
            jit: 0.7,
            step: (1.5, 3.0),
          ),
        );
      }
    }
    out.add(c);
  }
  return out;
}

/// Draw cracks grown to g(c) px of their length. heat(d) 0..1 at distance d along a crack lights it from the
/// hot ramp (bright to dark) before it cools to dark; lip is the lit lower edge; k dithers them out.
void drawCracks(
  Painter p,
  List<CrackLine> cracks,
  double Function(CrackLine c) g,
  double Function(double d) heat,
  List<int> hot,
  int dark,
  int lip, [
  double k = 1.0,
]) {
  if (k <= 0.0) return;
  int col(double d) {
    final h = heat(d);
    return h > 0.75
        ? hot[0]
        : (h > 0.5
            ? hot[1]
            : (h > 0.3 ? hot[2] : (h > 0.12 ? hot[3] : dark)));
  }

  for (final c in cracks) {
    final G = g(c);
    if (G <= 0.0) continue;
    for (final path in [c.pts, ...c.kids]) {
      for (var i = 1; i < path.length; i++) {
        final p0 = path[i - 1];
        final p1 = path[i];
        if (p0.d >= G) break;
        final f = p1.d > G ? (G - p0.d) / (p1.d - p0.d) : 1.0;
        final ex = p0.x + (p1.x - p0.x) * f;
        final ey = p0.y + (p1.y - p0.y) * f;
        p.lineShaded(
          p0.x,
          p0.y + 1.0,
          ex,
          ey + 1.0,
          color: (_) => lip,
          alpha: (u) => rand(
                    (p0.x + (ex - p0.x) * u + 0.5).floor(),
                    (p0.y + (ey - p0.y) * u + 0.5).floor(),
                    5,
                  ) <
                  0.3
              ? k * 0.8
              : 0.0,
        );
        p.lineShaded(
          p0.x,
          p0.y,
          ex,
          ey,
          color: (u) => col(p0.d + (p1.d - p0.d) * f * u),
          alpha: (_) => k,
        );
        final h = heat(p0.d);
        if (h > 0.12) {
          p.glow(
            (p0.x + ex) / 2.0,
            (p0.y + ey) / 2.0,
            4.0 + h * 4.0,
            hot[2],
            0.22 * h * k,
          );
        }
      }
    }
  }
}

/// A standing crescent shock front on the floor (y = 0): it leans back from a leading edge low at x, dir 1
/// racing right ")", -1 left "(". h tall, w thick at its widest; cols [edge, body, back] bright to dark; k dithers it out.
void frontCrescent(
  Painter p,
  double x,
  int dir,
  double h,
  double w,
  List<int> cols, [
  double k = 1.0,
]) {
  if (h < 1.0 || w < 0.3 || k <= 0.0) return;
  final ry = h * 0.8;
  final cy = -h * 0.2;
  final rx = math.max(2.0, h * 0.55);
  final x0 = dir > 0 ? x - rx - w - 1.0 : x - 1.0;
  final x1 = dir > 0 ? x + 1.0 : x + rx + w + 1.0;
  p.shade(x0, -h - 1.0, x1, 0.0, (px, py, out) {
    if (py > 0.0) return null;
    final ey = (py - cy) / ry;
    if (ey <= -1.0 || ey >= 1.0) return null;
    final e2 = 1.0 - ey * ey;
    final edge = rx * math.sqrt(e2) - rx;
    final wt = w * math.pow(e2, 0.45);
    final q = (edge - (px - x) * dir) / math.max(0.5, wt);
    if (q < 0.0 || q > 1.0) return null;
    out.c = q < 0.28 ? cols[0] : (q < 0.62 ? cols[1] : cols[2]);
    out.a = k * (ey < -0.8 ? 0.7 : 1.0) * (q > 0.7 ? 1.25 - q * 0.8 : 1.0);
    return null;
  });
}

/// A soft, lumpy ring of dust round (cx, cy): radius r, w thick (lumps swell it), alpha k, translucent and lit
/// on its upper side.
void dustRing(
  Painter p,
  double cx,
  double cy,
  double r,
  double w,
  double k,
  int c, {
  double sy = 1.0,
  double ph = 0.0,
  double brk = 0.0,
  double lit = 0.35,
  double maxY = double.infinity,
  int half = 0,
}) {
  if (k <= 0.01 || r <= 0.0) return;
  final W = w * 1.6;
  final lite = mix(c, kWhite, lit);
  final yEnd = math.min(maxY - 1.0, (cy + (r + W) * sy).ceilToDouble()).toInt();
  for (var y = (cy - (r + W) * sy).floor() - 1; y <= yEnd; y++) {
    for (var x = (cx - r - W).floor() - 1; x <= (cx + r + W).ceil() + 1; x++) {
      final dx = x + 0.5 - cx;
      final dy = (y + 0.5 - cy) / sy;
      final d = hypot(dx, dy);
      final g = math.atan2(dy, dx);
      if ((half < 0 && dy >= 0.0) || (half > 0 && dy < 0.0)) continue;
      final lumpy = 0.6 +
          0.3 * math.sin(5.0 * g + ph) +
          0.18 * math.sin(11.0 * g + ph * 2.1) +
          0.12 * math.sin(17.0 * g + ph * 0.7);
      final wt = w * lumpy;
      final off = (d - r - w * 0.25 * math.sin(7.0 * g + ph)).abs();
      if (off >= wt) continue;
      final tear = brk > 0.0
          ? clamp((0.55 + 0.45 * math.sin(6.0 * g + ph * 1.7) - brk) / 0.25)
          : 1.0;
      final a = k * (1.0 - math.pow(off / wt, 2)) * tear;
      if (a > 0.01) {
        p.blend(x, y, dy < 0.0 && d > r - wt * 0.3 ? lite : c, a);
      }
    }
  }
}

/// A rock's outline: n vertex radii round its centre.
List<double> rockShape(Rng r, [int n = 6]) =>
    List<double>.generate(n, (_) => r.range(0.7, 1.12));

/// A faceted rock tumbling at angle b.a: every facet shaded by how it faces the light, a lit top face, a dark
/// outline, dithering out over its last half second.
void rock(Painter p, DebrisBit b, List<double> pts, StonePalette st) {
  final r = 0.75 + b.s * 0.8;
  final n = pts.length;
  final fade = math.min(1.0, b.life / 0.5);
  final ca = math.cos(b.a);
  final sa = math.sin(b.a);
  p.shade(b.x - r - 2.0, b.y - r - 2.0, b.x + r + 2.0, b.y + r + 2.0, (x, y, out) {
    final dx = x - b.x;
    final dy = y - b.y;
    final u = dx * ca + dy * sa;
    final v = -dx * sa + dy * ca;
    final d = hypot(u, v);
    var ang = math.atan2(v, u);
    if (ang < 0.0) ang += tau;
    final f = (ang / tau) * n;
    final i = f.floor() % n;
    final w = f - f.floor();
    final edge = r * (pts[i] * (1.0 - w) + pts[(i + 1) % n] * w);
    if (d > edge + 0.85) return null;
    out.a = fade;
    if (d > edge) return kOutline;
    final lit = math.cos(((i + 0.5) / n) * tau + b.a - _light);
    if (d < edge * 0.42) return lit > 0.55 ? st.light : st.body;
    return lit > 0.35 ? st.light : (lit < -0.4 ? st.shade : st.body);
  });
}
