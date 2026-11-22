// Shared by the explosions.
// The fire balls, rocks and scorch are adapted from Sprite Fusion's open-source explosion
// (https://www.spritefusion.com/pixel-art-vfx/explosion), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

final int kExplosionOutline = hex('#1a1422');
final int kExplosionSoot = hex('#0d0a12');
final int kExplosionSoot2 = hex('#17121d');

class StoneColors {
  final int light;
  final int body;
  final int shade;
  final int dust;
  const StoneColors(this.light, this.body, this.shade, this.dust);
}

/// Stone colors from one body color: a lit face, the body, a shaded face, and the dust it makes.
StoneColors stoneColors(Object cRaw) {
  final c = hex(cRaw);
  return StoneColors(
    mix(scaleColor(c, 1.35), kWhite, 0.08),
    c,
    scaleColor(c, 0.64),
    mix(scaleColor(c, 1.2), rgb(150, 140, 150), 0.3),
  );
}

/// A 9-step fire ramp, white-hot down to smouldering, from an 8-step palette (dark to bright).
List<int> fireRamp(List<int> f) => [
      f[7],
      f[6],
      f[5],
      f[4],
      f[3],
      f[2],
      f[1],
      mix(f[1], f[0], 0.5),
      f[0],
    ];

/// Heat for a scorch, from a fire ramp (bright to dark) down to cinders.
List<int> heatRamp(List<int> fr) => [
      ...fr.sublist(0, 8),
      mix(fr[8], kExplosionSoot, 0.3),
      mix(fr[8], kExplosionSoot, 0.65),
    ];

/// One FIRE particle drawn in the fire ramp [fr]: a darker rim, a lit core, a tongue on top, a hot heart.
void fireBall(Painter p, SimParticle q, List<int> fr) {
  final k = q.life / q.max;
  final age = 1.0 - k;
  final n = fr.length;
  final x = q.x;
  final y = q.y;
  final heat = math.min(0.999, math.pow(age, 0.62).toDouble() + (q.seed % 1.0) * 0.1);
  final idx = math.min(n - 2, (heat * (n - 1)).floor());
  final r = q.size * (0.55 + 0.45 * math.min(1.0, age * 7.0)) * (1.0 - age * 0.55);
  final c = fr[idx];
  if (idx >= n - 2) {
    p.disc(x, y, r, c, math.min(1.0, k * 3.0) * 0.85);
    return;
  }
  p.circle(x, y, r, fr[math.min(n - 1, idx + (idx <= 2 ? 3 : 2))]);
  p.circle(x - r * 0.16, y - r * 0.22, r * 0.78, c);
  if (r > 1.6) p.circle(x, y - r * 0.9, r * 0.42, c);
  if (idx <= 3 && r > 1.8) {
    p.circle(x - r * 0.28, y - r * 0.34, r * 0.36, fr[math.max(0, idx - 1)]);
  }
  if (idx < 6) p.glow(x, y, r * 2.4 + 2.0, c, 0.18 * k);
}

/// A particle system's layer ("back" or "front") with its FIRE puffs in the fire ramp [fr].
void drawPs(Painter p, Particles ps, String layer, List<int> fr) {
  final all = List<SimParticle>.of(ps.list);
  final fires = <SimParticle>[];
  final rest = <SimParticle>[];
  for (final q in all) {
    if (q.k == P.fire) {
      fires.add(q);
    } else {
      rest.add(q);
    }
  }
  final back = layer == 'back';
  if (!back) {
    for (final q in fires) {
      if (q.delay <= 0.0 && (q.flag & PF.back) == 0) fireBall(p, q, fr);
    }
  }
  ps.list
    ..clear()
    ..addAll(rest);
  ps.draw(p, layer);
  ps.list
    ..clear()
    ..addAll(all);
  if (back) {
    for (final q in fires) {
      if (q.delay <= 0.0 && (q.flag & PF.back) != 0) fireBall(p, q, fr);
    }
  }
}

const Set<ParticleKind> _lifts = {
  P.smoke,
  P.dust,
  P.fire,
  P.ember,
  P.vapour,
};

/// An updraft column at [x]: smoke, dust, fire and embers below [top] and within [w] of the axis
/// are carried up ([up] px/s^2) and squeezed toward it.
void updraft(
  Particles ps,
  double dt, {
  double x = 0.0,
  double top = double.negativeInfinity,
  double w = 12.0,
  double up = 150.0,
  double squeeze = 4.0,
  double pull = 0.0,
  double low = 10.0,
  double reach = 100.0,
  double k = 1.0,
}) {
  if (k <= 0.0) return;
  for (final q in ps.list) {
    if (q.delay > 0.0 || !_lifts.contains(q.k) || q.y < top) continue;
    final dx = q.x - x;
    final ax = dx.abs();
    final u = ax / w;
    if (u < 1.0) {
      final f = (1.0 - u * u) * k;
      q.vy -= up * f * dt;
      q.vx -= dx * squeeze * f * dt;
    }
    if (pull != 0.0 && q.y > -low && ax > w * 0.4 && ax < reach) {
      q.vx -= dx.sign * pull * k * (1.0 - ax / reach) * dt;
    }
  }
}

/// Drop particles that leave the box (local px), so nothing is drawn past the canvas.
void cullParticles(
    Particles ps, double x0, double y0, double x1, double y1) {
  final l = ps.list;
  for (var i = l.length - 1; i >= 0; i--) {
    final q = l[i];
    if (q.x < x0 || q.x > x1 || q.y < y0 || q.y > y1) l.removeAt(i);
  }
}

const Set<ParticleKind> _soft = {P.smoke, P.dust, P.vapour};

/// Soft particles (smoke, dust, vapour) fade out over [w] px as they near the sides [x0], [x1].
void fadeEdges(
  Particles ps,
  double x0,
  double x1, [
  double w = 30.0,
  double y1 = double.infinity,
]) {
  final l = ps.list;
  for (var i = l.length - 1; i >= 0; i--) {
    final q = l[i];
    if (!_soft.contains(q.k)) continue;
    final r = q.size * 1.65;
    final e = math.min((math.min(q.x - x0, x1 - q.x) - r) / w, (y1 - q.y - r) / 6.0);
    if (e <= 0.0) {
      l.removeAt(i);
    } else if (e < 1.0) {
      q.life = math.min(q.life, q.max * 0.42 * e);
    }
  }
}

/// A soft pool of light, an ellipse [rx] by [ry] at ([x], [y]): light falling on the floor.
void lightPool(
  Painter p,
  double x,
  double y,
  double rx,
  double ry,
  int c,
  double k,
) {
  if (k <= 0.004 || rx < 1.0 || ry < 0.5) return;
  p.shade(x - rx, y - ry, x + rx, y + ry, (px, py, out) {
    final dx = (px - x) / rx;
    final dy = (py - y) / ry;
    final d = dx * dx + dy * dy;
    if (d >= 1.0) return null;
    final f = 1.0 - math.sqrt(d);
    out.l = c;
    out.k = f * f * k;
    return null;
  });
}

/// A translucent ellipse (blended, never dithered): [c] and [a] may depend on d (0 centre .. 1 rim).
void haze(
  Painter p,
  double x,
  double y,
  double rx,
  double ry,
  int Function(double d) c,
  double Function(double d) a,
) {
  if (rx < 0.5 || ry < 0.5) return;
  p.each(x - rx, y - ry, x + rx, y + ry, (lx, ly, sx, sy) {
    final dx = (lx - x) / rx;
    final dy = (ly - y) / ry;
    final d2 = dx * dx + dy * dy;
    if (d2 > 1.0) return;
    final d = math.sqrt(d2);
    p.blendPx(sx, sy, c(d), a(d));
  });
}

/// The floor under a blast: a burn that spreads out in a blink, glows white-hot and cools through [hr] to soot.
void scorch(
  Painter p,
  List<int> hr,
  double t,
  double rx0,
  double cool,
  double fade, [
  int rows = 3,
]) {
  if (fade <= 0.0) return;
  final rx = rx0 * math.min(1.0, t / 0.08);
  final ry = rows + 1.5;
  final n = hr.length;
  final x0 = (-rx).floor();
  final x1 = rx.ceil();
  for (var y = 0; y < rows; y++) {
    for (var x = x0; x <= x1; x++) {
      final dx = (x + 0.5) / rx;
      final dy = (y + 0.5) / ry;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > 1.0) continue;
      final k = rand(x * 31 + y, 3);
      final temp =
          math.pow(clamp(1.0 - t / cool), 1.4).toDouble() * (1.25 - d) - k * 0.35;
      final crack = k > 0.88 && d < 0.85
          ? math.pow(clamp(1.0 - t / (cool * 2.0)), 1.2).toDouble() *
              (1.15 - d) *
              0.8
          : 0.0;
      final h = math.max(temp, crack);
      if (h > 0.06) {
        final idx = math.min(n - 1, ((1.0 - math.min(1.0, h)) * (n - 1)).floor());
        final c = hr[idx];
        p.dot(x, y, c, fade);
        if ((x & 3) == 0 || crack > temp) {
          p.glow(x + 0.5, y, 6, c, 0.18 * h * fade);
        }
      } else {
        p.dot(x, y, d < 0.5 ? kExplosionSoot : kExplosionSoot2,
            (d < 0.95 - k * 0.3 ? 1.0 : 1.0 - d) * fade);
      }
    }
  }
}

class ExplosionBit extends DebrisBit {
  double size;
  double heat;
  double pvy = 0.0;
  bool dusted = false;
  bool thud = false;
  List<({double x, double y, double t})>? pts;

  ExplosionBit({
    super.kind = DebrisKind.chunk,
    required super.x,
    required super.y,
    super.vx = 0.0,
    super.vy = 0.0,
    super.a = 0.0,
    super.va = 0.0,
    required super.s,
    super.c,
    super.g = 1.0,
    super.drag = 0.0,
    super.bounce = 0.0,
    required super.life,
    this.heat = 0.0,
  }) : size = s;
}

/// A rock (a Bits CHUNK): a lit side, a shaded side and an outline, turning as it spins.
void drawRock(Painter p, ExplosionBit b, StoneColors st, List<int> fr) {
  final r = 0.6 + b.size * 0.75;
  final fade = math.min(1.0, b.life / 0.5);
  final lx = math.cos(b.a) * r * 0.4;
  final ly = math.sin(b.a) * r * 0.4;
  final heat = b.heat;
  p.shade(b.x - r - 1, b.y - r - 1, b.x + r + 1, b.y + r + 1, (x, y, out) {
    final dx = x - b.x;
    final dy = y - b.y;
    final d = hypot(dx * 1.15, dy);
    if (d > r + 0.9) return null;
    out.a = fade;
    if (d > r) return kExplosionOutline;
    final lit = dx * lx + dy * ly;
    if (heat > 0.08) {
      final g = heat * (1.1 - d / (r + 0.5)) + (lit > 0.3 ? heat * 0.45 : 0.0);
      if (g > 0.5) {
        return fr[g > 1.0 ? 1 : (g > 0.8 ? 2 : (g > 0.62 ? 3 : 4))];
      }
      if (g > 0.32) return fr[5];
    }
    return lit < -0.4 ? st.light : (lit > 0.6 ? st.shade : st.body);
  });
  if (heat > 0.05) p.glow(b.x, b.y, r * 2.0 + 3.0, fr[3], 0.32 * heat * fade);
}

/// Light hugging the upper half of a circle of radius [r] at ([x], [y]), falling off over width [w].
void glowDome(
  Painter p,
  double x,
  double y,
  double r,
  double w,
  int c,
  double k, [
  (double, double, double, double) box = const (
    double.negativeInfinity,
    double.negativeInfinity,
    double.infinity,
    double.infinity,
  ),
]) {
  if (k <= 0.004 || w < 1.0) return;
  p.shade(
    math.max(box.$1, x - r - w),
    math.max(box.$2, y - r - w),
    math.min(box.$3, x + r + w),
    math.min(box.$4, y + 0.5),
    (px, py, out) {
      final d = (hypot(px - x, py - y) - r).abs() / w;
      if (d >= 1.0) return null;
      out.l = c;
      out.k = (1.0 - d) * (1.0 - d) * k;
      return null;
    },
  );
}

/// A burning thing's trail: [pts] (oldest first) at time [t], drawn as a ribbon.
void burnTrail(
  Painter p,
  List<({double x, double y, double t})> pts,
  double t,
  List<int> fr,
  List<int> sm, [
  double life = 0.5,
  double w = 1.0,
  double heat = 1.0,
]) {
  var lx = double.nan;
  var ly = double.nan;
  for (var i = pts.length - 1; i >= 0; i--) {
    final q = pts[i];
    final age = (t - q.t) / life;
    if (age >= 1.0) break;
    if (hypot(q.x - lx, q.y - ly) < 1.6) continue;
    lx = q.x;
    ly = q.y;
    final r = w * (0.7 + age * 2.6);
    if (age < 0.12 * heat) {
      p.circle(q.x, q.y - age * 6.0, r * 0.8, fr[age < 0.05 ? 3 : 5]);
    } else {
      p.disc(
        q.x,
        q.y - age * 6.0,
        r,
        sm[math.min(sm.length - 1, 1 + (age * 3.0).floor())],
        0.55 * (1.0 - age),
      );
    }
  }
}

/// Draw a particle system's GRIT as dirt in flight.
void drawDirt(Painter p, Particles ps, String layer) {
  final all = List<SimParticle>.of(ps.list);
  final grit = <SimParticle>[];
  final rest = <SimParticle>[];
  for (final q in all) {
    if (q.k == P.grit) {
      grit.add(q);
    } else {
      rest.add(q);
    }
  }
  ps.list
    ..clear()
    ..addAll(rest);
  ps.draw(p, layer);
  ps.list
    ..clear()
    ..addAll(all);
  if (layer == 'back') return;
  for (final q in grit) {
    if (q.delay > 0.0) continue;
    final k = q.life / q.max;
    final sp = hypot(q.vx, q.vy);
    if (k < 0.25 && k * 4.0 < 0.5) continue;
    if (sp > 140.0) {
      final l = math.min(5.0, sp * 0.012);
      final ux = q.vx / sp;
      final uy = q.vy / sp;
      p.lineShaded(
        q.x - ux * l,
        q.y - uy * l,
        q.x,
        q.y,
        color: (u) => u < 0.5 ? scaleColor(q.col, 0.7) : q.col,
      );
    } else {
      p.px(q.x, q.y, q.col);
      if (q.size >= 2.0) {
        p.px(q.x + 1.0, q.y, q.col);
        p.px(q.x, q.y + 1.0, scaleColor(q.col, 0.8));
        p.px(q.x + 1.0, q.y + 1.0, scaleColor(q.col, 0.7));
      }
    }
  }
}

/// A crater in the floor at [x].
void crater(
  Painter p,
  List<int> e,
  double x,
  double r,
  double k, [
  double a = 1.0,
]) {
  if (k <= 0.0 || a <= 0.0) return;
  final n = e.length;
  final rx = r * k;
  final ry = math.max(1.5, r * 0.17 * k);
  final pyEnd = ry.ceil() + 1;
  final pxStart = (-rx - 1.0).floor();
  final pxEnd = (rx + 1.0).ceil();
  for (var py = -1; py <= pyEnd; py++) {
    for (var px = pxStart; px <= pxEnd; px++) {
      final dx = (px + 0.5) / rx;
      final dy = (py + 0.5 - ry * 0.35) / ry;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > 1.08) continue;
      final c = d > 0.92
          ? (dy < 0.0 ? e[n - 2] : e[2])
          : (dy < -0.2 ? e[0] : (dy < 0.35 ? e[1] : e[2]));
      p.dot(x + px, py, c, a);
    }
  }
  for (final s in const [-1, 1]) {
    for (var i = 0; i < 9; i++) {
      final u = i / 8.0;
      final hRaw = math.sin(math.pi * u) * 2.2 * k +
          (rand(i, s > 0 ? 3 : 4) < 0.4 ? 1.0 : 0.0) * k;
      final h = (hRaw + 0.5).floor();
      final hx = x + s * (rx * 0.82 + u * r * 0.55);
      for (var j = 0; j <= h; j++) {
        p.dot(hx, -j, j == h ? e[n - 2] : (j == h - 1 ? e[3] : e[2]), a);
      }
    }
  }
  for (var i = 0; i < 26; i++) {
    final s = rand(i, 7) < 0.5 ? -1.0 : 1.0;
    final d = rx * (1.05 + rand(i, 8) * 1.4);
    final y = (rand(i, 9) * 3.0 + 0.5).floor() - 1;
    if (rand(i, 10) < k) {
      p.dot(x + s * d, y, rand(i, 11) < 0.5 ? e[3] : e[2], a);
    }
  }
}

/// A hemisphere of white-hot air on the floor at [x], radius [r].
void dome(Painter p, List<int> f, double x, double r, double k) {
  final e = 1.4 / r;
  p.shade(x - r - 1.5, -r - 1.5, x + r + 1.5, 0.5, (px, py, out) {
    final d = hypot(px - x, py) / r;
    if (d > 1.0 + e) return null;
    if (d > 1.0) return f[2];
    if (d > 0.8) return k > 0.45 ? f[6] : f[5];
    if (d > 0.5) return k > 0.45 ? kWhite : f[6];
    return k > 0.2 ? kWhite : f[6];
  });
}

/// A lobe of a billowing cloud, shaded like a ball.
void lobe(
  Painter p,
  double x,
  double y,
  double r,
  List<int> fr,
  List<int> sm,
  double fire,
  double glow,
  double a, [
  double z = 0.0,
  int dark = 0,
  int style = 0,
]) {
  if (r < 0.7 || a <= 0.01) return;
  final n = fr.length;
  final m = sm.length;
  final back = z < -0.35 ? 1 : 0;
  final rim = 1.0 - math.min(0.35, 1.6 / r);
  final seam = 1.0 - math.min(0.3, 1.3 / r);
  int shadeAt(int i) => sm[math.min(m - 1, i + back + dark)];
  final soft = 0.55 + 0.4 * (1.0 - math.min(1.0, a));

  void px(double lx, double ly, int sx, int sy) {
    final dx = (lx - x) / r;
    final dy = (ly - y) / r;
    final d2 = dx * dx + dy * dy;
    if (d2 > 1.0) return;
    final d = math.sqrt(d2);
    final nz = math.sqrt(1.0 - d2);
    final sky = -0.5 * dx - 0.66 * dy + 0.56 * nz;
    final v = fire * (1.32 - 0.78 * d) + 0.14 * sky * fire;
    int c;
    var k = 0.0;
    var solid = false;
    if (v > 0.44) {
      var i = math.min(n - 3, math.max(0, ((1.3 - v) * (n - 1) * 0.78).floor()));
      if (d > seam) {
        i = math.min(6, math.max(4, i + 2));
      } else if (d > seam - 0.22) {
        i = math.min(n - 3, i + 1);
      }
      c = fr[i];
      k = 0.05 * fire;
      solid = true;
    } else if (style != 0) {
      final lam = -0.42 * dx - 0.78 * dy + 0.46 * nz;
      if (lam > 0.66 && d > 0.4) {
        c = shadeAt(0);
      } else if (lam > 0.16) {
        c = shadeAt(1);
      } else if (lam > -0.3) {
        c = shadeAt(2);
      } else {
        c = shadeAt(lam < -0.64 ? 4 : 3);
        final g = glow * (0.6 + 0.4 * dy);
        if (g > 0.55) {
          c = fr[g > 0.8 ? 5 : 6];
          k = 0.08 * g;
        } else if (g > 0.34) {
          c = mix(c, fr[6], 0.6);
        } else if (g > 0.16) {
          c = mix(c, fr[7], 0.45);
        }
      }
    } else {
      final g = glow * (0.82 * dy + 0.3 * nz);
      if (g > 0.45) {
        c = fr[g > 0.66 ? 4 : 5];
        k = 0.1 * glow;
      } else if (g > 0.3) {
        c = fr[6];
      } else if (g > 0.2) {
        c = fr[7];
      } else {
        final s = sky * 0.5 + 0.5;
        c = shadeAt(s > 0.8 ? 0 : (s > 0.62 ? 1 : (s > 0.42 ? 2 : (s > 0.22 ? 3 : 4))));
      }
    }
    p.blendPx(sx, sy, c, solid || d <= rim ? a : a * soft);
    if (k > 0.0) p.add(sx, sy, c, k);
  }

  if (p.sn != 0.0 || p.cs != 1.0) {
    p.each(x - r, y - r, x + r, y + r, px);
    return;
  }
  final ax = p.tx + (x - r) * p.fx;
  final bx = p.tx + (x + r) * p.fx;
  final sx0 = math.max(p.ox, math.min(ax, bx).floor());
  final sx1 = math.min(p.ox + p.w - 1, math.max(ax, bx).ceil());
  final sy0 = math.max(p.oy, (p.ty + y - r).floor());
  final sy1 = math.min(p.oy + p.h - 1, (p.ty + y + r).ceil());
  for (var sy = sy0; sy <= sy1; sy++) {
    final ly = sy + 0.5 - p.ty;
    final q = (ly - y) / r;
    if (q * q >= 1.0) continue;
    final hw = r * math.sqrt(1.0 - q * q);
    final cx = p.tx + x * p.fx;
    final start = math.max(sx0, (cx - hw - 0.5).floor());
    final end = math.min(sx1, (cx + hw).ceil());
    for (var sx = start; sx <= end; sx++) {
      px((sx + 0.5 - p.tx) * p.fx, ly, sx, sy);
    }
  }
}

class _PlumeLobeSpec {
  final double th, ph, j, s, h, dx, dy, f, gv;
  _PlumeLobeSpec({
    required this.th,
    required this.ph,
    required this.j,
    required this.s,
    required this.h,
    required this.dx,
    required this.dy,
    required this.f,
    required this.gv,
  });
}

class _PlumeLobeAt {
  final double x, y, z, up, out, heat, fade, r, d, c;
  final _PlumeLobeSpec q;
  _PlumeLobeAt({
    required this.x,
    required this.y,
    required this.z,
    required this.up,
    required this.out,
    required this.heat,
    required this.q,
    required this.fade,
    required this.r,
    required this.d,
    required this.c,
  });
}

/// A rolling fireball.
class Plume {
  final Rng r;
  final double x, y, rise, tauVal, drift, grow, swell, spin, spinTau, heat, cool, under, tilt, squash, glow, spread;
  final (double, double) tube, ring, size, fade;
  final int n, style;
  final bool inner, hollow;
  final (double, double, double?)? fray;

  late final List<_PlumeLobeSpec> _lobes;
  double t = 0.0;
  double roll = 0.0;
  void Function(double x, double y, double r, double ux, double uy)? onFray;

  Plume(
    this.r, {
    this.x = 0.0,
    this.y = -20.0,
    this.rise = 100.0,
    this.tauVal = 1.2,
    this.drift = 4.0,
    this.tube = (8.0, 20.0),
    this.ring = (1.0, 18.0),
    this.grow = 0.9,
    this.n = 40,
    this.size = (5.0, 10.0),
    this.swell = 0.5,
    this.spin = 2.4,
    this.spinTau = 1.6,
    this.heat = 1.15,
    this.cool = 0.45,
    this.under = 0.5,
    this.tilt = 0.2,
    this.squash = 0.7,
    this.fade = (4.0, 6.0),
    this.glow = 1.0,
    this.spread = 10.0,
    this.style = 0,
    this.inner = false,
    this.hollow = false,
    this.fray,
  }) {
    _lobes = List.generate(n, (i) {
      return _PlumeLobeSpec(
        th: tau * ((i * 0.618034 + r.range(-0.08, 0.08)) % 1.0),
        ph: (tau * (i + r.range(-0.35, 0.35))) / n,
        j: r.range(-0.55, 0.12),
        s: r.range(size.$1, size.$2),
        h: r.range(-0.22, 0.08),
        dx: r.range(-1.0, 1.0),
        dy: r.range(-1.0, 0.4),
        f: r.range(-0.9, 0.5),
        gv: r.range(0.55, 1.15),
      );
    }, growable: false);
  }

  ({double x, double y, double tube, double ring, double g}) shape([double? atT]) {
    final u = math.max(0.0, atT ?? t);
    final g = 1.0 - math.exp(-u / grow);
    return (
      x: x,
      y: y - rise * (1.0 - math.exp(-u / tauVal)) - drift * u,
      tube: tube.$1 + (tube.$2 - tube.$1) * g,
      ring: ring.$1 + (ring.$2 - ring.$1) * g,
      g: g,
    );
  }

  double hot([double? atT]) => clamp(heat - cool * (atT ?? t) + 0.3);

  double ember([double? atT]) => clamp((heat - cool * (atT ?? t) + 1.0) / 1.1);

  List<_PlumeLobeAt> _lobesAt(double atT) {
    final s = shape(atT);
    final base = heat - cool * atT;
    final rawSpan = s.ring + s.tube;
    final span = rawSpan == 0.0 ? 1.0 : rawSpan;
    final list = <_PlumeLobeAt>[];
    for (final q in _lobes) {
      final fadeVal =
          1.0 - smooth(fade.$1 + q.f, fade.$2 + q.f * 0.5, atT);
      if (fadeVal <= 0.0) continue;
      final loose =
          math.pow(smooth(fade.$1 - 1.8 + q.f, fade.$2, atT), 1.5).toDouble() *
              spread;
      final th = q.th - roll;
      final rt = s.tube * (1.0 + q.j);
      final rho = s.ring + rt * math.cos(th);
      final up = math.sin(th);
      final xPos = rho * math.cos(q.ph);
      final zPos = rho * math.sin(q.ph);
      final lobeHeat = base +
          q.h -
          0.18 * math.max(0.0, math.cos(th)) * clamp(atT * 2.0) +
          under * math.max(0.0, -up) * clamp(base + 0.6);
      final rad = q.s *
          (0.5 + 0.5 * s.g) *
          (1.0 + swell * clamp(1.0 - lobeHeat)) *
          (1.0 + 0.35 * (1.0 - fadeVal));
      list.add(_PlumeLobeAt(
        x: s.x + xPos + q.dx * loose,
        y: s.y - rt * up * squash + zPos * tilt + q.dy * loose,
        z: zPos / span,
        up: up,
        out: math.cos(th),
        heat: lobeHeat,
        q: q,
        fade: fadeVal,
        r: rad,
        d: hypot(xPos, zPos) / span,
        c: 1.0 - math.min(1.0, xPos.abs() / span),
      ));
    }
    list.sort((a, b) => a.z.compareTo(b.z));
    return list;
  }

  void update(double dt) {
    t += dt;
    roll += spin * (0.12 + 0.88 * math.exp(-t / spinTau)) * dt;
    final fr = fray;
    if (fr != null && onFray != null && t > fr.$1 && t < (fr.$3 ?? double.infinity)) {
      final s = shape();
      final k = fr.$2 * dt * smooth(fr.$1, fr.$1 + 1.0, t);
      for (final e in _lobesAt(t)) {
        if (e.out < 0.2 || !r.chance(k * e.fade)) continue;
        final ux = e.x - s.x;
        final uy = e.y - s.y;
        final rawL = hypot(ux, uy);
        final l = rawL == 0.0 ? 1.0 : rawL;
        onFray!(e.x + (ux / l) * e.r * 0.6, e.y + (uy / l) * e.r * 0.6, e.r,
            ux / l, uy / l);
      }
    }
  }

  void draw(Painter p, List<int> fr, List<int> sm, {void Function()? mid}) {
    if (t >= fade.$2 + 0.5) return;
    final s = shape(t);
    final base = heat - cool * t;
    final rawSpan = s.ring + s.tube;
    final span = rawSpan == 0.0 ? 1.0 : rawSpan;
    final list = _lobesAt(t);
    final age = clamp(t / fade.$2);
    final eVal = ember(t);
    final reach = 0.3 + 1.15 * eVal;
    var drawn = false;
    for (final e in list) {
      if (!drawn && e.z >= 0.0 && mid != null) {
        drawn = true;
        mid();
      }
      final h = e.heat;
      final fadeVal = e.fade;
      final fire = clamp((h - 0.2) / 0.75);
      final glowVal = inner
          ? eVal *
              clamp((reach - e.d) / 0.45) *
              (0.45 + 0.55 * math.max(0.0, -e.up)) *
              e.q.gv *
              glow
          : clamp((base + 0.45) / 0.85) *
              glow *
              (0.4 + 0.35 * math.max(0.0, -e.up) + 0.4 * e.c) *
              e.q.gv;
      lobe(
        p,
        e.x,
        e.y,
        e.r,
        fr,
        sm,
        fire,
        glowVal,
        fadeVal * (0.82 + 0.18 * fire),
        e.z,
        (age > 0.72 ? 1 : 0) + (hollow && e.up < -0.35 ? 1 : 0),
        style,
      );
      if (fire > 0.25) p.glow(e.x, e.y, e.r * 1.25 + 2.0, fr[2], 0.07 * fire);
    }
    if (!drawn && mid != null) mid();
    final h = hot(t);
    if (h > 0.0) p.glow(s.x, s.y, span * 1.8 + 14.0, fr[3], 0.32 * h * glow);
    if (inner && eVal > 0.05) {
      p.glow(s.x, s.y + s.tube * 0.3, span * (0.5 + 0.7 * eVal) + 8.0, fr[4],
          0.22 * eVal * eVal);
    }
  }
}

class _ColumnLobe {
  double y;
  final double x, s, ph, v;
  double a;
  _ColumnLobe({
    required this.y,
    required this.x,
    required this.s,
    required this.ph,
    required this.a,
    required this.v,
  });
}

/// A rising column of lobes boiling up a stem from the floor.
class PlumeColumn {
  final Rng r;
  final double w, foot, speed, sway, fade;
  final (double, double) size;
  final int n, style;

  double t = 0.0;
  final List<_ColumnLobe> _lobes = [];
  double acc = 0.0;

  PlumeColumn(
    this.r, {
    this.w = 7.0,
    this.foot = 16.0,
    this.speed = 70.0,
    this.size = (5.0, 8.0),
    this.n = 18,
    this.sway = 2.5,
    this.fade = 0.5,
    this.style = 0,
  });

  void spawn(double y) {
    _lobes.add(_ColumnLobe(
      y: y,
      x: r.range(-1.0, 1.0),
      s: r.range(size.$1, size.$2),
      ph: r.range(0.0, tau),
      a: 0.0,
      v: r.range(0.8, 1.2),
    ));
  }

  void update(double dt, double top, double feed) {
    final l = math.max(10.0, -top);
    t += dt;
    if (feed > 0.0) {
      for (acc += dt * feed * n * (speed / l); acc > 1.0; acc -= 1.0) {
        spawn(-1.0);
      }
    }
    for (var i = _lobes.length - 1; i >= 0; i--) {
      final b = _lobes[i];
      final u = clamp(-b.y / l);
      b.y -= speed * b.v * (0.45 + 0.55 * math.min(1.0, -b.y / 24.0)) * dt;
      b.a = math.min(1.0, b.a + dt * 4.0);
      if (b.y < top || (feed <= 0.0 && (b.a -= dt * (2.0 - u)) <= 0.0)) {
        _lobes.removeAt(i);
      }
    }
  }

  void draw(Painter p, double top, List<int> fr, List<int> sm, double fire,
      double glow) {
    final l = math.max(10.0, -top);
    final list = List<_ColumnLobe>.of(_lobes)..sort((a, b) => a.y.compareTo(b.y));
    for (final b in list) {
      final u = clamp(-b.y / l);
      final footVal = math.pow(1.0 - u, 4.0).toDouble();
      final width = w + foot * footVal;
      final x = b.x * width * 0.45 +
          math.sin(t * 1.7 + b.ph + u * 3.0) * sway * u;
      final rad = b.s *
          (0.75 + 0.5 * footVal + 0.35 * u) *
          math.min(1.0, b.a * 1.5);
      final end = 1.0 - smooth(0.85, 1.0, u);
      lobe(
        p,
        x,
        b.y - rad * 0.3 * footVal,
        rad,
        fr,
        sm,
        clamp(fire * (1.1 - u * 0.9)),
        glow * smooth(0.55, 1.0, u),
        math.min(1.0, b.a) * end * 0.9,
        0.0,
        u > 0.5 ? 0 : 1,
        style,
      );
    }
  }
}
