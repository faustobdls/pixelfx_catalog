import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pixelfx_core/pixelfx_core.dart';
import 'shadow_lib.dart';

const double _d = 2.4;
const int _gx = 22;
const int _gy = 60;

class _Tongue {
  const _Tongue(this.dx, this.h0, this.w, this.n);
  final double dx;
  final double h0;
  final double w;
  final int n;
}

const List<_Tongue> _tongues = [
  _Tongue(-11, 20, 4.2, 1),
  _Tongue(11, 22, 4.4, 2),
  _Tongue(-6, 31, 5.4, 3),
  _Tongue(6, 29, 5.2, 4),
  _Tongue(0, 40, 6.6, 5),
];

class _Layer {
  const _Layer(this.lw, this.lh, this.tone);
  final double lw;
  final double lh;
  final int tone;
}

const List<_Layer> _layers = [
  _Layer(1.0, 1.0, 0),
  _Layer(0.8, 0.88, 1),
  _Layer(0.54, 0.68, 2),
  _Layer(0.32, 0.48, 3),
];

double _lnoise(double t, double v, int seed, [double speed = 5]) => noise2(
  math.cos((tau * t) / _d) * speed + v,
  math.sin((tau * t) / _d) * speed,
  seed,
);

void _drawBack(Painter p, double t, Map<String, Object?> o) {
  final C = fit(o.palette, 8);
  final S = o.seed;
  p.ellipseShaded(
    0,
    0.5,
    22,
    3.2,
    color: (d, _) => d < 0.6 ? C[0] : C[1],
    alpha: (d, _) => d < 0.85 ? 1.0 : (1 - d) * 6,
  );
  p.glow(0, -2, 46, C[4], 0.3);

  cycle(t, _d, 14, S + 1, (r) => r.range(1.2, 1.9), (age, L, r, _) {
    final u = age / L;
    final x = r.range(-6, 6) + math.sin(u * 4 + r.range(0, 6)) * 5 * u;
    final y = -30 - u * r.range(36, 52);
    final rad = 3 + u * 6;
    final a = math.min(1.0, u * 6) * (1 - u) * 0.7;
    p.disc(x, y, rad, mix(mix(C[3], C[2], 0.5), C[1], u), a);
    p.disc(x - rad * 0.2, y - rad * 0.3, rad * 0.5, C[3], a * 0.4);
    p.disc(x, y + rad * 0.45, rad * 0.55, C[5], a * 0.45 * (1 - u));
  });
}

void _draw(Painter p, double t, Map<String, Object?> o) {
  final C = fit(o.palette, 8);
  final S = o.seed;
  final toneColors = [C[6], C[4], C[2], C[0]];
  final grid = Int8List(_gx * 2 * _gy)..fillRange(0, _gx * 2 * _gy, -1);

  void setCell(int x, int y, int v) {
    final i = x + _gx;
    final j = y + _gy;
    if (i >= 0 && j >= 0 && i < _gx * 2 && j < _gy) {
      grid[j * _gx * 2 + i] = v;
    }
  }

  final order = [0, 1, 2, 3, 4]
    ..sort((a, b) => _tongues[b].dx.abs().compareTo(_tongues[a].dx.abs()));
  for (final i in order) {
    final tg = _tongues[i];
    final h = tg.h0 * (0.78 + 0.22 * _lnoise(t, tg.n * 3.0, tg.n, 4));
    final sway = _lnoise(t, tg.n * 7.0, tg.n + 9, 3) * 3;
    for (final layer in _layers) {
      final hl = h * layer.lh;
      for (int r = 0; r <= hl; r++) {
        final u = r / math.max(1.0, hl);
        final half =
            tg.w *
                layer.lw *
                math.pow(1 - u, 0.85) *
                math.min(1.0, (r + 1.5) / 3.5) +
            _lnoise(t, r * 0.45 + tg.n, tg.n + 20, 6) * 1.1 +
            _lnoise(t, r * 1.3 + tg.n * 5, tg.n + 50, 9) * 0.6;
        final cx =
            tg.dx +
            sway * u * u * layer.lh +
            _lnoise(t, r * 0.2 + tg.n * 2, tg.n + 30, 5) * u * 1.4;
        if (half < 0.3) continue;
        final xStart = (cx - half + 0.5).floor();
        final xEnd = (cx + half + 0.5).floor();
        for (int x = xStart; x <= xEnd; x++) {
          if (layer.tone == 0 &&
              u > 0.45 &&
              _lnoise(t, x * 0.9 + r * 0.7 + tg.n, tg.n + 60, 8) > 0.35) {
            continue;
          }
          setCell(x, -r, layer.tone);
        }
      }
    }
  }

  for (int j = 0; j < _gy; j++) {
    for (int i = 0; i < _gx * 2; i++) {
      final v = grid[j * _gx * 2 + i];
      if (v < 0) continue;
      final x = i - _gx;
      final y = j - _gy;
      int c = toneColors[v];
      if (v == 0 && y < -24 && (j == 0 || grid[(j - 1) * _gx * 2 + i] < 0)) {
        c = y < -32 ? kWhite : C[7];
      }
      p.px(x + 0.5, y + 0.5, c);
    }
  }

  cycle(t, _d, 34, S, (r) => r.range(0.25, 0.5), (age, L, r, _) {
    final u = age / L;
    final k = r.intRange(0, 4);
    final tg = _tongues[k];
    final x = tg.dx + r.range(-4, 4) + u * r.range(-5, 5);
    final y = -tg.h0 * r.range(0.45, 0.85) - u * r.range(10, 20);
    final rad = r.range(1, 2.2) * (1 - u) + 0.3;
    p.circle(x, y, rad + 0.6, u < 0.5 ? C[6] : C[4]);
    if (rad > 1) p.circle(x, y + 0.4, rad * 0.5, u < 0.3 ? C[2] : C[4]);
  });

  cycle(t, _d, 30, S + 2, (r) => r.range(1, 1.8), (age, L, r, _) {
    final u = age / L;
    final x = r.range(-12, 12) + math.sin(u * 6 + r.range(0, 6)) * 5 * u;
    final y = -10 - u * r.range(40, 70);
    if (u > 0.7 && math.sin(age * 40 + x) < 0) return;
    p.px(x, y, u < 0.3 ? kWhite : u < 0.6 ? C[7] : C[6]);
    p.glow(x, y, 3, C[6], 0.35 * (1 - u));
  });

  final fl = 0.85 + 0.15 * _lnoise(t, 0, 77, 6);
  p.glow(0, -16, 52, C[4], 0.5 * fl);
  p.glow(0, -12, 26, C[6], 0.34 * fl);
  for (int j = 0; j < _gy; j++) {
    for (int i = 0; i < _gx * 2; i++) {
      if (grid[j * _gx * 2 + i] == 3) {
        final sx = p.cellX(i - _gx + 0.5, j - _gy + 0.5) - p.ox;
        final sy = p.cellY(i - _gx + 0.5, j - _gy + 0.5) - p.oy;
        if (sx >= 0 && sy >= 0 && sx < p.w && sy < p.h) {
          p.frame.light[sy * p.w + sx] = 0;
        }
      }
    }
  }
}

final PixelEffect shadowFlamesEffect = PureEffect(
  meta: const EffectMeta(
    id: 'shadow/shadow-flames',
    name: 'Shadow flames',
    desc:
        'Inside-out fire on the floor: a black heart wrapped in violet flame with pale skin and tips, shedding embers and dark smoke.',
    category: 'shadow',
    kind: AssetKind.effect,
    tags: ['shadow', 'fire', 'flame', 'ground', 'dark', 'magic', 'loop'],
    size: (104, 112),
    origin: (52, 102),
    duration: 2.4,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {'palette': kVoidPalette, 'seed': 12},
  ),
  onDrawBack: _drawBack,
  onDraw: _draw,
);
