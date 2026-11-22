import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'scifi_lib.dart';

const double _duration = 3.2;
const double _lock = 0.3;
const double _scan0 = 0.42;
const double _scan1 = 1.6;
const double _done = 1.75;
const double _let = 2.5;

const Pose _stiff = Pose(
  turn: 0.9,
  crouch: -1.0,
  fx: -7.0,
  fy: -14.0,
  bx: 8.0,
  by: -14.0,
  ffx: -3.0,
  fbx: 4.0,
);
const Pose _ok = Pose(
  turn: 0.9,
  fx: -9.0,
  fy: -37.0,
  bx: 8.0,
  by: -15.0,
  ffx: -3.0,
  fbx: 4.0,
);

const ActSpec _act = ActSpec(
  onBody: true,
  poses: [
    PoseKey(0.0, Pose()),
    PoseKey(0.3, _stiff, PoseEase.snap),
    PoseKey(1.75, _stiff),
    PoseKey(1.85, _ok, PoseEase.snap),
    PoseKey(2.5, _ok),
    PoseKey(2.8, Pose()),
    PoseKey(3.2, Pose()),
  ],
);

class _Body {
  final List<(int, int)> edge;
  final Map<int, (int, int)> rows;

  const _Body(this.edge, this.rows);
}

final Expando<_Body> _bodies = Expando<_Body>();

_Body _body(ActorDefinition a) {
  final hit = _bodies[a];
  if (hit != null) return hit;

  final m = a.mask;
  bool on(int x, int y) =>
      x >= 0 && y >= 0 && x < m.w && y < m.h && m.data[y * m.w + x] != 0;

  final edge = <(int, int)>[];
  final rows = <int, (int, int)>{};
  for (var y = -1; y <= m.h; y++) {
    for (var x = -1; x <= m.w; x++) {
      if (on(x, y)) {
        final ry = a.y + y;
        final rx = a.x + x;
        final r = rows[ry];
        rows[ry] = r == null ? (rx, rx) : (math.min(r.$1, rx), math.max(r.$2, rx));
      } else if (on(x - 1, y) || on(x + 1, y) || on(x, y - 1) || on(x, y + 1)) {
        edge.add((a.x + x, a.y + y));
      }
    }
  }
  final b = _Body(edge, rows);
  _bodies[a] = b;
  return b;
}

double _scanY(double t, ActorDefinition a) => lerp(
      a.y - 3.0,
      1.0,
      Ease.inOutSine(clamp((t - _scan0) / (_scan1 - _scan0))),
    );

double _scanT(int y, ActorDefinition a) =>
    _scan0 +
    ((_scan1 - _scan0) *
            math.acos(
              1.0 -
                  2.0 *
                      clamp((y + 0.5 - (a.y - 3.0)) / (4.0 - a.y)),
            )) /
        math.pi;

void _bracket(
  Painter p,
  double x,
  double y,
  int sx,
  int sy,
  double l,
  int c,
  int hot,
  double a,
) {
  p.line(x, y, x + sx * l, y, c, a);
  p.line(x, y, x, y + sy * l, c, a);
  p.line(x + sx, y + sy, x + sx * 3, y + sy, c, a * 0.6);
  p.dot(x, y, hot, a);
}

final Expando<Map<String, Ghosts>> _ghostCache = Expando<Map<String, Ghosts>>();

Ghosts _ghosts(
  Map<String, Object?> o,
  ActorDefinition a,
  List<int> c,
) {
  final pal = o.palette;
  final key = '${o.seed}:${pal.join(',')}';
  var byActor = _ghostCache[a];
  if (byActor == null) {
    byActor = {};
    _ghostCache[a] = byActor;
  }
  final hit = byActor[key];
  if (hit != null) return hit;

  final rows = _body(a).rows;
  final g = Ghosts(
    _duration,
    ground: (_) => 0.0,
    box: (-40.0, -58.0, 68.0, 9.0),
  );
  for (var y = a.y; y < 0; y += 3) {
    final r = rows[y];
    if (r == null) continue;
    for (final (x, s) in [(r.$1 - 1, -1), (r.$2 + 1, 1)]) {
      if (rand(o.seed, y, s) < 0.6) {
        g.add(
          _scanT(y, a),
          P.mote,
          x.toDouble(),
          y.toDouble(),
          s * (30.0 + 50.0 * rand(y, s, 3)),
          -10.0 + 20.0 * rand(y, s, 4),
          0.2 + 0.15 * rand(y, s, 5),
          rand(y, s, 6) < 0.4 ? kWhite : c[5],
          0.6,
        );
      }
    }
  }
  byActor[key] = g;
  return g;
}

void _draw(Painter p, double t, Map<String, Object?> o) {
  final c = fit(o.palette, 8);
  final a = o.actor;
  final b = _body(a);
  final edge = b.edge;
  final rows = b.rows;

  final bx0 = a.x - 4;
  final bx1 = a.x + a.w + 3;
  final by0 = a.y - 4;
  const by1 = 3;

  final lock = Ease.outBack(clamp(t / _lock), 2.2);
  final out = Ease.inCubic(clamp((t - _let) / 0.45));
  final spread = (1.0 - lock) * 14.0 + out * 12.0;
  final gone = t > _let + 0.45 ||
      (t > _let + 0.25 && ((t - _let) * 20.0).floor() % 2 == 1);
  final vis = gone ? 0.0 : 1.0;
  final flashOn = (t > _lock && t < _lock + 0.07) ||
      (t > _done && t < _done + 0.05) ||
      (t > _done + 0.12 && t < _done + 0.17);
  final bc = flashOn ? kWhite : c[5];
  const l = 7.0;

  if (vis > 0.0) {
    for (final (x, y, sx, sy) in [
      (bx0 - spread, by0 - spread, 1, 1),
      (bx1 + spread, by0 - spread, -1, 1),
      (bx0 - spread, by1 + spread, 1, -1),
      (bx1 + spread, by1 + spread, -1, -1),
    ]) {
      _bracket(p, x, y, sx, sy, l, bc, kWhite, vis);
      p.glow(x, y, 6, c[4], 0.35 * vis);
    }
  }

  final lk = (t - _lock) / 0.3;
  if (lk >= 0.0 && lk < 1.0) {
    final e = 3.0 + 10.0 * Ease.outCubic(lk);
    final col =
        lk < 0.25 ? kWhite : (lk < 0.5 ? c[6] : (lk < 0.75 ? c[5] : c[3]));
    p.line(bx0 - e, by0 - e, bx1 + e, by0 - e, col);
    p.line(bx0 - e, by1 + e, bx1 + e, by1 + e, col);
    p.line(bx0 - e, by0 - e, bx0 - e, by1 + e, col);
    p.line(bx1 + e, by0 - e, bx1 + e, by1 + e, col);
  }

  final sinceDone = since(t, _done, _duration);
  final pulse = sinceDone < 0.3 ? 1.0 - sinceDone / 0.3 : 0.0;
  final offY = lerp(a.y - 2.0, 2.0, clamp((t - _let) / 0.4));
  if (t > _scan0) {
    for (final (x, y) in edge) {
      final age = t - _scanT(y, a);
      if (age < 0.0 || (t > _let && y < offY)) continue;
      final col = pulse > 0.4
          ? kWhite
          : (age < 0.07
              ? kWhite
              : (age < 0.25
                  ? c[6]
                  : (age < 0.6 ? c[5] : (t > _let - 0.3 ? c[3] : c[4]))));
      p.px(x, y, col);
    }
  }

  if (t > _scan0 && t < _scan1) {
    final y = _scanY(t, a).floor();
    for (var k = 1; k <= 5; k++) {
      final r = rows[y - k];
      if (r != null) {
        for (var x = r.$1; x <= r.$2; x++) {
          if (a.mask.data[(y - k - a.y) * a.w + x - a.x] != 0) {
            p.blend(x + 0.5, y - k + 0.5, k < 2 ? c[6] : c[5], 0.55 - k * 0.09);
          }
        }
      }
    }
    final r = rows[y];
    for (var x = bx0 - 2; x <= bx1 + 2; x++) {
      final inside = r != null && x >= r.$1 && x <= r.$2;
      p.px(x, y, inside ? kWhite : c[6]);
      p.blend(x + 0.5, y - 0.5, c[5], 0.35);
    }
    p.glowLine(bx0, y, bx1, y, 6, c[5], 0.45);
    if (r != null) {
      for (final x in [r.$1 - 0.5, r.$2 + 1.5]) {
        sparkle(p, x, y + 0.5, 2, c[6], c[5], 0.3);
      }
    }
  }

  final lead = clamp((t - _lock) / 0.1);
  if (vis > 0.0 && lead > 0.0) {
    final px = bx1 + spread + 6.0;
    final py = by0 - spread + 2.0;
    final k = clamp((t - _scan0) / (_scan1 - _scan0));
    final ok = t > _done;
    p.line(
      bx1 + spread,
      by0 - spread,
      lerp(bx1 + spread, px - 1.0, lead),
      lerp(by0 - spread, py + 4.0, lead),
      c[3],
    );
    if (lead < 1.0) {
      _ghosts(o, a, c).at(t).draw(p);
      return;
    }
    p.line(px - 1.0, py + 4.0, px + 1.0, py + 4.0, c[3]);
    final del = clamp((t - _let) / 0.25);
    final full = ok ? 'OK' : '${(k * 100.0).floor()}%';
    final labelLen = (full.length * (1.0 - del)).ceil();
    final label = full.substring(0, math.max(0, labelLen));
    final blinkOk =
        ok && ((t - _done) * 8.0).floor() % 2 == 0 && t < _done + 0.5;
    if (label.isNotEmpty) {
      p.text(
        label,
        px + 2.0,
        py,
        blinkOk ? kWhite : c[6],
        font: PixelFontKind.mini,
        scale: 2,
        shadow: c[1],
      );
    }
    for (var i = 0; i < 10; i++) {
      if (i >= 10.0 * (1.0 - del)) break;
      final on = (i + 1) / 10.0 <= k + 1e-6 || ok;
      p.rect(
        px + 2.0 + i * 3.0,
        py + 13.0,
        2,
        3,
        on ? (ok ? c[6] : c[5]) : c[2],
      );
    }
    p.glow(px + 16.0, py + 6.0, 18, c[4], 0.2 * vis);
  }
  _ghosts(o, a, c).at(t).draw(p);
}

final PixelEffect scannerEffect = PureEffect(
  meta: const EffectMeta(
    id: 'scifi/scanner',
    name: 'Scanner',
    desc:
        'Brackets snap onto the hero, a scan line sweeps head to toe leaving a cooling outline, and a readout counts up to OK before it all lets go.',
    category: 'scifi',
    tags: ['scifi', 'scan', 'target', 'hud', 'tech', 'status', 'ui', 'loop'],
    size: (112, 78),
    origin: (42, 58),
    duration: _duration,
    loop: true,
    fps: 30,
    bg: BackdropKind.ground,
    actorScale: 2,
    defaultOptions: {
      'palette': [
        '#03140a',
        '#06301a',
        '#0c5a2c',
        '#16893e',
        '#2cc256',
        '#7cf08c',
        '#d0ffd4',
        '#ffffff',
      ],
      'seed': 22,
    },
  ),
  act: _act,
  onDraw: _draw,
);
