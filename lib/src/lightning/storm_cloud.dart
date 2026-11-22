// The bolt's forked shape, its halo-body-core inking and its flicker follow Sprite Fusion's open-source
// lightning (https://www.spritefusion.com/pixel-art-vfx/lightning), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

import 'lightning_lib.dart';

const int _fps = 30;
const int _n = 90;
const double _period = 3.0;
const double _base = -100.0;
const double _top = -156.0;
const double _th = 0.35;
final double _vis = math.sqrt(1.0 - math.sqrt(_th));

const List<(double x, double y, double v, double sq)> _billowsDef = [
  (-6, -132, 17, 1.0),
  (18, -127, 14, 1.0),
  (-28, -122, 12, 1.0),
  (38, -118, 10, 1.0),
  (0, -142, 12, 1.0),
  (14, -149, 19, 0.38),
  (40, -148, 14, 0.34),
  (-48, -113, 10, 1.0),
  (55, -110, 9, 1.0),
  (-17, -115, 13, 1.0),
  (22, -113, 12, 1.0),
  (-42, -104, 11, 1.0),
  (-10, -104, 12, 1.0),
  (20, -104, 11, 1.0),
  (48, -103, 9, 1.0),
  (-63, -104, 7, 1.0),
  (66, -103, 6, 1.0),
];

const List<(int f, int b, double k)> _flashes = [
  (7, 2, 0.8),
  (8, 9, 0.55),
  (29, 1, 0.75),
  (31, 10, 1.0),
  (33, 3, 0.5),
  (70, 0, 0.8),
  (71, 4, 0.55),
  (72, 5, 0.35),
];

const int _bolt = 52;
const int _boltB = 12;
const List<double> _bk = [1.0, 0.7, 0.3, 0.95, 0.5, 0.75, 0.2];
const int _w0 = -84;
const int _h0 = -162; // TOP - 6
const int _gw = 168;
const int _gh = 70; // BASE + 8 - H0

final Float32List _field = Float32List(_gw * _gh);
final Float32List _gx = Float32List(_gw * _gh);
final Float32List _gy = Float32List(_gw * _gh);
final Float32List _lit = Float32List(_gw * _gh);

class _Billow {
  final double sq;
  final double x;
  final double y;
  final double r;
  const _Billow(this.sq, this.x, this.y, this.r);
}

List<_Billow> _billows(int seed, double ph) {
  return List.generate(_billowsDef.length, (i) {
    final (x, y, v, sq) = _billowsDef[i];
    final top = y < -112.0 && sq == 1.0;
    final sinBoil = math.sin(math.pi * ((ph + i * 0.37) % 1.0));
    final boil = 0.82 + 0.3 * sinBoil * sinBoil;
    return _Billow(
      sq,
      x +
          3.5 * loopNoise(ph, 0.7, seed + i) +
          (sq < 1.0 ? 4.0 * loopNoise(ph, 0.5, seed + i + 90) : 0.0),
      y +
          2.0 * loopNoise(ph, 0.7, seed + i + 30) -
          (top ? 4.0 * (boil - 0.97) : 0.0),
      (v * (top ? boil : 1.0 + 0.08 * loopNoise(ph, 0.6, seed + i + 60))) /
          _vis,
    );
  });
}

void _cloud(
  Painter p,
  List<_Billow> bs,
  double ph,
  int seed,
  List<int> kCols,
  List<int> cCols,
  Map<int, double> flashes,
) {
  _field.fillRange(0, _field.length, 0.0);
  _gx.fillRange(0, _gx.length, 0.0);
  _gy.fillRange(0, _gy.length, 0.0);
  _lit.fillRange(0, _lit.length, 0.0);

  for (var i = 0; i < bs.length; i++) {
    final b = bs[i];
    final k = flashes[i] ?? 0.0;
    final r2 = b.r * b.r;
    final ry = b.r * b.sq;
    final yStart = math.max(0, (b.y - ry - _h0).floor());
    final yEnd = math.min(_gh, (b.y + ry - _h0).ceil());
    final xStart = math.max(0, (b.x - b.r - _w0).floor());
    final xEnd = math.min(_gw, (b.x + b.r - _w0).ceil());
    for (var y = yStart; y < yEnd; y++) {
      for (var x = xStart; x < xEnd; x++) {
        final dx = x + _w0 + 0.5 - b.x;
        final dy = (y + _h0 + 0.5 - b.y) / b.sq;
        final d2 = (dx * dx + dy * dy) / r2;
        if (d2 >= 1.0) continue;
        final j = y * _gw + x;
        final u = 1.0 - d2;
        final c = u * u;
        _field[j] += c;
        _gx[j] += (-4.0 * u * dx) / r2;
        _gy[j] += (-4.0 * u * dy) / (r2 * b.sq);
        if (k != 0.0) _lit[j] += k * (0.25 + 0.75 * c);
      }
    }
  }

  final rampCols = [...kCols, cCols[3], cCols[4], cCols[5], cCols[6]];
  final n = kCols.length;
  for (var y = 0; y < _gh; y++) {
    final cy = y + _h0 + 0.5;
    for (var x = 0; x < _gw; x++) {
      final j = y * _gw + x;
      if (_field[j] < _th - 0.06) continue;
      final cx = x + _w0 + 0.5;
      final base =
          _base + 1.5 * tileNoise(cx * 0.12 + 9.0 * ph, 3.0, 9, 0, seed + 5);
      final fVal = _field[j] * (1.0 - smooth(base - 3.0, base, cy)) +
          0.05 * tileNoise(cx * 0.21 + 18.0 * ph, cy * 0.21, 18, 0, seed);
      if (fVal < _th) continue;
      final glRaw = hypot(_gx[j], _gy[j]);
      final gl = glRaw == 0.0 ? 1.0 : glRaw;
      final lam = -(_gx[j] * 0.42 + _gy[j] * 0.9) / gl;
      final edge = math.min(1.0, gl * 5.0) * (fVal < _th + 0.08 ? 1.0 : 0.55);
      final h = 1.0 - 2.0 * clamp((cy - _top) / (_base - _top));
      var idxF = 2.7 +
          2.2 * h +
          1.3 * lam * edge +
          0.4 * tileNoise(cx * 0.16 + 12.0 * ph, cy * 0.16, 12, 0, seed + 9);
      if (fVal < _th + 0.05 && lam > 0.3 && h > -0.5) idxF += 1.0;
      if (cy > base - 6.0) idxF -= 1.0;
      var idx = clampInt(jsRound(idxF), 0, n - 1);
      final lVal = _lit[j] *
          (0.7 +
              0.6 *
                  tileNoise(
                    cx * 0.2 - 14.0 * ph,
                    cy * 0.2,
                    14,
                    0,
                    seed + 3,
                  ));
      if (lVal > 0.12) {
        idx = math.min(rampCols.length - 1, idx + jsRound(lVal * 5.5));
      }
      p.px(cx, cy, rampCols[idx]);
    }
  }
}

void _scud(Painter p, double ph, int seed, List<int> kCols) {
  final r = rng(seed, 13);
  for (var w = 0; w < 6; w++) {
    final x0 = r.range(-60.0, 60.0);
    final y0 = _base + r.range(3.0, 9.0);
    final rx = r.range(10.0, 20.0);
    final ry = r.range(1.3, 2.2);
    final off = r.next();
    final u = (ph + off) % 1.0;
    final a = math.pow(math.sin(math.pi * u), 0.8).toDouble();
    final xc = x0 + 16.0 * (u - 0.5);
    final y0i = (y0 - ry - 1.0).floor();
    final y1d = y0 + ry + 1.0;
    final x0i = (xc - rx - 1.0).floor();
    final x1d = xc + rx + 1.0;
    for (var y = y0i; y <= y1d; y++) {
      for (var x = x0i; x <= x1d; x++) {
        final dx = (x + 0.5 - xc) / rx;
        final dy = (y + 0.5 - y0) / ry;
        final nz = tileNoise(
          (x + 0.5) * 0.35 + 10.0 * ph + w * 7.0,
          (y + 0.5) * 0.5,
          10,
          0,
          seed + 20 + w,
        );
        final v = (1.0 - dx * dx - dy * dy) * a + 0.6 * nz - 0.25;
        if (v > 0.0) {
          p.blend(
            x + 0.5,
            y + 0.5,
            v > 0.4 ? kCols[2] : kCols[3],
            math.min(0.6, 0.2 + v * 0.7),
          );
        }
      }
    }
  }
}

final PureEffect stormCloudEffect = PureEffect(
  meta: const EffectMeta(
    id: 'lightning/storm-cloud',
    name: 'Storm cloud',
    desc:
        'A storm cloud boils overhead, billows lit from inside by flickering discharges, ragged scud under its flat dark base; rain slants down and once a loop a bolt cracks to the floor.',
    category: 'lightning',
    tags: ['lightning', 'storm', 'weather', 'cloud', 'rain', 'ambient', 'loop'],
    size: (168, 176),
    origin: (84, 164),
    duration: 3.0,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': voltPalette,
      'sparks': plasmaSparks,
      'cloud': [
        '#09070f',
        '#120f1e',
        '#1b182e',
        '#252640',
        '#323758',
        '#464d78',
        '#646b9c',
      ],
      'rain': ['#2b3250', '#46527a', '#6d7cab', '#a5b5e0'],
      'seed': 8,
    },
  ),
  onDraw: (Painter p, double t, Map<String, Object?> o) {
    final c = fit(o.palette, 8);
    final kCols = fit((o['cloud'] as List).cast<Object>(), 7);
    final rn = fit((o['rain'] as List).cast<Object>(), 4);
    final sparks =
        (o['sparks'] as List).cast<Object>().map(hex).toList(growable: false);
    final seed = o.seed;
    final f = (t * _fps + 1e-6).floor() % _n;
    final ph = f / _n;
    final bs = _billows(seed, ph);
    final br = rng(seed, 5, _bolt);
    final ba = f - _bolt;
    final bx0 = _billowsDef[_boltB].$1 + br.range(-4.0, 4.0);
    final bx1 = br.range(-24.0, 24.0);

    final flashes = <int, double>{
      for (final (ff, b, k) in _flashes)
        if (ff == f) b: k,
    };
    if (ba >= 0 && ba < _bk.length) {
      flashes[_boltB] = math.max(flashes[_boltB] ?? 0.0, _bk[ba]);
    }
    final lights = [
      for (final entry in flashes.entries)
        (
          x: bs[entry.key].x,
          y: bs[entry.key].y,
          k: entry.value,
          r: bs[entry.key].r *
              _vis *
              (bs[entry.key].sq < 1.0 ? 1.6 : 2.2),
        ),
    ];
    var flash = 0.0;
    for (final l in lights) {
      if (l.k > flash) flash = l.k;
    }

    cycle(t, _period, 150, seed + 11, (g) => g.range(0.5, 0.62),
        (age, life, r, _) {
      final x0 = r.range(-62.0, 62.0);
      final vy = r.range(190.0, 240.0);
      final vx = -vy * 0.18;
      final tf = (0.0 - (_base + 4.0)) / vy;
      if (age < tf) {
        final x = x0 + vx * age;
        final y = _base + 4.0 + vy * age;
        final l = r.range(4.0, 6.5);
        p.lineShaded(
          x - vx * 0.018 * (l / 4.0),
          y - l,
          x,
          y,
          color: (u) => u > 0.7
              ? (flash > 0.5 ? c[5] : rn[3])
              : (flash > 0.5 ? c[3] : rn[u > 0.35 ? 2 : 1]),
        );
      } else if (age < tf + 0.12) {
        final x = x0 + vx * tf;
        final a = (age - tf) / 0.12;
        for (final s in const [-1, 1]) {
          p.px(
            x + s * (1.0 + a * 2.5),
            -1.0 - math.sin(a * math.pi) * 2.5,
            a < 0.5 ? rn[3] : rn[2],
          );
        }
        if (a < 0.4) p.px(x, 0, rn[3]);
      }
    });

    _scud(p, ph, seed, kCols);
    _cloud(p, bs, ph, seed, kCols, c, flashes);
    for (final l in lights) {
      p.glow(l.x, l.y, l.r, c[4], 0.4 * l.k);
    }
    p.glow(0, -122, 80, c[2], 0.05 + 0.22 * flash);

    for (final (ff, b, k) in _flashes) {
      if (ff == f && k > 0.6) {
        final r = rng(seed, 7, ff);
        final x = bs[b].x;
        crackle(
          p,
          zigzag(
            r,
            x - r.range(12.0, 22.0),
            _base - r.range(2.0, 6.0),
            x + r.range(12.0, 22.0),
            _base - r.range(1.0, 5.0),
            0.25,
            0.5,
          ),
          0.6,
          c,
          0.4,
        );
      }
    }

    if (ba >= 0 && ba < _bk.length) {
      final k = _bk[ba];
      boltStrokeWith(
        p,
        zigzag(rng(seed, 9, _bolt), bx0, _base - 3.0, bx1, 0.0, 0.22, 0.7),
        k,
        c,
        s: ba == 0 ? 1.15 : 1.0,
        hero: ba == 0,
      );
      p.circle(bx1, -1, 3.0 * k + 1.5, c[2]);
      p.circle(bx1, -1, 3.0 * k + 0.5, c[5]);
      p.circle(bx1, -1, 2.0 * k, kWhite);
      p.glow(bx1, -22, 78, c[3], 0.5 * k);
      p.glow(bx1, -3, 18, c[5], 0.45 * k);
      p.glow(bx0, _base, 84, c[4], 0.3 * k);
    }

    final sa = (((t - _bolt / _fps) % _period) + _period) % _period;
    for (var j = 0; j < 16; j++) {
      final q = rng(seed, 31, j);
      final life = q.range(0.25, 0.6);
      if (sa >= life) continue;
      final a = -math.pi / 2.0 + q.range(-1.3, 1.3);
      final sp = q.range(60.0, 200.0);
      final (x, y, vx, vy) = lightningFlight(
        bx1,
        -1.0,
        math.cos(a) * sp,
        math.sin(a) * sp,
        sa,
        floor: 0.0,
      );
      lightningSpark(p, x, y, vx, vy, 1.0 - sa / life, sparks);
    }
  },
);
