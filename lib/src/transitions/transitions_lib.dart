// Shared by the screen transitions: a 320 x 180 screen with its origin at the top-left.
// glint() is adapted from Sprite Fusion's open-source sparkle
// (https://www.spritefusion.com/pixel-art-vfx/sparkle), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const int kScreenW = 320;
const int kScreenH = 180;

EffectMeta screenMeta({
  required String id,
  required String name,
  required String desc,
  required List<String> tags,
  required double duration,
  Map<String, Object?> options = const {},
}) {
  return EffectMeta(
    id: id,
    name: name,
    desc: desc,
    category: 'transitions',
    tags: ['transition', 'screen', ...tags, 'one-shot'],
    size: (kScreenW, kScreenH),
    origin: (0, 0),
    duration: duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.sky,
    defaultOptions: {
      'color': '#0b0a10',
      'seed': 1,
      ...options,
    },
  );
}

class ClippedScreenPainter extends Painter {
  ClippedScreenPainter(super.frame);

  void syncFrom(Painter p) {
    reset();
    tx = p.tx;
    ty = p.ty;
    fx = p.fx;
    cs = p.cs;
    sn = p.sn;
    fade = p.fade;
    lightK = p.lightK;
    layer = p.layer;
  }

  bool inside(int sx, int sy) {
    final lx = fromX(sx + 0.5, sy + 0.5);
    final ly = fromY(sx + 0.5, sy + 0.5);
    return lx >= 0.0 && ly >= 0.0 && lx < kScreenW && ly < kScreenH;
  }

  @override
  void put(int sx, int sy, int c, [double a = 1.0]) {
    if (inside(sx, sy)) super.put(sx, sy, c, a);
  }

  @override
  void add(int sx, int sy, int c, [double k = 1.0]) {
    if (inside(sx, sy)) super.add(sx, sy, c, k);
  }

  @override
  void blendPx(int sx, int sy, int c, double a) {
    if (inside(sx, sy)) super.blendPx(sx, sy, c, a);
  }
}

final Expando<ClippedScreenPainter> _clippedScreens = Expando();

Painter clipTo(Painter p) {
  var q = _clippedScreens[p];
  if (q == null) {
    q = ClippedScreenPainter(p.frame);
    _clippedScreens[p] = q;
  }
  q.syncFrom(p);
  return q;
}

bool _unrotated(Painter p) => p.sn == 0.0 && p.cs == 1.0;

int _col0(Painter p) => p.fx > 0 ? (p.tx + 0.5).floor() : (p.tx - 0.5).floor();

void fastRect(Painter p, double x, double y, double w, double h, int c) {
  if (!_unrotated(p)) {
    p.rect(x, y, w, h, c);
    return;
  }
  final x0 = x.round();
  final x1 = (x + w).round();
  final y0 = y.round();
  final y1 = (y + h).round();
  final fx = p.fx;
  final b = _col0(p);
  for (var yy = y0; yy < y1; yy++) {
    final sy = (p.ty + yy + 0.5).floor();
    for (var xx = x0; xx < x1; xx++) {
      p.put(b + fx * xx, sy, c, 1.0);
    }
  }
}

void transitionGlint(
  Painter p,
  double x,
  double y,
  double lenTotal,
  double ang,
  int c1,
  int c2, [
  double a = 1.0,
]) {
  if (lenTotal < 0.8 || a <= 0.0) return;
  for (var i = 0; i < 8; i++) {
    final diag = i % 2 == 1;
    final an = ang + (i * tau) / 8.0;
    final len = diag ? lenTotal * 0.42 : lenTotal;
    final ca = math.cos(an);
    final sa = math.sin(an);
    for (var d = 0.0; d <= len; d += 0.5) {
      final u = d / len;
      final c = diag
          ? (u < 0.5 ? c1 : c2)
          : (u < 0.3 ? kWhite : (u < 0.65 ? c1 : c2));
      p.dot(
        x + ca * d,
        y + sa * d,
        c,
        a * (u < 0.7 ? 1.0 : 1.0 - (u - 0.7) / 0.35),
      );
      if (!diag && u < 0.22 && lenTotal > 4.0) {
        p.dot(x + ca * d - sa, y + sa * d + ca, c1, a);
        p.dot(x + ca * d + sa, y + sa * d - ca, c1, a);
      }
    }
  }
  p.dot(x, y, kWhite, a);
  p.glow(x, y, 4.0 + lenTotal * 1.4, c1, 0.5 * a);
  p.glow(x, y, 2.0 + lenTotal * 0.5, kWhite, 0.4 * a);
}

double lifeLeft(double life, double t, double end) => math.min(life, end - t);
