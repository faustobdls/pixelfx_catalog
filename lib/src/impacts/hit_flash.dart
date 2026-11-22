import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';

const Pose _blown = Pose(
  x: -5.0,
  crouch: 4.0,
  lean: -5.0,
  hx: -1.0,
  fx: 8.0,
  fy: -33.0,
  bx: -11.0,
  by: -27.0,
  ffx: 9.0,
  ffy: -7.0,
  fbx: -6.0,
);

final SimulatedEffect hitFlashEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'impacts/hit-flash',
    name: 'Hit flash',
    desc:
        'The character takes damage: a white frame, then their own colors flushed red and blinking white, cooling off, while comic hit lines jab in at them.',
    category: 'impacts',
    tags: [
      'impact',
      'hit',
      'damage',
      'hurt',
      'flash',
      'blink',
      'actor',
      'comic',
      'one-shot',
    ],
    size: (80, 64),
    origin: (40, 54),
    duration: 0.5,
    loop: false,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#14040a',
        '#3a0a14',
        '#6a101c',
        '#a01824',
        '#d42a30',
        '#ff5a50',
        '#ff9a8a',
      ],
      'lines': 7,
      'side': 1,
      'seed': 17,
    },
  ),
  act: ActSpec(
    onBody: true,
    poses: [
      PoseKey(-0.26, kReady.copyWith(x: 0.0)),
      const PoseKey(0.0, _blown, PoseEase.snap),
      PoseKey(0.16, _blown.copyWith(x: -8.0, crouch: 5.0)),
      PoseKey(
        0.42,
        _blown.copyWith(
          x: -8.0,
          crouch: 5.0,
          lean: -2.0,
          fx: 9.0,
          fy: -22.0,
          bx: 6.0,
          by: -20.0,
          ffy: -4.0,
        ),
      ),
      PoseKey(0.86, kReady.copyWith(x: 0.0)),
    ],
    hits: const [HitSpec(t: 0.0, stop: 0.07, shake: 0.14, amp: 2.0)],
  ),
  onCreate: (o) => _HitFlashSim(o),
);

const List<(double, String)> _beats = [
  (0.025, 'white'),
  (0.058, 'white2'),
  (0.125, 'red'),
  (0.158, 'rim'),
  (0.36, 'cool'),
];

class _HitLine {
  final double a;
  final double d;
  final double len;
  final double t0;

  const _HitLine({
    required this.a,
    required this.d,
    required this.len,
    required this.t0,
  });
}

class _HitFlashSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final ActorDefinition a;
  final ActorMask m;
  final Uint32List px;
  final double s;
  late final double cx;
  late final double cy;
  late final double hx;
  late final double hy;
  final Lights lights = Lights();
  late final Uint32List reds;
  late final Uint32List tints;
  late final List<_HitLine> lines;
  double t = 0.0;

  _HitFlashSim(Map<String, Object?> o)
      : c = fit(o.palette, 7),
        r = Rng(o.seed),
        a = o.actor,
        m = o.actor.mask,
        px = o.actor.pixels,
        s = o.numOpt('side', 1.0) {
    cx = a.chest.$1;
    cy = a.chest.$2;
    hx = cx + s * 12.0;
    hy = cy - 5.0;
    lights.add(hx, hy, 34.0, kWhite, 0.6, 0.1);
    lights.add(cx, cy, 30.0, c[4], 0.5, 0.35);

    reds = Uint32List(px.length);
    tints = Uint32List(px.length);
    for (var i = 0; i < px.length; i++) {
      if (px[i] == 0) continue;
      final col = px[i] | 0xff000000;
      final l = luma(col);
      reds[i] = c[clampInt((2.0 + l * 5.0 + 0.5).floor(), 2, 6)];
      tints[i] = mix(col, c[4], 0.55);
    }

    final nLines = o.intOpt('lines', 7);
    lines = List<_HitLine>.generate(nLines, (i) {
      final ang = -math.pi -
          0.3 +
          ((i + r.range(0.25, 0.75)) / nLines) * (math.pi + 0.6);
      return _HitLine(
        a: ang,
        d: r.range(15.0, 19.0),
        len: r.range(6.0, 9.0),
        t0: r.range(0.0, 0.04),
      );
    });
  }

  String? _beat() {
    for (final (end, b) in _beats) {
      if (t < end) return b;
    }
    return null;
  }

  void _body(Painter p, int Function(int i) color) {
    p.maskShaded(m, a.x, a.y, color: (mx, my) => color(my * m.w + mx));
  }

  @override
  void update(double dt, Map<String, Object?> opts) {
    t += dt;
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final b = _beat();
    if (b == 'white' || b == 'white2') {
      _body(p, (_) => kWhite);
      p.outline(m, a.x, a.y, b == 'white' ? c[6] : c[5]);
    } else if (b == 'red') {
      _body(p, (i) => reds[i]);
      p.outline(m, a.x, a.y, c[5]);
    } else if (b == 'rim') {
      p.outline(m, a.x, a.y, kWhite);
    } else if (b == 'cool') {
      final k = 1.0 - (t - 0.158) / (0.36 - 0.158);
      _body(p, (i) => mix(px[i] | 0xff000000, tints[i], k));
      if (k > 0.5) {
        p.outline(m, a.x, a.y, c[4], (k - 0.5) * 2.0);
      }
    }

    if (t < 0.07) {
      final big = t < 0.035 ? 1.0 : 1.3;
      final k = t < 0.035 ? 0 : 1;
      for (var i = 0; i < 8; i++) {
        final ang = (i / 8) * tau + 0.2;
        final l = (i.isOdd ? 4.0 : 9.0) * big;
        p.lineShaded(
          hx + math.cos(ang) * l * 0.45 * k,
          hy + math.sin(ang) * l * 0.45 * k,
          hx + math.cos(ang) * l,
          hy + math.sin(ang) * l,
          color: (u) =>
              u < 0.45 && k == 0 ? kWhite : (u < 0.75 ? c[6] : c[4]),
        );
      }
      if (k == 0) {
        const offsets = [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)];
        for (final (dx, dy) in offsets) {
          p.px(hx + dx, hy + dy, kWhite);
        }
      }
      p.glow(hx, hy, 14.0, c[6], 0.5 * (1.0 - t / 0.07));
    }

    for (final l in lines) {
      final u = (t - l.t0) / 0.16;
      if (u < 0.0 || u >= 1.0) continue;
      final d0 = l.d - 6.0 * Ease.outCubic(u);
      final len = l.len * (1.0 - u);
      final ca = math.cos(l.a);
      final sa = math.sin(l.a) * 1.15;
      if (len < 1.0) continue;
      final w = (2.8 - 1.6 * u) / 2.0;
      final nx = -sa * w;
      final ny = ca * w;
      final ex = cx + ca * (d0 + len);
      final ey = cy + sa * (d0 + len);
      final px0 = cx + ca * d0;
      final py0 = cy + sa * d0;
      p.poly([
        (px0 - ca, py0 - sa),
        (ex + nx * 1.5 + ca, ey + ny * 1.5 + sa),
        (ex - nx * 1.5 + ca, ey - ny * 1.5 + sa),
      ], c[3]);
      p.poly([
        (px0, py0),
        (ex + nx, ey + ny),
        (ex - nx, ey - ny),
      ], u < 0.5 ? kWhite : c[6]);
    }

    final k = math.exp(-t / 0.08);
    if (k > 0.02) {
      p.glow(
        cx,
        cy,
        26.0,
        b == 'white' || b == 'white2' ? kWhite : c[5],
        0.35 * k,
      );
    }
    lights.draw(p);
  }
}
