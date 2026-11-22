import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

/// Steady emitter for seamless loops: particle [i] is born at `i * period / n`.
void beat(
  double t,
  double period,
  int n,
  int seed,
  double Function(Rng r) life,
  void Function(double age, double life, Rng r, int i) fn,
) {
  for (var i = 0; i < n; i++) {
    final l = life(rng(seed, i, 911));
    for (var age = wrap(t - (i * period) / n + 1e-7, period);
        age < l;
        age += period) {
      fn(age, l, rng(seed, i), i);
    }
  }
}

/// Position and screen velocity after [age] seconds in the frame of a projectile
/// flying right at [v] px/s, with drag [k] (1/s) and gravity [g].
(double, double, double, double) wake(
  double x,
  double y,
  double vx,
  double vy,
  double age,
  double v,
  double k, [
  double g = 0,
]) {
  final e = math.exp(-k * age);
  final f = (1 - e) / k;
  final vt = g / k;
  return (
    x + vx * f - v * age,
    y + vt * age + (vy - vt) * f,
    vx * e - v,
    vt + (vy - vt) * e,
  );
}

/// A soft smoke puff with body, lower core, young top cap, and optional fire light.
void puff(
  Painter p,
  double x,
  double y,
  double r,
  double a,
  int c, [
  double cap = 1,
  double warm = 0,
  int wc = 0,
  double wa = 0,
]) {
  if (a <= 0.01 || r < 0.5) return;
  p.disc(x, y, r, c, a * 0.45);
  p.disc(x + r * 0.05, y + r * 0.06, r * 0.74, c, a * 0.62);
  if (cap > 0.02) {
    p.disc(
      x - r * 0.22,
      y - r * 0.3,
      r * 0.5,
      mix(c, kWhite, 0.14),
      a * 0.42 * cap,
    );
  }
  if (warm > 0.02) {
    p.disc(
      x + math.cos(wa) * r * 0.32,
      y + math.sin(wa) * r * 0.32,
      r * 0.55,
      wc,
      a * 0.7 * warm,
    );
  }
}

/// A single puff entry consumed by [cloud].
class CloudPuff {
  CloudPuff({
    required this.x,
    required this.y,
    required this.r,
    required this.a,
    required this.b,
    required this.w,
  });

  double x;
  double y;
  double r;
  double a;
  double b;
  double w;
}

/// Merges [list] of puffs into a single quantized, top-lit translucent smoke volume.
void cloud(
  Painter p,
  List<CloudPuff> list,
  List<int> rRamp,
  List<int> wrRamp, {
  double dens = 1.5,
  double max = 0.86,
  bool Function(double x, double y)? clip,
  double lit = 1,
}) {
  if (list.isEmpty) return;
  var x0 = 1 << 30;
  var y0 = 1 << 30;
  var x1 = -(1 << 30);
  var y1 = -(1 << 30);
  for (final q in list) {
    x0 = math.min(x0, (q.x - q.r).floor());
    x1 = math.max(x1, (q.x + q.r).ceil());
    y0 = math.min(y0, (q.y - q.r).floor());
    y1 = math.max(y1, (q.y + q.r).ceil());
  }
  final w = x1 - x0 + 3;
  final h = y1 - y0 + 3;
  final dArr = Float32List(w * h);
  final lArr = Float32List(w * h);
  final fArr = Float32List(w * h);
  x0--;
  y0--;
  for (final q in list) {
    final r = q.r;
    final r2 = r * r;
    for (var y = (q.y - r).floor(); y <= (q.y + r).ceil(); y++) {
      final dy = y + 0.5 - q.y;
      for (var x = (q.x - r).floor(); x <= (q.x + r).ceil(); x++) {
        final dx = x + 0.5 - q.x;
        final d2 = (dx * dx + dy * dy) / r2;
        if (d2 >= 1) continue;
        final k = math.sqrt(1 - d2) * q.a;
        final i = (y - y0) * w + (x - x0);
        dArr[i] += k;
        lArr[i] += k * q.b;
        fArr[i] += k * q.w * (0.5 + 0.5 * clamp(0.5 + dx / r));
      }
    }
  }
  final bArr = _blur(_blur(dArr, w, h, 1, 2), w, h, w, 2);
  final n = rRamp.length;
  p.each(x0 + 1.0, y0 + 1.0, x1 + 1.0, y1 + 1.0, (lx, ly, sx, sy) {
    final cx = lx.floor() - x0;
    final cy = ly.floor() - y0;
    if (cx < 1 || cy < 1 || cx >= w - 1 || cy >= h - 1) return;
    final i = cy * w + cx;
    final d = dArr[i];
    if (d < 0.05 || (clip != null && !clip(lx, ly))) return;
    final a = math.min(max, ((1 - math.exp(-d * dens)) * 6).ceil() / 6);
    if (a < 0.15) return;
    final gy = bArr[i + w] - bArr[i - w];
    final gx = bArr[i + 1] - bArr[i - 1];
    final up = clamp(
      0.5 +
          math.atan((gy * 0.9 + gx * 0.35) / (bArr[i] * 0.16 + 0.03)) *
              0.42 *
              lit,
    );
    final warm = fArr[i] / d;
    final j = clampInt(
      ((lArr[i] / d) * (0.3 + 0.7 * up) * (n - 1) + 0.25 + warm * 1.5 + 0.5)
          .floor(),
      0,
      n - 1,
    );
    p.blendPx(
      sx,
      sy,
      warm > 0.03
          ? mix(rRamp[j], wrRamp[j], math.min(0.9, (warm * 10).ceil() / 10))
          : rRamp[j],
      a,
    );
  });
}

Float32List _blur(Float32List src, int w, int h, int step, int r) {
  final out = Float32List(src.length);
  final n = step == 1 ? w : h;
  final lines = step == 1 ? h : w;
  final k = 1 / (2 * r + 1);
  for (var l = 0; l < lines; l++) {
    final base = step == 1 ? l * w : l;
    var acc = 0.0;
    for (var j = -r; j <= r; j++) {
      if (j >= 0 && j < n) acc += src[base + j * step];
    }
    for (var j = 0; j < n; j++) {
      out[base + j * step] = acc * k;
      final a = j - r;
      final b = j + r + 1;
      if (a >= 0) acc -= src[base + a * step];
      if (b < n) acc += src[base + b * step];
    }
  }
  return out;
}

/// Configuration for a simulated smoke puff in [Smoke].
class SmokePuff {
  SmokePuff({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    required this.r0,
    required this.r1,
    required this.life,
    this.a = 0.6,
    this.b = 0.85,
    this.warm = 0,
    this.drag = 2.5,
    this.rise = 12,
    this.grow = 2,
    this.curl = 0,
    this.delay = 0,
  });

  double x;
  double y;
  double vx;
  double vy;
  double r0;
  double r1;
  double life;
  double a;
  double b;
  double warm;
  double drag;
  double rise;
  double grow;
  double curl;
  double delay;
  double age = 0;
  double seed = 0;
}

/// Simulated smoke for one-shot effects, rendered with [cloud].
class Smoke {
  Smoke(this.r);

  final Rng r;
  final List<SmokePuff> list = [];
  double t = 0;

  void add(SmokePuff q) {
    q.seed = r.next() * 100;
    list.add(q);
  }

  int get count => list.length;

  void update(double dt) {
    t += dt;
    for (var i = list.length - 1; i >= 0; i--) {
      final q = list[i];
      if (q.delay > 0) {
        q.delay -= dt;
        continue;
      }
      if ((q.age += dt) >= q.life) {
        list.removeAt(i);
        continue;
      }
      if (q.curl != 0) {
        final c = math.cos(q.curl * dt);
        final s = math.sin(q.curl * dt);
        final vx = q.vx;
        q.vx = vx * c - q.vy * s;
        q.vy = vx * s + q.vy * c;
      }
      q.vy -= q.rise * dt;
      q.vx += math.sin(t * 1.3 + q.seed) * 8 * dt;
      q.vx -= q.vx * q.drag * dt;
      q.vy -= q.vy * q.drag * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
    }
  }

  List<CloudPuff> puffs() {
    final out = <CloudPuff>[];
    for (final q in list) {
      if (q.delay > 0) continue;
      final k = q.age / q.life;
      out.add(CloudPuff(
        x: q.x,
        y: q.y,
        r: q.r0 + (q.r1 - q.r0) * (1 - math.exp(-q.grow * q.age)),
        a: q.a * math.min(1.0, q.age * 30) * math.pow(1 - k, 1.3),
        b: q.b * (1 - k * 0.5),
        w: q.warm * math.exp(-q.age * 5),
      ));
    }
    return out;
  }
}

/// Two-tone velocity-stretched spark streak with glow.
void spark(
  Painter p,
  double x,
  double y,
  double vx,
  double vy,
  double k,
  List<int> s, [
  double glow = 0.45,
  double stretch = 0.022,
  double max = 9,
]) {
  final sp0 = hypot(vx, vy);
  final sp = sp0 == 0 ? 1.0 : sp0;
  final ux = vx / sp;
  final uy = vy / sp;
  final len = math.min(max, 1 + sp * stretch);
  final head = k > 0.6
      ? s[0]
      : k > 0.3
          ? s[1]
          : s[2];
  p.line(
    x - ux * len,
    y - uy * len,
    x - ux * len * 0.4,
    y - uy * len * 0.4,
    k > 0.5 ? head : s[3],
  );
  p.line(x - ux * len * 0.45, y - uy * len * 0.45, x, y, head);
  p.glow(x, y, 3, head, glow * k);
}

/// A single lobe of a muzzle flash.
class FlashLobe {
  const FlashLobe({
    required this.off,
    required this.a,
    required this.len,
    required this.wid,
    required this.core,
  });

  final double off;
  final double a;
  final double len;
  final double wid;
  final double core;
}

/// Generates spiky muzzle-flash lobes from [r] for frame [f] (1 or 2).
List<FlashLobe> flashShape(
  Rng r,
  int f, {
  double size = 1,
  List<double> spike = const [12, 20],
  List<double> diag = const [5, 10],
  List<double> cross = const [3, 6],
  List<double> back = const [2, 4.5],
  double core = 0.7,
}) {
  final k = f == 1 ? 1.0 : 0.6;
  final w = f == 1 ? 1.0 : 0.72;
  final s = size;
  final l = <FlashLobe>[
    FlashLobe(
      off: 0.5,
      a: r.range(-0.08, 0.08),
      len: r.range(5.5, 8) * s * k,
      wid: r.range(2.1, 2.6) * s * w,
      core: 0.5 * core,
    ),
    FlashLobe(
      off: 2,
      a: r.range(-0.07, 0.07),
      len: r.range(spike[0], spike[1]) * s * k,
      wid: r.range(1, 1.3) * s * w,
      core: 0.35 * core,
    ),
  ];
  void ray(double a, double len, double wid, bool on) {
    if (on) {
      l.add(FlashLobe(
        off: r.range(0.5, 2),
        a: a,
        len: len * s * k,
        wid: wid * s * w,
        core: 0.25 * core,
      ));
    }
  }

  for (final sign in const [-1, 1]) {
    ray(
      sign * r.range(0.3, 0.8),
      r.range(diag[0], diag[1]),
      r.range(1.1, 1.5),
      r.chance(0.85),
    );
    ray(
      sign * r.range(1.15, 1.7),
      r.range(cross[0], cross[1]),
      r.range(1, 1.3),
      r.chance(0.6),
    );
    ray(
      sign * r.range(2, 2.7),
      r.range(back[0], back[1]),
      1,
      r.chance(0.7) && f == 1,
    );
  }
  return l;
}

double _profile(FlashLobe l, double u) {
  final k = u / l.len;
  return l.wid *
      math.pow(math.max(0.0, 1 - k), 0.8) *
      math.min(1.0, 0.45 + k * 3);
}

/// Renders flash lobes [l] at ([x], [y]) along angle [a], returning flash reach.
double flash(
  Painter p,
  double x,
  double y,
  double a,
  List<FlashLobe> l,
  List<int> c,
  int seed,
) {
  final cs = math.cos(a);
  final sn = math.sin(a);
  var ext = 2.0;
  for (final lobe in l) {
    ext = math.max(ext, lobe.off + lobe.len + 2);
  }
  p.shade(x - ext, y - ext, x + ext, y + ext, (px, py, _) {
    final dx = px - x;
    final dy = py - y;
    final along = dx * cs + dy * sn;
    final across = -dx * sn + dy * cs;
    var m = -9.0;
    var hot = false;
    var warm = false;
    for (final lobe in l) {
      final ca = math.cos(lobe.a);
      final sa = math.sin(lobe.a);
      final lu = (along - lobe.off) * ca + across * sa;
      final lv = -(along - lobe.off) * sa + across * ca;
      if (lu < -1.5 || lu > lobe.len + 1) continue;
      final r = _profile(lobe, math.max(0.0, lu));
      final mm = r - lv.abs();
      if (mm > m) m = mm;
      if (lu < lobe.len * lobe.core && lv.abs() <= r * 0.5) hot = true;
      if (mm > r * 0.4) warm = true;
    }
    final dm = 1.6 - hypot(along - 0.5, across);
    if (dm > m) m = dm;
    if (dm > 0.6) hot = true;
    m += (rand(px.floor() * 73 + py.floor() * 151, seed) - 0.5) *
        0.5 *
        math.min(1.0, ext / 14);
    if (m < -0.85) return null;
    return m < 0
        ? c[3]
        : hot
            ? c[0]
            : warm
                ? c[1]
                : c[2];
  });
  return ext;
}

/// Closed-form state of a bouncing brass casing.
class CasingState {
  const CasingState({
    required this.x,
    required this.y,
    required this.a,
    required this.rest,
    required this.hit,
  });

  final double x;
  final double y;
  final double a;
  final bool rest;
  final double hit;
}

/// Evaluates closed-form bouncing casing kinematics at [age].
CasingState casing(
  double x,
  double y,
  double vx,
  double vy,
  double va,
  double age,
  double g,
  double floor, [
  double bounce = 0.42,
  double a0 = 0,
]) {
  var t0 = 0.0;
  var a = a0;
  var hit = -1.0;
  for (var n = 0; n < 6; n++) {
    final d = floor - y;
    final tBounce = (-vy + math.sqrt(math.max(0.0, vy * vy + 2 * g * d))) / g;
    if (age - t0 < tBounce) {
      final u = age - t0;
      return CasingState(
        x: x + vx * u,
        y: y + vy * u + 0.5 * g * u * u,
        a: a + va * u,
        rest: false,
        hit: hit,
      );
    }
    x += vx * tBounce;
    a += va * tBounce;
    t0 += tBounce;
    hit = age - t0;
    final vin = vy + g * tBounce;
    y = floor;
    if (vin * bounce < 45) {
      final u = age - t0;
      const k = 7.0;
      final s = (1 - math.exp(-k * u)) / k;
      return CasingState(
        x: x + vx * 0.6 * s,
        y: floor,
        a: (a / math.pi + 0.5).floor() * math.pi,
        rest: true,
        hit: hit,
      );
    }
    vy = -vin * bounce;
    vx *= 0.55;
    va *= 0.6;
  }
  return CasingState(
    x: x,
    y: floor,
    a: (a / math.pi + 0.5).floor() * math.pi,
    rest: true,
    hit: hit,
  );
}

/// Draws a 3 px brass casing slug and impact glint.
void drawCasing(
  Painter p,
  CasingState k,
  List<int> b, [
  double fade = 1,
]) {
  final ca = math.cos(k.a);
  final sa = math.sin(k.a);
  final x = k.x;
  final y = k.y - 0.5;
  p.dot(x - ca, y - sa, b[1], fade);
  p.dot(x, y, b[2], fade);
  p.dot(x + ca, y + sa, b[3], fade);
  if (k.hit >= 0 && k.hit < 0.07) {
    p.px(x + ca * 0.5, y - 1, kWhite);
    p.glow(x, y, 5, b[3], 0.55 * (1 - k.hit / 0.07));
  }
}

/// Draws a character sprite rotated by [ang] around pivot ([px], [py]) at ([x], [y]).
void turnSprite(
  Painter p,
  List<String> rows,
  Map<String, int> pal,
  double x,
  double y,
  double ang,
  double px,
  double py, [
  double a = 1,
]) {
  final h = rows.length;
  final w = rows[0].length;
  final cs = math.cos(ang);
  final sn = math.sin(ang);
  final r = hypot(math.max(px, w - px), math.max(py, h - py)) + 1;
  p.shade(x - r, y - r, x + r, y + r, (lx, ly, out) {
    final dx = lx - x;
    final dy = ly - y;
    final i = (dx * cs + dy * sn + px).floor();
    final j = (-dx * sn + dy * cs + py).floor();
    if (i < 0 || j < 0 || i >= w || j >= h) return null;
    final c = pal[rows[j][i]];
    if (c == null) return null;
    out.c = c;
    out.a = a;
    return null;
  });
}

/// Outlined pixel sprite shape built by [pixelShape].
class PixelShape {
  const PixelShape({required this.rows, required this.x0, required this.y0});

  final List<String> rows;
  final int x0;
  final int y0;
}

/// Builds a pixel shape with an automatic 1 px `'o'` outline.
PixelShape pixelShape(
  int x0,
  int y0,
  int w,
  int h,
  void Function(void Function(int px, int py, String ch) set) build,
) {
  final g = List.generate(h, (_) => List.filled(w, '.'));
  void set(int px, int py, String ch) {
    final i = px - x0;
    final j = py - y0;
    if (i >= 0 && j >= 0 && i < w && j < h) g[j][i] = ch;
  }

  build(set);
  bool solid(int i, int j) =>
      i >= 0 && j >= 0 && i < w && j < h && g[j][i] != '.' && g[j][i] != 'o';
  for (var j = 0; j < h; j++) {
    for (var i = 0; i < w; i++) {
      if (g[j][i] == '.' &&
          (solid(i - 1, j) ||
              solid(i + 1, j) ||
              solid(i, j - 1) ||
              solid(i, j + 1))) {
        g[j][i] = 'o';
      }
    }
  }
  return PixelShape(
    rows: g.map((r) => r.join()).toList(),
    x0: x0,
    y0: y0,
  );
}
