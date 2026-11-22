import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

/// Is `(x, y)` inside the polygon [pts] `[(x, y), ...]`? (even-odd rule)
bool inPoly(List<(double, double)> pts, double x, double y) {
  var inside = false;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final (xi, yi) = pts[i];
    final (xj, yj) = pts[j];
    if ((yi > y) != (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

/// A polygon's centroid and area.
({double x, double y, double area}) centroid(List<(double, double)> pts) {
  var a = 0.0;
  var cx = 0.0;
  var cy = 0.0;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final (x0, y0) = pts[j];
    final (x1, y1) = pts[i];
    final k = x0 * y1 - x1 * y0;
    a += k;
    cx += (x0 + x1) * k;
    cy += (y0 + y1) * k;
  }
  if (a.abs() < 1e-6) {
    final n = pts.length;
    var sx = 0.0;
    var sy = 0.0;
    for (final (qx, qy) in pts) {
      sx += qx;
      sy += qy;
    }
    return (x: sx / n, y: sy / n, area: 0.0);
  }
  return (x: cx / (3.0 * a), y: cy / (3.0 * a), area: a.abs() / 2.0);
}

/// Cut a polygon along the line through `(x, y)` at angle [a]: the pieces with three corners or more.
List<List<(double, double)>> splitPoly(
  List<(double, double)> pts,
  double x,
  double y,
  double a,
) {
  final nx = -math.sin(a);
  final ny = math.cos(a);
  double side((double, double) q) => (q.$1 - x) * nx + (q.$2 - y) * ny;
  final left = <(double, double)>[];
  final right = <(double, double)>[];
  for (var i = 0; i < pts.length; i++) {
    final p = pts[i];
    final q = pts[(i + 1) % pts.length];
    final sp = side(p);
    final sq = side(q);
    (sp >= 0.0 ? left : right).add(p);
    if ((sp >= 0.0) != (sq >= 0.0)) {
      final u = sp / (sp - sq);
      final m = (p.$1 + (q.$1 - p.$1) * u, p.$2 + (q.$2 - p.$2) * u);
      left.add(m);
      right.add(m);
    }
  }
  return [
    if (left.length >= 3) left,
    if (right.length >= 3) right,
  ];
}

/// A color turned to ice: its brightness picks a step of the ice ramp [c] (dark to bright), never the darkest.
int iceOf(int col, List<int> c) {
  final n = c.length;
  final l = luma(col);
  final idx =
      ((((l < 0.12 ? 2.0 : 2.0 + l * 5.2) * (n - 1)) / 7.0) + 0.5).floor();
  return c[clampInt(idx, 1, n - 1)];
}

/// Fill a polygon with translucent color (true blending, no dither): glass, ice, light.
void glassPoly(Painter p, List<(double, double)> pts, int c, double a) {
  var x0 = double.infinity;
  var y0 = double.infinity;
  var x1 = double.negativeInfinity;
  var y1 = double.negativeInfinity;
  for (final (x, y) in pts) {
    if (x < x0) x0 = x;
    if (x > x1) x1 = x;
    if (y < y0) y0 = y;
    if (y > y1) y1 = y;
  }
  for (var y = y0.floor(); y <= y1.ceil(); y++) {
    for (var x = x0.floor(); x <= x1.ceil(); x++) {
      if (inPoly(pts, x + 0.5, y + 0.5)) p.blend(x, y, c, a);
    }
  }
}

/// A flat pane of ice managed by [Panes].
class IcePane {
  final List<(double, double)> pts;
  double x;
  double y;
  double vx;
  double vy;
  double a;
  double va;
  double f;
  double vf;
  final double lit;
  final double g;
  final double drag;
  final double bounce;
  double life;
  final double max;
  bool rest = false;
  double restT = 0.0;
  int hits = 0;

  /// Number of hard landings before breaking (`0` means not brittle).
  final int brittle;
  final double? crumble;
  final bool solid;
  final double? tone;
  final double? ridge;

  IcePane({
    required this.pts,
    required this.x,
    required this.y,
    this.vx = 0.0,
    this.vy = 0.0,
    this.a = 0.0,
    this.va = 0.0,
    this.f = 0.0,
    this.vf = 0.0,
    this.lit = 0.6,
    this.g = 1.0,
    this.drag = 0.3,
    this.bounce = 0.35,
    this.life = 1.0,
    this.brittle = 0,
    this.crumble,
    this.solid = false,
    this.tone,
    this.ridge,
  }) : max = life;
}

/// Panes of ice: flat polygons that fly, spin and tumble end over end, bounce on the floor, skid, settle and fade.
class Panes {
  final List<IcePane> list = [];
  final double Function(double x) ground;
  final void Function(IcePane q, double x, double y, double speed)? onLand;
  final void Function(IcePane q)? onCrumble;
  final void Function(IcePane q, double x, double y)? onSkid;

  Panes({
    double Function(double x)? ground,
    this.onLand,
    this.onCrumble,
    this.onSkid,
  }) : ground = ground ?? ((_) => double.infinity);

  void add(IcePane q) => list.add(q);

  int get count => list.length;

  /// The pane's corners as drawn: tumbled (squashed across its own width), turned and placed.
  List<(double, double)> corners(IcePane q) {
    final ca = math.cos(q.a);
    final sa = math.sin(q.a);
    final k = math.cos(q.f);
    return [
      for (final (x, y) in q.pts)
        (
          q.x + x * ca - (y * k) * sa,
          q.y + x * sa + (y * k) * ca,
        ),
    ];
  }

  double seat(IcePane q) {
    var low = double.negativeInfinity;
    for (final c in corners(q)) {
      if (c.$2 > low) low = c.$2;
    }
    return low;
  }

  void update(double dt) {
    for (var i = list.length - 1; i >= 0; i--) {
      final q = list[i];
      if ((q.life -= dt) <= 0.0) {
        list.removeAt(i);
        continue;
      }
      final floor = ground(q.x) - 0.5;
      if (q.rest && q.crumble != null && (q.restT += dt) > q.crumble!) {
        onCrumble?.call(q);
        list.removeAt(i);
        continue;
      }
      if (q.rest) {
        if (q.vx.abs() > 8.0) onSkid?.call(q, q.x, floor + 0.5);
        q.x += q.vx * dt;
        q.vx -= q.vx * 7.0 * dt;
        q.a += q.va * dt;
        q.va -= q.va * 9.0 * dt;
        q.vf -= q.vf * 9.0 * dt;
        q.f += q.vf * dt;
        q.y -= seat(q) - floor;
        continue;
      }
      q.vy += kGravity * q.g * dt;
      q.vx -= q.vx * q.drag * dt;
      q.vy -= q.vy * q.drag * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      q.a += q.va * dt;
      q.f += q.vf * dt;
      final low = seat(q);
      if (q.g <= 0.0 || low < floor || q.vy <= 0.0) continue;
      q.y -= low - floor;
      if (q.vy > 70.0) {
        q.hits += 1;
        onLand?.call(q, q.x, floor + 0.5, q.vy);
      }
      if (q.brittle > 0 && q.vy > 70.0 && q.hits >= q.brittle) {
        list.removeAt(i);
        continue;
      }
      if (q.vy > 70.0 && q.bounce > 0.0) {
        q.vy = -q.vy * q.bounce;
        q.vx *= 0.75;
        q.va *= 0.6;
        q.vf *= 0.5;
      } else {
        q.rest = true;
        q.vy = 0.0;
      }
    }
  }

  void draw(Painter p, List<int> c) {
    final n = c.length;
    for (final q in list) {
      final a = math.min(1.0, q.life / 0.35);
      final pts = corners(q);
      final k = math.cos(q.f);
      final face = k.abs();
      final lv = q.lit * (0.35 + 0.65 * face);
      final flash = face > 0.97 && !q.rest;
      if (face > 0.25) {
        if (q.solid && q.tone != null) {
          final idx = clampInt(
            (1.0 + q.tone! * 5.0 * (0.6 + 0.4 * face) + 0.5).floor(),
            1,
            n - 2,
          );
          p.poly(pts, flash ? c[n - 1] : c[idx], a);
        } else if (q.solid) {
          final rr = q.ridge ?? -math.pi / 2.0;
          final cr = math.cos(rr);
          final sr = math.sin(rr);
          final ca = math.cos(q.a);
          final sa = math.sin(q.a);
          final rx = cr * ca - sr * k * sa;
          final ry = cr * sa + sr * k * ca;
          var nx = -ry;
          var ny = rx;
          if (nx * -0.55 + ny * -0.84 < 0.0) {
            nx = -nx;
            ny = -ny;
          }
          final lit = flash
              ? c[n - 1]
              : c[clampInt((3.0 + lv * 3.0 + 0.5).floor(), 3, n - 2)];
          final deep = c[clampInt((1.0 + lv * 2.0 + 0.5).floor(), 1, 3)];
          p.polyShaded(
            pts,
            color: (x, y) {
              final d = (x - q.x) * nx + (y - q.y) * ny;
              return d > 0.6 ? lit : (d > -0.6 ? c[n - 2] : deep);
            },
            alpha: (_, _) => a,
          );
        } else {
          final col = flash
              ? c[n - 1]
              : c[clampInt((3.0 + lv * 3.0 + 0.5).floor(), 3, n - 2)];
          glassPoly(p, pts, col, (0.3 + 0.35 * lv + (flash ? 0.3 : 0.0)) * a);
        }
      }
      var cx = 0.0;
      var cy = 0.0;
      var top = 0;
      for (final (px, py) in pts) {
        cx += px;
        cy += py;
      }
      cx /= pts.length;
      cy /= pts.length;
      for (var i = 0; i < pts.length; i++) {
        final (x0, y0) = pts[i];
        final (x1, y1) = pts[(i + 1) % pts.length];
        var nx = y1 - y0;
        var ny = x0 - x1;
        if (nx * ((x0 + x1) / 2.0 - cx) + ny * ((y0 + y1) / 2.0 - cy) < 0.0) {
          nx = -nx;
          ny = -ny;
        }
        final l = hypot(nx, ny);
        final denom = l == 0.0 ? 1.0 : l;
        final lit = (-nx * 0.55 - ny * 0.84) / denom;
        final edgeCol = face < 0.25 || lit > 0.35
            ? c[n - 1]
            : (lit > -0.25
                ? c[n - 2]
                : (q.solid ? c[1] : c[math.max(2, n - 4)]));
        p.line(x0, y0, x1, y1, edgeCol, a);
        if (pts[i].$2 < pts[top].$2) top = i;
      }
      if (face > 0.7) p.dot(pts[top].$1, pts[top].$2, kWhite, a);
      p.glow(cx, cy, 5, c[n - 3], (flash ? 0.5 : 0.14) * a);
    }
  }
}

/// A jagged ice blade standing on its base `(bx, by)`, tip at `(tx, ty)`, [w] wide at the base.
void blade(
  Painter p,
  double bx,
  double by,
  double tx,
  double ty,
  double w,
  List<int> c, {
  double a = 1.0,
  bool white = false,
  double glint = -1.0,
  double jag = -1.0,
  int dim = 0,
}) {
  final dx = tx - bx;
  final dy = ty - by;
  final len = hypot(dx, dy);
  if (len < 1.5 || w < 0.5) return;
  final ux = dx / len;
  final uy = dy / len;
  final nx = -uy;
  final ny = ux;
  int kCol(int i) => c[clampInt(i - dim, 0, c.length - 1)];
  final hw = w / 2.0;
  double left(double u) => hw * (1.0 - u) + 0.35;
  double right(double u) =>
      hw * (1.0 - u) * (jag >= 0.0 && u > jag ? 0.55 : 1.0) + 0.35;
  double ridge(double u) => -w * 0.12 * (1.0 - u);
  final pad = hw + 2.0;
  p.shade(
    math.min(bx, tx) - pad,
    math.min(by, ty) - pad,
    math.max(bx, tx) + pad,
    math.max(by, ty),
    (x, y, o) {
      final rx = x - bx;
      final ry = y - by;
      final u = (rx * ux + ry * uy) / len;
      final s = rx * nx + ry * ny;
      if (u < 0.0) return null;
      final cu = math.min(u, 1.0);
      final l = left(cu);
      final r = right(cu);
      if (u > 1.0 || s < -l || s > r) {
        final over = u > 1.0 ? (u - 1.0) * len : 0.0;
        final out = math.max(over, s < -l ? -l - s : s - r);
        if (out < 1.0 && u < 1.0 + 1.0 / len) {
          o.c = kCol(0);
          o.a = a;
        }
        return null;
      }
      o.a = a;
      if (white) return o.c = kWhite;
      final rd = ridge(u);
      int col;
      if (u > 0.88) {
        col = kWhite;
      } else if ((s - rd).abs() < 0.55) {
        col = kCol(6);
      } else if (s < rd) {
        col = s + l < 1.0
            ? kCol(6)
            : ((s + l) / math.max(1.0, rd + l) > 0.55 ? kCol(5) : kCol(4));
      } else {
        col = r - s < 1.1
            ? kCol(1)
            : ((s - rd) / math.max(1.0, r - rd) > 0.5 ? kCol(2) : kCol(3));
      }
      if (jag >= 0.0 && (u - jag).abs() * len < 0.8 && s > rd) {
        col = kCol(6);
      } else if (s < rd && col != kCol(6)) {
        final h = ((x.floor() * 73856093).toSigned(32) ^
                (y.floor() * 19349663).toSigned(32))
            .toSigned(32)
            .remainder(997);
        if (h < 30) col = kCol(7);
      }
      if (glint >= 0.0 && s <= rd + 0.6) {
        final g = (u - glint).abs() * len;
        if (g < 0.8) {
          col = kWhite;
        } else if (g < 1.8) {
          col = kCol(6);
        }
      }
      o.c = col;
      return null;
    },
  );
}

/// Seeded snowflake design used by [snowflake].
class FlakeDesign {
  final List<(double u, double l)> branches;
  final bool plate;
  final bool fork;

  const FlakeDesign({
    required this.branches,
    required this.plate,
    required this.fork,
  });
}

/// A snowflake design, seeded: pairs of side branches along each arm, optional hexagonal plate and forked tips.
FlakeDesign flakeDesign(Rng r) {
  final n = r.intRange(1, 3);
  final branches = <(double, double)>[];
  for (var i = 0; i < n; i++) {
    branches.add((
      0.38 + (0.4 * (i + r.range(0.2, 0.8))) / n,
      r.range(0.24, 0.36) * (1.0 - i * 0.15),
    ));
  }
  return FlakeDesign(
    branches: branches,
    plate: r.chance(0.45),
    fork: r.chance(0.45),
  );
}

/// A six-armed snowflake of radius [r] turned by [rot], crisp 1 px lines.
void snowflake(
  Painter p,
  double x,
  double y,
  double r,
  double rot,
  FlakeDesign d,
  List<int> c, {
  double a = 1.0,
  double hot = 0.0,
}) {
  final n = c.length;
  const step = math.pi / 18.0;
  rot = (rot / step + 0.5).floor() * step;
  if (r < 1.2) {
    p.dot(x, y, kWhite, a);
    return;
  }
  if (r < 2.6) {
    const sector = math.pi / 3.0;
    final pose =
        (((rot.remainder(sector) + sector) / (math.pi / 6.0)).floor()) % 2;
    const ptsA = [(1, 0), (-1, 0), (0, 1), (0, -1)];
    const ptsB = [(1, 1), (-1, -1), (1, -1), (-1, 1)];
    for (final (dx, dy) in pose != 0 ? ptsA : ptsB) {
      p.dot(x + dx, y + dy, hot > 0.5 ? kWhite : c[n - 3], a);
    }
    p.dot(x, y, kWhite, a);
    p.glow(x, y, 4, c[n - 3], 0.2 * a);
    return;
  }
  final arm = hot > 0.5 ? kWhite : c[n - 2];
  final br = hot > 0.5 ? c[n - 2] : c[n - 3];
  final big = r >= 7.0;
  final branches = r < 4.0
      ? const <(double, double)>[]
      : (big
          ? (d.branches.length > 2 ? d.branches.sublist(0, 2) : d.branches)
          : const [(0.58, 0.36)]);
  for (var k = 0; k < 6; k++) {
    final g = rot + (k * tau) / 6.0;
    final ca = math.cos(g);
    final sa = math.sin(g);
    p.line(x, y, x + ca * r, y + sa * r, arm, a);
    for (final (u, l) in branches) {
      final bx = x + ca * r * u;
      final by = y + sa * r * u;
      final bl = math.max(1.0, r * l);
      for (final s in const [-1, 1]) {
        p.line(
          bx,
          by,
          bx + math.cos(g + (s * math.pi) / 3.0) * bl,
          by + math.sin(g + (s * math.pi) / 3.0) * bl,
          br,
          a,
        );
      }
    }
    if (d.fork && big && !d.plate) {
      for (final s in const [-1, 1]) {
        p.dot(
          x + ca * r + math.cos(g + s * 0.9) * 1.2,
          y + sa * r + math.sin(g + s * 0.9) * 1.2,
          br,
          a,
        );
      }
    }
    p.dot(x + ca * r, y + sa * r, kWhite, a);
  }
  if (d.plate && big) {
    final q = r * 0.34;
    for (var k = 0; k < 6; k++) {
      final g0 = rot + math.pi / 6.0 + (k * tau) / 6.0;
      final g1 = g0 + tau / 6.0;
      p.line(
        x + math.cos(g0) * q,
        y + math.sin(g0) * q,
        x + math.cos(g1) * q,
        y + math.sin(g1) * q,
        c[n - 3],
        a,
      );
    }
  }
  p.px(x, y, kWhite);
  p.glow(x, y, 3.0 + r * 1.2, c[n - 4], (0.14 + 0.35 * hot) * a);
  if (hot > 0.3) p.glow(x, y, 2.0 + r * 0.5, kWhite, 0.3 * hot * a);
}

/// Nothing outlives the effect: trims the life of every particle, bit and pane that would last past [duration].
void endBy(
  double t,
  double duration, {
  Particles? ps,
  Bits? bits,
  Panes? panes,
}) {
  final left = math.max(0.001, duration - 0.05 - t);
  if (ps != null) {
    for (final q in ps.list) {
      if (q.life > left) q.life = left;
    }
  }
  if (bits != null) {
    for (final q in bits.list) {
      if (q.life > left) q.life = left;
    }
  }
  if (panes != null) {
    for (final q in panes.list) {
      if (q.life > left) q.life = left;
    }
  }
}

/// Cracks racing out from `(x, y)` through a shape.
List<List<(double x, double y, double d)>> fractures(
  Rng r,
  bool Function(double x, double y) inside,
  double x,
  double y,
  int n, {
  (double, double) step = const (1.6, 2.6),
  int len = 18,
  double fork = 0.16,
  double? a0,
  double spread = tau,
}) {
  final out = <List<(double, double, double)>>[];
  final startAngle = a0 ?? r.range(0, tau);
  void walk(double x, double y, double d, double a, int len, int depth) {
    final pts = <(double, double, double)>[(x, y, d)];
    for (var s = 0; s < len; s++) {
      a += r.range(-0.55, 0.55);
      final st = r.range(step.$1, step.$2);
      final nx = x + math.cos(a) * st;
      final ny = y + math.sin(a) * st;
      if (!inside(nx, ny)) break;
      x = nx;
      y = ny;
      d += st;
      pts.add((x, y, d));
      if (depth < 2 && pts.length > 2 && r.chance(fork)) {
        walk(
          x,
          y,
          d,
          a + r.sign() * r.range(0.6, 1.2),
          (len * 0.5).ceil(),
          depth + 1,
        );
      }
    }
    if (pts.length > 1) out.add(pts);
  }

  for (var i = 0; i < n; i++) {
    walk(
      x,
      y,
      0.0,
      startAngle + (i / n) * spread + r.range(-0.3, 0.3) * math.min(1.0, spread / tau),
      len,
      0,
    );
  }
  return out;
}

/// Draw cracks grown out to distance [reach] from their start.
void drawFractures(
  Painter p,
  List<List<(double x, double y, double d)>> cracks,
  double reach,
  List<int> c, {
  double ox = 0.0,
  double oy = 0.0,
  bool hot = true,
  double a = 1.0,
}) {
  final n = c.length;
  ({double x0, double y0, double x1, double y1, bool tip})? segOf(
    List<(double x, double y, double d)> pts,
    int i,
  ) {
    final (x0, y0, d0) = pts[i - 1];
    final (x1, y1, d1) = pts[i];
    if (d0 >= reach) return null;
    final u = math.min(1.0, (reach - d0) / math.max(0.01, d1 - d0));
    return (
      x0: x0 + ox,
      y0: y0 + oy,
      x1: x0 + ox + (x1 - x0) * u,
      y1: y0 + oy + (y1 - y0) * u,
      tip: reach - d1 < 3.0,
    );
  }

  for (final pts in cracks) {
    for (var i = 1; i < pts.length; i++) {
      final s = segOf(pts, i);
      if (s == null) break;
      p.line(s.x0, s.y0 + 1, s.x1, s.y1 + 1, c[math.min(2, n - 1)], a);
    }
  }
  for (final pts in cracks) {
    for (var i = 1; i < pts.length; i++) {
      final s = segOf(pts, i);
      if (s == null) break;
      final tip = hot && s.tip;
      p.line(s.x0, s.y0, s.x1, s.y1, tip ? kWhite : c[n - 2], a);
      if (tip) {
        p.glow(s.x1, s.y1, 5, c[n - 3], 0.5 * a);
      } else if (i.isOdd) {
        p.glow(s.x1, s.y1, 3, c[n - 3], 0.18 * a);
      }
    }
  }
}
