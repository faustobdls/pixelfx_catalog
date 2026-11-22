// Shared by the fire effects.
// Adapted from Sprite Fusion's open-source fire
// (https://www.spritefusion.com/pixel-art-vfx/fire), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

typedef FireNoiseFn = double Function(
  double tt,
  double rate, [
  int seed,
  double off,
]);

/// Smooth value noise in [-1, 1] repeating every [period] cells.
double pnoise(double x, int period, [int seed = 0]) {
  final i = x.floor();
  final f = x - i;
  final u = f * f * (3.0 - 2.0 * f);
  final a = rand(wrapInt(i, period), seed);
  final b = rand(wrapInt(i + 1, period), seed);
  return (a + (b - a) * u) * 2.0 - 1.0;
}

/// Noise for a loop [d] seconds long (pass 0 for one-shots).
FireNoiseFn noiseFor(double d) {
  if (d == 0.0) {
    return (tt, rate, [seed = 0, off = 0.0]) => noise(tt * rate + off, seed);
  }
  return (tt, rate, [seed = 0, off = 0.0]) {
    final p = math.max(1, (rate * d).round());
    return pnoise((tt / d) * p + off, p, seed);
  };
}

/// Seamless particles for a loop [d] seconds long.
void looped<T>(
  double t,
  double d,
  int count,
  int seed,
  (T data, double life) Function(Rng r, int i) make,
  void Function(T data, double age, int i) draw,
) {
  for (var i = 0; i < count; i++) {
    final r = rng(seed, i);
    final born = r.next() * d;
    final (q, life) = make(r, i);
    for (var age = wrap(t - born, d); age < life; age += d) {
      draw(q, age, i);
    }
  }
}

double flicker(
  double Function(double rate, [int seed, double off]) n, [
  int s = 0,
]) =>
    0.74 + 0.16 * n(7.3, 1 + s) + 0.1 * n(19.0, 2 + s);

List<int> hotFirst(List<int> f) => f.reversed.toList(growable: false);

const List<(double lw, double lh, int ri)> fireLayers = [
  (1.0, 1.0, 6),
  (0.76, 0.86, 4),
  (0.54, 0.68, 2),
  (0.3, 0.42, 0),
];

const List<(double lw, double lh, int ri)> fireBigLayers = [
  (1.0, 1.0, 6),
  (0.8, 0.9, 5),
  (0.62, 0.78, 4),
  (0.44, 0.6, 3),
  (0.26, 0.4, 1),
  (0.12, 0.22, 0),
];

const List<(double lw, double lh, int ri)> fireBackLayers = [
  (1.0, 1.0, 7),
  (0.76, 0.86, 5),
  (0.54, 0.68, 3),
  (0.3, 0.42, 2),
];

void flameTongue(
  Painter p,
  double x,
  double y,
  double h,
  double w,
  double sx,
  double Function(double rate, [int seed, double off]) n,
  int seedN,
  List<int> hRamp, {
  List<(double, double, int)> layers = fireLayers,
  double jit = 0.5,
  double wob = 1.1,
}) {
  if (h < 1.0) return;
  for (final (lw, lh, ri) in layers) {
    final l = h * lh;
    final c = hRamp[ri];
    final maxR = l.floor();
    for (var r = 0; r <= maxR; r++) {
      final u = r / math.max(1.0, l);
      final half = w *
              lw *
              math.pow(1.0 - u, 0.85) *
              math.min(1.0, (r + 1.5) / 3.5) +
          n(9.0, seedN, r * 0.45) * jit;
      if (half < 0.3) continue;
      final cx =
          x + sx * u * u * lh + n(4.0, seedN + 7, r * 0.2) * u * wob;
      final yRow = (y - r + 0.5).floor();
      final x0 = (cx - half + 0.5).floor();
      final x1 = (cx + half + 0.5).floor();
      for (var px = x0; px <= x1; px++) {
        p.px(px, yRow, c);
      }
    }
  }
}

void flameBlade(
  Painter p,
  double x,
  double y,
  double ux,
  double uy,
  double len,
  double w,
  double bend,
  double Function(double rate, [int seed, double off]) n,
  int seedN,
  List<int> hRamp, {
  List<(double, double, int)> layers = fireLayers,
  double jit = 0.5,
  double wob = 1.1,
}) {
  if (len < 1.0) return;
  final nx = -uy;
  final ny = ux;
  for (final (lw, lh, ri) in layers) {
    final l = len * lh;
    final c = hRamp[ri];
    for (var r = 0.0; r <= l; r += 0.5) {
      final u = r / math.max(1.0, l);
      final half = w *
              lw *
              math.pow(1.0 - u, 0.85) *
              math.min(1.0, (r + 1.5) / 3.5) +
          n(9.0, seedN, r * 0.45) * jit;
      if (half < 0.3) continue;
      final off =
          bend * u * u * lh + n(4.0, seedN + 7, r * 0.2) * u * wob;
      final cx = x + ux * r + nx * off;
      final cy = y + uy * r + ny * off;
      for (var q = -half; q <= half; q += 0.5) {
        p.px(cx + nx * q, cy + ny * q, c);
      }
    }
  }
}

void solidDisc(Painter p, double x, double y, double r, int c) {
  if (r < 0.6) {
    p.px(x, y, c);
    return;
  }
  final cx = p.toX(x, y);
  final cy = p.toY(x, y);
  final r2 = r * r;
  final y0 = (cy - r).floor();
  final y1 = (cy + r).ceil();
  for (var sy = y0; sy <= y1; sy++) {
    final dy = sy + 0.5 - cy;
    final s2 = r2 - dy * dy;
    if (s2 < 0.0) continue;
    final s = math.sqrt(s2);
    final x0 = (cx - s - 0.5).ceil();
    final x1 = (cx + s - 0.5).floor();
    for (var sx = x0; sx <= x1; sx++) {
      p.put(sx, sy, c, 1.0);
    }
  }
}

void softDisc(Painter p, double x, double y, double r, int c, double a) {
  if (a <= 0.004) return;
  if (r < 0.5) {
    p.blend(x, y, c, a);
    return;
  }
  final cx = p.toX(x, y);
  final cy = p.toY(x, y);
  final r2 = r * r;
  final y0 = (cy - r).floor();
  final y1 = (cy + r).ceil();
  for (var sy = y0; sy <= y1; sy++) {
    final dy = sy + 0.5 - cy;
    final s2 = r2 - dy * dy;
    if (s2 < 0.0) continue;
    final s = math.sqrt(s2);
    final x0 = (cx - s - 0.5).ceil();
    final x1 = (cx + s - 0.5).floor();
    for (var sx = x0; sx <= x1; sx++) {
      p.blendPx(sx, sy, c, a);
    }
  }
}

void firePuff(
  Painter p,
  double x,
  double y,
  double k,
  double size,
  double frac,
  List<int> hRamp, [
  double glowK = 0.18,
  double tx = 0.0,
  double ty = -1.0,
]) {
  final age = 1.0 - k;
  final n = hRamp.length;
  final heat = math.min(0.999, math.pow(age, 0.62).toDouble() + frac * 0.1);
  final idx = math.min(n - 2, (heat * (n - 1)).floor());
  final r = size *
      (0.55 + 0.45 * math.min(1.0, age * 7.0)) *
      (1.0 - age * 0.55);
  final c = hRamp[idx];
  if (idx >= n - 2) {
    softDisc(p, x, y, r, c, math.min(1.0, k * 3.0) * 0.85);
    return;
  }
  solidDisc(p, x, y, r, hRamp[math.min(n - 1, idx + 2)]);
  if (r > 1.6 && ty > -0.99) {
    solidDisc(p, x + tx * r * 1.5, y + ty * r * 1.5, r * 0.3,
        hRamp[math.min(n - 1, idx + 1)]);
  }
  solidDisc(p, x - r * 0.16, y - r * 0.22, r * 0.78, c);
  if (r > 1.6) {
    solidDisc(p, x + tx * r * 0.9, y + ty * r * 0.9, r * 0.42, c);
  }
  if (idx <= 3 && r > 1.8) {
    solidDisc(
        p, x - r * 0.28, y - r * 0.34, r * 0.36, hRamp[math.max(0, idx - 1)]);
  }
  if (idx < 6) p.glow(x, y, r * 2.4 + 2.0, c, glowK * k);
}

void lick(Painter p, double x, double y, double k, double s, List<int> hRamp) {
  final r = s * (0.4 + 0.6 * k);
  solidDisc(p, x, y, r + 0.6, k > 0.5 ? hRamp[5] : hRamp[6]);
  if (k > 0.35) {
    solidDisc(p, x, y - 0.3, r * 0.6, k > 0.7 ? hRamp[2] : hRamp[4]);
  }
}

int _rampAt(List<int> r, double t) =>
    r[math.min(r.length - 1, math.max(0, (t * r.length).floor()))];

void smokePuff(
  Painter p,
  double x,
  double y,
  double k,
  double size, [
  int col = 0,
  bool big = false,
  double aMul = 1.0,
]) {
  final age = 1.0 - k;
  final r = size *
      (0.65 + math.min(1.0, age * 2.5) * 0.45 + age * (big ? 0.5 : 0.4));
  final a = math.min(1.0, age * 12.0) *
      math.min(1.0, k * 2.4) *
      (big ? 0.7 : 0.58) *
      aMul;
  final c = col != 0
      ? mix(col, _rampAt(kSmokeRamp, age), age)
      : _rampAt(kSmokeRamp, age * 1.05);
  softDisc(p, x, y, r, c, a * 0.45);
  softDisc(p, x + r * 0.05, y + r * 0.06, r * 0.74, c, a * 0.62);
  if (age < 0.5) {
    softDisc(p, x - r * 0.22, y - r * 0.3, r * 0.5, mix(c, kWhite, 0.12),
        a * 0.4 * (1.0 - age * 2.0));
  }
}

void emberDot(
  Painter p,
  double x,
  double y,
  double k,
  double size,
  List<int> cols,
  double ph,
) {
  if (k < 0.25 && math.sin(ph) < 0.0) return;
  final c = k > 0.6 ? cols[0] : (k > 0.3 ? cols[1] : cols[2]);
  if (size >= 2.0) {
    final rim = k > 0.45 ? cols[2] : cols[3];
    p.px(x - 1, y, rim);
    p.px(x + 1, y, rim);
    p.px(x, y - 1, rim);
    p.px(x, y + 1, rim);
    p.px(x, y, c);
    p.glow(x, y, 8, c, 0.4 * k);
    return;
  }
  p.px(x, y, c);
  if (size > 1.4) p.px(x, y + 1, cols[3]);
  p.glow(x, y, 3.0 + size, c, 0.35 * k);
}

void sparkLine(
  Painter p,
  double x,
  double y,
  double vx,
  double vy,
  double k,
  List<int> cols,
) {
  final rawSp = hypot(vx, vy);
  final sp = rawSp == 0.0 ? 1.0 : rawSp;
  final ux = vx / sp;
  final uy = vy / sp;
  final len = math.min(9.0, 1.0 + sp * 0.022);
  final head = k > 0.6 ? cols[0] : (k > 0.3 ? cols[1] : cols[2]);
  p.line(x - ux * len, y - uy * len, x - ux * len * 0.4, y - uy * len * 0.4,
      k > 0.5 ? head : cols[cols.length - 1]);
  p.line(x - ux * len * 0.45, y - uy * len * 0.45, x, y, head);
  p.glow(x, y, 3, head, 0.45 * k);
}

(double, double) _along(
  double x,
  double v,
  double a,
  double k,
  double t,
) {
  if (k <= 0.0) return (x + v * t + 0.5 * a * t * t, v + a * t);
  final e = math.exp(-k * t);
  final vt = a / k;
  return (x + vt * t + ((v - vt) * (1.0 - e)) / k, vt + (v - vt) * e);
}

(double x, double y, double vx, double vy) drift(
  double x,
  double y,
  double vx,
  double vy,
  double t,
  double ax,
  double ay,
  double kx,
  double ky,
) {
  final xRes = _along(x, vx, ax, kx, t);
  final yRes = _along(y, vy, ay, ky, t);
  return (xRes.$1, yRes.$1, xRes.$2, yRes.$2);
}

final int _smoke1 = hex('#5b5566');

typedef TongueSpec = (double dx, double dy, double h, double w, int back);

class _TongueData {
  final double dx;
  final double y;
  final double h;
  final double w;
  final int back;
  final double env;
  final int n;

  _TongueData(this.dx, this.y, this.h, this.w, this.back, this.env, this.n);
}

class _SmokePuffSeed {
  final double x, y, vx, vy, life, s;
  _SmokePuffSeed(this.x, this.y, this.vx, this.vy, this.life, this.s);
}

class _FirePuffSeed {
  final int i;
  final double fire, sl, ox, oy, vx, vy, s, f;
  final bool smokes;
  _FirePuffSeed(this.i, this.fire, this.smokes, this.sl, this.ox, this.oy,
      this.vx, this.vy, this.s, this.f);
}

class _LickSeed {
  final int i;
  final double vx, vy, s;
  _LickSeed(this.i, this.vx, this.vy, this.s);
}

class _EmberSeed {
  final double x, y, vx, vy, life, s, a, b;
  _EmberSeed(this.x, this.y, this.vx, this.vy, this.life, this.s, this.a, this.b);
}

({(double, double, double) Function(int i, double tt) tip, double fl}) burn(
  Painter p,
  double t,
  List<TongueSpec> tongues, {
  required List<int> hRamp,
  required double d,
  required FireNoiseFn nl,
  required int seed,
  required double height,
  double x = 0.0,
  double y = 0.0,
  double lean = 0.1,
  double spread = 6.0,
  double puffsRate = 8.0,
  double licksRate = 4.0,
  double smokeRate = 12.0,
  double smokeSize = 3.0,
  (double, double) smokeLife = const (1.6, 2.6),
  double embersRate = 8.0,
  double glowR = 46.0,
  double glow = 1.0,
  double wind = 3.0,
  void Function(double fl)? mid,
}) {
  double n(double rate, [int s = 0, double off = 0.0]) => nl(t, rate, s, off);
  double fla(double tt) =>
      0.74 + 0.16 * nl(tt, 7.3, seed + 1) + 0.1 * nl(tt, 19.0, seed + 2);
  final fl = fla(t);
  final smokeCol = mix(_smoke1, hRamp[6], 0.25);
  final embCols = [hRamp[1], hRamp[2], hRamp[4], hRamp[6]];
  final glowCol = mix(mix(hRamp[3], hRamp[4], 0.5), kWhite, 0.25);
  final r = rng(seed, 77);
  int count(double rate) => (rate * d).round();

  final ttList = [
    for (var i = 0; i < tongues.length; i++)
      _TongueData(
        tongues[i].$1 + r.range(-0.3, 0.3),
        tongues[i].$2,
        2.0 + height * tongues[i].$3 * r.range(0.92, 1.08),
        tongues[i].$4 * r.range(0.92, 1.08),
        tongues[i].$5,
        tongues[i].$3,
        (seed * 7 + i) * 13,
      ),
  ];

  double leanAt(double tt) => nl(tt, 0.67, seed + 90) * lean;

  double heightAt(int i, double tt) {
    final td = ttList[i];
    final leap = math.max(0.0, nl(tt, 2.6, td.n + 70) - 0.55) * 1.4;
    return (td.h + 0.25 * td.h * nl(tt, 3.3, td.n) + td.h * leap) *
        (0.9 + 0.1 * fla(tt));
  }

  double sweepAt(int i, double tt, double hVal) =>
      nl(tt, 2.2, ttList[i].n + 40) * (1.0 + hVal * 0.08) +
      leanAt(tt) * hVal * 0.9 -
      clamp(ttList[i].dx * 0.3, -2.5, 2.5);

  (double, double, double) tipAt(int i, double tt) {
    final hVal = heightAt(i, tt);
    return (
      x + ttList[i].dx + sweepAt(i, tt, hVal) * 0.85,
      y + ttList[i].y - hVal * 0.88 + 3.0,
      hVal,
    );
  }

  void tongueAt(int i) {
    final td = ttList[i];
    final hVal = heightAt(i, t);
    flameTongue(
      p,
      x + td.dx,
      y + td.y,
      hVal,
      td.w,
      sweepAt(i, t, hVal),
      n,
      td.n,
      hRamp,
      layers: td.back != 0
          ? fireBackLayers
          : (td.w > 2.2 ? fireBigLayers : fireLayers),
      jit: 0.5,
      wob: 1.1 + hVal * 0.04,
    );
  }

  looped<_SmokePuffSeed>(
    t,
    d,
    count(smokeRate),
    seed + 300,
    (r, _) {
      final px = r.range(-spread, spread) * 0.7;
      final py = -height * 0.8 - r.range(0.0, 6.0);
      final vx = r.range(-2.0, 2.0);
      final vy = -r.range(10.0, 17.0);
      final life = r.range(smokeLife.$1, smokeLife.$2);
      final s = r.range(0.7, 1.1) * smokeSize;
      return (_SmokePuffSeed(px, py, vx, vy, life, s), life);
    },
    (q, age, _) {
      final (dx, dy, _, _) =
          drift(q.x, q.y, q.vx, q.vy, age, wind, -20.0, 1.6, 1.0);
      smokePuff(
        p,
        x + dx + nl(t - age, 0.8, seed + 60) * (1.5 + 2.5 * age),
        y + dy,
        1.0 - age / q.life,
        q.s,
        smokeCol,
      );
    },
  );

  final puffDraws = <(double, double, double, double, double)>[];
  looped<_FirePuffSeed>(
    t,
    d,
    ttList.length * count(puffsRate),
    seed + 200,
    (r, j) {
      final i = j % ttList.length;
      final fire = r.range(0.14, 0.3);
      final smokes = r.chance(0.45);
      final life = fire + (smokes ? 1.4 : 0.0);
      return (
        _FirePuffSeed(
          i,
          fire,
          smokes,
          r.range(0.8, 1.4),
          r.range(-1.0, 1.0),
          r.range(0.0, 4.0),
          r.range(-4.0, 4.0),
          -r.range(15.0, 30.0),
          r.range(0.8, 1.6) * (0.8 + 0.6 * ttList[i].env),
          r.next(),
        ),
        life,
      );
    },
    (q, age, _) {
      final (tx, ty, _) = tipAt(q.i, t - age);
      final (px, py, vx, vy) = drift(
        tx + q.ox,
        ty + q.oy,
        q.vx,
        q.vy,
        math.min(age, q.fire),
        0.0,
        -95.0,
        5.0,
        3.2,
      );
      if (age < q.fire) {
        puffDraws.add((px, py, 1.0 - age / q.fire, q.s, q.f));
        return;
      }
      if (age - q.fire > q.sl) return;
      final (sx, sy, _, _) = drift(
        px,
        py,
        vx * 0.6,
        vy * 0.6 - 6.0,
        age - q.fire,
        wind,
        -16.0,
        1.6,
        1.2,
      );
      smokePuff(p, sx, sy, 1.0 - (age - q.fire) / q.sl, q.s * 0.7, 0);
    },
  );

  for (var i = 0; i < ttList.length; i++) {
    if (ttList[i].back != 0) tongueAt(i);
  }
  for (var i = 0; i < ttList.length; i++) {
    if (ttList[i].back == 0) tongueAt(i);
  }
  mid?.call(fl);

  looped<_LickSeed>(
    t,
    d,
    ttList.length * count(licksRate),
    seed + 220,
    (r, j) {
      final idx = j % ttList.length;
      return (
        _LickSeed(
          idx,
          r.range(-3.0, 3.0),
          -r.range(12.0, 22.0),
          r.range(0.9, 1.6) * (0.8 + 0.5 * ttList[idx].env),
        ),
        0.26,
      );
    },
    (q, age, _) {
      final (tx, ty, _) = tipAt(q.i, t - age);
      lick(p, tx + q.vx * age, ty - 2.0 + q.vy * age, 1.0 - age / 0.26, q.s,
          hRamp);
    },
  );

  for (final (px, py, k, s, f) in puffDraws) {
    firePuff(p, px, py, k, s, f, hRamp);
  }

  looped<_EmberSeed>(
    t,
    d,
    count(embersRate),
    seed + 500,
    (r, _) {
      final px = r.range(-spread, spread);
      final py = -r.range(height * 0.3, height * 0.8);
      final vx = r.range(-15.0, 15.0);
      final vy = -r.range(25.0, 60.0);
      final life = r.range(1.1, 2.4);
      final s = r.chance(0.15) ? 2.0 : r.range(1.0, 1.6);
      final a = r.range(0.0, 6.3);
      final b = r.range(0.0, 6.3);
      return (_EmberSeed(px, py, vx, vy, life, s, a, b), life);
    },
    (q, age, _) {
      final (dx, dy, _, _) =
          drift(q.x, q.y, q.vx, q.vy, age, 0.0, -30.0, 1.6, 1.6);
      emberDot(
        p,
        x + dx + 7.0 * (math.sin(age * 2.3 + q.a) - math.sin(q.a)),
        y + dy + 2.0 * (math.sin(age * 3.0 + q.b) - math.sin(q.b)),
        1.0 - age / q.life,
        q.s,
        embCols,
        age * 40.0 + q.a,
      );
    },
  );

  if (glow > 0.0) {
    final lx = x + leanAt(t) * 12.0;
    p.glow(lx, y - height * 0.35, glowR * 1.5, glowCol, 0.22 * fl * glow);
    p.glow(lx, y - height * 0.75, glowR, glowCol, 0.34 * fl * glow);
    p.glow(x, y - height * 0.2, glowR * 0.32, hRamp[2], 0.2 * fl * glow);
    p.glow(x, y - 2.0, 8, hRamp[0], 0.14 * fl * glow);
  }
  return (tip: tipAt, fl: fl);
}
