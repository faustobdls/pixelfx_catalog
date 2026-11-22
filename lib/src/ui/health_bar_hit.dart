import 'dart:math' as math;

import 'package:pixelfx_core/pixelfx_core.dart';

import 'ui_lib.dart';

const double _hit = 0.2;
const double _drain = 0.62;
const double _drained = 1.05;
const double _fold = 1.62;
const double _bx = -48.0;
const double _bw = 104.0;
const double _by = -4.0;
const double _bh = 8.0;
const int _cells = 10;

final PanelColors _ink = PanelColors(
  outline: hex('#0d0a14'),
  rim: hex('#4a4060'),
  top: hex('#2a2338'),
  body: hex('#1e1929'),
  low: hex('#141019'),
);

final int _paleMix = hex('#ffe9a8');
final int _trackDark = hex('#0d0a14');
final int _trackEmptyTop = hex('#2a2338');
final int _trackEmptyBody = hex('#191424');

class _HealthBarHitSim extends BaseEffectSim {
  final List<int> c;
  final Rng r;
  final int seed;
  final double from;
  final double to;
  late final Particles ps;
  final Bits bits = Bits();
  final Lights lights = Lights();
  late final int pale;
  late final Map<String, Object> pal;
  late final Map<String, Object> whitePal;
  late final PanelColors redInk;

  double t = 0.0;
  bool hit = false;

  _HealthBarHitSim(Map<String, Object?> o)
      : c = fit(o.palette, 8),
        r = Rng(o.seed),
        seed = o.seed,
        from = clamp(o.numOpt('from', 0.8)),
        to = clamp(math.min(o.numOpt('to', 0.45), clamp(o.numOpt('from', 0.8)))) {
    ps = Particles(rng: r, sparks: [c[7], c[6], c[5], c[3]]);
    pale = mix(c[6], _paleMix, 0.5);
    pal = heartPal(c);
    whitePal = {
      'k': 0,
      'w': kWhite,
      'h': kWhite,
      'o': kWhite,
      'm': kWhite,
      'd': c[6],
    };
    redInk = PanelColors(
      outline: c[4],
      rim: c[6],
      top: _ink.top,
      body: _ink.body,
      low: _ink.low,
    );
  }

  double _ghostAt(double time) => time < _drain
      ? from
      : from - (from - to) * Ease.inOutQuad(seg(time, _drain, _drained));

  @override
  void update(double dt, Map<String, Object?> options) {
    t += dt;
    if (!hit && t >= _hit) {
      hit = true;
      lights.add(_bx + (_bw * (to + from)) / 2.0, _by + 4.0, 50, c[5], 0.7, 0.3);
      lights.add(_bx + (_bw * (to + from)) / 2.0, _by + 4.0, 24, kWhite, 0.6, 0.08);
      for (var i = 0; i < 12; i++) {
        final x = _bx + _bw * r.range(to, from);
        final an = -math.pi / 2.0 + r.range(-1.2, 1.2);
        final sp = r.range(50.0, 130.0);
        bits.add(DebrisBit(
          kind: B.shard,
          x: x,
          y: _by + r.range(1.0, 7.0),
          vx: math.cos(an) * sp,
          vy: math.sin(an) * sp,
          g: 0.45,
          drag: 1.2,
          life: r.range(0.35, 0.6),
          a: r.range(0.0, tau),
          va: r.range(-20.0, 20.0),
          s: r.range(1.5, 3.0),
          c: r.pick([c[7], c[6], c[5], c[4]]),
        ));
      }
      for (var i = 0; i < 10; i++) {
        final an = r.range(0.0, tau);
        final sp = r.range(60.0, 160.0);
        ps.spawn(
          P.spark,
          _bx + _bw * r.range(to, from),
          _by + 4.0,
          math.cos(an) * sp,
          math.sin(an) * sp * 0.6 - 30.0,
          r.range(0.12, 0.26),
        );
      }
    }

    if (t > _drain && t < _drained && r.chance(0.5)) {
      final x = _bx + _bw * _ghostAt(t);
      ps.spawn(
        P.spark,
        x,
        _by + r.range(1.0, 7.0),
        r.range(-20.0, 60.0),
        -r.range(20.0, 70.0),
        r.range(0.1, 0.22),
      );
    }

    bits.update(dt);
    ps.update(dt);
    lights.update(dt);
  }

  @override
  void draw(Painter p) {
    final (jx, jy) = shake(t, 3.0, _hit, 0.28, seed);
    final dip = t > _hit
        ? (3.0 * math.exp(-(t - _hit) * 10.0) * math.cos((t - _hit) * 24.0) +
                0.5)
            .floor()
        : 0;
    final open = Ease.outBack(seg(t, 0.0, 0.14), 2.0) *
        (1.0 - Ease.inBack(seg(t, _fold, _fold + 0.18), 2.0));
    if (open > 0.04) {
      final ox = jx.toDouble();
      final oy = (jy + dip).toDouble();
      final h = 18.0 * open;
      final y0 = -9.0 + (18.0 - h) / 2.0;
      final red = t >= _hit && t < _hit + 0.07;
      panel(
        p,
        _bx - 22.0 + ox,
        y0 + oy,
        _bw + 26.0,
        h,
        red ? redInk : _ink,
        r: math.min(5.0, h / 2.0),
      );
      if (open > 0.75) {
        final val = t < _hit ? from : to;
        final ghost = t < _hit ? from : _ghostAt(t);
        final white = t >= _hit && t < _hit + 0.07;
        p.rect(_bx + ox, _by + oy, _bw, _bh, _trackDark);
        p.shade(
          _bx + ox,
          _by + oy,
          _bx + _bw + ox,
          _by + _bh + oy,
          (x, y, _) {
            final u = (x - _bx - ox) / _bw;
            final v = y - _by - oy;
            if (u < val) {
              return v < 1.0
                  ? c[6]
                  : (v < 2.0
                      ? c[5]
                      : (v < 5.0 ? c[4] : (v < 7.0 ? c[3] : c[2])));
            }
            if (u < ghost) {
              return white
                  ? kWhite
                  : (v < 1.0 ? kWhite : (v < 6.0 ? pale : c[5]));
            }
            return v < 1.0 ? _trackEmptyTop : _trackEmptyBody;
          },
        );
        for (var i = 1; i < _cells; i++) {
          p.rect(
            _bx + ox + ((_bw * i) / _cells + 0.5).floor(),
            _by + oy,
            1,
            _bh,
            _trackDark,
          );
        }
        if (t > _hit) {
          p.rect(
            _bx + ox + (_bw * val + 0.5).floor() - 1.0,
            _by + oy,
            1,
            _bh,
            c[7],
          );
        }
        if (t > _drain && t < _drained) {
          final gx = _bx + ox + _bw * ghost;
          p.rect(gx - 1.0, _by + oy - 1.0, 2, _bh + 2.0, kWhite);
          p.glow(gx, _by + oy + 4.0, 10, c[5], 0.6);
        }
        p.glow(_bx + ox + _bw * val * 0.5, _by + oy + 4.0, _bw * 0.4, c[3], 0.12);
        final hk = t - _hit;
        final hop = hk > 0.0
            ? (-3.0 *
                        math.exp(-hk * 12.0) *
                        math.cos(hk * 22.0).abs() +
                    0.5)
                .floor()
            : 0;
        p.sprite(kHeartSprite, pal, _bx - 17.0 + ox, oy - 6.0 + hop);
        if (hk > 0.0 && hk < 0.07) {
          p.sprite(kHeartSprite, whitePal, _bx - 17.0 + ox, oy - 6.0 + hop);
        }
        p.glow(
          _bx - 11.0 + ox,
          oy,
          10,
          c[4],
          0.25 + (hk > 0.0 && hk < 0.2 ? 0.4 : 0.0),
        );
        if (t < _hit && (t * 2.5).remainder(1.0) < 0.3) {
          sparkle(p, _bx - 14.0 + ox, oy - 3.0, 2.0, c[7], c[6], 0.3);
        }
      }
    }

    bits.draw(p);
    ps.draw(p);
    lights.draw(p);
  }
}

final SimulatedEffect healthBarHitEffect = SimulatedEffect(
  meta: const EffectMeta(
    id: 'ui/health-bar-hit',
    name: 'Health bar hit',
    desc:
        'A segmented health bar takes a hit: it jolts and dips, the lost chunk flashes white and sheds chips, holds, then drains away behind a sparking edge.',
    category: 'ui',
    tags: ['ui', 'health', 'hud', 'damage', 'bar', 'one-shot'],
    size: (160, 64),
    origin: (80, 30),
    duration: 2.0,
    loop: false,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {
      'palette': [
        '#1a0508',
        '#4a0b12',
        '#8c1420',
        '#d42a2e',
        '#ff5a4a',
        '#ff9a86',
        '#ffd8cc',
        '#ffffff',
      ],
      'from': 0.8,
      'to': 0.45,
      'seed': 3,
    },
  ),
  onCreate: _HealthBarHitSim.new,
);
