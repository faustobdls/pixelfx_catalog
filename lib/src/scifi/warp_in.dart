import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

const double _duration = 3.0;
const int _originY = 128;
const double _slam = 0.34;
const double _open = 0.52;
const double _scan0 = 0.62;
const double _scan1 = 1.4;
const double _cool = 0.42;
const double _done = _scan1 + _cool;
const double _close = 1.9;
const double _snap = 2.16;
const double _top = -_originY * 1.0;

const Pose _inPose = Pose(
  crouch: 7.0,
  lean: 3.0,
  fx: 9.0,
  fy: -12.0,
  bx: 12.0,
  by: -12.0,
  ffx: 8.0,
  fbx: -6.0,
);

const ActSpec _act = ActSpec(
  onBody: true,
  follow: 0.0,
  poses: [
    PoseKey(0.0, _inPose),
    PoseKey(1.82, _inPose),
    PoseKey(
      2.05,
      Pose(
        crouch: 3.0,
        fx: 8.0,
        fy: -19.0,
        bx: 8.0,
        by: -18.0,
        ffx: 4.0,
        fbx: -3.0,
      ),
    ),
    PoseKey(2.5, kReady),
    PoseKey(3.0, kReady),
  ],
);

double _scanY(double t, int y0) => lerp(
      y0 - 2.0,
      1.0,
      Ease.inOutSine(clamp((t - _scan0) / (_scan1 - _scan0))),
    );

double _scanT(int y, int y0) =>
    _scan0 +
    ((_scan1 - _scan0) *
            math.acos(
              1.0 -
                  2.0 * clamp((y + 0.5 - (y0 - 2.0)) / (3.0 - y0)),
            )) /
        math.pi;

double _widthAt(double t, double w) {
  if (t < _slam) return 0.0;
  if (t < _close) {
    return w *
        (1.0 +
            0.45 * math.exp(-(t - _slam) * 14.0) +
            0.03 * math.sin(t * 31.0));
  }
  return lerp(w, 0.7, Ease.outCubic(clamp((t - _close) / (_snap - _close))));
}

class _BodyPx {
  final int x;
  final int y;
  final int c;
  final bool edge;
  final double ts;
  final double j;

  const _BodyPx({
    required this.x,
    required this.y,
    required this.c,
    required this.edge,
    required this.ts,
    required this.j,
  });
}

class _WarpInSim extends BaseEffectSim {
  final List<int> c;
  final double w;
  final int seed;
  final Rng r;
  final ActorDefinition a;
  final Particles ps;
  final Lights lights = Lights();
  final List<_BodyPx> body;
  final Map<int, (int, int)> rows;
  final List<double> rings = [];

  double t = 0.0;
  bool slammed = false;
  bool snapped = false;
  double nextRing = _slam + 0.08;
  int lastRow;

  factory _WarpInSim.create(Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final w = o.numOpt('width', 15.0);
    final seed = o.seed;
    final r = Rng(seed);
    final a = o.actor;
    final ps = Particles(
      rng: r,
      ground: (_) => 0.0,
      sparks: [kWhite, c[6], c[5], c[3]],
      haze: c[5],
    );
    bool on(int x, int y) =>
        x >= 0 && y >= 0 && x < a.w && y < a.h && a.mask.data[y * a.w + x] != 0;

    final body = <_BodyPx>[];
    final rows = <int, (int, int)>{};
    for (var my = 0; my < a.h; my++) {
      for (var mx = 0; mx < a.w; mx++) {
        final i = my * a.w + mx;
        if (a.mask.data[i] == 0) continue;
        final x = a.x + mx;
        final y = a.y + my;
        final edge = !on(mx - 1, my) ||
            !on(mx + 1, my) ||
            !on(mx, my - 1) ||
            !on(mx, my + 1);
        final pxCol = a.pixels[i];
        body.add(_BodyPx(
          x: x,
          y: y,
          c: pxCol != 0 ? pxCol : c[2],
          edge: edge,
          ts: _scanT(y, a.y),
          j: rand(seed, mx, my),
        ));
        final row = rows[y];
        rows[y] = row == null ? (x, x) : (math.min(row.$1, x), math.max(row.$2, x));
      }
    }
    return _WarpInSim._(
      c: c,
      w: w,
      seed: seed,
      r: r,
      a: a,
      ps: ps,
      body: body,
      rows: rows,
      lastRow: a.y - 3,
    );
  }

  _WarpInSim._({
    required this.c,
    required this.w,
    required this.seed,
    required this.r,
    required this.a,
    required this.ps,
    required this.body,
    required this.rows,
    required this.lastRow,
  });

  void _column(Painter p) {
    final width = _widthAt(t, w);
    if (width <= 0.05 || t > _snap + 0.14) return;
    final bottom = t - _slam < 0.06
        ? lerp(
            _top,
            0.0,
            Ease.inCubic(clamp((t - _slam) / 0.06) * 0.5 + 0.5),
          )
        : (t > _snap
            ? lerp(0.0, _top, Ease.outExpo((t - _snap) / 0.14))
            : 0.0);
    final hero = t - _slam < 0.07;
    final hollow = 0.78 * smooth(_open - 0.16, _open, t);
    final thin = 1.0 - clamp((width - 1.5) / (w - 1.5));

    for (var y = _top.floor(); y < bottom; y++) {
      final pulse =
          ((((y - _top) * 0.028 - t * 2.6) % 1.0) + 1.0) % 1.0 < 0.09 ? 1 : 0;
      for (var x = (-width * 1.35).floor(); x <= (width * 1.35).ceil(); x++) {
        final q = (x + 0.5).abs() / width;
        if (q > 1.35) continue;
        if (hero) {
          p.dot(
            x,
            y,
            q < 0.55
                ? kWhite
                : (q < 0.8 ? c[6] : (q < 1.0 ? c[5] : c[4])),
            q < 1.0 ? 1.0 : (1.35 - q) / 0.35,
          );
          continue;
        }
        if (width < 2.4) {
          p.dot(
            x,
            y,
            q < 0.7 ? kWhite : c[6],
            q < 1.0 ? 1.0 : (1.35 - q) / 0.35,
          );
          continue;
        }
        var strand = 0;
        for (var s = 0; s < 5; s++) {
          if (((x + 0.5) / width -
                      (rand(seed, s) - 0.5) * 1.3 -
                      0.06 * math.sin(t * (1.5 + s) + s * 2.0))
                  .abs() <
              0.05) {
            strand = 1;
          }
        }
        if (q < hollow) {
          p.blend(
            x + 0.5,
            y + 0.5,
            strand != 0 || pulse != 0 ? c[6] : c[5],
            clamp(
              0.12 +
                  0.3 * q * q +
                  0.3 * strand +
                  0.25 * pulse +
                  0.7 * thin,
            ),
          );
        } else if (q < 0.78) {
          final lvl = math.max(
            0,
            (q < 0.22 ? 0 : (q < 0.45 ? 1 : 2)) - pulse - strand,
          );
          p.px(x, y, lvl == 0 ? kWhite : c[7 - lvl]);
        } else if (q < 0.96) {
          p.px(x, y, q > 0.86 && q < 0.93 ? kWhite : c[6]);
        } else {
          p.dot(x, y, q < 1.1 ? c[5] : c[4], (1.35 - q) / 0.39);
        }
      }
      if ((y & 7) == 0) {
        final rad = math.min(width + 8.0, y - _top + 2.0);
        if (hollow < 0.4) {
          p.glow(0, y, math.min(width * 2.6 + 6.0, y - _top + 2.0), c[4],
              hero ? 0.55 : 0.32);
        } else {
          for (final s in const [-1, 1]) {
            p.glow(s * (width + 3.0), y, rad, c[4], 0.24);
          }
        }
      }
    }
  }

  void _ring(Painter p, bool near) {
    final width = _widthAt(t, w);
    for (final t0 in rings) {
      final k = (t - t0) / 0.5;
      if (k < 0.0 || k >= 1.0) continue;
      final y = lerp(_top + 6.0, -1.0, Ease.inQuad(k));
      final rx = width * 1.18 + 1.0;
      final col = k < 0.25 ? kWhite : c[6];
      band(
        p,
        0.0,
        y,
        rx,
        2.6 / rx,
        1.5,
        1.0,
        [c[3], c[5], col, kWhite],
        keep: (g) => (math.sin(g) >= 0.0) == near,
      );
      if (near) p.glow(0, y, rx + 6.0, c[5], 0.25);
    }
  }

  void _floor(Painter p, bool near) {
    final on = t < _slam
        ? smooth(0.0, _slam, t) * 0.5
        : 1.0 - smooth(_snap, _snap + 0.5, t);
    if (!near && on > 0.01) {
      final rx = w * 1.9 + (t < _slam ? 0.0 : 2.0 * math.sin(t * 6.0));
      const ry = 4.0;
      for (var y = -4; y <= 4; y++) {
        for (var x = (-rx).floor(); x <= rx.ceil(); x++) {
          final d = hypot((x + 0.5) / rx, (y + 0.5) / ry);
          if (d > 1.0) continue;
          p.dot(
            x,
            y,
            d < 0.35
                ? c[7]
                : (d < 0.6 ? c[6] : (d < 0.85 ? c[5] : c[4])),
            on * clamp((1.05 - d) * 2.4),
          );
        }
      }
      for (final x in [-rx * 0.6, 0.0, rx * 0.6]) {
        p.glow(x, -1, rx * 1.3, c[4], 0.3 * on);
      }
    }
    bool keep(double g) => (math.sin(g) >= 0.0) == near;
    for (final t0 in rings) {
      final k = (t - t0 - 0.5) / 0.35;
      if (k >= 0.0 && k < 1.0) {
        band(
          p,
          0.0,
          0.0,
          w * (1.2 + 1.3 * Ease.outCubic(k)),
          0.16,
          1.5,
          1.0 - k,
          [c[3], c[4], c[5], c[6]],
          keep: keep,
        );
      }
    }
    for (final (d, s) in const [(0.0, 1.0), (0.08, 0.65)]) {
      final k = (t - _slam - d) / 0.55;
      if (k >= 0.0 && k < 1.0) {
        band(
          p,
          0.0,
          0.5,
          92.0 * s * Ease.outCubic(k),
          0.16,
          math.max(1.0, 5.0 * (1.0 - k)),
          1.15 - k,
          [c[3], c[5], c[6], kWhite],
          keep: keep,
          hot: k < 0.25,
        );
      }
    }
    final k = (t - _snap) / 0.45;
    if (k >= 0.0 && k < 1.0) {
      band(
        p,
        0.0,
        0.0,
        10.0 + 26.0 * Ease.outCubic(k),
        0.16,
        2.0 * (1.0 - k) + 0.5,
        1.1 - k,
        [c[4], c[5], c[6], kWhite],
        keep: keep,
        hot: k < 0.3,
      );
    }
  }

  void _hero(Painter p) {
    if (t >= _done || t < _scan0 - 0.2) return;
    final blink = (t * 24.0).floor();
    for (final b in body) {
      final age = t - b.ts;
      if (age < 0.0) {
        if (b.edge && rand(b.x, b.y, blink) < 0.6) {
          p.dot(
            b.x,
            b.y,
            c[1],
            0.8 * smooth(_scan0 - 0.25, _scan0 - 0.05, t),
          );
        }
        continue;
      }
      final k = age / _cool;
      final dx = age < 0.06 && b.j < 0.3 ? (b.j < 0.15 ? -1 : 1) : 0;
      p.px(
        b.x + dx,
        b.y,
        k < 0.18
            ? kWhite
            : (k < 0.45
                ? mix(b.c, c[6], 0.72)
                : (k < 0.75 ? mix(b.c, c[5], 0.38) : b.c)),
      );
      if (k < 0.5) p.light(b.x + dx, b.y, c[5], 0.22 * (1.0 - k / 0.5));
    }
  }

  void _scanline(Painter p) {
    if (t < _scan0 || t > _scan1) return;
    final y = _scanY(t, a.y).floor();
    final width = _widthAt(t, w) * 1.5;
    final row = rows[y];
    for (var x = (-width).floor(); x <= width.ceil(); x++) {
      final inside = row != null && x >= row.$1 && x <= row.$2;
      p.dot(
        x,
        y,
        inside ? kWhite : c[6],
        inside ? 1.0 : 1.0 - (x + 0.5).abs() / (width + 1.0),
      );
    }
    p.glowLine(-width, y, width, y, 5, c[5], 0.5);
    if (row != null) {
      sparkle(p, row.$1 + 0.5, y.toDouble(), 2, c[6], c[5], 0.3);
      sparkle(p, row.$2 + 0.5, y.toDouble(), 2, c[6], c[5], 0.3);
    }
  }

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    if (t < _slam - 0.04) {
      if (r.chance(0.8)) {
        final ang = r.range(-math.pi * 0.95, -math.pi * 0.05);
        final d = r.range(30.0, 64.0);
        final dur = r.range(0.18, 0.28);
        final v = (d * 3.0) / (math.exp(3.0 * dur) - 1.0);
        final x = math.cos(ang) * d;
        final y = math.sin(ang) * d * 0.8 - 2.0;
        final l = hypot(x, y + 2.0);
        final denom = l == 0.0 ? 1.0 : l;
        ps.spawn(
          P.streak,
          x,
          y,
          (-x / denom) * v,
          (-(y + 2.0) / denom) * v,
          dur,
          r.chance(0.5) ? c[6] : c[5],
        );
      }
      if (r.chance(0.12)) {
        final s = r.sign();
        ps.spawn(
          P.vapour,
          s * r.range(30.0, 56.0),
          -r.range(0.0, 2.0),
          -s * r.range(40.0, 70.0),
          -r.range(0.0, 4.0),
          r.range(0.3, 0.45),
          c[5],
          r.range(2.0, 3.0),
        );
      }
    }
    if (t >= _slam && !slammed) {
      slammed = true;
      lights.add(0.0, -40.0, 120.0, c[4], 1.0, 0.55);
      lights.add(0.0, -10.0, 44.0, kWhite, 0.9, 0.14);
      for (var i = 0; i < 34; i++) {
        final ang = -math.pi / 2.0 + r.sign() * r.range(0.35, 1.45);
        final sp = r.range(110.0, 270.0);
        ps.spawn(
          P.spark,
          r.range(-w, w) * 0.6,
          -1.0,
          math.cos(ang) * sp,
          math.sin(ang) * sp,
          r.range(0.25, 0.75),
        );
      }
      for (var i = 0; i < 18; i++) {
        final s = r.sign();
        ps.spawn(
          P.vapour,
          s * r.range(4.0, 18.0),
          -r.range(0.0, 4.0),
          s * r.range(40.0, 150.0),
          -r.range(2.0, 18.0),
          r.range(0.5, 0.95),
          r.chance(0.6) ? c[6] : c[5],
          r.range(3.0, 6.0),
        );
      }
      for (var i = 0; i < 10; i++) {
        ps.spawn(
          P.star,
          r.range(-w, w) * 1.3,
          -r.range(2.0, 40.0),
          r.range(-20.0, 20.0),
          -r.range(10.0, 40.0),
          r.range(0.4, 0.8),
          r.chance(0.5) ? kWhite : c[6],
          r.range(1.0, 2.2),
        );
      }
    }
    if (slammed && t < _close) {
      if (t >= nextRing) {
        rings.add(nextRing);
        nextRing += 0.17;
      }
      final width = _widthAt(t, w);
      if (r.chance(0.5)) {
        ps.spawn(
          P.streak,
          r.range(-0.8, 0.8) * width,
          _top + r.range(9.0, 36.0),
          0.0,
          r.range(60.0, 110.0),
          r.range(0.3, 0.45),
          r.chance(0.5) ? kWhite : c[6],
        );
      }
      if (r.chance(0.18)) {
        ps.spawn(
          P.star,
          r.sign() * width * r.range(0.8, 1.3),
          -r.range(4.0, 70.0),
          0.0,
          -r.range(5.0, 20.0),
          r.range(0.3, 0.6),
          c[6],
          r.range(0.6, 1.8),
        );
      }
      if (r.chance(0.1)) {
        final s = r.sign();
        ps.spawn(
          P.vapour,
          s * r.range(8.0, 16.0),
          -r.range(0.0, 3.0),
          s * r.range(20.0, 50.0),
          -r.range(2.0, 8.0),
          r.range(0.5, 0.8),
          c[5],
          r.range(2.5, 4.0),
        );
      }
    }
    if (t > _scan0 && t < _scan1) {
      final y = _scanY(t, a.y).floor();
      if (y != lastRow) {
        lastRow = y;
        final row = rows[y];
        if (row != null && r.chance(0.7)) {
          for (final (x, s) in [(row.$1, -1), (row.$2 + 1, 1)]) {
            if (r.chance(0.6)) {
              ps.spawn(
                P.mote,
                x.toDouble(),
                y.toDouble(),
                s * r.range(40.0, 90.0),
                r.range(-20.0, 10.0),
                r.range(0.15, 0.3),
                r.chance(0.5) ? kWhite : c[6],
                0.6,
              );
            }
          }
        }
      }
    }
    if (t >= _done && t - dt < _done) {
      for (var i = 0; i < 6; i++) {
        final b = body[(r.next() * body.length).floor()];
        ps.spawn(
          P.star,
          b.x + 0.5,
          b.y + 0.5,
          r.range(-6.0, 6.0),
          -r.range(6.0, 20.0),
          r.range(0.4, 0.8),
          r.chance(0.5) ? kWhite : c[6],
          r.range(1.0, 2.0),
        );
      }
    }
    if (t >= _snap && !snapped) {
      snapped = true;
      lights.add(0.0, -1.0, 32.0, c[4], 0.5, 0.25);
      lights.add(0.0, -1.0, 10.0, kWhite, 0.5, 0.08);
      for (var i = 0; i < 22; i++) {
        final ang = -math.pi / 2.0 + r.range(-1.4, 1.4);
        final sp = r.range(90.0, 260.0);
        ps.spawn(
          P.spark,
          r.range(-2.0, 2.0),
          -1.0,
          math.cos(ang) * sp,
          math.sin(ang) * sp,
          r.range(0.2, 0.6),
        );
      }
      for (var i = 0; i < 12; i++) {
        ps.spawn(
          P.star,
          r.range(-16.0, 16.0),
          -r.range(0.0, 46.0),
          r.range(-10.0, 10.0),
          -r.range(8.0, 26.0),
          r.range(0.5, 0.9),
          r.chance(0.5) ? kWhite : c[6],
          r.range(0.6, 1.8),
        );
      }
      for (var i = 0; i < 18; i++) {
        ps.spawn(
          r.chance(0.6) ? P.star : P.mote,
          r.range(-6.0, 6.0),
          -r.range(10.0, 100.0),
          r.range(-6.0, 6.0),
          -r.range(14.0, 40.0),
          r.range(0.5, 0.75),
          r.chance(0.4) ? kWhite : (r.chance(0.5) ? c[6] : c[5]),
          r.range(0.5, 1.4),
          r.range(0.0, 0.25),
        );
      }
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void drawBack(Painter p) {
    _floor(p, false);
    _ring(p, false);
    _column(p);
    if (t < _slam) {
      final aAlpha = smooth(0.0, _slam * 0.8, t) * 0.8;
      final head = lerp(_top, 0.0, Ease.outCubic(clamp(t / (_slam * 0.6))));
      for (var y = _top.toInt(); y < head; y++) {
        p.dot(
          0,
          y,
          (y & 1) == 0 ? c[6] : c[5],
          aAlpha * (0.35 + 0.65 * ((y - _top) / -_top)),
        );
      }
      p.glow(0, head, 10, c[5], 0.5 * aAlpha);
      final rx = lerp(34.0, 12.0, Ease.outCubic(t / _slam));
      final k = smooth(0.0, 0.15, t);
      for (var i = 0; i < 48; i++) {
        final g = (i / 48.0) * tau + t * 3.0;
        if ((i ~/ 4).isOdd) continue;
        p.dot(
          math.cos(g) * rx,
          math.sin(g) * rx * 0.16,
          i % 4 == 0 ? kWhite : c[5],
          k,
        );
      }
    }
    ps.draw(p, 'back');
  }

  @override
  void draw(Painter p) {
    _hero(p);
    _scanline(p);
    _ring(p, true);
    _floor(p, true);
    if (t >= _done && t < _done + 0.3) {
      p.outline(a.mask, a.x, a.y, c[6], 1.0 - (t - _done) / 0.3);
    }
    if (t > _slam && t < _slam + 0.16) {
      sparkle(p, 0, -2, 12.0 * (1.0 - (t - _slam) / 0.16), c[6], c[5], 0.6);
    }
    ps.draw(p, 'front');
    lights.draw(p);
  }
}

final PixelEffect warpInEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'scifi/warp-in',
    name: 'Warp in',
    desc:
        'A beam slams down, rings run down it and a scanline paints the hero in from head to toe, white-hot pixels cooling to their own colors; the beam pinches shut in sparks.',
    category: 'scifi',
    tags: [
      'scifi',
      'teleport',
      'warp',
      'beam',
      'spawn',
      'arrive',
      'one-shot',
    ],
    size: (192, 168),
    origin: (96, _originY),
    duration: _duration,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#0b1030',
        '#152a63',
        '#1d4f9e',
        '#2582d2',
        '#36b9ee',
        '#8ae8ff',
        '#d4fbff',
        '#ffffff',
      ],
      'width': 15,
      'seed': 3,
    },
  ),
  act: _act,
  onActorAlpha: (t, _) => t >= _done ? 1.0 : 0.0,
  onCreate: _WarpInSim.create,
);
