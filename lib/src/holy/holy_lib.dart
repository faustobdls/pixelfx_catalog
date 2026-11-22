// The plus sign's lit and shaded bevel is adapted from Sprite Fusion's open-source heal (https://www.spritefusion.com/pixel-art-vfx/heal),
// MIT License, Copyright (c) 2026 Hugo Duprez.
// Shared by the holy effects: gold, green and ash ramps, the character's silhouette and recolors, floor ovals,
// feathers of light (drawn, and simulated as they rock and sink) and plus signs.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

/// Holy gold, dark to bright: a plum shadow, rust, amber, gold, pale gold, cream, white.
const List<String> kHolyGold = [
  '#3b1d2a',
  '#7a3a2c',
  '#c4652e',
  '#f0a040',
  '#ffd25e',
  '#fff0a0',
  '#fffbe0',
  '#ffffff',
];

/// Healing green, warm: deep pine, leaf, spring green, a yellow-green highlight, cream.
const List<String> kHolyGreen = [
  '#0e2a24',
  '#14472f',
  '#1d6e3a',
  '#2f9a45',
  '#5cc654',
  '#a0e46c',
  '#dcffb4',
  '#ffffff',
];

/// Ash: the colour of the fallen, a cool grey-violet, dark to light.
const List<String> kHolyAsh = [
  '#16131c',
  '#26222f',
  '#3a3546',
  '#524c5e',
  '#6e6878',
  '#8c8796',
];

/// JS `Math.round(v)` parity (rounds half towards +infinity, e.g. -1.5 -> -1).
@pragma('vm:prefer-inline')
int holyRound(double v) => (v + 0.5).floor();

// ---- the character

/// Cached silhouette points for an actor at (x, y): rim pixels inside ([edge]),
/// 1 px ring just outside ([out]), vertical bounds, and an inside test [at].
class HolyShape {
  final int x;
  final int y;
  final List<(int x, int y)> edge;
  final List<(int x, int y)> out;
  final int top;
  final int bottom;
  final ActorMask mask;

  const HolyShape({
    required this.x,
    required this.y,
    required this.edge,
    required this.out,
    required this.top,
    required this.bottom,
    required this.mask,
  });

  bool at(double px, double py) {
    final i = px.floor() - x;
    final j = py.floor() - y;
    return i >= 0 &&
        j >= 0 &&
        i < mask.w &&
        j < mask.h &&
        mask.data[j * mask.w + i] > 0;
  }
}

final Expando<HolyShape> _shapes = Expando<HolyShape>();

HolyShape shapeOf(ActorDefinition a) {
  var s = _shapes[a.mask];
  if (s != null && s.x == a.x && s.y == a.y) return s;
  final m = a.mask;
  bool inside(int i, int j) =>
      i >= 0 && j >= 0 && i < m.w && j < m.h && m.data[j * m.w + i] > 0;
  final edge = <(int, int)>[];
  final out = <(int, int)>[];
  for (var j = -1; j <= m.h; j++) {
    for (var i = -1; i <= m.w; i++) {
      final nb = (inside(i - 1, j) ? 1 : 0) +
          (inside(i + 1, j) ? 1 : 0) +
          (inside(i, j - 1) ? 1 : 0) +
          (inside(i, j + 1) ? 1 : 0);
      if (inside(i, j)) {
        if (nb < 4) edge.add((a.x + i, a.y + j));
      } else if (nb != 0) {
        out.add((a.x + i, a.y + j));
      }
    }
  }
  s = HolyShape(
    x: a.x,
    y: a.y,
    edge: edge,
    out: out,
    top: a.y,
    bottom: a.y + m.h,
    mask: m,
  );
  _shapes[a.mask] = s;
  return s;
}

/// Draw the actor's own pixels recolored: [fn] returns the new color for pixel [c] at `(x, y)`,
/// or `0` to leave that pixel alone.
void recolor(
  Painter p,
  ActorDefinition a,
  int Function(int c, int x, int y) fn, [
  double alpha = 1.0,
]) {
  recolorShaded(p, a, fn, (_, _) => alpha);
}

/// Variant of [recolor] with per-pixel alpha callback `(x, y)`.
void recolorShaded(
  Painter p,
  ActorDefinition a,
  int Function(int c, int x, int y) fn,
  double Function(int x, int y) alpha,
) {
  final m = a.mask;
  final pix = a.pixels;
  if (pix.isEmpty) return;
  for (var j = 0; j < m.h; j++) {
    for (var i = 0; i < m.w; i++) {
      final c = pix[j * m.w + i];
      if (c == 0) continue;
      final x = a.x + i;
      final y = a.y + j;
      final n = fn(c, x, y);
      if (n != 0) p.dot(x, y, n, alpha(x, y));
    }
  }
}

/// A color mapped onto a ramp by its brightness (a tint that keeps the character's shading).
int toneOf(List<int> rampColors, int c, [double lift = 0.0]) =>
    rampColors[clampInt(
      ((luma(c) * 1.1 + lift) * rampColors.length).floor(),
      0,
      rampColors.length - 1,
    )];

// ---- floor and ovals

bool farHalf(double g) => math.sin(g) < 0.0;
bool nearHalf(double g) => math.sin(g) >= 0.0;

/// A 1 px oval (a ring on a tilted plane): centre `(cx, cy)`, radii `rx`, `ry`.
/// [keep] picks the part to draw.
void oval(
  Painter p,
  num cx,
  num cy,
  num rx,
  num ry,
  int c, [
  double a = 1.0,
  bool Function(double g)? keep,
]) {
  ovalShaded(p, cx, cy, rx, ry, color: (_) => c, alpha: (_) => a, keep: keep);
}

/// Shaded variant of [oval] where [color] and [alpha] are functions of angle `g`.
void ovalShaded(
  Painter p,
  num cx,
  num cy,
  num rx,
  num ry, {
  required int Function(double g) color,
  double Function(double g)? alpha,
  bool Function(double g)? keep,
}) {
  final rxd = rx.toDouble();
  final ryd = ry.toDouble();
  if (rxd < 0.5) return;
  final cxd = cx.toDouble();
  final cyd = cy.toDouble();
  final n = (math.max(rxd, ryd) * tau * 1.5).ceil() + 6;
  for (var j = 0; j < n; j++) {
    final g = (j / n) * tau;
    if (keep != null && !keep(g)) continue;
    p.dot(
      cxd + math.cos(g) * rxd,
      cyd + math.sin(g) * ryd,
      color(g),
      alpha != null ? alpha(g) : 1.0,
    );
  }
}

// ---- feathers

/// A feather of light from its quill at `(x, y)` pointing along [ang], [len] px long.
void feather(
  Painter p,
  double x,
  double y,
  double ang,
  double len,
  double wid,
  List<int> rampColors, [
  double a = 1.0,
  int side = 1,
  double hot = 0.0,
  double quill = 0.02,
]) {
  if (len < 1.5 || a <= 0.02) return;
  final n = rampColors.length;
  final ca = math.cos(ang);
  final sa = math.sin(ang);
  final x1 = x + ca * len;
  final y1 = y + sa * len;
  final pad = wid + 1.2;
  final h = hot > 0.5;
  final edge = h ? rampColors[n - 3] : rampColors[n - 5];
  final lead = h ? kWhite : rampColors[n - 2];
  final body0 = h ? kWhite : rampColors[n - 2];
  final body1 = h ? kWhite : rampColors[n - 3];
  final body2 = h ? rampColors[n - 2] : rampColors[n - 4];

  p.each(
    math.min(x, x1) - pad,
    math.min(y, y1) - pad,
    math.max(x, x1) + pad,
    math.max(y, y1) + pad,
    (px, py, sx, sy) {
      final dx = px - x;
      final dy = py - y;
      final u = (dx * ca + dy * sa) / len;
      if (u < 0.0 || u > 1.05) return;
      final v = (-dx * sa + dy * ca) * side;
      final av = v.abs();
      final tipTerm = math.max(0.0, (u - 0.55) / 0.47);
      final w = wid *
          math.sqrt(clamp((u - quill) / 0.22)) *
          math.sqrt(math.max(0.0, 1.0 - tipTerm * tipTerm));
      final lim = v < 0.0 ? w * 0.42 : w;
      final fade = u < 0.72 ? 1.0 : 1.0 - (u - 0.72) * 1.6;
      if (av < 0.5 && u < 0.9) {
        p.put(sx, sy, u < 0.5 ? kWhite : body0, a);
        return;
      }
      if (av > lim + 0.05 || w < 0.5) return;
      if (lim - av < 1.0) {
        if (v > 0.0) {
          p.put(sx, sy, u > 0.85 ? body2 : edge, a * fade);
        } else {
          p.put(sx, sy, lead, a);
        }
        return;
      }
      if (u < 0.72) {
        p.put(sx, sy, u < 0.38 ? body0 : body1, a);
        return;
      }
      p.blendPx(sx, sy, body2, a * fade);
    },
  );
}

class FeatherItem {
  double x;
  double y;
  double vx;
  double vy;
  double a;
  final double len;
  final double wid;
  double life;
  final double max;
  double delay;
  final bool back;
  final int side;
  final double ph;
  final double w;
  final double amp;
  final double sink;
  final double va;
  final double tilt;
  double age = 0.0;
  bool landed = false;

  FeatherItem({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.a,
    required this.len,
    required this.wid,
    required this.life,
    required this.delay,
    required this.back,
    required this.side,
    required this.ph,
    required this.w,
    required this.amp,
    required this.sink,
    required this.va,
    required this.tilt,
  }) : max = life;
}

/// Loose feathers that are thrown, brake hard, then rock like a pendulum as they sink.
class Feathers {
  final Rng r;
  final double floor;
  final List<FeatherItem> list = [];

  Feathers(this.r, [this.floor = 0.0]);

  void add({
    required double x,
    required double y,
    double vx = 0.0,
    double vy = 0.0,
    double a = 0.0,
    double len = 7.0,
    double wid = 2.0,
    required double life,
    double delay = 0.0,
    bool back = false,
    int? side,
    double? ph,
    double? w,
    double? amp,
    double? sink,
    double? va,
    double? tilt,
  }) {
    // Always draw all default RNG values in exact JS object-literal order before overriding.
    final defSide = r.sign();
    final defPh = r.range(0.0, tau);
    final defW = r.range(3.2, 4.6);
    final defAmp = r.range(6.0, 11.0);
    final defSink = r.range(14.0, 24.0);
    final defVa = r.range(-9.0, 9.0);
    final defTilt = r.range(-0.35, 0.35);

    list.add(FeatherItem(
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      a: a,
      len: len,
      wid: wid,
      life: life,
      delay: delay,
      back: back,
      side: side ?? defSide,
      ph: ph ?? defPh,
      w: w ?? defW,
      amp: amp ?? defAmp,
      sink: sink ?? defSink,
      va: va ?? defVa,
      tilt: tilt ?? defTilt,
    ));
  }

  int get count => list.length;

  void update(double dt) {
    for (var i = list.length - 1; i >= 0; i--) {
      final f = list[i];
      if (f.delay > 0.0) {
        f.delay -= dt;
        continue;
      }
      f.life -= dt;
      if (f.life <= 0.0) {
        list.removeAt(i);
        continue;
      }
      f.age += dt;
      if (f.landed) {
        f.a += (holyRound(f.a / math.pi) * math.pi - f.a) *
            math.min(1.0, dt * 10.0);
        continue;
      }
      f.vx -= f.vx * 3.4 * dt;
      f.vy -= f.vy * 3.4 * dt;
      final s = smooth(0.1, 0.6, f.age);
      final ph = f.age * f.w + f.ph;
      final c = math.cos(ph);
      f.x += (f.vx + math.sin(ph) * f.amp * s * 0.9) * dt;
      f.y += (f.vy + f.sink * s * (c * c * 1.5 - 0.2)) * dt;
      final rest =
          holyRound(f.a / math.pi) * math.pi + f.tilt + math.sin(ph) * 0.6;
      f.a += f.va * dt * (1.0 - s) +
          (rest - f.a) * math.min(1.0, dt * 5.0 * s);
      if (f.y >= floor - 0.5) {
        f.y = floor - 0.5;
        f.landed = true;
        f.life = math.min(f.life, 0.6);
      }
    }
  }

  void draw(Painter p, List<int> rampColors, [String? layer]) {
    for (final f in list) {
      if (f.delay > 0.0 ||
          (layer != null && (f.back ? 'back' : 'front') != layer)) {
        continue;
      }
      final k = f.life / f.max;
      final a = math.min(1.0, math.min(f.life / 0.45, f.age / 0.06));
      final ca = math.cos(f.a);
      final sa = math.sin(f.a);
      feather(
        p,
        f.x - (ca * f.len) / 2.0,
        f.y - (sa * f.len) / 2.0,
        f.a,
        f.len,
        f.wid,
        rampColors,
        a,
        f.side,
        f.age < 0.06 ? 1.0 : 0.0,
        0.2,
      );
      p.glow(
        f.x,
        f.y,
        4.0 + f.len * 0.5,
        rampColors[rampColors.length - 3],
        0.22 * a * (0.4 + 0.6 * k),
      );
    }
  }
}

// ---- plus signs

/// A plus sign of light centred on `(x, y)`: arm length [armLen] (`1..4`) and thickness [th] (`1` or `3`).
void plus(
  Painter p,
  double x,
  double y,
  int armLen,
  int th,
  List<int> rampColors, [
  double a = 1.0,
  bool glint = false,
]) {
  final n = rampColors.length;
  final xi = holyRound(x);
  final yi = holyRound(y);
  final w = th > 1 ? 1 : 0;
  bool ins(int i, int j) =>
      (i.abs() <= w && j.abs() <= armLen) ||
      (j.abs() <= w && i.abs() <= armLen);
  for (var j = -armLen - 1; j <= armLen + 1; j++) {
    for (var i = -armLen - 1; i <= armLen + 1; i++) {
      if (!ins(i, j)) {
        if (w != 0 &&
            (ins(i - 1, j) ||
                ins(i + 1, j) ||
                ins(i, j - 1) ||
                ins(i, j + 1))) {
          p.dot(xi + i, yi + j, rampColors[math.max(0, n - 6)], a * 0.9);
        }
        continue;
      }
      int c;
      if (w == 0) {
        c = i == 0 && j == 0
            ? kWhite
            : (i.abs() + j.abs() >= armLen
                ? rampColors[n - 3]
                : rampColors[n - 2]);
      } else if (i == 0 && j == 0) {
        c = kWhite;
      } else if (i == 0 || j == 0) {
        c = i.abs() + j.abs() < armLen
            ? rampColors[n - 2]
            : rampColors[n - 3];
      } else {
        c = i < 0 || j < 0 ? rampColors[n - 3] : rampColors[n - 5];
      }
      if (glint && ((i == 0 && j == -armLen) || (i == -armLen && j == 0))) {
        c = kWhite;
      }
      p.dot(xi + i, yi + j, c, a);
    }
  }
}
