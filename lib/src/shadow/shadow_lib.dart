import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pixelfx_core/pixelfx_core.dart';

/// Dark magic, dark to bright: void black, deep violet, a white-lilac edge.
const List<String> kVoidPalette = [
  '#06040b',
  '#150c26',
  '#2a1150',
  '#461a84',
  '#6f2cc0',
  '#9d5cec',
  '#cfa6ff',
  '#f6eaff',
];

/// Take the light back off every pixel in a local box where [dark] is true,
/// keeping a share [keep] (0..1): call it last, so black shapes stay black
/// under every glow, spark and ring drawn before.
void unlight(
  Painter p,
  num x0,
  num y0,
  num x1,
  num y1,
  bool Function(double x, double y) dark, [
  double keep = 0,
]) {
  final lBuf = p.frame.light;
  final w = p.w;
  final ox = p.ox;
  final oy = p.oy;
  p.each(x0.toDouble(), y0.toDouble(), x1.toDouble(), y1.toDouble(), (x, y, sx, sy) {
    if (!dark(x, y)) return;
    final i = (sy - oy) * w + (sx - ox);
    final d = lBuf[i];
    if (d == 0) return;
    if (keep <= 0) {
      lBuf[i] = 0;
    } else {
      final r = (((d >> 16) & 255) * keep).toInt();
      final g = (((d >> 8) & 255) * keep).toInt();
      final b = ((d & 255) * keep).toInt();
      lBuf[i] = (255 << 24) | (r << 16) | (g << 8) | b;
    }
  });
}

void _annulus(
  double x,
  double y,
  double r0,
  double r1,
  void Function(double cx, double cy, double d) fn,
) {
  final r02 = r0 > 0 ? r0 * r0 : -1.0;
  final r12 = r1 * r1;
  final yEnd = (y + r1).ceil();
  for (int py = (y - r1).floor(); py <= yEnd; py++) {
    final cy = py + 0.5;
    final dy = cy - y;
    final dy2 = dy * dy;
    if (dy2 >= r12) continue;
    final xo = math.sqrt(r12 - dy2);
    final xi = dy2 < r02 ? math.sqrt(r02 - dy2) : 0.0;
    final x1 = (x + xo).ceil();
    for (int px = (x - xo).floor(); px <= x1; px++) {
      final cx = px + 0.5;
      final dx = cx - x;
      if (xi > 0 && dx > -xi && dx < xi) {
        px = math.max(px, (x + xi).floor() - 1);
        continue;
      }
      final d2 = dx * dx + dy2;
      if (d2 < r12 && d2 >= r02) {
        fn(cx, cy, math.sqrt(d2));
      }
    }
  }
}

/// A ring from radius `r - w` out to `r` round `(x, y)`, visiting only the
/// band's own pixels so a big thin shock ring stays cheap.
void ringFast(
  Painter p,
  num x,
  num y,
  num r,
  num w,
  int c, [
  double a = 1.0,
]) {
  final rd = r.toDouble();
  if (rd <= 0) return;
  final r0 = math.max(0.0, rd - w.toDouble());
  final xd = x.toDouble();
  final yd = y.toDouble();
  _annulus(xd, yd, r0, rd, (cx, cy, d) {
    p.dot(cx, cy, c, a);
  });
}

/// Variant of [ringFast] accepting dynamic color and/or alpha callbacks `(v, ang)`.
void ringFastFn(
  Painter p,
  num x,
  num y,
  num r,
  num w,
  int Function(double v, double ang) cFn, [
  double a = 1.0,
  double Function(double v, double ang)? aFn,
]) {
  final rd = r.toDouble();
  if (rd <= 0) return;
  final r0 = math.max(0.0, rd - w.toDouble());
  final span = rd - r0;
  final denom = span != 0 ? span : 1.0;
  final xd = x.toDouble();
  final yd = y.toDouble();
  _annulus(xd, yd, r0, rd, (cx, cy, d) {
    final v = (d - r0) / denom;
    final ang = math.atan2(cy - yd, cx - xd);
    p.dot(cx, cy, cFn(v, ang), aFn != null ? aFn(v, ang) : a);
  });
}

/// Light hugging a circle of radius [R] at `(x, y)`, falling off over [w]
/// either side, only where [keep] returns true.
void ringLight(
  Painter p,
  num x,
  num y,
  num R,
  num w,
  int col,
  num k, [
  bool Function(double x, double y)? keep,
]) {
  final wd = w.toDouble();
  final kd = k.toDouble();
  if (wd < 1 || kd <= 0.004) return;
  final rd = R.toDouble();
  _annulus(x.toDouble(), y.toDouble(), math.max(0.0, rd - wd), rd + wd, (cx, cy, d) {
    if (keep != null && !keep(cx, cy)) return;
    final f = 1 - (d - rd).abs() / wd;
    p.light(cx, cy, col, f * f * kd);
  });
}

/// A ring of light hugging a black disc: [k] at radius [r0], falling to
/// nothing at [r1], and none inside [r0].
void halo(
  Painter p,
  num x,
  num y,
  num r0,
  num r1,
  int col,
  num k,
) {
  final r0d = r0.toDouble();
  final r1d = r1.toDouble();
  final kd = k.toDouble();
  if (r1d <= r0d || kd <= 0.004) return;
  final w = r1d - r0d;
  _annulus(x.toDouble(), y.toDouble(), math.max(0.0, r0d), r1d, (cx, cy, d) {
    final f = 1 - (d - r0d) / w;
    p.light(cx, cy, col, f * f * kd);
  });
}

/// Is `(x, y)` inside a four-point star at `(cx, cy)`, arms [L] long, turned [rot]?
/// [q] < 1 hollows the sides into thin spikes.
bool inStar(
  double x,
  double y,
  double cx,
  double cy,
  double L,
  double rot, [
  double q = 0.42,
]) {
  if (L <= 0) return false;
  final c = math.cos(rot);
  final s = math.sin(rot);
  final dx = x - cx;
  final dy = y - cy;
  final u = (dx * c + dy * s).abs() / L;
  final v = (-dx * s + dy * c).abs() / L;
  return u < 1 &&
      v < 1 &&
      math.min(u, v) <= math.pow(0.5, 1 / q) &&
      math.pow(u, q) + math.pow(v, q) <= 1;
}

/// A black star rasterized once: four long arms and four short ones.
class BlackStar {
  BlackStar(this.cy, double L, double rot, [double short = 0.46, double q = 0.32])
      : r0 = L.ceil() + 2,
        n = (L.ceil() + 2) * 2 + 1,
        _data = Uint8List(((L.ceil() + 2) * 2 + 1) * ((L.ceil() + 2) * 2 + 1)) {
    for (int j = 0; j < n; j++) {
      for (int i = 0; i < n; i++) {
        final x = i - r0 + 0.5;
        final y = cy + j - r0 + 0.5;
        if (inStar(x, y, 0, cy, L, rot, q) ||
            inStar(x, y, 0, cy, L * short, rot + math.pi / 4, q)) {
          _data[j * n + i] = 1;
        }
      }
    }
    for (int a = 0; a < 4; a++) {
      final ca = math.cos(rot + (a * math.pi) / 2);
      final sa = math.sin(rot + (a * math.pi) / 2);
      for (double d = 0; d < L - 1; d += 0.5) {
        final i = (ca * d).floor() + r0;
        final j = (sa * d).floor() + r0;
        if (i >= 0 && j >= 0 && i < n && j < n) {
          _data[j * n + i] = 1;
        }
      }
    }
  }

  final double cy;
  final int r0;
  final int n;
  final Uint8List _data;

  bool at(double x, double y) {
    final i = x.floor() + r0;
    final j = (y - cy).floor() + r0;
    return i >= 0 && j >= 0 && i < n && j < n && _data[j * n + i] == 1;
  }

  void unlight(Painter p) {
    final lb = p.frame.light;
    final w = p.w;
    final h = p.h;
    final ox = p.ox;
    final oy = p.oy;
    for (int j = 0; j < n; j++) {
      for (int i = 0; i < n; i++) {
        if (_data[j * n + i] == 0) continue;
        final x = i - r0 + 0.5;
        final y = cy + j - r0 + 0.5;
        final sx = p.cellX(x, y) - ox;
        final sy = p.cellY(x, y) - oy;
        if (sx >= 0 && sy >= 0 && sx < w && sy < h) {
          lb[sy * w + sx] = 0;
        }
      }
    }
  }

  void draw(
    Painter p,
    int c, [
    int? rim,
    bool Function(double x, double y)? skip,
  ]) {
    for (int j = 0; j < n; j++) {
      for (int i = 0; i < n; i++) {
        final x = i - r0 + 0.5;
        final y = cy + j - r0 + 0.5;
        if (_data[j * n + i] != 0) {
          p.px(x, y, c);
        } else if (rim != null &&
            (skip == null || !skip(x, y)) &&
            (at(x - 1, y) || at(x + 1, y) || at(x, y - 1) || at(x, y + 1))) {
          p.px(x, y, rim);
        }
      }
    }
  }
}

/// Pull [SimParticle]s toward `(x, y)` with softened gravity, swirl and drag.
int attractParticles(
  List<SimParticle> list,
  double x,
  double y,
  double G,
  double reach,
  double swirl,
  double r0,
  double dt, [
  double Function(SimParticle q)? w,
  double vmax = double.infinity,
]) {
  int eaten = 0;
  for (int i = list.length - 1; i >= 0; i--) {
    final q = list[i];
    final wt = w != null ? w(q) : 1.0;
    if (wt == 0 || q.delay > 0) continue;
    final dx = x - q.x;
    final dy = y - q.y;
    final d2 = dx * dx + dy * dy;
    if (d2 > reach * reach) continue;
    final d = d2 > 0 ? math.sqrt(d2) : 1.0;
    if (d < r0) {
      list.removeAt(i);
      eaten++;
      continue;
    }
    final a =
        (G / (d2 + r0 * r0)) * math.min(1.0, (reach - d) / (reach * 0.25)) * wt * dt;
    final ux = dx / d;
    final uy = dy / d;
    q.vx += (ux - uy * swirl) * a;
    q.vy += (uy + ux * swirl) * a;
    final drag = math.min(0.2, (1 - d / reach) * 1.6 * dt);
    q.vx -= q.vx * drag;
    q.vy -= q.vy * drag;
    final v = hypot(q.vx, q.vy);
    if (v > vmax) {
      q.vx *= vmax / v;
      q.vy *= vmax / v;
    }
  }
  return eaten;
}

/// Pull [Puff]s toward `(x, y)` with softened gravity, swirl and drag.
int attractPuffs(
  List<Puff> list,
  double x,
  double y,
  double G,
  double reach,
  double swirl,
  double r0,
  double dt, [
  double Function(Puff q)? w,
  double vmax = double.infinity,
]) {
  int eaten = 0;
  for (int i = list.length - 1; i >= 0; i--) {
    final q = list[i];
    final wt = w != null ? w(q) : 1.0;
    if (wt == 0 || q.delay > 0) continue;
    final dx = x - q.x;
    final dy = y - q.y;
    final d2 = dx * dx + dy * dy;
    if (d2 > reach * reach) continue;
    final d = d2 > 0 ? math.sqrt(d2) : 1.0;
    if (d < r0) {
      list.removeAt(i);
      eaten++;
      continue;
    }
    final a =
        (G / (d2 + r0 * r0)) * math.min(1.0, (reach - d) / (reach * 0.25)) * wt * dt;
    final ux = dx / d;
    final uy = dy / d;
    q.vx += (ux - uy * swirl) * a;
    q.vy += (uy + ux * swirl) * a;
    final drag = math.min(0.2, (1 - d / reach) * 1.6 * dt);
    q.vx -= q.vx * drag;
    q.vy -= q.vy * drag;
    final v = hypot(q.vx, q.vy);
    if (v > vmax) {
      q.vx *= vmax / v;
      q.vy *= vmax / v;
    }
  }
  return eaten;
}

/// Puff kinds: flame (cooling down a ramp) or soot (dark smoke lit on one side).
enum PuffKind { flame, soot }

class Puff {
  Puff({
    required this.k,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.max,
    required this.size,
    required this.delay,
    required this.smokes,
    required this.seed,
  });

  final PuffKind k;
  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double max;
  final double size;
  double delay;
  final bool smokes;
  final double seed;
}

class PuffLight {
  const PuffLight({
    required this.x,
    required this.y,
    required this.k,
    required this.reach,
  });

  final double x;
  final double y;
  final double k;
  final double reach;
}

/// Violet flame and dark smoke puffs.
class Puffs {
  Puffs({
    required Rng rng,
    required List<Object> flame,
    required List<Object> soot,
    required Object cap,
    required List<Object> rim,
    this.floor,
  })  : R = rng,
        F = ramp(flame),
        soot = ramp(soot),
        cap = hex(cap),
        rim = ramp(rim);

  final Rng R;
  final List<Puff> list = [];
  double t = 0;
  final List<int> F;
  final List<int> soot;
  final int cap;
  final List<int> rim;
  final double Function(double x)? floor;

  void spawn(
    PuffKind k,
    double x,
    double y,
    double vx,
    double vy,
    double life,
    double size, [
    double delay = 0,
    bool smokes = false,
  ]) {
    list.add(Puff(
      k: k,
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      life: life,
      max: life,
      size: size,
      delay: delay,
      smokes: smokes,
      seed: R.next() * 100,
    ));
  }

  int get count => list.length;

  void update(double dt) {
    t += dt;
    for (int i = list.length - 1; i >= 0; i--) {
      final q = list[i];
      if (q.delay > 0) {
        q.delay -= dt;
        continue;
      }
      if ((q.life -= dt) <= 0) {
        if (q.k == PuffKind.flame && q.smokes) {
          spawn(
            PuffKind.soot,
            q.x,
            q.y - 1,
            q.vx * 0.5,
            q.vy * 0.5 - 6,
            R.range(0.9, 1.6),
            q.size * 1.25,
          );
        }
        list.removeAt(i);
        continue;
      }
      if (q.k == PuffKind.flame) {
        q.vy -= 95 * dt;
        q.vx += math.sin(t * 17 + q.seed) * 30 * dt;
        q.vx -= q.vx * 5 * dt;
        q.vy -= q.vy * 3.2 * dt;
      } else {
        q.vy -= 18 * dt;
        q.vx += math.sin(t * 1.3 + q.seed) * 8 * dt;
        q.vx -= q.vx * 1.6 * dt;
        q.vy -= q.vy * 1.3 * dt;
      }
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      if (floor != null && q.k == PuffKind.soot) {
        final f = floor!(q.x) - q.size * 0.6;
        if (q.y > f) {
          q.y = f;
          q.vy = math.min(0.0, q.vy);
          q.vx *= 1 - 2 * dt;
        }
      }
    }
  }

  void draw(Painter p, PuffKind kind, [PuffLight? light]) {
    final n = F.length;
    for (final q in list) {
      if (q.delay > 0 || q.k != kind) continue;
      final k = q.life / q.max;
      final age = 1 - k;
      final x = q.x;
      final y = q.y;
      if (q.k == PuffKind.flame) {
        final heat = math.min(
          0.999,
          math.pow(age, 0.62) + q.seed.remainder(1.0) * 0.1,
        );
        final idx = math.min(n - 2, (heat * (n - 1)).floor());
        final r = q.size * (0.55 + 0.45 * math.min(1.0, age * 7)) * (1 - age * 0.55);
        final c = F[idx];
        if (idx >= n - 3) {
          p.disc(x, y, r, c, math.min(1.0, k * 3) * 0.8);
        } else {
          p.circle(x, y, r, F[math.min(n - 1, idx + 2)]);
          p.circle(x - r * 0.16, y - r * 0.22, r * 0.78, c);
          if (r > 1.6) p.circle(x, y - r * 0.9, r * 0.42, c);
          if (idx <= 3 && r > 1.8) {
            p.circle(x - r * 0.28, y - r * 0.34, r * 0.36, F[math.max(0, idx - 1)]);
          }
          if (idx < 6) p.glow(x, y, r * 2.4 + 2, c, 0.2 * k);
        }
        continue;
      }
      final r = q.size * (0.65 + math.min(1.0, age * 2.5) * 0.45 + age * 0.45);
      final a = math.min(1.0, age * 10) * math.min(1.0, k * 2.2) * 0.72;
      final body = mix(soot[0], soot[1], age);
      final edge = a * 0.5;
      final core = 1 - (1 - a * 0.5) * (1 - a * 0.62);
      p.discShaded(
        x,
        y + r * 0.06,
        r,
        color: (_, _) => body,
        alpha: (d, _) => d < 0.72 ? core : edge,
      );
      final lk = light != null ? light.k : 0.0;
      if (lk < 0.5) {
        p.disc(x - r * 0.2, y - r * 0.32, r * 0.48, cap, a * 0.32 * (1 - age * 0.7) * (1 - lk * 2));
      }
      if (lk <= 0.02 || light == null) continue;
      final lx = light.x - x;
      final ly = light.y - y;
      final dlRaw = math.sqrt(lx * lx + ly * ly);
      final dl = dlRaw > 0 ? dlRaw : 1.0;
      final ux = lx / dl;
      final uy = ly / dl;
      final lit = math.min(1.0, light.k * clamp(1.3 - dl / light.reach)) * a;
      if (lit <= 0.02) continue;
      final hot = rim[0];
      final warm = rim[1];
      final dim = rim[2];
      p.disc(x + ux * r * 0.26, y + uy * r * 0.26, r * 0.72, dim, lit * 0.55);
      p.disc(x + ux * r * 0.5, y + uy * r * 0.5, r * 0.46, warm, lit * 0.5);
      if (r > 3) {
        p.disc(x + ux * r * 0.68, y + uy * r * 0.68, r * 0.24, hot, lit * 0.4);
      }
    }
  }
}

/// An obsidian shard from core [DebrisBit].
void shard(
  Painter p,
  DebrisBit b,
  List<int> C,
  double lx,
  double ly,
  double lk,
) {
  final fa = math.min(1.0, b.life / 0.4);
  final ca = math.cos(b.a);
  final sa = math.sin(b.a);
  final L = math.max(2.0, b.s);
  final W = math.max(2.0, L * 0.55);
  final side = -sa * (lx - b.x) + ca * (ly - b.y) > 0 ? 1.0 : -1.0;
  final rim = lk > 0.6
      ? C[6]
      : lk > 0.3
          ? C[5]
          : lk > 0.08
              ? C[4]
              : C[3];
  final E = L / 2 + 1.5;
  p.shade(b.x - E, b.y - E, b.x + E, b.y + E, (x, y, out) {
    final dx = x - b.x;
    final dy = y - b.y;
    final u = dx * ca + dy * sa;
    final v = (-dx * sa + dy * ca) * side;
    if (u < -L / 2 - 0.4 || u > L / 2 + 0.4) return null;
    final half = ((W / 2) * (L / 2 - u)) / L + 0.4;
    if (v.abs() > half) return null;
    out.a = fa;
    if (u > L / 2 - 1.3 && lk > 0.3) return kWhite;
    if (v > half - 1) return u > -L / 4 ? rim : C[math.max(3, C.indexOf(rim) - 1)];
    return v < -half + 1 ? C[1] : C[2];
  });
  if (lk > 0.04) p.glow(b.x, b.y, 3 + L * 0.6, C[5], 0.2 * lk * fa);
}

class _Drop {
  _Drop({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
  });

  double x;
  double y;
  double vx;
  double vy;
  final double size;
}

/// Ink drops: fly under gravity, land on the floor and call [onLand].
class Drops {
  Drops({
    double Function(double x)? floor,
    this.onLand,
    this.g = 0.8,
  }) : floor = floor ?? ((_) => 0.0);

  final List<_Drop> _list = [];
  final double Function(double x) floor;
  final void Function(double x, double y, double speed, double size)? onLand;
  final double g;

  void add(double x, double y, double vx, double vy, [double size = 1]) {
    _list.add(_Drop(x: x, y: y, vx: vx, vy: vy, size: size));
  }

  void update(double dt) {
    for (int i = _list.length - 1; i >= 0; i--) {
      final d = _list[i];
      d.vy += kGravity * g * dt;
      d.vx -= d.vx * 0.4 * dt;
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      final f = floor(d.x);
      if (d.vy > 0 && d.y >= f) {
        onLand?.call(d.x, f, d.vy, d.size);
        _list.removeAt(i);
      }
    }
  }

  void draw(Painter p, int body, int shine) {
    for (final d in _list) {
      final up = d.vy < 0;
      p.px(d.x, d.y, body);
      if (d.size > 1.4) p.px(d.x, d.y + (up ? 1 : -1), body);
      p.px(d.x, d.y - (d.size > 1.4 && !up ? 1 : 0), shine);
    }
  }
}

class PoolRipple {
  PoolRipple({
    required this.x,
    required this.t0,
    required this.life,
    required this.w,
  });

  final double x;
  final double t0;
  final double life;
  final double w;
}

/// A dark pool opened in the floor, seen at a slant.
void floorPool(
  Painter p,
  List<int> C,
  double rx,
  double t,
  List<PoolRipple> ripples,
) {
  if (rx < 1) return;
  final ry = rx * 0.17 + 0.6;
  p.shade(-rx - 3, -ry - 2, rx + 3, ry + 2, (x, y, _) {
    final dx = x / rx;
    final dy = (y - 0.5) / ry;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d > 1.18) return null;
    if (d > 1) {
      if (dy < 0 && d < 1.09) {
        return dx.abs() < 0.55 ? C[6] : dx.abs() < 0.85 ? C[5] : C[4];
      }
      if (dy >= 0 && d < 1.09) return C[2];
      return y > -0.5 && noise(x * 0.7, 9) > 0.15 ? C[1] : null;
    }
    for (final r in ripples) {
      final age = t - r.t0;
      final rr = age * 46 * r.w + 1;
      final ex = x - r.x;
      final ey = (y - 0.5) / 0.17;
      final eRaw = math.sqrt(ex * ex + ey * ey);
      final e = eRaw > 0 ? eRaw : 1.0;
      final g = math.sqrt(ex * ex + math.pow(ey / 0.17, 2)) / e;
      if ((e - rr).abs() < 0.55 * g && age < r.life) {
        return age < r.life * 0.5 ? C[4] : C[3];
      }
    }
    if (dy < -0.55 && dy > -0.85 && noise(x * 0.25 + t * 1.3, 4) > 0.2) {
      return noise(x * 0.6 - t * 2, 6) > 0.55 ? C[5] : C[2];
    }
    if (dy < -0.35 && d > 0.72) return d > 0.9 ? C[3] : C[2];
    return d > 0.86 ? C[1] : C[0];
  });
}
