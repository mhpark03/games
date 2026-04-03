import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../services/ad_service.dart';

/// Marble Sort Game

const List<Color> _colors = [
  Color(0xFFFF1744), // 빨강
  Color(0xFF2979FF), // 파랑
  Color(0xFF00E676), // 초록
  Color(0xFFFFEA00), // 노랑
  Color(0xFFAA00FF), // 보라
  Color(0xFFFF9100), // 주황
  Color(0xFF00E5FF), // 시안
  Color(0xFFFF4081), // 핑크
  Color(0xFF76FF03), // 라임
  Color(0xFF651FFF), // 인디고
  Color(0xFFFFFFFF), // 흰색
  Color(0xFFFF6E40), // 코랄
];

const int _nSlots = 30;
const int _maxBasketRows = 5;

class MBox {
  final int colorIndex; bool released; bool locked; int multiplier;
  MBox(this.colorIndex, [this.released = false, this.locked = true, this.multiplier = 1]);
  int get marbleCount => 9 * multiplier;
}

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
  final double w, h, mg, pw, barH, mR, drawR, bktH, trackW;
  final int gridCols, boxCols;
  final double funnelTop, funnelBot, containerW, narrowStart, beltEntryW;
  final double bSz, boxTop, boxTotalW, boxAreaH;
  final _Geo geo;
  final double basketTop, basketMg, basketPw;
  const _L({
    required this.w, required this.h, required this.mg, required this.pw,
    required this.barH, required this.mR, required this.drawR, required this.bktH, required this.trackW,
    required this.gridCols, required this.boxCols,
    required this.funnelTop, required this.funnelBot, required this.containerW,
    required this.narrowStart, required this.beltEntryW,
    required this.bSz, required this.boxTop, required this.boxTotalW, required this.boxAreaH,
    required this.geo, required this.basketTop,
    required this.basketMg, required this.basketPw,
  });
}

_L _calcLayout(double w, double h, int nBoxes, int nBaskets) {
  final mg = w * 0.03, pw = w - mg * 2;
  final barH = h * 0.045;
  final mR = max(min(pw * 0.023, h * 0.015), 8.0);
  final bktH = mR * 2.8;
  final trackW = mR * 3.2;
  const gap = 4.0;

  // 바구니 그리드 4열 고정
  const int gridCols = 4;

  // ── 하단 고정: 바구니 5줄 ──
  final basketAreaH = _maxBasketRows * bktH + (_maxBasketRows - 1) * gap;
  final basketTop = h - 4 - basketAreaH;

  // ── 벨트 ──
  final halfW = min(pw * 0.44, h * 0.22);
  final capR = max(halfW / (2 * pi), mR * 1.8);
  final trackCy = basketTop - mR * 3 - capR;
  final geo = _Geo(w / 2, trackCy, halfW, capR);

  // ── 깔대기 컨테이너 (넓고 낮게) ──
  final funnelBot = trackCy - capR - mR * 2;
  final funnelTop = barH + 2;
  final funnelH = funnelBot - funnelTop;
  final beltEntryW = mR * 2.05;

  // 컨테이너 폭 = 벨트 폭과 동일 (넓게)
  final containerW = 2 * halfW;
  final boxTop = funnelTop + mR * 2.5;

  // 박스 크기 (6열 고정, 9구슬 3x3, 깔대기 안에 맞춤)
  final boxCols = min(max(nBoxes, 1), 6);
  final bxRows = max((nBoxes / boxCols).ceil(), 1);
  final boxAreaH = funnelH * 0.65;
  final bSzW = (containerW * 0.95 - (boxCols - 1) * gap) / boxCols;
  final bSzH = (boxAreaH - (bxRows - 1) * gap) / bxRows;
  final bSz = min(bSzW, bSzH).clamp(mR * 2.5, double.infinity).toDouble();
  final boxTotalW = boxCols * bSz + (boxCols - 1) * gap;
  // 통일 구슬 크기: 박스 안에도 맞는 크기 (작게)
  final drawR = min(mR * 0.7, bSz / 7.0);

  // 좁아지는 구간: 짧고 곡선 (벽에 부딪혀 튕기기)
  final boxBot = boxTop + bxRows * bSz + (bxRows - 1) * gap;
  final narrowStart = funnelBot - mR * 12;

  // 바구니 폭 = 벨트 하단 폭 (2*halfW) 에 맞춤
  final basketPw = 2 * halfW;
  final basketMg = (w - basketPw) / 2;

  return _L(
    w: w, h: h, mg: mg, pw: pw, barH: barH,
    mR: mR, drawR: drawR, bktH: bktH, trackW: trackW,
    gridCols: gridCols, boxCols: boxCols,
    funnelTop: funnelTop, funnelBot: funnelBot,
    containerW: containerW, narrowStart: narrowStart, beltEntryW: beltEntryW,
    bSz: bSz, boxTop: boxTop, boxTotalW: boxTotalW, boxAreaH: boxAreaH,
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
  bool playing = false, over = false, paused = false;
  double _fullBeltTimer = 0; // 벨트 꽉 참 후 한 바퀴 대기 타이머

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

  int get _emptySlots {
    final occupied = slots.where((s) => s != null).length;
    final pending = physMarbles.where((m) => m.state < 2).length;
    return _nSlots - occupied - pending;
  }

  @override void initState() { super.initState(); level = widget.startLevel; _start(); }
  @override void dispose() { loop?.cancel(); super.dispose(); }

  int _gridColsFor(int totalBaskets) {
    return 4; // 하단 바구니 4열 고정
  }

  void _start() {
    final r = Random();
    // 박스 수: 15~36 균등 랜덤
    final nBoxes = 15 + r.nextInt(22); // 15~36
    final nCol = min(max(nBoxes ~/ 3, 3), _colors.length);
    final perColor = List.filled(nCol, nBoxes ~/ nCol);
    for (int i = 0; i < nBoxes % nCol; i++) perColor[i]++;

    // 1) 박스 생성 및 셔플
    boxes = <MBox>[];
    for (int c = 0; c < nCol; c++) {
      for (int j = 0; j < perColor[c]; j++) boxes.add(MBox(c));
    }
    boxes.shuffle(r);

    // 2) 박스 잠금 설정 (화면상 맨 아래 줄 = topRow 0)
    final bCols = min(max(nBoxes, 1), 6);
    final bRows = (nBoxes / bCols).ceil();

    // 10% 이하 박스에 멀티플라이어(2~5) 지정 — 윗줄(row>=2)에만 배치
    final multiCount = max(1, (nBoxes * 0.1).floor());
    final upperIndices = <int>[];
    for (int i = 0; i < boxes.length; i++) {
      if (i ~/ bCols >= 2) upperIndices.add(i); // topRow 2 이상만
    }
    if (upperIndices.isEmpty) {
      // 줄이 2줄 이하면 topRow 1에 배치
      for (int i = 0; i < boxes.length; i++) {
        if (i ~/ bCols >= 1) upperIndices.add(i);
      }
    }
    upperIndices.shuffle(r);
    for (int i = 0; i < min(multiCount, upperIndices.length); i++) {
      // 가중치: x2(40%), x3(30%), x4(20%), x5(10%)
      final roll = r.nextInt(10);
      boxes[upperIndices[i]].multiplier = roll < 4 ? 2 : roll < 7 ? 3 : roll < 9 ? 4 : 5;
    }

    for (int i = 0; i < boxes.length; i++) {
      final topRow = i ~/ bCols;
      if (topRow == 0) {
        boxes[i].locked = false; // 맨 아래 줄 모두 오픈
      } else if (topRow == 1) {
        boxes[i].locked = r.nextBool(); // 두 번째 줄 랜덤 오픈
      } else {
        boxes[i].locked = true;
      }
    }

    // 3) 박스 접근 우선순위: 열린 박스 → 잠긴 박스 순서로 색상 우선순위 산출
    final colorPriority = <int, int>{};
    int priority = 0;
    // 먼저 열린 박스(아래쪽)의 색상
    for (int row = bRows - 1; row >= 0; row--) {
      for (int col = 0; col < bCols; col++) {
        final idx = row * bCols + col;
        if (idx >= boxes.length) continue;
        final ci = boxes[idx].colorIndex;
        if (!colorPriority.containsKey(ci)) {
          colorPriority[ci] = priority++;
        }
      }
    }

    // 4) 바구니 생성: 박스 아래줄 색 → 바구니 상단에 흩어서 배치
    final gc = 4; // 4열 고정

    // 색상별 총 구슬 수 계산 (멀티플라이어 반영)
    final marblesPerColor = List.filled(nCol, 0);
    for (final b in boxes) marblesPerColor[b.colorIndex] += b.marbleCount;

    // 박스 오픈 순서(아래→위)로 색상 순서 결정
    final colorOrder = <int>[];
    for (int i = 0; i < boxes.length; i++) {
      final ci = boxes[i].colorIndex;
      if (!colorOrder.contains(ci)) colorOrder.add(ci);
    }

    // 색상별 바구니 리스트 생성
    final basketsByColor = <int, List<Basket>>{};
    for (final ci in colorOrder) {
      final cnt = (marblesPerColor[ci] / 3).ceil();
      basketsByColor[ci] = List.generate(cnt, (_) => Basket(ci, 0, 0));
    }

    // 고배수 색상 파악 (멀티플라이어 박스가 있는 색)
    final highMultiColors = <int>{};
    for (final b in boxes) {
      if (b.multiplier >= 3) highMultiColors.add(b.colorIndex);
    }

    // 라운드 로빈 방식으로 흩어서 배치 — 고배수 색은 큐 앞에 배치
    final mixed = <Basket>[];
    // 고배수 색 큐를 앞에, 일반 색 큐를 뒤에 정렬
    final highQueues = <List<Basket>>[];
    final normalQueues = <List<Basket>>[];
    for (final ci in colorOrder) {
      final q = List<Basket>.from(basketsByColor[ci]!);
      if (highMultiColors.contains(ci)) { highQueues.add(q); } else { normalQueues.add(q); }
    }
    final queues = [...highQueues, ...normalQueues];
    while (queues.any((q) => q.isNotEmpty)) {
      for (final q in queues) {
        if (q.isNotEmpty) mixed.add(q.removeAt(0));
      }
    }

    // 행 단위 열 위치 셔플 (같은 행 내 다양하게)
    final totalBasketRows = (mixed.length / gc).ceil();
    for (int row = 0; row < totalBasketRows; row++) {
      final start = row * gc;
      final end = min(start + gc, mixed.length);
      final rowItems = mixed.sublist(start, end)..shuffle(r);
      for (int j = 0; j < rowItems.length; j++) mixed[start + j] = rowItems[j];
    }

    for (int i = 0; i < mixed.length; i++) { mixed[i].col = i % gc; mixed[i].row = i ~/ gc; }
    baskets = mixed;
    slots = List.filled(_nSlots, null);
    physMarbles = []; clearing = []; fx = [];
    combo = 0; comboTxt = null; comboAlpha = 0;
    trackOffset = 0; _clearDir = 1; _fullBeltTimer = 0;
    speed = 0.0012 + level * 0.0003; if (speed > 0.005) speed = 0.005;
    playing = true; over = false; paused = false;
    loop?.cancel();
    loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  // ── 게임 루프 ──
  void _tick() {
    if (paused) return;
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

      // 벨트 꽉 참: 한 바퀴(trackOffset 1.0) 돌 때까지 대기 후 종료
      if (playing) {
        final fullSlots = slots.where((s) => s != null).length;
        final waitingInFunnel = physMarbles.where((m) => m.state == 0).length;
        if (fullSlots >= _nSlots && waitingInFunnel > 0) {
          _fullBeltTimer += speed.abs();
          if (_fullBeltTimer >= 1.0) {
            playing = false; over = true;
            loop?.cancel();
            Future.delayed(const Duration(milliseconds: 300), () => _showOver());
          }
        } else {
          _fullBeltTimer = 0;
        }
      }

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
    const gravity = 0.35, bounce = 0.8, friction = 0.97;

    final active = <_PhysMarble>[];
    for (final m in physMarbles) {
      if (m.state != 0) continue;
      active.add(m);

      m.vy += gravity;
      m.vx *= friction;
      m.x += m.vx;
      m.y += m.vy;

      // 벽 충돌: 직사각형 구간 vs 곡선 좁아지는 구간
      double wallHalfW;
      bool inNarrow = false;
      double curveF = 0;
      if (m.y <= nStart) {
        wallHalfW = cHalfW - mR - 3;
      } else {
        inNarrow = true;
        final f = ((m.y - nStart) / (fBot - nStart)).clamp(0.0, 1.0);
        curveF = f * f; // easeIn 곡선: 완만하게 시작 → 급격히 좁아짐
        wallHalfW = (cHalfW + (eHalfW - cHalfW) * curveF) - mR;
      }
      final left = cx - wallHalfW, right = cx + wallHalfW;
      if (m.x < left) {
        m.x = left; m.vx = m.vx.abs() * bounce;
        if (inNarrow) m.vy = -m.vy.abs() * (0.4 + curveF * 0.5); // 곡선벽: 위로 튕김
      }
      if (m.x > right) {
        m.x = right; m.vx = -m.vx.abs() * bounce;
        if (inNarrow) m.vy = -m.vy.abs() * (0.4 + curveF * 0.5);
      }

      // 상단 벽
      if (m.y < fTop + mR + 3) { m.y = fTop + mR + 3; m.vy = m.vy.abs() * bounce * 0.3; }

      // 속도 제한
      if (m.vx.abs() > 12) m.vx = 12 * m.vx.sign;
      if (m.vy.abs() > 16) m.vy = 16 * m.vy.sign;

      // 깔대기 탈출 → 빈 홈이 출구 아래를 지날 때만 이동
      if (m.y >= fBot) {
        final slot = _findNextEmptySlot(m);
        if (slot >= 0) {
          m.state = 1; m.startX = m.x; m.startY = fBot;
          m.transProgress = 0; m.targetSlot = slot;
        } else {
          // 빈 홈 없으면 튕겨서 대기
          m.y = fBot - 1;
          m.vy = -m.vy.abs() * 0.4;
        }
      }
    }

    // 구슬 간 충돌 (탄성) — 다른 색은 50% 확률로 통과
    final rng = Random();
    for (int i = 0; i < active.length; i++) {
      for (int j = i + 1; j < active.length; j++) {
        final a = active[i], b = active[j];
        final dx = b.x - a.x, dy = b.y - a.y;
        final dist = sqrt(dx * dx + dy * dy);
        final minDist = mR * 2.1;
        if (dist < minDist && dist > 0.1) {
          // 다른 색 구슬은 50% 확률로 통과 (겹침만 해소)
          if (a.colorIndex != b.colorIndex && rng.nextDouble() < 0.5) {
            final nx = dx / dist, ny = dy / dist, overlap = minDist - dist;
            a.x -= nx * overlap / 2; a.y -= ny * overlap / 2;
            b.x += nx * overlap / 2; b.y += ny * overlap / 2;
            continue;
          }
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
    // 벨트 상단 중앙(t≈0) 근처 빈 홈만 허용
    const topRange = 0.06;
    int best = -1; double bestDist = topRange;
    for (int idx = 0; idx < _nSlots; idx++) {
      if (slots[idx] != null) continue;
      if (physMarbles.any((p) => p != pm && p.targetSlot == idx && p.state >= 0)) continue;
      final t = (idx / _nSlots + trackOffset) % 1.0;
      final d = min(t, 1.0 - t);
      if (d < bestDist) { bestDist = d; best = idx; }
    }
    return best;
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

  void _tap(Offset p) { if (!playing || paused) return; _tapBox(p); }

  // 박스 인덱스 → 화면 좌표 (아래부터 채움)
  Rect _boxRect(int i) {
    final l = _l!;
    final cols = l.boxCols;
    const gap = 4.0;
    final cx = l.w / 2;
    final sx = cx - l.boxTotalW / 2;
    final col = i % cols, topRow = i ~/ cols;
    final bx = sx + col * (l.bSz + gap);
    final by = l.boxTop + l.boxAreaH - (topRow + 1) * (l.bSz + gap) + gap;
    return Rect.fromLTWH(bx, by, l.bSz, l.bSz);
  }

  void _tapBox(Offset p) {
    if (_l == null) return;
    for (int i = 0; i < boxes.length; i++) {
      if (boxes[i].released || boxes[i].locked) continue;
      final r = _boxRect(i);
      if (r.contains(p)) {
        _releaseBox(i);
        return;
      }
    }
  }

  // 인접 박스 잠금 해제 (상하좌우)
  void _unlockAdjacent(int idx) {
    final cols = _l!.boxCols;
    final col = idx % cols, row = idx ~/ cols;
    final neighbors = <int>[];
    if (col > 0) neighbors.add(idx - 1);           // 왼쪽
    if (col < cols - 1) neighbors.add(idx + 1);     // 오른쪽
    if (row > 0) neighbors.add(idx - cols);          // 위
    if (row + 1 < (boxes.length / cols).ceil()) {
      final below = idx + cols;
      if (below < boxes.length) neighbors.add(below); // 아래
    }
    for (final ni in neighbors) {
      if (ni >= 0 && ni < boxes.length && !boxes[ni].released) {
        boxes[ni].locked = false;
      }
    }
  }

  void _releaseBox(int boxIdx) {
    boxes[boxIdx].released = true;
    _unlockAdjacent(boxIdx);
    final ci = boxes[boxIdx].colorIndex;
    if (_l == null) return;
    final l = _l!;
    final rng = Random();
    final cx = l.w / 2;
    // 구슬을 컨테이너 전체 폭에 퍼뜨려 생성
    final br = _boxRect(boxIdx);
    final by = br.bottom + l.mR;
    final mc = boxes[boxIdx].marbleCount;
    for (int j = 0; j < mc; j++) {
      final px = cx + (rng.nextDouble() - 0.5) * l.containerW * 0.7;
      final py = by + rng.nextDouble() * l.mR * 3;
      final vx = (rng.nextDouble() - 0.5) * 14;
      final vy = rng.nextDouble() * 4;
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
            onPressed: () async {
              Navigator.pop(c);
              final adService = AdService();
              final result = await adService.showRewardedAd(
                onUserEarnedReward: (ad, reward) {
                  setState(() { score = 0; lives = 3; level = 1; _start(); });
                },
              );
              if (!result && mounted) {
                setState(() { score = 0; lives = 3; level = 1; _start(); });
                adService.loadRewardedAd();
              }
            },
            child: Text('common.tryAgain'.tr(), style: const TextStyle(color: Colors.black))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(child: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: (e) {
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.space && playing) {
            setState(() { paused = !paused; });
          }
        },
        child: GestureDetector(
        onTapDown: (d) => _tap(d.localPosition),
        child: LayoutBuilder(builder: (ctx, cons) {
          sz = Size(cons.maxWidth, cons.maxHeight);
          _l = _calcLayout(sz.width, sz.height, boxes.length, baskets.length);
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
              if (playing)
                Positioned(top: 4, right: 40, child: IconButton(
                    icon: Icon(paused ? Icons.play_arrow : Icons.pause, color: Colors.white70, size: 24),
                    onPressed: () => setState(() { paused = !paused; }))),
              if (paused)
                Positioned.fill(child: GestureDetector(
                  onTap: () => setState(() { paused = false; }),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    alignment: Alignment.center,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.pause_circle_outline, color: Colors.white, size: 64),
                      const SizedBox(height: 12),
                      Text('common.paused'.tr(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('games.marbleSort.tapToSort'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 14)),
                    ]),
                  ),
                )),
              if (playing && !paused && lives <= 1)
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
      ))),
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
  }

  // ── 깔대기 컨테이너 (박스 감싸기 + 구슬 낙하 공간) ──
  void _drawFunnel(Canvas canvas) {
    final cx = l.w / 2;
    final topW = l.containerW, botW = l.beltEntryW;
    final top = l.funnelTop, nStart = l.narrowStart, bot = l.funnelBot;
    const cR = 14.0;

    // 채우기용 닫힌 경로 (배경)
    final fill = Path()
      ..moveTo(cx - topW / 2, top + cR)
      ..quadraticBezierTo(cx - topW / 2, top, cx - topW / 2 + cR, top)
      ..lineTo(cx + topW / 2 - cR, top)
      ..quadraticBezierTo(cx + topW / 2, top, cx + topW / 2, top + cR)
      ..lineTo(cx + topW / 2, nStart)
      ..quadraticBezierTo(cx + topW / 2, bot, cx + botW / 2, bot)
      ..lineTo(cx - botW / 2, bot)
      ..quadraticBezierTo(cx - topW / 2, bot, cx - topW / 2, nStart)
      ..close();
    canvas.drawPath(fill, Paint()..color = const Color(0xFF2A2A4A));

    // 내부 배경
    final inner = Path()
      ..moveTo(cx - topW / 2 + 3, top + cR)
      ..quadraticBezierTo(cx - topW / 2 + 3, top + 3, cx - topW / 2 + cR, top + 3)
      ..lineTo(cx + topW / 2 - cR, top + 3)
      ..quadraticBezierTo(cx + topW / 2 - 3, top + 3, cx + topW / 2 - 3, top + cR)
      ..lineTo(cx + topW / 2 - 3, nStart)
      ..quadraticBezierTo(cx + topW / 2 - 3, bot - 2, cx + botW / 2 - 2, bot - 2)
      ..lineTo(cx - botW / 2 + 2, bot - 2)
      ..quadraticBezierTo(cx - topW / 2 + 3, bot - 2, cx - topW / 2 + 3, nStart)
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFF151528));

    // 테두리: 하단 출구 부분 열린 상태로 개별 선 그리기
    final sp = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke..strokeWidth = 2;
    // 좌측 벽 (상단 → 좁아지는 곡선 → 출구)
    final leftWall = Path()
      ..moveTo(cx - botW / 2, bot)
      ..quadraticBezierTo(cx - topW / 2, bot, cx - topW / 2, nStart)
      ..lineTo(cx - topW / 2, top + cR)
      ..quadraticBezierTo(cx - topW / 2, top, cx - topW / 2 + cR, top);
    canvas.drawPath(leftWall, sp);
    // 상단
    canvas.drawLine(Offset(cx - topW / 2 + cR, top), Offset(cx + topW / 2 - cR, top), sp);
    // 우측 벽
    final rightWall = Path()
      ..moveTo(cx + topW / 2 - cR, top)
      ..quadraticBezierTo(cx + topW / 2, top, cx + topW / 2, top + cR)
      ..lineTo(cx + topW / 2, nStart)
      ..quadraticBezierTo(cx + topW / 2, bot, cx + botW / 2, bot);
    canvas.drawPath(rightWall, sp);

    // 출구 양쪽에서 아래로 내려가는 선
    final exitLen = l.mR * 3;
    final ep = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - botW / 2, bot), Offset(cx - botW / 2, bot + exitLen), ep);
    canvas.drawLine(Offset(cx + botW / 2, bot), Offset(cx + botW / 2, bot + exitLen), ep);

    // 하단 화살표
    final ap = Paint()..color = Colors.amber.withValues(alpha: 0.35)..strokeWidth = 2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final aBot = bot + exitLen - 4;
    canvas.drawLine(Offset(cx, bot + 2), Offset(cx, aBot), ap);
    canvas.drawLine(Offset(cx - 4, aBot - 8), Offset(cx, aBot), ap);
    canvas.drawLine(Offset(cx + 4, aBot - 8), Offset(cx, aBot), ap);
  }

  // ── 상단 박스 (깔대기 안) ──
  void _drawBoxes(Canvas canvas) {
    final cx = l.w / 2, cols = l.boxCols;
    const gap = 4.0;
    final sx = cx - l.boxTotalW / 2;
    final r = l.drawR;
    final sp = r * 2; // 간격 없이 지름만큼 배치
    final gridW = sp * 2; // 3개: 0, sp, sp*2
    for (int i = 0; i < boxes.length; i++) {
      final b = boxes[i]; final col = i % cols, topRow = i ~/ cols;
      final bx = sx + col * (l.bSz + gap);
      final by = l.boxTop + l.boxAreaH - (topRow + 1) * (l.bSz + gap) + gap;
      final clr = _colors[b.colorIndex % _colors.length];
      final rr = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, l.bSz, l.bSz), const Radius.circular(6));
      if (b.released) {
        canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: 0.03));
        canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: 0.08)..style = PaintingStyle.stroke..strokeWidth = 1);
      } else if (b.locked) {
        // 잠긴 박스: 어두운 뚜껑
        canvas.drawRRect(rr, Paint()..color = const Color(0xFF2A2A40));
        canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 1.5);
        // 자물쇠 아이콘
        final lcx = bx + l.bSz / 2, lcy = by + l.bSz / 2;
        final ls = l.bSz * 0.18;
        final lockBody = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(lcx, lcy + ls * 0.2), width: ls * 1.4, height: ls * 1.1),
          Radius.circular(ls * 0.15));
        canvas.drawRRect(lockBody, Paint()..color = Colors.white.withValues(alpha: 0.3));
        final arc = Path()
          ..addArc(Rect.fromCenter(center: Offset(lcx, lcy - ls * 0.3), width: ls * 0.9, height: ls * 0.9), pi, pi);
        canvas.drawPath(arc, Paint()..color = Colors.white.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 2);
      } else {
        // 열린 박스: 구슬 보임
        canvas.drawRRect(rr, Paint()..color = clr.withValues(alpha: 0.25));
        canvas.drawRRect(rr, Paint()..color = clr.withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 1.5);
        final ox = bx + (l.bSz - gridW) / 2, oy = by + (l.bSz - gridW) / 2;
        for (int ry = 0; ry < 3; ry++) for (int cx2 = 0; cx2 < 3; cx2++) {
          _marble(canvas, ox + cx2 * sp, oy + ry * sp, r, b.colorIndex);
        }
      }
      // 멀티플라이어 오버레이 (박스 중앙)
      if (!b.released && b.multiplier > 1) {
        final badge = 'x${b.multiplier}';
        final mcx = bx + l.bSz / 2, mcy = by + l.bSz / 2;
        final fs = l.bSz * 0.45;
        // 반투명 배경 원
        canvas.drawCircle(Offset(mcx, mcy), fs * 0.7,
          Paint()..color = Colors.black.withValues(alpha: 0.6));
        canvas.drawCircle(Offset(mcx, mcy), fs * 0.7,
          Paint()..color = Colors.amber.withValues(alpha: 0.9)..style = PaintingStyle.stroke..strokeWidth = 2);
        _txt(canvas, badge, mcx, mcy,
          TextStyle(color: Colors.amber, fontSize: fs, fontWeight: FontWeight.bold), c: true);
      }
    }
  }

  // ── 물리 구슬 (깔대기 안 + 슬롯 이동) ──
  void _drawPhysMarbles(Canvas canvas) {
    final g = l.geo;
    // 깔대기 안 구슬 클리핑
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, l.funnelTop, l.w, l.funnelBot));
    for (final pm in physMarbles) {
      if (pm.state == 0) {
        _marble(canvas, pm.x, pm.y, l.drawR, pm.colorIndex);
      }
    }
    canvas.restore();
    // 슬롯 이동 중 구슬은 클리핑 없이
    for (final pm in physMarbles) {
      if (pm.state == 1 && pm.targetSlot >= 0) {
        final p = pm.transProgress.clamp(0.0, 1.0);
        final slotT = (pm.targetSlot / _nSlots + trackOffset) % 1.0;
        final sp = g.pos(slotT);
        final mx = pm.startX + (sp.dx - pm.startX) * p;
        final my = pm.startY + (sp.dy - pm.startY) * p;
        _marble(canvas, mx, my, l.drawR, pm.colorIndex, a: 1.0 - p * 0.1);
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
    final slotR = l.drawR * 0.6;
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
      _marble(canvas, p.dx, p.dy, l.drawR, slots[i]!);
    }
  }

  // ── 하단 바구니 ──
  void _drawBaskets(Canvas canvas) {
    const gap = 4.0;
    final bw = (l.basketPw - gap * (l.gridCols - 1)) / l.gridCols;
    // 화면 밖 바구니 클리핑
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, l.basketTop, l.w, l.h - l.basketTop));
    for (final b in baskets) {
      final bx = l.basketMg + b.col * (bw + gap);
      final by = l.basketTop + b.row * (l.bktH + gap) + b.slideY * (l.bktH + gap);
      final clr = _colors[b.colorIndex % _colors.length];
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, l.bktH), const Radius.circular(5));
      canvas.drawRRect(rect, Paint()..color = clr.withValues(alpha: 0.45));
      canvas.drawRRect(rect, Paint()..color = clr.withValues(alpha: 0.9)..style = PaintingStyle.stroke..strokeWidth = 2.5);
      final r = l.drawR;
      final msp = r * 2.2;
      final mgw = msp * 2;
      final mox = bx + (bw - mgw) / 2;
      for (int k = 0; k < 3; k++) {
        final mx = mox + k * msp, my = by + l.bktH / 2;
        if (k < b.filled) { _marble(canvas, mx, my, r, b.colorIndex); }
        else {
          canvas.drawCircle(Offset(mx, my), r, Paint()..color = clr.withValues(alpha: 0.2));
          canvas.drawCircle(Offset(mx, my), r, Paint()..color = clr.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1);
        }
      }
    }
    canvas.restore();
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
      final r = l.drawR;
      final msp = r * 2.2;
      final mgw = msp * 2;
      final mox = bx + (bw - mgw) / 2;
      for (int k = 0; k < 3; k++) {
        final mx = mox + k * msp, my = by + l.bktH / 2;
        canvas.drawCircle(Offset(mx, my), r, Paint()..color = clr.withValues(alpha: alpha));
        canvas.drawCircle(Offset(mx - r * 0.2, my - r * 0.2), r * 0.3,
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
