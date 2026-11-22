import 'dart:math' as math;
import 'package:pixelfx_core/pixelfx_core.dart';
import 'shadow_lib.dart';

const double _cy = -52;
const double _fb = -32;
const double _fh = 34;
const double _rx = 42;
const double _ry = 11;
const double _tilt = -0.12;
const double _d = 3;
const int _n = 5;

const List<String> _skullSprite = [
  '...kkkkk...',
  '.kkhhhllkk.',
  'khhhhlllmmk',
  'khhllllllmk',
  'kleeeleeemk',
  'kleeeleeedk',
  'kmleelleedk',
  '.kmllnllmk.',
  '.kmmlnlmdk.',
  '..kmmmmmk..',
  '..ktgtgtk..',
  '...kkkkk...',
];

class _SkullPos {
  const _SkullPos(this.x, this.y, this.z, this.a);
  final double x;
  final double y;
  final double z;
  final double a;
}

_SkullPos _skullAt(int i, double t) {
  final a = (tau * t) / _d + (i * tau) / _n;
  final ex = math.cos(a) * _rx;
  final ey = math.sin(a) * _ry;
  final bob = math.sin((tau * 2 * t) / _d + i * 1.7) * 2;
  return _SkullPos(
    ex * math.cos(_tilt) - ey * math.sin(_tilt),
    _cy + ex * math.sin(_tilt) + ey * math.cos(_tilt) + bob,
    math.sin(a),
    a,
  );
}

void _tail(Painter p, List<int> C, int i, double t) {
  for (int k = 8; k >= 1; k--) {
    final tt = t - k * 0.05;
    final s = _skullAt(i, tt);
    final age = k / 8;
    final r = 2 + age * 3.6;
    final a = (1 - age) * 0.5 * (0.6 + 0.4 * (s.z + 1) / 2);
    p.disc(
      s.x,
      s.y - age * 7 + 2,
      r,
      age < 0.4 ? C[5] : age < 0.7 ? C[4] : C[3],
      a,
    );
  }
}

void _drawSkull(
  Painter p,
  List<int> C,
  List<int> K,
  _SkullPos s,
  double t,
  int i,
) {
  final front = s.z >= 0;
  final depth = 0.55 + 0.45 * (s.z + 1) / 2;
  final pal = front
      ? {
          'k': K[0],
          'd': K[1],
          'm': K[2],
          'l': K[3],
          'h': K[4],
          'e': C[0],
          'n': C[0],
          't': K[3],
          'g': K[0],
        }
      : {
          'k': K[0],
          'd': K[0],
          'm': K[1],
          'l': K[2],
          'h': K[3],
          'e': C[0],
          'n': C[0],
          't': K[2],
          'g': K[0],
        };
  final x0 = (s.x + 0.5).floor() - 5;
  final y0 = (s.y + 0.5).floor() - 6;
  p.sprite(_skullSprite, pal, x0, y0);
  final k = (0.5 + 0.5 * math.sin((tau * 3 * t) / _d + i * 2.1)) * 0.5 + 0.5;
  for (final ex in const [3, 7]) {
    p.px(
      x0 + ex + 0.5,
      y0 + 5.5,
      front ? (k > 0.75 ? kWhite : C[7]) : C[6],
    );
    if (front) p.px(x0 + ex + 0.5, y0 + 4.5, C[5]);
    p.glow(x0 + ex + 1, y0 + 6, 6, C[5], 0.45 * depth * k);
  }
  p.glow(s.x, s.y, 11, C[4], 0.18 * depth);
}

void _flame(Painter p, List<int> C, double t) {
  const wBase = 10.0;
  final scroll = t / _d;
  p.shade(-wBase - 4, _fb - _fh - 4, wBase + 4, _fb + 2, (x, y, out) {
    final u = (_fb - y) / _fh;
    if (u < -0.04 || u >= 1) return null;
    final n1 = tileNoise(x * 0.3, y * 0.2 + scroll * 8, 0, 8, 3);
    final n2 = tileNoise(x * 0.6, y * 0.45 + scroll * 16, 0, 16, 5);
    final prof = u < 0.22
        ? 0.35 + 0.65 * math.sqrt(math.max(0.0, u) / 0.22)
        : math.pow(1 - (u - 0.22) / 0.78, 0.85).toDouble();
    final w = wBase * prof * (1 + 0.3 * n1) + n2 * 2.2 * u;
    final sway = n1 * 3 * u * u;
    final d = (x - sway).abs() / math.max(0.6, w);
    if (d > 1) return null;
    final heat =
        math.pow(1 - d, 0.7) * math.pow(math.max(0.0, 1 - u), 0.55) + n2 * 0.12;
    if (((x.floor() + y.floor()) & 1) == 0) out.k = 0.16 * heat;
    return heat > 0.82
        ? kWhite
        : heat > 0.66
            ? C[7]
            : heat > 0.46
                ? C[6]
                : heat > 0.27
                    ? C[5]
                    : heat > 0.12
                        ? C[4]
                        : C[3];
  });
  p.glow(0, _fb - _fh * 0.35, 40, C[5], 0.45);
  p.glow(0, _fb - 5, 12, C[7], 0.25);
}

void _drawBack(Painter p, double t, Map<String, Object?> o) {
  final C = fit(o.palette, 8);
  final K = fit(
    o['bone'] is List
        ? o.rampOpt('bone')
        : const ['#0c1a1c', '#2c4a4a', '#5c847c', '#a6cdb8', '#e4fff0'],
    5,
  );
  p.glow(0, -1, 40, C[4], 0.2);
  final order = <(int, _SkullPos)>[
    for (int i = 0; i < _n; i++) (i, _skullAt(i, t)),
  ].where((e) => e.$2.z < 0).toList()
    ..sort((a, b) => a.$2.z.compareTo(b.$2.z));
  for (final e in order) {
    _tail(p, C, e.$1, t);
  }
  for (final e in order) {
    _drawSkull(p, C, K, e.$2, t, e.$1);
  }
}

void _draw(Painter p, double t, Map<String, Object?> o) {
  final C = fit(o.palette, 8);
  final K = fit(
    o['bone'] is List
        ? o.rampOpt('bone')
        : const ['#0c1a1c', '#2c4a4a', '#5c847c', '#a6cdb8', '#e4fff0'],
    5,
  );
  final S = o.seed;

  cycle(t, _d, 18, S, (r) => r.range(0.8, 1.4), (age, L, r, _) {
    final x0 = r.range(-6, 6);
    final u = age / L;
    final x = x0 + math.sin(u * 5 + r.range(0, 6)) * 3 * u;
    final y = _fb - 6 - u * r.range(36, 56);
    p.dot(x, y, u < 0.5 ? C[7] : C[6], u < 0.7 ? 1.0 : (1 - u) * 3.3);
    p.glow(x, y, 3, C[6], 0.3 * (1 - u));
  });

  _flame(p, C, t);

  final order = <(int, _SkullPos)>[
    for (int i = 0; i < _n; i++) (i, _skullAt(i, t)),
  ].where((e) => e.$2.z >= 0).toList()
    ..sort((a, b) => a.$2.z.compareTo(b.$2.z));
  for (final e in order) {
    _tail(p, C, e.$1, t);
  }
  for (final e in order) {
    _drawSkull(p, C, K, e.$2, t, e.$1);
  }
  halo(p, 0, _cy, 0, 46, C[4], 0.12);
}

final PixelEffect necroSkullsEffect = PureEffect(
  meta: const EffectMeta(
    id: 'shadow/necro-skulls',
    name: 'Necro skulls',
    desc:
        'Spectral skulls circle a cold green flame on a tilted orbit, passing behind and before it, eyes lit, trailing curls of ghost smoke.',
    category: 'shadow',
    kind: AssetKind.effect,
    tags: [
      'shadow',
      'necromancy',
      'skull',
      'orbit',
      'ghost',
      'spectral',
      'magic',
      'loop',
    ],
    size: (136, 116),
    origin: (68, 108),
    duration: 3,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    defaultOptions: {
      'palette': [
        '#040e10',
        '#0a2228',
        '#0f3d44',
        '#16615f',
        '#23907f',
        '#45c4a0',
        '#9af0c8',
        '#e8fff4',
      ],
      'bone': ['#0c1a1c', '#2c4a4a', '#5c847c', '#a6cdb8', '#e4fff0'],
      'seed': 6,
    },
  ),
  onDrawBack: _drawBack,
  onDraw: _draw,
);
