import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../services/ad_service.dart';

/// Marble Sort Game

const List<Color> _colors = [
  Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047),
  Color(0xFFFDD835), Color(0xFF8E24AA), Color(0xFFFF6D00),
  Color(0xFF00ACC1), Color(0xFFD81B60),
];

const int _nSlots = 30;
const int _maxBasketRows = 5;

class MBox { final int colorIndex; bool released; MBox(this.colorIndex, [this.released = false]); }

class Basket {
  final int colorIndex; int filled, col, row; double slideY;
  Basket(this.colorIndex, this.col, this.row, [this.filled = 0, this.slideY = 0]);
  bool get full => filled >= 3; bool get done => filled >= 3;
}

class _PhysMarble {
  final int colorIndex;
  double x, y, vx, vy;
  int state; // 0=깔대기 물리, 1=슬롯 이동중
  int targetSlot;
  double transProgress, startX, startY;
  _PhysMarble(this.colorIndex, this.x, this.y, this.vx, this.vy)
    : state = 0, targetSlot = -1, transProgress = 0, startX = 0, startY = 0;
}

class _Fx { final int col, row; double life; _Fx(this.col, this.row) : life = 1.0; }

class _ClearAnim {
  final int colorIndex, col, row, dir; double progress;
  _ClearAnim(this.colorIndex, this.col, this.row, this.dir, [this.progress = 0]);
}

// ─── 트랙 지오메트리 (스타디움) ──────────────────────────────
class _Geo {
  final double cx, cy, halfW, r;
  late final double total, s1, s2, s3, s4;
  _Geo(this.cx, this.cy, this.halfW, this.r) {
    final cap = pi * r; total = 4 * halfW + 2 * cap;
    s1 = halfW / total; s2 = (halfW + cap) / total;
    s3 = (halfW + cap + 2 * halfW) / total;
    s4 = (halfW + cap + 2 * halfW + cap) / total;
  }
  Offset pos(double t) {
    t = t % 1.0; if (t < 0) t += 1;
    if (t <= s1) return Offset(cx + (t / s1) * halfW, cy - r);
    if (t <= s2) { final a = -pi / 2 + ((t - s1) / (s2 - s1)) * pi; return Offset(cx + halfW + r * cos(a), cy + r * sin(a)); }
    if (t <= s3) { final f = (t - s2) / (s3 - s2); return Offset(cx + halfW - f * 2 * halfW, cy + r); }
    if (t <= s4) { final a = pi / 2 + ((t - s3) / (s4 - s3)) * pi; return Offset(cx - halfW + r * cos(a), cy + r * sin(a)); }
    final f = (t - s4) / (1.0 - s4); return Offset(cx - halfW + f * halfW, cy - r);
  }
  bool isBottom(double t) { t = t % 1.0; if (t < 0) t += 1; return t >= s2 && t <= s3; }
}

// ─── 레이아웃 (하단 고정, 상단 가변) ────────────────────────
class _L {
  final double w, h, mg, pw, barH, mR, bktH, trackW;
  final int gridCols, boxCols;
  final double funnelTop, funnelBot, containerW, narrowStart, beltEntryW;
  final double bSz, boxTop, boxTotalW;
  final _Geo geo;
  final double basketTop, basketMg, basketPw;
  const _L({
    required this.w, required this.h, required this.mg, required this.pw,
    required this.barH, required this.mR, required this.bktH, required this.trackW,
    required this.gridCols, required this.boxCols,
    required this.funnelTop, required this.funnelBot, required this.containerW,
    required this.narrowStart, required this.beltEntryW,
    required this.bSz, required this.boxTop, required this.boxTotalW,
    required this.geo, required this.basketTop,
    required this.basketMg, required this.basketPw,
  });
}

_L _calcLayout(double w, double h, int nBoxes, int nColors) {
  final mg = w * 0.03, pw = w - mg * 2;
  final barH = h * 0.045;
  final mR = max(min(pw * 0.023, h * 0.015), 8.0);
  final bktH = mR * 3.8;
  final trackW = mR * 3.2;
  const gap = 4.0;

  // 바구니 그리드 열 수 (5줄 이내)
  final total = nColors * 3;
  int gridCols = 4;
  for (int c = 4; c <= 6; c++) {
    if ((total / c).ceil() <= _maxBasketRows) { gridCols = c; break; }
  }

  // ── 하단 고정: 바구니 5줄 ──
  final basketAreaH = _maxBasketRows * bktH + (_maxBasketRows - 1) * gap;
  final basketTop = h - 4 - basketAreaH;

  // ── 벨트 ──
  final halfW = min(pw * 0.44, h * 0.22);
  final capR = max(halfW / (2 * pi), mR * 1.8);
  final trackCy = basketTop - mR - capR;
  final geo = _Geo(w / 2, trackCy, halfW, capR);

  // ── 깔대기 컨테이너 (박스 감싸기) ──
  final funnelBot = trackCy - capR - 2;
  final funnelTop = barH + 2;
  final funnelH = funnelBot - funnelTop;
  final beltEntryW = mR * 4;

  // 박스 크기 (깔대기 상부 ~25%)
  final boxCols = min(max(nBoxes, 1), 6);
  final bxRows = max((nBoxes / boxCols).ceil(), 1);
  final boxAreaH = funnelH * 0.25;
  final bSz = min(
    (pw * 0.7 - (boxCols - 1) * gap) / boxCols,
    (boxAreaH - (bxRows - 1) * gap) / bxRows,
  ).clamp(mR * 3, min(pw * 0.13, h * 0.065)).toDouble();
  final boxTotalW = boxCols * bSz + (boxCols - 1) * gap;
  final containerW = min(boxTotalW + mR * 8, pw * 0.85);
  final boxTop = funnelTop + mR * 2.5;

  // 좁아지는 시작점 (박스 아래 + 애니메이션 공간)
  final boxBot = boxTop + bxRows * bSz + (bxRows - 1) * gap;
  final narrowStart = min(boxBot + funnelH * 0.4, funnelBot - funnelH * 0.15);

  // 바구니 폭 = 벨트 하단 폭 (2*halfW) 에 맞춤
  final basketPw = 2 * halfW;
  final basketMg = (w - basketPw) / 2;

  return _L(
    w: w, h: h, mg: mg, pw: pw, barH: barH,
    mR: mR, bktH: bktH, trackW: trackW,
    gridCols: gridCols, boxCols: boxCols,
    funnelTop: funnelTop, funnelBot: funnelBot,
    containerW: containerW, narrowStart: narrowStart, beltEntryW: beltEntryW,
    bSz: bSz, boxTop: boxTop, boxTotalW: boxTotalW,
    geo: geo, basketTop: basketTop,
    basketMg: basketMg, basketPw: basketPw,
  );
}

// ─── 게임 화면 ───────────────────────────────────────────────
class MarbleSortScreen extends StatefulWidget {
  final int startLevel;
  const MarbleSortScreen({super.key, this.startLevel = 1});
  @override State<MarbleSortScreen> createState() => _MarbleSortScreenState();
}

class _MarbleSortScreenState extends State<MarbleSortScreen> {
  int level = 1, score = 0, hiScore = 0, lives = 3;
  bool playing = false, over = false;

  List<MBox> boxes = [];
  List<Basket> baskets = [];
  List<int?> slots = List.filled(_nSlots, null);
  double trackOffset = 0;
  List<_PhysMarble> physMarbles = [];
  List<_ClearAnim> clearing = [];
  double speed = 0.002;
  Timer? loop;
  int combo = 0; String? comboTxt; double comboAlpha = 0;
  List<_Fx> fx = [];
  Size sz = Size.zero;
  _L? _l;
  int _clearDir = 1;

  int get nColors => min(3 + (level - 1) ~/ 2, 8);
  int get _emptySlots {
    final occupied = slots.where((s) => s != null).length;
    final pending = physMarbles.where((m) => m.state < 2).length;
    return _nSlots - occupied - pending;
  }

  @override void initState() { super.initState(); level = widget.startLevel; _start(); }
  @override void dispose() { loop?.cancel(); super.dispose(); }

  int _gridColsFor(int n) {
    final t = n * 3;
    for (int c = 4; c <= 6; c++) { if ((t / c).ceil() <= _maxBasketRows) return c; }
    return 6;
  }

  void _start() {
    final r = Random(), n = nColors, gc = _gridColsFor(n);
    boxes = List.generate(n, (i) => MBox(i))..shuffle(r);
    final raw = <Basket>[];
    for (int c = 0; c < n; c++) for (int j = 0; j < 3; j++) raw.add(Basket(c, 0, 0));
    raw.shuffle(r);
    for (int i = 0; i < raw.length; i++) { raw[i].col = i % gc; raw[i].row = i ~/ gc; }
    baskets = raw;
    slots = List.filled(_nSlots, null);
    physMarbles = []; clearing = []; fx = [];
    combo = 0; comboTxt = null; comboAlpha = 0;
    trackOffset = 0; _clearDir = 1;
    speed = 0.0012 + level * 0.0003; if (speed > 0.005) speed = 0.005;
    playing = true; over = false;
    loop?.cancel();
    loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  // ── 게임 루프 ──
  void _tick() {
    if (!playing && clearing.isEmpty && physMarbles.isEmpty) return;
    setState(() {
      trackOffset -= speed; if (trackOffset < 0) trackOffset += 1;
      _tickPhysics();

      for (int i = physMarbles.length - 1; i >= 0; i--) {
        final pm = physMarbles[i];
        if (pm.state == 1) {
          pm.transProgress += 0.07;
          if (pm.transProgress >= 1.0) {
            if (pm.targetSlot >= 0 && pm.targetSlot < _nSlots && slots[pm.targetSlot] == null)
              slots[pm.targetSlot] = pm.colorIndex;
            physMarbles.removeAt(i);
          }
        }
      }

      if (playing) _autoCheck();

      for (int i = clearing.length - 1; i >= 0; i--) {
        clearing[i].progress += 0.035;
        if (clearing[i].progress >= 1.0) {
          final ca = clearing.removeAt(i);
          for (final b in baskets) {
            if (b.col == ca.col && b.row > ca.row) { b.row--; b.slideY = 1.0; }
          }
        }
      }
      for (final b in baskets) { if (b.slideY > 0) { b.slideY -= 0.08; if (b.slideY < 0) b.slideY = 0; } }
      for (int i = fx.length - 1; i >= 0; i--) { fx[i].life -= 0.025; if (fx[i].life <= 0) fx.removeAt(i); }
      if (comboAlpha > 0) { comboAlpha -= 0.015; if (comboAlpha < 0) comboAlpha = 0; }
    });
  }

  // ── 물리 시뮬레이션 (깔대기 컨테이너 내부) ──
  void _tickPhysics() {
    if (_l == null) return;
    final l = _l!;
    final cx = l.w / 2;
    final nStart = l.narrowStart;
    final fBot = l.funnelBot;
    final fTop = l.funnelTop;
    final cHalfW = l.containerW / 2;
    final eHalfW = l.beltEntryW / 2;
    final mR = l.mR;
    const gravity = 0.35, bounce = 0.6, friction = 0.97;

    final active = <_PhysMarble>[];
    for (final m in physMarbles) {
      if (m.state != 0) continue;
      active.add(m);

      m.vy += gravity;
      m.vx *= friction;
      m.x += m.vx;
      m.y += m.vy;

      // 벽 충돌: 직사각형 구간 vs 좁아지는 구간
      double wallHalfW;
      if (m.y <= nStart) {
        wallHalfW = cHalfW - mR - 3;
      } else {
        final f = ((m.y - nStart) / (fBot - nStart)).clamp(0.0, 1.0);
        wallHalfW = (cHalfW + (eHalfW - cHalfW) * f) - mR;
      }
      final left = cx - wallHalfW, right = cx + wallHalfW;
      if (m.x < left) { m.x = left; m.vx = m.vx.abs() * bounce; }
      if (m.x > right) { m.x = right; m.vx = -m.vx.abs() * bounce; }

      // 상단 벽
      if (m.y < fTop + mR + 3) { m.y = fTop + mR + 3; m.vy = m.vy.abs() * bounce * 0.3; }

      // 속도 제한
      if (m.vx.abs() > 8) m.vx = 8 * m.vx.sign;
      if (m.vy.abs() > 12) m.vy = 12 * m.vy.sign;

      // 깔대기 탈출 → 슬롯 이동
      if (m.y >= fBot) {
        m.state = 1; m.startX = m.x; m.startY = fBot;
        m.transProgress = 0; m.targetSlot = _findNextEmptySlot(m);
      }
    }

    // 구슬 간 충돌 (탄성)
    for (int i = 0; i < active.length; i++) {
      for (int j = i + 1; j < active.length; j++) {
        final a = active[i], b = active[j];
        final dx = b.x - a.x, dy = b.y - a.y;
        final dist = sqrt(dx * dx + dy * dy);
        final minDist = mR * 2.1;
        if (dist < minDist && dist > 0.1) {
          final nx = dx / dist, ny = dy / dist, overlap = minDist - dist;
          a.x -= nx * overlap / 2; a.y -= ny * overlap / 2;
          b.x += nx * overlap / 2; b.y += ny * overlap / 2;
          final relVn = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny;
          if (relVn > 0) {
            a.vx -= relVn * nx * bounce; a.vy -= relVn * ny * bounce;
            b.vx += relVn * nx * bounce; b.vy += relVn * ny * bounce;
          }
        }
      }
    }
  }

  int _findNextEmptySlot(_PhysMarble pm) {
    final indices = List.generate(_nSlots, (i) => i);
    indices.sort((a, b) {
      final ta = (a / _nSlots + trackOffset) % 1.0, tb = (b / _nSlots + trackOffset) % 1.0;
      return min(ta, 1 - ta).compareTo(min(tb, 1 - tb));
    });
    for (final idx in indices) {
      if (slots[idx] != null) continue;
      if (physMarbles.any((p) => p != pm && p.targetSlot == idx && p.state >= 0)) continue;
      return idx;
    }
    return -1;
  }

  // ── 벨트→바구니 자동 체크 ──
  void _autoCheck() {
    if (_l == null) return;
    final l = _l!;
    final g = l.geo;
    final bw = (l.basketPw - 4.0 * (l.gridCols - 1)) / l.gridCols;
    final threshold = bw * 0.3;

    final topPerCol = <int, Basket>{};
    for (int col = 0; col < l.gridCols; col++) {
      Basket? top;
      for (final b in baskets) { if (b.col != col || b.full) continue; if (top == null || b.row < top.row) top = b; }
      if (top != null) topPerCol[col] = top;
    }

    for (int i = 0; i < _nSlots; i++) {
      if (slots[i] == null) continue;
      final t = (i / _nSlots + trackOffset) % 1.0;
      if (!g.isBottom(t)) continue;
      final pos = g.pos(t); final ci = slots[i]!;

      Basket? bestB; double bestDist = threshold;
      for (final entry in topPerCol.entries) {
        final b = entry.value;
        if (b.colorIndex != ci) continue;
        final bc = _basketCenterFor(b.col, b.row);
        final dx = (pos.dx - bc.dx).abs();
        if (dx < bestDist) { bestDist = dx; bestB = b; }
      }

      if (bestB != null) {
        slots[i] = null; bestB.filled++;
        score += 10 * (1 + combo); combo++;
        if (combo >= 3) { comboTxt = 'Combo x$combo!'; comboAlpha = 1; }
        if (bestB.done) {
          score += 50 * level; fx.add(_Fx(bestB.col, bestB.row));
          _clearDir *= -1;
          clearing.add(_ClearAnim(bestB.colorIndex, bestB.col, bestB.row, _clearDir));
          baskets.remove(bestB);
          topPerCol.remove(bestB.col);
          Basket? newTop;
          for (final b in baskets) { if (b.col != bestB.col || b.full) continue; if (newTop == null || b.row < newTop.row) newTop = b; }
          if (newTop != null) topPerCol[bestB.col] = newTop;
        }
        if (baskets.isEmpty) {
          playing = false; loop?.cancel();
          if (score > hiScore) hiScore = score;
          Future.delayed(const Duration(milliseconds: 600), () => _showClear());
        }
      }
    }
  }

  void _tap(Offset p) { if (!playing) return; _tapBox(p); }

  void _tapBox(Offset p) {
    if (_l == null) return;
    final l = _l!;
    final cx = l.w / 2, cols = l.boxCols;
    const gap = 4.0;
    final sx = cx - l.boxTotalW / 2;
    for (int i = 0; i < boxes.length; i++) {
      if (boxes[i].released) continue;
      final c = i % cols, r = i ~/ cols;
      final bx = sx + c * (l.bSz + gap), by = l.boxTop + r * (l.bSz + gap);
      if (p.dx >= bx && p.dx <= bx + l.bSz && p.dy >= by && p.dy <= by + l.bSz) {
        if (_emptySlots >= 9) _releaseBox(i);
        return;
      }
    }
  }

  void _releaseBox(int boxIdx) {
    boxes[boxIdx].released = true;
    final ci = boxes[boxIdx].colorIndex;
    if (_l == null) return;
    final l = _l!;
    final rng = Random();
    final cx = l.w / 2, cols = l.boxCols;
    const gap = 4.0;
    // 박스 위치에서 구슬 생성
    final bx = cx - l.boxTotalW / 2 + (boxIdx % cols) * (l.bSz + gap) + l.bSz / 2;
    final by = l.boxTop + (boxIdx ~/ cols) * (l.bSz + gap) + l.bSz;
    for (int j = 0; j < 9; j++) {
      final px = bx + (rng.nextDouble() - 0.5) * l.bSz * 0.6;
      final py = by + j * l.mR * 1.8 + rng.nextDouble() * l.mR;
      final vx = (rng.nextDouble() - 0.5) * 3;
      final vy = rng.nextDouble() * 2;
      physMarbles.add(_PhysMarble(ci, px, py, vx, vy));
    }
  }

  Offset _basketCenterFor(int col, int row) {
    if (_l == null) return Offset.zero;
    final l = _l!;
    const gap = 4.0;
    final bw = (l.basketPw - gap * (l.gridCols - 1)) / l.gridCols;
    return Offset(l.basketMg + col * (bw + gap) + bw / 2, l.basketTop + row * (l.bktH + gap) + l.bktH / 2);
  }

  // ── 다이얼로그 ──
  void _showClear() {
    showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 2)),
      title: Text('games.marbleSort.levelClear'.tr(), textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('games.marbleSort.levelValue'.tr(namedArgs: {'level': '$level'}),
            style: const TextStyle(color: Colors.white70, fontSize: 18)),
        const SizedBox(height: 8),
        Text('games.marbleSort.scoreValue'.tr(namedArgs: {'score': '$score'}),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ]),
      actions: [
        TextButton(onPressed: () { Navigator.pop(c); Navigator.pop(c); },
            child: Text('app.close'.tr(), style: const TextStyle(color: Colors.grey))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () { Navigator.pop(c); setState(() { level++; _start(); }); },
            child: Text('games.marbleSort.nextLevel'.tr(), style: const TextStyle(color: Colors.black))),
      ],
    ));
  }

  void _showOver() {
    if (score > hiScore) hiScore = score;
    showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.5), width: 2)),
      title: Text('common.gameOver'.tr(), textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('games.marbleSort.finalScore'.tr(namedArgs: {'score': '$score'}),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('games.marbleSort.highScoreLabel'.tr(namedArgs: {'score': '$hiScore'}),
            style: const TextStyle(color: Colors.amber, fontSize: 16)),
      ]),
      actions: [
        TextButton(onPressed: () { Navigator.pop(c); Navigator.pop(c); },
            child: Text('app.close'.tr(), style: const TextStyle(color: Colors.grey))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () { Navigator.pop(c); setState(() { score = 0; lives = 3; level = 1; _start(); }); },
            child: Text('common.tryAgain'.tr(), style: const TextStyle(color: Colors.black))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(child: GestureDetector(
        onTapDown: (d) => _tap(d.localPosition),
        child: LayoutBuilder(builder: (ctx, cons) {
          sz = Size(cons.maxWidth, cons.maxHeight);
          _l = _calcLayout(sz.width, sz.height, boxes.length, nColors);
          return CustomPaint(
            painter: _P(l: _l!, boxes: boxes, baskets: baskets, slots: slots,
              trackOffset: trackOffset, physMarbles: physMarbles,
              clearing: clearing, fx: fx, comboTxt: comboTxt, comboAlpha: comboAlpha,
              score: score, level: level, lives: lives),
            size: sz,
            child: SizedBox(width: sz.width, height: sz.height, child: Stack(children: [
              Positioned(top: 4, left: 4, child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 22),
                  onPressed: () => Navigator.pop(context))),
              if (playing && lives <= 1)
                Positioned(top: 4, right: 4, child: IconButton(
                    icon: const Icon(Icons.favorite_border, color: Colors.green, size: 24),
                    onPressed: () {
                      showDialog(context: context, builder: (c) => AlertDialog(
                        backgroundColor: Colors.grey.shade900,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('games.marbleSort.extraLife'.tr(), style: const TextStyle(color: Colors.green)),
                        content: Text('games.marbleSort.extraLifeMessage'.tr(), style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c),
                              child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.grey))),
                          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () async {
                              Navigator.pop(c); final ad = AdService();
                              final ok = await ad.showRewardedAd(onUserEarnedReward: (_, __) { setState(() { lives++; }); });
                              if (!ok && mounted) { setState(() { lives++; }); ad.loadRewardedAd(); }
                            },
                            child: Text('common.watchAd'.tr(), style: const TextStyle(color: Colors.white))),
                        ],
                      ));
                    })),
            ])),
          );
        }),
      )),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────
class _P extends CustomPainter {
  final _L l;
  final List<MBox> boxes; final List<Basket> baskets; final List<int?> slots;
  final double trackOffset; final List<_PhysMarble> physMarbles;
  final List<_ClearAnim> clearing; final List<_Fx> fx;
  final String? comboTxt; final double comboAlpha;
  final int score, level, lives;

  _P({required this.l, required this.boxes, required this.baskets,
    required this.slots, required this.trackOffset, required this.physMarbles,
    required this.clearing, required this.fx, required this.comboTxt,
    required this.comboAlpha, required this.score, required this.level, required this.lives});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBar(canvas);
    _drawFunnel(canvas);
    _drawBoxes(canvas);
    _drawPhysMarbles(canvas);
    _drawTrack(canvas);
    _drawSlotMarbles(canvas);
    _drawBaskets(canvas);
    _drawClearing(canvas);
    _drawFx(canvas);
    if (comboTxt != null && comboAlpha > 0)
      _txt(canvas, comboTxt!, l.w / 2, l.geo.cy, TextStyle(
          color: Colors.amber.withValues(alpha: comboAlpha), fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.orange.withValues(alpha: comboAlpha), blurRadius: 10)]), c: true);
  }

  // ── 상단바 ──
  void _drawBar(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, l.w, l.barH), Paint()..color = const Color(0xFF0F0F23));
    _txt(canvas, 'Lv.$level', 48, l.barH / 2, const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold));
    _txt(canvas, '$score', l.w / 2, l.barH / 2, const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold), c: true);
    final p = Paint()..color = Colors.red;
    for (int i = 0; i < lives; i++) {
      final x = l.w - 28 - i * 22.0, y = l.barH / 2;
      canvas.drawCircle(Offset(x - 3, y - 2), 5, p); canvas.drawCircle(Offset(x + 3, y - 2), 5, p);
      canvas.drawPath(Path()..moveTo(x - 8, y)..lineTo(x, y + 8)..lineTo(x + 8, y)..close(), p);
    }
  }

  // ── 깔대기 컨테이너 (박스 감싸기 + 구슬 낙하 공간) ──
  void _drawFunnel(Canvas canvas) {
    final cx = l.w / 2;
    final topW = l.containerW, botW = l.beltEntryW;
    final top = l.funnelTop, nStart = l.narrowStart, bot = l.funnelBot;
    const cR = 14.0;

    // 외곽 (둥근 상단 + 좁아지는 하단)
    final outer = Path()
      ..moveTo(cx - topW / 2, top + cR)
      ..quadraticBezierTo(cx - topW / 2, top, cx - topW / 2 + cR, top)
      ..lineTo(cx + topW / 2 - cR, top)
      ..quadraticBezierTo(cx + topW / 2, top, cx + topW / 2, top + cR)
      ..lineTo(cx + topW / 2, nStart)
      ..lineTo(cx + botW / 2, bot)
      ..lineTo(cx - botW / 2, bot)
      ..lineTo(cx - topW / 2, nStart)
      ..close();
    canvas.drawPath(outer, Paint()..color = const Color(0xFF2A2A4A));

    // 내부 배경 (약간 작게)
    final inner = Path()
      ..moveTo(cx - topW / 2 + 3, top + cR)
      ..quadraticBezierTo(cx - topW / 2 + 3, top + 3, cx - topW / 2 + cR, top + 3)
      ..lineTo(cx + topW / 2 - cR, top + 3)
      ..quadraticBezierTo(cx + topW / 2 - 3, top + 3, cx + topW / 2 - 3, top + cR)
      ..lineTo(cx + topW / 2 - 3, nStart)
      ..lineTo(cx + botW / 2 - 2, bot - 2)
      ..lineTo(cx - botW / 2 + 2, bot - 2)
      ..lineTo(cx - topW / 2 + 3, nStart)
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFF151528));

    // 테두리 글로우
    canvas.drawPath(outer, Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke..strokeWidth = 2);

    // 좁아지는 구간 강조선
    final lp = Paint()..color = Colors.white.withValues(alpha: 0.06)..strokeWidth = 1;
    canvas.drawLine(Offset(cx - topW / 2, nStart), Offset(cx - botW / 2, bot), lp);
    canvas.drawLine(Offset(cx + topW / 2, nStart), Offset(cx + botW / 2, bot), lp);

    // 하단 화살표
    final ap = Paint()..color = Colors.amber.withValues(alpha: 0.35)..strokeWidth = 2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final aTop = nStart + (bot - nStart) * 0.3, aBot = bot - 4;
    canvas.drawLine(Offset(cx, aTop), Offset(cx, aBot), ap);
    canvas.drawLine(Offset(cx - 4, aBot - 8), Offset(cx, aBot), ap);
    canvas.drawLine(Offset(cx + 4, aBot - 8), Offset(cx, aBot), ap);
  }

  // ── 상단 박스 (깔대기 안) ──
  void _drawBoxes(Canvas canvas) {
    final cx = l.w / 2, cols = l.boxCols;
    const gap = 4.0;
    final sx = cx - l.boxTotalW / 2;
    final miniR = l.mR * 0.45;
    for (int i = 0; i < boxes.length; i++) {
      final b = boxes[i]; final col = i % cols, row = i ~/ cols;
      final bx = sx + col * (l.bSz + gap), by = l.boxTop + row * (l.bSz + gap);
      final clr = _colors[b.colorIndex % _colors.length];
      final rr = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, l.bSz, l.bSz), const Radius.circular(6));
      if (b.released) {
        canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: 0.03));
        canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: 0.08)..style = PaintingStyle.stroke..strokeWidth = 1);
      } else {
        canvas.drawRRect(rr, Paint()..color = clr.withValues(alpha: 0.25));
        canvas.drawRRect(rr, Paint()..color = clr.withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 1.5);
        for (int ry = 0; ry < 3; ry++) for (int cx2 = 0; cx2 < 3; cx2++) {
          final mx = bx + l.bSz * (0.2 + cx2 * 0.3), my = by + l.bSz * (0.2 + ry * 0.3);
          canvas.drawCircle(Offset(mx, my), miniR, Paint()..color = clr);
          canvas.drawCircle(Offset(mx - miniR * 0.2, my - miniR * 0.2), miniR * 0.3,
              Paint()..color = Colors.white.withValues(alpha: 0.3));
        }
      }
    }
  }

  // ── 물리 구슬 (깔대기 안 + 슬롯 이동) ──
  void _drawPhysMarbles(Canvas canvas) {
    final g = l.geo;
    for (final pm in physMarbles) {
      if (pm.state == 0) {
        _marble(canvas, pm.x, pm.y, l.mR, pm.colorIndex);
      } else if (pm.state == 1 && pm.targetSlot >= 0) {
        final p = pm.transProgress.clamp(0.0, 1.0);
        final slotT = (pm.targetSlot / _nSlots + trackOffset) % 1.0;
        final sp = g.pos(slotT);
        final mx = pm.startX + (sp.dx - pm.startX) * p;
        final my = pm.startY + (sp.dy - pm.startY) * p;
        _marble(canvas, mx, my, l.mR, pm.colorIndex, a: 1.0 - p * 0.1);
      }
    }
  }

  // ── 벨트 트랙 ──
  void _drawTrack(Canvas canvas) {
    final g = l.geo; final tw = l.trackW;
    canvas.drawPath(_stadiumPath(g, tw / 2), Paint()..color = const Color(0xFF3A3A5C));
    canvas.drawPath(_stadiumPath(g, -tw / 2), Paint()..color = const Color(0xFF1A1A2E));
    final center = Path();
    for (int i = 0; i <= 100; i++) { final t = i / 100.0, p = g.pos(t);
      if (i == 0) center.moveTo(p.dx, p.dy); else center.lineTo(p.dx, p.dy); }
    center.close();
    canvas.drawPath(center, Paint()..color = Colors.white.withValues(alpha: 0.1)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    final slotR = l.mR * 0.6;
    for (int i = 0; i < _nSlots; i++) {
      final t = (i / _nSlots + trackOffset) % 1.0, p = g.pos(t);
      if (slots[i] == null) {
        canvas.drawCircle(p, slotR, Paint()..color = Colors.white.withValues(alpha: 0.06));
        canvas.drawCircle(p, slotR, Paint()..color = Colors.white.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 0.8);
      }
    }
    // 방향 화살표
    final ap = Paint()..color = Colors.white.withValues(alpha: 0.2)..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) { final t = i / 6.0, p1 = g.pos(t), p2 = g.pos(t - 0.01);
      final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy; final len = sqrt(dx * dx + dy * dy); if (len < 0.1) continue;
      final nx = dx / len, ny = dy / len;
      canvas.drawLine(Offset(p1.dx - nx * 6 - ny * 3, p1.dy - ny * 6 + nx * 3), p1, ap);
      canvas.drawLine(Offset(p1.dx - nx * 6 + ny * 3, p1.dy - ny * 6 - nx * 3), p1, ap);
    }
    // 하단 트랙 하이라이트
    final dp = Path(); bool first = true;
    for (double t = g.s2; t <= g.s3; t += 0.003) { final p = g.pos(t);
      if (first) { dp.moveTo(p.dx, p.dy); first = false; } else dp.lineTo(p.dx, p.dy); }
    canvas.drawPath(dp, Paint()..color = Colors.amber.withValues(alpha: 0.1)..style = PaintingStyle.stroke..strokeWidth = tw * 1.2);
  }

  Path _stadiumPath(_Geo g, double offset) {
    final r = g.r + offset, hw = g.halfW;
    return Path()..moveTo(g.cx - hw, g.cy - r)..lineTo(g.cx + hw, g.cy - r)
      ..arcToPoint(Offset(g.cx + hw, g.cy + r), radius: Radius.circular(r), clockwise: true)
      ..lineTo(g.cx - hw, g.cy + r)
      ..arcToPoint(Offset(g.cx - hw, g.cy - r), radius: Radius.circular(r), clockwise: true)..close();
  }

  // ── 슬롯 구슬 ──
  void _drawSlotMarbles(Canvas canvas) {
    final g = l.geo;
    for (int i = 0; i < _nSlots; i++) {
      if (slots[i] == null) continue;
      final t = (i / _nSlots + trackOffset) % 1.0, p = g.pos(t);
      _marble(canvas, p.dx, p.dy, l.mR, slots[i]!);
    }
  }

  // ── 하단 바구니 ──
  void _drawBaskets(Canvas canvas) {
    const gap = 4.0;
    final bw = (l.basketPw - gap * (l.gridCols - 1)) / l.gridCols;
    for (final b in baskets) {
      final bx = l.basketMg + b.col * (bw + gap);
      final by = l.basketTop + b.row * (l.bktH + gap) + b.slideY * (l.bktH + gap);
      final clr = _colors[b.colorIndex % _colors.length];
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, l.bktH), const Radius.circular(5));
      canvas.drawRRect(rect, Paint()..color = clr.withValues(alpha: 0.25));
      canvas.drawRRect(rect, Paint()..color = clr.withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 2);
      for (int k = 0; k < 3; k++) {
        final mx = bx + bw * (0.2 + k * 0.3), my = by + l.bktH / 2;
        if (k < b.filled) { _marble(canvas, mx, my, l.mR, b.colorIndex); }
        else {
          canvas.drawCircle(Offset(mx, my), l.mR, Paint()..color = clr.withValues(alpha: 0.12));
          canvas.drawCircle(Offset(mx, my), l.mR, Paint()..color = clr.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 1);
        }
      }
    }
  }

  // ── 사라지는 바구니 ──
  void _drawClearing(Canvas canvas) {
    const gap = 4.0;
    final bw = (l.basketPw - gap * (l.gridCols - 1)) / l.gridCols;
    for (final ca in clearing) {
      final p = ca.progress.clamp(0.0, 1.0); final alpha = 1.0 - p;
      final slideX = ca.dir * p * l.w * 0.6;
      final bx = l.basketMg + ca.col * (bw + gap) + slideX; final by = l.basketTop + ca.row * (l.bktH + gap);
      final clr = _colors[ca.colorIndex % _colors.length];
      canvas.save();
      canvas.translate(bx + bw / 2, by + l.bktH / 2); canvas.scale(1.0 - p * 0.3);
      canvas.translate(-(bx + bw / 2), -(by + l.bktH / 2));
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, l.bktH), const Radius.circular(5));
      canvas.drawRRect(rect, Paint()..color = clr.withValues(alpha: 0.55 * alpha));
      canvas.drawRRect(rect, Paint()..color = clr.withValues(alpha: 0.9 * alpha)..style = PaintingStyle.stroke..strokeWidth = 2);
      for (int k = 0; k < 3; k++) {
        final mx = bx + bw * (0.2 + k * 0.3), my = by + l.bktH / 2;
        canvas.drawCircle(Offset(mx, my), l.mR, Paint()..color = clr.withValues(alpha: alpha));
        canvas.drawCircle(Offset(mx - l.mR * 0.2, my - l.mR * 0.2), l.mR * 0.3,
            Paint()..color = Colors.white.withValues(alpha: 0.3 * alpha));
      }
      canvas.restore();
    }
  }

  // ── 이펙트 ──
  void _drawFx(Canvas canvas) {
    const gap = 4.0;
    final bw = (l.basketPw - gap * (l.gridCols - 1)) / l.gridCols;
    for (final e in fx) {
      final cx = l.basketMg + e.col * (bw + gap) + bw / 2;
      final cy = l.basketTop + e.row * (l.bktH + gap) + l.bktH / 2;
      final rnd = Random(e.col * 10 + e.row);
      for (int i = 0; i < 8; i++) { final a = rnd.nextDouble() * 2 * pi, d = (1 - e.life) * 35 + rnd.nextDouble() * 12;
        canvas.drawCircle(Offset(cx + cos(a) * d, cy + sin(a) * d), 3 * e.life,
            Paint()..color = Colors.amber.withValues(alpha: e.life * 0.8)); }
    }
  }

  // ── 구슬 렌더링 ──
  void _marble(Canvas canvas, double x, double y, double r, int ci, {double a = 1.0}) {
    final c = _colors[ci % _colors.length];
    canvas.drawCircle(Offset(x, y + r * 0.1), r, Paint()..color = Colors.black.withValues(alpha: 0.25 * a));
    final g = RadialGradient(center: const Alignment(-0.3, -0.3), radius: 0.9, colors: [
      Color.lerp(c, Colors.white, 0.4)!.withValues(alpha: a), c.withValues(alpha: a),
      Color.lerp(c, Colors.black, 0.3)!.withValues(alpha: a)]);
    canvas.drawCircle(Offset(x, y), r, Paint()..shader = g.createShader(Rect.fromCircle(center: Offset(x, y), radius: r)));
    canvas.drawCircle(Offset(x - r * 0.25, y - r * 0.25), r * 0.28, Paint()..color = Colors.white.withValues(alpha: 0.4 * a));
  }

  void _txt(Canvas canvas, String t, double x, double y, TextStyle s, {bool c = false}) {
    final tp = TextPainter(text: TextSpan(text: t, style: s), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(c ? x - tp.width / 2 : x, y - tp.height / 2));
  }

  @override bool shouldRepaint(covariant CustomPainter o) => true;
}
