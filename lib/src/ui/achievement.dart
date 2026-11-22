import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ui_lib.dart';

const double _pw = 130.0;
const double _ph = 34.0;
const double _px = -_pw / 2.0;
const double _py = -_ph / 2.0;
const double _inT = 0.2;
const double _medal = 0.26;
const double _shine = 0.95;
const double _outT = 1.92;
const double _mx = _px + 17.0;
const double _my = 2.0;

final PanelColors _ink = PanelColors(
  outline: hex('#0d0a14'),
  rim: hex('#5a4f74'),
  top: hex('#2a2338'),
  body: hex('#211b2d'),
  low: hex('#15111c'),
);

final int _subMid = hex('#9a94b0');
final int _subLight = hex('#d8d4e6');
final int _subUnder = hex('#6e6886');

void _drawMedal(
  Painter p,
  List<int> g,
  List<int> b,
  double x,
  double y,
  double s,
  bool white,
  double? shine,
) {
  final r = 10.0 * s;
  for (final sd in const [-1, 1]) {
    p.polyShaded(
      [
        (x + sd * 2.0 * s, y - r + 2.0),
        (x + sd * 7.0 * s, y - r + 2.0),
        (x + sd * 9.0 * s, _py + 1.0),
        (x + sd * 4.0 * s, _py + 1.0),
      ],
      color: (px, _) => (px - x).abs() < 4.5 * s ? b[2] : b[3],
    );
    p.line(x + sd * 2.0 * s, y - r + 2.0, x + sd * 4.0 * s, _py + 1.0, b[0]);
    p.line(x + sd * 7.0 * s, y - r + 2.0, x + sd * 9.0 * s, _py + 1.0, b[0]);
  }

  final st = star(x, y + 0.5, 2.8 * s, 6.5 * s, 5);
  bool inStar(double px, double py) {
    var inside = false;
    for (var i = 0, j = st.length - 1; i < st.length; j = i++) {
      final (xi, yi) = st[i];
      final (xj, yj) = st[j];
      if ((yi > py) != (yj > py) &&
          px < ((xj - xi) * (py - yi)) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  p.shade(x - r - 1.0, y - r - 1.0, x + r + 1.0, y + r + 1.0, (px, py, _) {
    final dx = px - x;
    final dy = py - y;
    final d = hypot(dx, dy);
    if (d > r) return null;
    if (white) return r - d < 1.0 ? g[6] : kWhite;
    if (r - d < 1.0) return g[0];
    final l = -(dx * 0.6 + dy * 0.8) / r;
    if (shine != null && (dx - dy * 0.6 - shine).abs() < 1.2) return kWhite;
    if (r - d < 2.5) return l > 0.2 ? g[6] : (l > -0.3 ? g[4] : g[3]);
    if (inStar(px, py)) {
      return (!inStar(px + 1.0, py) ||
              !inStar(px - 1.0, py) ||
              !inStar(px, py + 1.0) ||
              !inStar(px, py - 1.0))
          ? g[2]
          : (dx + dy < 0.0 ? g[7] : g[6]);
    }
    return l > 0.4 ? g[5] : (l > -0.2 ? g[4] : g[3]);
  });
}

class _AchievementSim extends BaseEffectSim {
  final List<int> g;
  final List<int> b;
  final Rng r;
  late final Particles ps;
  final Lights lights = Lights();
  late final SpelledWord title;
  late final SpelledWord sub;
  static const double _tx = _px + 34.0;
  static const double _end = 2.4 - 0.05;

  double t = 0.0;
  bool popped = false;

  _AchievementSim(Map<String, Object?> o)
      : g = fit(o.palette, 8),
        b = fit(o.rampOpt('ribbon'), 5),
        r = Rng(o.seed) {
    ps = Particles(rng: r, sparks: [g[7], g[6], g[5], g[3]]);
    title = spell(o.strOpt('title', 'ACHIEVEMENT'), PixelFontKind.mini);
    sub = spell(o.strOpt('text', 'UNLOCKED'), PixelFontKind.mini);
  }

  double _xAt(double time) {
    if (time < _inT) return 30.0 * math.pow(1.0 - time / _inT, 3);
    if (time < _outT) {
      return -3.0 *
          math.exp(-(time - _inT) * 12.0) *
          math.sin((time - _inT) * 30.0);
    }
    final u0 = seg(time, _outT, _outT + 0.06);
    if (u0 < 1.0) return -3.0 * u0;
    return -3.0 + 33.0 * Ease.inQuad(seg(time, _outT + 0.06, _outT + 0.24));
  }

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    if (!popped && t >= _medal + 0.06) {
      popped = true;
      lights.add(_mx, _my, 36, g[5], 0.7, 0.4);
      for (var i = 0; i < 12; i++) {
        final an = (i / 12.0) * tau + r.range(-0.2, 0.2);
        final sp = r.range(40.0, 90.0);
        ps.spawn(
          P.star,
          _mx + math.cos(an) * 9.0,
          _my + math.sin(an) * 9.0,
          math.cos(an) * sp,
          math.sin(an) * sp * 0.6,
          r.range(0.25, 0.45),
          r.pick([g[7], g[6], g[5]]),
          i % 3 != 0 ? 0.6 : r.range(1.2, 1.8),
        );
      }
    }
    if (t > 0.5 && t < _outT && r.chance(0.05)) {
      ps.spawn(
        P.star,
        _mx + r.range(-11.0, 11.0),
        _my + r.range(-11.0, 9.0),
        0.0,
        -r.range(4.0, 10.0),
        math.min(r.range(0.3, 0.5), _end - t),
        g[6],
        r.chance(0.3) ? 1.4 : 0.6,
      );
    }
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final x = _xAt(t);
    final out = t > _outT + 0.06;
    final a = t < 0.05
        ? 0.5
        : (out ? 1.0 - seg(t, _outT + 0.12, _outT + 0.24) : 1.0);
    if (a <= 0.0) return;

    final moving = t < _inT * 0.8 || out;
    if (moving) {
      final f = (t * 30.0).floor();
      for (var i = 0; i < 8; i++) {
        final y = _py + 3.0 + rand(f, i, 1) * (_ph - 6.0);
        final len = 10.0 + rand(f, i, 2) * 26.0;
        final x0 = x + _pw / 2.0 + 2.0 + rand(i, 3) * 6.0;
        p.lineShaded(
          x0,
          y,
          math.min(106.0, x0 + len),
          y,
          color: (u) => u < 0.3 ? kWhite : (u < 0.6 ? g[6] : g[4]),
          alpha: (u) => a * (1.1 - u),
        );
      }
    }

    final sh = seg(t, _shine, _shine + 0.36);
    final shine = (sh > 0.0 && sh < 1.0)
        ? _px - 12.0 + (_pw + 30.0) * Ease.inOutSine(sh)
        : null;
    panel(
      p,
      _px + x,
      _py,
      _pw,
      _ph,
      _ink,
      r: 4.0,
      a: a,
      shine: shine == null ? null : shine + x,
    );
    p.line(_px + x + 4.0, _py + 1.0, _px + x + _pw - 5.0, _py + 1.0, g[4], a);
    p.px(_px + x + 3.0, _py + 1.0, g[2]);

    final ti = [
      for (final l in title.letters)
        if (l.g != null)
          WordLetter(g: l.g!, x: _tx + x + l.x * 2.0, y: _py + 5.0, sx: 2.0, sy: 2.0, a: a),
    ];
    drawWord(
      p,
      ti,
      WordStyle(
        fill: [g[4], g[5], g[6]],
        edge: g[7],
        under: g[3],
        outline: _ink.outline,
        shine: shine == null ? null : shine + x,
        shineY: _py,
        glint: g[7],
      ),
    );

    final si = [
      for (final l in sub.letters)
        if (l.g != null)
          WordLetter(g: l.g!, x: _tx + x + l.x * 2.0, y: _py + 19.0, sx: 2.0, sy: 2.0, a: a),
    ];
    drawWord(
      p,
      si,
      WordStyle(
        fill: [_subMid, _subLight, kWhite],
        edge: kWhite,
        under: _subUnder,
        outline: _ink.outline,
        shine: shine == null ? null : shine + x,
        shineY: _py,
      ),
    );

    final mk = t - _medal;
    if (mk > 0.0) {
      final s = mk < 0.035
          ? 1.5
          : 1.0 + 0.35 * math.exp(-mk * 16.0) * math.cos(mk * 28.0);
      _drawMedal(
        p,
        g,
        b,
        _mx + x,
        _my,
        s,
        mk < 0.07,
        shine == null ? null : shine - _mx + 4.0,
      );
      p.glow(
        _mx + x,
        _my,
        20,
        g[5],
        0.3 * a + (mk < 0.15 ? 0.5 * (1.0 - mk / 0.15) : 0.0),
      );
      final gl = ((t - 1.5).remainder(0.9)) / 0.9;
      if (t > 1.5 && gl < 0.25) {
        sparkle(
          p,
          _mx + x - 4.0,
          _my - 4.0,
          4.0 * math.sin((gl / 0.25) * math.pi),
          g[7],
          g[6],
          0.5,
        );
      }
    }

    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect achievementEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ui/achievement',
    name: 'Achievement',
    desc:
        'A toast slides in on speed lines and settles; a gold medal pops onto it in a burst of sparkles, a shine sweeps the whole toast, then it slides away.',
    category: 'ui',
    tags: ['ui', 'achievement', 'toast', 'medal', 'reward', 'text', 'one-shot'],
    size: (220, 72),
    origin: (110, 36),
    duration: 2.4,
    loop: false,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#2a1405',
        '#5c3008',
        '#9a5a0e',
        '#d48e18',
        '#f5b92c',
        '#ffde5e',
        '#fff4bc',
        '#ffffff',
      ],
      'ribbon': ['#0c1430', '#1f3a7a', '#2f66c4', '#5aa0f0', '#a6d4ff'],
      'title': 'ACHIEVEMENT',
      'text': 'UNLOCKED',
      'seed': 9,
    },
  ),
  onCreate: _AchievementSim.new,
);
