import 'package:pixelfx_core/pixelfx_core.dart';

const double _duration = 2.4;
const int _fps = 30;
final int _nf = ((_duration * _fps) + 0.5).floor();

const Pose _twitchA = Pose(
  turn: 0.3,
  lean: 3.0,
  crouch: 1.0,
  fx: 13.0,
  fy: -31.0,
  bx: 6.0,
  by: -14.0,
  hx: 1.0,
);
const Pose _twitchB = Pose(
  turn: 1.2,
  lean: -3.0,
  crouch: 0.0,
  fx: -9.0,
  fy: -14.0,
  bx: 14.0,
  by: -31.0,
  hx: -1.0,
);
const Pose _fine = Pose();

final ActSpec _act = ActSpec(
  onBody: true,
  poses: [
    const PoseKey(0.0, _fine),
    const PoseKey(0.3, _twitchA, PoseEase.snap),
    const PoseKey(0.37, _twitchB, PoseEase.snap),
    const PoseKey(0.44, _twitchA, PoseEase.snap),
    const PoseKey(0.53, _fine, PoseEase.snap),
    const PoseKey(1.1, _twitchB, PoseEase.snap),
    const PoseKey(1.23, _fine, PoseEase.snap),
    const PoseKey(1.7, _twitchA, PoseEase.snap),
    PoseKey(1.8, _twitchB.copyWith(crouch: 3.0), PoseEase.snap),
    const PoseKey(1.9, _twitchA, PoseEase.snap),
    const PoseKey(2.0, _twitchB, PoseEase.snap),
    const PoseKey(2.07, _fine, PoseEase.snap),
    const PoseKey(2.4, _fine),
  ],
);

const List<(int, int, double)> _bursts = [
  (9, 16, 0.8),
  (33, 37, 0.5),
  (51, 62, 1.0),
];

void _draw(Painter p, double t, Map<String, Object?> o) {
  final c = fit(o.palette, 7);
  final a = o.actor;
  final s = o.seed;
  final red = c[2];
  final cyan = c[4];
  final f = (t * _fps + 1e-6).floor() % _nf;

  (int, int, double)? burst;
  for (final b in _bursts) {
    if (f >= b.$1 && f <= b.$2) {
      burst = b;
      break;
    }
  }
  final k = burst?.$3 ?? 0.0;

  double r(int n0, [int? n1]) => rand(s, f, n0, n1);

  final split = burst != null
      ? ((1.0 + r(1) * 3.0 * k) + 0.5).floor() * (r(2) < 0.5 ? -1 : 1)
      : 0;
  final tears = <(int y0, int h, int dx, double tint)>[];
  if (burst != null) {
    for (var i = 0; i < 1 + (r(3) * 4.0 * k).floor(); i++) {
      tears.add((
        a.y + (r(4, i) * a.h).floor(),
        1 + (r(5, i) * 5.0).floor(),
        (((r(6, i) - 0.5) * 16.0 * k) + 0.5).floor(),
        r(7, i),
      ));
    }
  }
  if (burst == null && r(8) < 0.07) {
    tears.add((a.y + (r(9) * a.h).floor(), 1, r(10) < 0.5 ? -2 : 2, 1.0));
  }
  final interlace = burst != null && r(11) < 0.3;
  final roll =
      burst != null && r(12) < 0.15 ? -2 - (r(13) * 2.0).floor() : 0;
  final poster = burst != null && r(14) < 0.15 * k;

  (int, double)? tearAt(int y) {
    for (final tr in tears) {
      if (y >= tr.$1 && y < tr.$1 + tr.$2) return (tr.$3, tr.$4);
    }
    return null;
  }

  final bar = a.y +
      (((t / _duration) * 2.0 * (a.h + 12)) % (a.h + 12)) -
      6.0;

  if (split != 0) {
    for (var my = 0; my < a.h; my++) {
      for (var mx = 0; mx < a.w; mx++) {
        if (a.mask.data[my * a.w + mx] == 0) continue;
        final y = a.y + my + roll;
        final tr = tearAt(a.y + my);
        final dx = tr?.$1 ?? 0;
        p.px(a.x + mx + dx - split, y, red);
        p.px(a.x + mx + dx + split, y, cyan);
      }
    }
  }

  for (var my = 0; my < a.h; my++) {
    final ry = a.y + my;
    final y = ry + roll;
    if (interlace && (my & 1) != 0) continue;
    final tr = tearAt(ry);
    final dx = tr?.$1 ?? 0;
    final tint = tr != null && tr.$2 < 0.35
        ? (tr.$2 < 0.18 ? red : cyan)
        : 0;
    final near = (ry - bar).abs();
    for (var mx = 0; mx < a.w; mx++) {
      final colPx = a.pixels[my * a.w + mx];
      if (colPx == 0) continue;
      var col = colPx;
      if (poster) {
        col = luma(colPx) > 0.32 ? c[5] : c[1];
      } else if (tint != 0) {
        col = mix(colPx, tint, 0.6);
      } else if (near < 1.0) {
        col = mix(colPx, c[5], 0.35);
      }
      p.px(a.x + mx + dx, y, col);
    }
    if (tr != null && dx.abs() > 2 && rand(s, f, ry) < 0.6) {
      final right = dx > 0;
      var mx = -1;
      if (right) {
        for (var i = 0; i < a.w; i++) {
          if (a.mask.data[my * a.w + a.w - 1 - i] != 0) {
            mx = a.w - 1 - i;
            break;
          }
        }
      } else {
        for (var i = 0; i < a.w; i++) {
          if (a.mask.data[my * a.w + i] != 0) {
            mx = i;
            break;
          }
        }
      }
      if (mx >= 0 && mx < a.w) {
        final colPx = a.pixels[my * a.w + mx];
        final l = 4 + (rand(s, f, ry, 1) * 10.0).floor();
        for (var i = 1; i <= l; i++) {
          p.dot(
            a.x + mx + dx + (right ? i : -i),
            y,
            colPx,
            1.0 - i / (l + 1),
          );
        }
      }
    }
  }

  if (roll != 0) {
    for (var my = 0; my < -roll; my++) {
      for (var mx = 0; mx < a.w; mx++) {
        final colPx = a.pixels[my * a.w + mx];
        if (colPx != 0 && ((mx + my) & 1) != 0) {
          p.px(a.x + mx, a.y + a.h + roll + my, mix(colPx, c[1], 0.5));
        }
      }
    }
  }

  if (burst != null) {
    for (var i = 0; i < 2 + (r(20) * 5.0 * k).floor(); i++) {
      final w = 2 + (r(21, i) * 9.0).floor();
      final h = 1 + (r(22, i) * 3.0).floor();
      final x = a.x - 6 + (r(23, i) * (a.w + 12)).floor();
      final y = a.y + (r(24, i) * a.h).floor();
      final col = [kWhite, red, cyan, c[5], c[3]][(r(25, i) * 5.0).floor()];
      if (r(26, i) < 0.4) {
        for (var yy = 0; yy < h; yy++) {
          for (var xx = 0; xx < w; xx++) {
            p.px(x + xx, y + yy, ((xx + yy) & 1) != 0 ? col : c[0]);
          }
        }
      } else {
        p.rect(x, y, w, h, col);
      }
    }
  }

  for (final (ba, bb, kk) in _bursts) {
    final age = (f - ba + _nf) % _nf;
    if (age > bb - ba + 8) continue;
    for (var i = 0; i < 10 * kk; i++) {
      final life = 4 + (rand(s, ba, i) * 6.0).floor();
      final at = (rand(s, ba, i, 1) * (bb - ba + 1)).floor();
      final q = age - at;
      if (q < 0 || q > life || (q > life / 2.0 && (q & 1) != 0)) continue;
      final x0 = a.x + rand(s, ba, i, 2) * a.w;
      final y0 = a.y + rand(s, ba, i, 3) * a.h;
      final side = rand(s, ba, i, 4) < 0.5 ? -1 : 1;
      p.px(
        x0 + side * q * (1.0 + rand(s, ba, i, 5) * 2.0),
        y0 - q * 0.5,
        [kWhite, red, cyan][i % 3],
      );
    }
  }

  if (burst != null) {
    if (f == burst.$1) {
      p.glow(a.x + a.w / 2.0, a.y + a.h / 2.0, 26, c[5], 0.4);
    }
    p.glow(a.x + a.w / 2.0 - split * 4.0, a.y + a.h / 2.0, 18, red, 0.18 * k);
    p.glow(a.x + a.w / 2.0 + split * 4.0, a.y + a.h / 2.0, 18, cyan, 0.18 * k);
  }
  if ((bar - (a.y + a.h / 2.0)).abs() < a.h / 2.0 + 3.0) {
    p.glowLine(a.x - 2, bar, a.x + a.w + 2, bar, 4, c[4], 0.12);
  }
}

final PixelEffect glitchEffect = PureEffect(
  meta: const EffectMeta(
    id: 'scifi/glitch',
    name: 'Glitch',
    desc:
        "The hero's signal breaks up in bursts: an RGB split, slices torn sideways, rows smeared out, junk blocks and dead pixels, then snaps back clean.",
    category: 'scifi',
    tags: [
      'scifi',
      'glitch',
      'digital',
      'corrupt',
      'hologram',
      'status',
      'loop',
    ],
    size: (88, 64),
    origin: (44, 54),
    duration: _duration,
    loop: true,
    fps: _fps,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#14101f',
        '#3b1f5c',
        '#ff2e63',
        '#ff7aa8',
        '#2ef2ff',
        '#b4fbff',
        '#ffffff',
      ],
      'seed': 7,
    },
  ),
  act: _act,
  onActorAlpha: (_, _) => 0.0,
  onDraw: _draw,
);
