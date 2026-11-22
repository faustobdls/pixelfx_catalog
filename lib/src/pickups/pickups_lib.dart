// Helpers for the pickups: a scratch layer to build outlined sprites in, floor shadows, twinkles and bobs.
// Adapted from Sprite Fusion's open-source pickup and sparkle (MIT, Hugo Duprez).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

/// A scratch layer: draw a sprite into it, give it a dark outline, recolor it, then stamp it onto the frame.
class SpriteLayer {
  final PixelFrame f;
  late final Painter q;
  final Uint32List tmp;

  SpriteLayer([int w = 64, int h = 64])
      : f = createFrame(w, h),
        tmp = Uint32List(w * h) {
    q = Painter(f);
  }

  Painter begin(num x0, num y0) {
    f.ox = x0.floor();
    f.oy = y0.floor();
    f.color.fillRange(0, f.color.length, 0);
    f.light.fillRange(0, f.light.length, 0);
    return q.reset().place(0, 0);
  }

  int idx(num x, num y) {
    final i = x.floor() - f.ox;
    final j = y.floor() - f.oy;
    return (i < 0 || j < 0 || i >= f.w || j >= f.h) ? -1 : j * f.w + i;
  }

  int get(num x, num y) {
    final i = idx(x, y);
    return i < 0 ? 0 : f.color[i];
  }

  void set(num x, num y, int c) {
    final i = idx(x, y);
    if (i >= 0) f.color[i] = c;
  }

  void fill(num x0, num y0, num x1, num y1, int Function(double x, double y) fn) {
    final startY = y0.floor();
    final startX = x0.floor();
    for (var y = startY; y <= y1; y++) {
      for (var x = startX; x <= x1; x++) {
        final c = fn(x + 0.5, y + 0.5);
        if (c != 0) set(x, y, c);
      }
    }
  }

  SpriteLayer outline(int c, {bool corners = false}) =>
      outlineShaded((_, _, _) => c, corners: corners);

  SpriteLayer outlineShaded(
    int Function(int x, int y, int neighborColor) fn, {
    bool corners = false,
  }) {
    final buf = f.color;
    final tBuf = tmp;
    final w = f.w;
    final h = f.h;
    tBuf.fillRange(0, tBuf.length, 0);
    for (var j = 0; j < h; j++) {
      for (var i = 0; i < w; i++) {
        final k = j * w + i;
        if (buf[k] != 0) continue;
        var n = 0;
        if (i > 0 && buf[k - 1] != 0) {
          n = buf[k - 1];
        } else if (i < w - 1 && buf[k + 1] != 0) {
          n = buf[k + 1];
        } else if (j > 0 && buf[k - w] != 0) {
          n = buf[k - w];
        } else if (j < h - 1 && buf[k + w] != 0) {
          n = buf[k + w];
        }
        if (n == 0 && corners) {
          if (i > 0 && j > 0 && buf[k - w - 1] != 0) {
            n = buf[k - w - 1];
          } else if (i < w - 1 && j > 0 && buf[k - w + 1] != 0) {
            n = buf[k - w + 1];
          } else if (i > 0 && j < h - 1 && buf[k + w - 1] != 0) {
            n = buf[k + w - 1];
          } else if (i < w - 1 && j < h - 1 && buf[k + w + 1] != 0) {
            n = buf[k + w + 1];
          }
        }
        if (n != 0) tBuf[k] = fn(i + f.ox, j + f.oy, n);
      }
    }
    for (var k = 0; k < w * h; k++) {
      if (tBuf[k] != 0) buf[k] = tBuf[k];
    }
    return this;
  }

  SpriteLayer map(int Function(int x, int y, int c) fn) {
    final buf = f.color;
    for (var k = 0; k < buf.length; k++) {
      if (buf[k] != 0) {
        final c = fn((k % f.w) + f.ox, (k ~/ f.w) + f.oy, buf[k]);
        if (c != 0) buf[k] = c;
      }
    }
    return this;
  }

  SpriteLayer draw(
    Painter p, [
    double dx = 0.0,
    double dy = 0.0,
    double a = 1.0,
    (double, double)? clip,
  ]) {
    final buf = f.color;
    for (var k = 0; k < buf.length; k++) {
      if (buf[k] == 0) continue;
      final x = (k % f.w) + f.ox + dx;
      if (clip != null && (x < clip.$1 || x >= clip.$2)) continue;
      p.dot(x, (k ~/ f.w) + f.oy + dy, buf[k], a);
    }
    return this;
  }
}

final int _shadowCol = hex('#100e17');
final int _inkCol = hex('#0b0814');

void shadowBand(Painter p, double x, double rx, [double k = 1.0]) {
  if (rx < 1.0) return;
  for (var row = 0; row < 2; row++) {
    final w = rx - row * 2.0;
    final iEnd = (x + w).ceil();
    for (var i = (x - w).floor(); i < iEnd; i++) {
      final e = (i + 0.5 - x).abs() / w;
      if (e <= 1.0) {
        p.dot(i, row, _shadowCol, row != 0 ? k : k * (e < 0.8 ? 1.0 : 0.5));
      }
    }
  }
}

void twinkle(
  Painter p,
  num x,
  num y,
  double s,
  int c, [
  int? mid,
  int? core,
]) {
  final n = s.round();
  if (n <= 0) return;
  final midC = mid ?? c;
  final coreC = core ?? kWhite;
  for (var d = 1; d <= n - 1; d++) {
    final k = d < n / 2.0 ? midC : c;
    p.px(x + d, y, k);
    p.px(x - d, y, k);
    p.px(x, y + d, k);
    p.px(x, y - d, k);
  }
  if (n >= 4) {
    p.px(x + 1, y + 1, c);
    p.px(x - 1, y - 1, c);
    p.px(x + 1, y - 1, c);
    p.px(x - 1, y + 1, c);
  }
  p.px(x, y, coreC);
}

double bob(double ph, double amp, [double n = 1.0, double off = 0.0]) =>
    -amp * math.sin((ph * n + off) * tau);

void pillow(
  SpriteLayer l,
  double x0,
  double y0,
  double x1,
  double y1,
  double Function(double x, double y) sdf,
  int Function(double b, double e, double x, double y) color, {
  double bevel = 3.0,
  List<double> light = const [-0.5, -0.6, 0.62],
  bool Function(double x, double y)? clip,
}) {
  l.fill(x0, y0, x1, y1, (x, y) {
    final d = sdf(x, y);
    if (d > 0.0 || (clip != null && clip(x, y))) return 0;
    final e = -d;
    var gx = sdf(x + 0.5, y) - sdf(x - 0.5, y);
    var gy = sdf(x, y + 0.5) - sdf(x, y - 0.5);
    final glRaw = hypot(gx, gy);
    final gl = glRaw == 0.0 ? 1.0 : glRaw;
    gx /= gl;
    gy /= gl;
    final k = math.max(0.0, 1.0 - e / bevel) * 1.25;
    final sn = math.sin(k);
    final cs = math.cos(k);
    return color(gx * sn * light[0] + gy * sn * light[1] + cs * light[2], e, x, y);
  });
}

double heartSdf(
  double x,
  double y,
  double cx,
  double cy,
  double w, [
  double? h,
]) {
  final hh = h ?? w;
  final s = w / 1.14;
  final xx = (x - cx) / s;
  final yy = -(y - cy) / (hh / 1.14) + 0.12;
  final q = xx * xx + yy * yy - 1.0;
  final f = q * q * q - xx * xx * yy * yy * yy;
  final gx = 6.0 * xx * q * q - 2.0 * xx * yy * yy * yy;
  final gy = 6.0 * yy * q * q - 3.0 * xx * xx * yy * yy;
  return (f / math.max(hypot(gx, gy), 0.6)) * s;
}

void blobShadow(
  Painter p,
  double x,
  double rx, [
  double k = 1.0,
  double y = 0.0,
]) {
  if (rx < 0.8 || k <= 0.0) return;
  final endI = (x + rx).ceil();
  for (var i = (x - rx).floor(); i <= endI; i++) {
    final u = (i + 0.5 - x).abs() / rx;
    if (u > 1.0) continue;
    final a = k * (1.0 - u * u);
    p.dot(i, y, _inkCol, a * 1.1);
    if (u < 0.6) p.dot(i, y + 1, _inkCol, a * 0.6);
  }
}

void glint(
  Painter p,
  double x,
  double y,
  double arm,
  int c, [
  double k = 0.4,
  int? tip,
]) {
  final n = arm.round();
  final xi = x.floor();
  final yi = y.floor();
  if (n < 0) return;
  final tipC = tip ?? scaleColor(c, 0.8);
  for (var d = 1; d <= n; d++) {
    final cc = (d == n && n > 1) ? tipC : c;
    p.px(xi + d, yi, cc);
    p.px(xi - d, yi, cc);
    p.px(xi, yi + d, cc);
    p.px(xi, yi - d, cc);
  }
  p.px(xi, yi, n > 0 ? kWhite : c);
  p.glow(xi + 0.5, yi + 0.5, 3.0 + n * 2.5, c, k);
}

void pool(
  Painter p,
  double x,
  double y,
  double rx,
  double ry,
  int c,
  double k,
) {
  if (k <= 0.004 || rx < 1.0) return;
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

void coin(
  SpriteLayer l,
  Painter p,
  double x,
  double y,
  double r,
  double ax,
  double spin,
  List<int> c, {
  bool white = false,
  double a = 1.0,
  bool snap = true,
}) {
  final xx = snap ? (x + 0.5).floorToDouble() : x;
  final yy = snap ? (y + 0.5).floorToDouble() : y;
  final cs = math.cos(spin);
  final sn = math.sin(spin);
  final b = math.max(0.5, r * cs.abs());
  final th = 1.2 * sn * (cs == 0.0 ? 1.0 : cs.sign);
  final ca = math.cos(ax);
  final sa = math.sin(ax);
  final face = cs.abs();
  final rad = r.ceil() + 2;
  l.begin(xx.floor() - rad, yy.floor() - rad);
  l.fill(xx.floor() - rad, yy.floor() - rad, xx.floor() + rad, yy.floor() + rad,
      (px, py) {
    final dx = px - xx;
    final dy = py - yy;
    final u = dx * ca + dy * sa;
    final w = -dx * sa + dy * ca;
    final ef = hypot(u / r, w / b);
    final er = hypot(u / r, (w - th) / b);
    if (white && (ef <= 1.0 || er <= 1.0)) return kWhite;
    if (ef <= 1.0) {
      final lit = -(dx * 0.62 + dy * 0.78) / math.max(1.0, hypot(dx, dy));
      final dim = face < 0.45 ? 1 : 0;
      if (b < 1.1) return lit > 0.0 ? c[6] : c[4];
      if (ef > 0.72) {
        return c[(lit > 0.3 ? 6 : (lit > -0.35 ? 5 : 3)) - dim];
      }
      if (b > 2.2 && ef > 0.42) return c[(lit > 0.2 ? 4 : 5) - dim];
      if (face > 0.6 && lit > 0.5) return c[7];
      return c[5 - dim];
    }
    if (er <= 1.0) return (w - th).abs() < w.abs() ? c[2] : c[3];
    return 0;
  });
  l.outline(c[1]).draw(p, 0, 0, a);
}

void gemlet(
  SpriteLayer l,
  Painter p,
  double x,
  double y,
  double r,
  double ang,
  List<int> g, {
  bool white = false,
  double a = 1.0,
}) {
  final xx = (x + 0.5).floor();
  final yy = (y + 0.5).floor();
  final ca = math.cos(ang);
  final sa = math.sin(ang);
  final n = g.length;
  final rad = (r * 1.4).ceil() + 2;
  final ct = r * 0.75;
  final tw = r * 0.5;
  final pv = r * 1.3;
  l.begin(xx - rad, yy - rad);
  l.fill(xx - rad, yy - rad, xx + rad - 1, yy + rad - 1, (px, py) {
    final dx = px - xx;
    final dy = py - yy;
    final u = dx * ca + dy * sa;
    final w = -dx * sa + dy * ca;
    int facet;
    if (w < 0.0) {
      if (w < -ct || u.abs() > r - ((-w) / ct) * (r - tw)) return 0;
      facet = w < -ct * 0.45 && u.abs() < tw * 0.95 ? 0 : (u < 0.0 ? 1 : 2);
    } else {
      if (w > pv || u.abs() > r * (1.0 - w / pv)) return 0;
      facet = u.abs() < 0.5 ? 4 : (u < 0.0 ? 3 : 5);
    }
    if (white) return kWhite;
    const normals = [
      (0.0, -1.0),
      (-0.7, -0.7),
      (0.7, -0.7),
      (-0.6, 0.8),
      (0.0, 1.0),
      (0.6, 0.8),
    ];
    final norm = normals[facet];
    final nx = norm.$1 * ca - norm.$2 * sa;
    final ny = norm.$1 * sa + norm.$2 * ca;
    final lit = -(nx * 0.62 + ny * 0.78);
    if (facet == 0 && lit > 0.3 && u < 0.0) return kWhite;
    return lit > 0.6
        ? g[n - 1]
        : (lit > 0.2
            ? g[n - 2]
            : (lit > -0.2 ? g[n - 3] : (lit > -0.6 ? g[n - 4] : g[n - 5])));
  });
  l.outline(g[0]).draw(p, 0, 0, a);
}

class GemPlane {
  final List<double> n;
  final double d;
  final int kind;

  const GemPlane(this.n, this.d, this.kind);
}

class GemSolid {
  final List<GemPlane> planes;
  final double r;
  final double top;
  final double bottom;

  const GemSolid({
    required this.planes,
    required this.r,
    required this.top,
    required this.bottom,
  });
}

GemSolid brilliant({
  double r = 7.5,
  double crown = 3.6,
  double table = 0.52,
  double pavilion = 8.0,
  double girdle = 0.8,
  int n = 8,
}) {
  final planes = <GemPlane>[
    GemPlane(const [0.0, 1.0, 0.0], crown + girdle / 2.0, 0),
  ];
  final cs = math.atan2(crown, r * (1.0 - table));
  final ps = math.atan2(pavilion, r);
  for (var i = 0; i < n * 2; i++) {
    final a = (i * math.pi) / n;
    final half = i % 2 != 0;
    final c = half ? math.min(1.45, cs + 0.22) : cs;
    final pv = half ? ps - 0.1 : ps;
    planes.add(GemPlane(
      [math.sin(c) * math.cos(a), math.cos(c), math.sin(c) * math.sin(a)],
      r * math.sin(c) * (half ? 1.012 : 1.0) + (girdle / 2.0) * math.cos(c),
      half ? 2 : 1,
    ));
    planes.add(GemPlane([math.cos(a), 0.0, math.sin(a)], r, 3));
    planes.add(GemPlane(
      [math.sin(pv) * math.cos(a), -math.cos(pv), math.sin(pv) * math.sin(a)],
      r * math.sin(pv) * (half ? 1.03 : 1.0) + (girdle / 2.0) * math.cos(pv),
      half ? 5 : 4,
    ));
  }
  return GemSolid(
    planes: planes,
    r: r,
    top: crown + girdle / 2.0,
    bottom: pavilion + girdle / 2.0,
  );
}

GemSolid prism({
  double r = 4.6,
  double half = 5.5,
  double top = 7.5,
  double bottom = 6.0,
  int n = 6,
}) {
  final planes = <GemPlane>[];
  final ct = math.atan2(top, r);
  final cb = math.atan2(bottom, r);
  for (var i = 0; i < n; i++) {
    final a = (i * tau) / n;
    planes.add(GemPlane([math.cos(a), 0.0, math.sin(a)], r, 6));
    planes.add(GemPlane(
      [math.sin(ct) * math.cos(a), math.cos(ct), math.sin(ct) * math.sin(a)],
      math.sin(ct) * r + math.cos(ct) * half,
      7,
    ));
    planes.add(GemPlane(
      [math.sin(cb) * math.cos(a), -math.cos(cb), math.sin(cb) * math.sin(a)],
      math.sin(cb) * r + math.cos(cb) * half,
      8,
    ));
  }
  return GemSolid(
    planes: planes,
    r: r / math.cos(math.pi / n),
    top: half + top,
    bottom: half + bottom,
  );
}

({double x, double y, double k}) drawGem(
  SpriteLayer l,
  Painter p,
  GemSolid g,
  double x,
  double y,
  double spin,
  List<int> c, {
  double tilt = 0.32,
  bool white = false,
  double a = 1.0,
  bool edges = true,
  double gain = 1.0,
}) {
  final cs = math.cos(spin);
  final sn = math.sin(spin);
  final ct = math.cos(tilt);
  final st = math.sin(tilt);
  final planes = g.planes
      .map((q) => GemPlane(
            [
              q.n[0] * cs - q.n[2] * sn,
              q.n[1],
              q.n[0] * sn + q.n[2] * cs,
            ],
            q.d,
            q.kind,
          ))
      .toList();
  const lx = -0.55;
  const ly = 0.72;
  const lz = 0.42;
  final dx = 0.0;
  final dy = -st;
  final dz = -ct;
  final vx = 0.0;
  final vy = st;
  final vz = ct;
  final hl = math.sqrt((lx + vx) * (lx + vx) +
      (ly + vy) * (ly + vy) +
      (lz + vz) * (lz + vz));
  final hx = (lx + vx) / hl;
  final hy = (ly + vy) / hl;
  final hz = (lz + vz) / hl;
  final xi = (x + 0.5).floor();
  final yi = (y + 0.5).floor();
  final rad = g.r.ceil() + 2;
  final top = (g.top + 2).ceil();
  final bot = (g.bottom + 2).ceil();
  var best = -1.0;
  var bx = xi.toDouble();
  var by = yi.toDouble();
  final ids = <int, int>{};
  l.begin(xi - rad, yi - top);
  l.fill(xi - rad, yi - top, xi + rad, yi + bot, (px, py) {
    final sx = px - xi;
    final sy = -(py - yi);
    final ox = sx;
    final oy = sy * ct;
    final oz = -sy * st;
    var t0 = -1e9;
    var t1 = 1e9;
    var hitIdx = -1;
    for (var idx = 0; idx < planes.length; idx++) {
      final q = planes[idx];
      final nd = q.n[0] * dx + q.n[1] * dy + q.n[2] * dz;
      final no = q.n[0] * ox + q.n[1] * oy + q.n[2] * oz;
      if (nd.abs() < 1e-6) {
        if (no > q.d) return 0;
        continue;
      }
      final tt = (q.d - no) / nd;
      if (nd < 0.0) {
        if (tt > t0) {
          t0 = tt;
          hitIdx = idx;
        }
      } else if (tt < t1) {
        t1 = tt;
      }
    }
    if (hitIdx < 0 || t0 > t1) return 0;
    if (white) return kWhite;
    ids[(px.floor() + 500) * 1000 + py.floor() + 500] = hitIdx;
    final hit = planes[hitIdx];
    final n = hit.n;
    final pav = hit.kind == 4 || hit.kind == 5 || hit.kind == 8;
    final mx = n[0];
    final my = pav ? -n[1] * 0.6 : n[1];
    final mz = n[2];
    final ml = math.sqrt(mx * mx + my * my + mz * mz);
    final lam = math.max(0.0, (mx * lx + my * ly + mz * lz) / ml);
    final spec = math.pow(
      math.max(0.0, (mx * hx + my * hy + mz * hz) / ml),
      18,
    ).toDouble();
    var b = pav
        ? 0.02 + 0.72 * math.pow(lam, 2.4).toDouble()
        : (hit.kind == 3
            ? 0.12 + 0.4 * lam
            : 0.04 + 0.66 * math.pow(lam, 1.8).toDouble());
    if (hit.kind == 6) {
      b = 0.16 +
          0.66 *
              math.pow(
                math.max(0.0, (n[0] * lx + n[2] * lz) / hypot(lx, lz)),
                1.3,
              ).toDouble();
    } else if (hit.kind == 7) {
      b = 0.22 + 0.62 * math.pow(lam, 1.2).toDouble();
    } else if (hit.kind == 9) {
      b = 0.62 + 0.25 * lam;
    } else if (hit.kind == 10) {
      b = 0.3 +
          0.5 * lam +
          (rand((px - xi).floor(), (py - yi).floor(), 43) - 0.5) * 0.08;
    }
    if (hit.kind != 9) b *= gain;
    if (hit.kind == 0) b -= 0.04;
    final s = b + spec * 0.6;
    if (s > best) {
      best = s;
      bx = px;
      by = py;
    }
    if (spec > 0.8) return pav ? c[6] : kWhite;
    return c[clampInt((1.0 + s * 5.6 + 0.5).floor(), 1, 6)];
  });
  if (!white && edges) {
    final out = <(int, int, int)>[];
    for (final entry in ids.entries) {
      final key = entry.key;
      final id = entry.value;
      final kx = key ~/ 1000;
      final ky = key - kx * 1000;
      final ex = kx - 500;
      final ey = ky - 500;
      final rId = ids[key + 1000];
      final dId = ids[key + 1];
      if ((rId != null && rId != id) || (dId != null && dId != id)) {
        final col = l.get(ex, ey);
        final i = c.indexOf(col);
        final kind = planes[id].kind;
        final pav = kind == 4 || kind == 5 || kind == 8;
        if (i > 0) {
          out.add((
            ex,
            ey,
            pav ? c[math.max(1, i - 1)] : c[math.min(7, i + 1)],
          ));
        }
      }
    }
    for (final (ex, ey, col) in out) {
      l.set(ex, ey, col);
    }
  }
  l.outline(c[0]).draw(p, 0, 0, a);
  return (x: bx, y: by, k: best);
}

double coin3d(
  SpriteLayer l,
  Painter p,
  double x,
  double y,
  double r,
  double th,
  double theta,
  List<int> c, {
  double a = 1.0,
  bool white = false,
}) {
  final ct = math.cos(theta);
  final st = math.sin(theta);
  final sg = ct < 0.0 ? -1.0 : 1.0;
  final act = ct.abs();
  final ast = st.abs();
  final xc = (th / 2.0) * st * sg;
  final nfx = st * sg;
  const lx = -0.55;
  const ly = 0.45;
  const lz = 0.7;
  final ln = math.sqrt(lx * lx + ly * ly + lz * lz);
  final lam = (nfx * lx + act * lz) / ln;
  final hx = lx / ln;
  final hz = lz / ln + 1.0;
  final hn = hypot(hx, hz);
  final base = clampInt((2.0 + lam * 3.2).round(), 2, 5);
  final xi = (x + 0.5).floor();
  final yi = (y + 0.5).floor();
  final b = (r + th).ceil() + 2;
  var flash = 0.0;
  l.begin(xi - b, yi - b);
  l.fill(xi - b, yi - b, xi + b, yi + b, (px, py) {
    final sx = px - xi;
    final sy = -(py - yi);
    if (sy.abs() > r) return 0;
    final s = math.sqrt(math.max(0.0, 1.0 - (sy / r) * (sy / r)));
    final hw = r * s * act;
    final xr = -(st < 0.0 ? -1.0 : 1.0) * s * r * ct;
    final rw = (th / 2.0) * ast;
    if (white &&
        ((sx - xc).abs() <= hw || (sx - xr).abs() <= rw + 0.05)) {
      return kWhite;
    }
    if ((sx - xc).abs() <= hw && act > 0.08) {
      final fx = (sx - xc) / act;
      final fy = sy;
      final d = hypot(fx, fy) / r;
      final tx = nfx + (fx / r) * 0.3 * act;
      final sp = math.pow(
        math.max(0.0, (tx * hx + act * hz) / hn / hypot(tx, act)),
        130,
      ).toDouble();
      flash = math.max(flash, sp);
      final lit = (-fx * 0.6 + fy * 0.8) / math.max(0.5, hypot(fx, fy));
      int k;
      if (d > 0.76) {
        k = base + (lit > 0.75 ? 2 : (lit > 0.3 ? 1 : (lit < -0.35 ? -1 : 0)));
      } else {
        final q = (fx.abs() + fy.abs()) / (r * 0.52);
        k = q >= 1.0
            ? base - 1
            : (q < 0.45
                ? base + 1
                : (fx <= 0.0 && fy >= 0.0
                    ? base + 1
                    : (fx > 0.0 && fy < 0.0 ? base - 2 : base)));
      }
      if (sp > 0.5) return sp > 0.8 ? kWhite : c[math.min(7, k + 2)];
      return c[clampInt(k, 2, 6)];
    }
    if ((sx - xr).abs() <= rw + 0.05) {
      final cphi = xr < 0.0 ? -s : s;
      final nx = cphi * ct;
      final ny = sy / r;
      final nz = -cphi * st;
      final lVal = (nx * lx + ny * ly + nz * lz) / ln;
      final groove = ((math.asin((sy / r).clamp(-1.0, 1.0)) + math.pi) * 9.0)
              .floor() %
          2;
      final edge = (sx - xr).abs() > rw - 0.6 &&
          (sx - xr).sign == (xc - xr).sign;
      return c[clampInt(
        (2.6 + lVal * 2.6).round() - groove + (edge ? 1 : 0),
        1,
        6,
      )];
    }
    return 0;
  });
  l.outline(c[1]).draw(p, 0, 0, a);
  return flash;
}
