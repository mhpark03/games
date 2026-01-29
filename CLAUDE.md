# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

Flutter 기반 게임 센터 앱으로, 다양한 보드 게임과 카드 게임을 포함합니다.

## 개발 명령어

```bash
# 의존성 설치
flutter pub get

# 앱 실행
flutter run

# 빌드
flutter build apk              # Android APK
flutter build appbundle        # Android AAB (스토어 배포용)
flutter build ios              # iOS
flutter build windows          # Windows

# 분석
flutter analyze
```

## 다국어 지원

`easy_localization` 패키지를 사용하여 4개 언어 지원:
- `assets/translations/ko.json` - 한국어 (기본)
- `assets/translations/en.json` - 영어
- `assets/translations/ja.json` - 일본어
- `assets/translations/zh.json` - 중국어

사용법: `'key'.tr()` 또는 `context.tr('key')`

## 아키텍처

### 디렉토리 구조
- `lib/main.dart` - 앱 진입점 및 홈 화면 (게임 선택 다이얼로그 포함)
- `lib/games/` - 각 게임별 폴더
- `lib/services/` - 공통 서비스 (게임 저장, Gemini API 등)

### 게임 저장 시스템
`GameSaveService` (`lib/services/game_save_service.dart`)를 통해 게임 상태를 SharedPreferences에 저장합니다.
- 한 번에 하나의 게임만 저장 가능
- 각 게임 화면에서 `hasSavedGame()`, `loadGame()`, `saveGame()`, `clearSavedGame()` 정적 메서드 구현

### 광고 시스템
`AdService` (`lib/services/ad_service.dart`) 싱글톤으로 Google AdMob 광고 관리
- 보상형 광고: 힌트/되돌리기 기능에 연동
- 배너 광고: 홈 화면 하단
- 네트워크 미연결 시에도 기능 사용 가능 (광고 없이 실행)
- 광고 다이얼로그 패턴:
```dart
void _showAdDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      // ... 다이얼로그 내용
      actions: [
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            final adService = AdService();
            final result = await adService.showRewardedAd(
              onUserEarnedReward: (ad, reward) {
                _executeFeature(); // 기능 실행
              },
            );
            if (!result && mounted) {
              _executeFeature(); // 광고 없어도 기능 실행
              adService.loadRewardedAd();
            }
          },
          child: const Text('광고 보기'),
        ),
      ],
    ),
  );
}
```

### 게임 화면 패턴
각 게임은 `lib/games/{game_name}/{game_name}_screen.dart` 형식으로 구성됩니다.
- `resumeGame` 파라미터로 이어하기 지원
- 게임 모드, 난이도 등은 enum으로 정의
- 컴퓨터 AI는 각 게임 화면 내에 구현

### 주요 게임
| 게임 | 폴더 | 특징 |
|------|------|------|
| 오목 | `gomoku/` | vs 컴퓨터(흑/백), 2인 플레이, 난이도 선택, 되돌리기(광고) |
| 오델로 | `othello/` | vs 컴퓨터(흑/백), 2인 플레이, 난이도 선택, 되돌리기(광고) |
| 체스 | `chess/` | vs 컴퓨터(흑/백), 2인 플레이, 되돌리기(광고) |
| 장기 | `janggi/` | vs 컴퓨터(초/한), 2인 플레이 |
| 원카드 | `onecard/` | 2~4인, 컴퓨터 AI |
| 윷놀이 | `yutnori/` | 2~4인, 컴퓨터 AI |
| 훌라 | `hula/` | 2~4인, 컴퓨터 AI (땡큐, 멜드 등록) |
| 테트리스 | `tetris/` | 싱글 플레이 |
| 지뢰찾기 | `minesweeper/` | 난이도 선택, 힌트(광고) |
| 솔리테어 | `solitaire/` | 클론다이크, 되돌리기(광고) |
| 숫자야구 | `baseball/` | vs 컴퓨터, 힌트(광고) |
| 스도쿠 | `sudoku/` | 일반/사무라이/킬러 (별도 저장 시스템) |
| 넘버 썸즈 | `number_sums/` | 5x5/6x6/7x7 합계 힌트, 힌트 모드(광고) |
| 미로찾기 | `maze/` | 쉬움/보통/어려움, DFS 미로 생성 |
| 두더지 잡기 | `mole/` | 30초 타이머, 점수 시스템 |
| 버블 슈터 | `bubble/` | 12x8 그리드, 물리 엔진, 3개 연결 제거 |

## 윷놀이 말판 구조

```
          10/28 ─── 9 ─── 8 ─── 7 ─── 6 ─── 5/21
            |  \                             /  |
            |    29                       22    |
           11      \                     /      4
            |        30               23        |
           12          \             /          3
            |           31/24 (중앙)            |
           13          /             \          2
            |        25               32        |
           14      /                     \      1
            |    26                       33    |
            |  /                             \  |
          15/27 ── 16 ── 17 ── 18 ── 19 ── 0/20/34
```

### 위치 번호 체계

#### 외곽 경로 (0-19)
| 위치 | 설명 |
|-----|------|
| 0 | 시작점/우하단 코너 (→34로 변환) |
| 1-4 | 우측 변 (아래→위) |
| 5 | 우상단 코너 (→21로 변환, 멈출 때만) |
| 6-9 | 상단 변 (오른쪽→왼쪽) |
| 10 | 좌상단 코너 (→28로 변환, 멈출 때만) |
| 11-14 | 좌측 변 (위→아래) |
| 15 | 좌하단 코너 |
| 16-19 | 하단 변 (왼쪽→오른쪽) |

#### 우상단 대각선 (21-27)
| 위치 | 설명 |
|-----|------|
| 21 | 우상단 코너 (=5) |
| 22 | 우상단 대각선 1/3 |
| 23 | 우상단 대각선 2/3 |
| 24 | 중앙 (→31로 변환, 멈출 때만) |
| 25 | 중앙→좌하단 1/3 |
| 26 | 중앙→좌하단 2/3 |
| 27 | 좌하단 코너 (→15로 변환, 항상) |

#### 좌상단 대각선 (28-33)
| 위치 | 설명 |
|-----|------|
| 28 | 좌상단 코너 (=10) |
| 29 | 좌상단 대각선 1/3 |
| 30 | 좌상단 대각선 2/3 |
| 31 | 중앙 (=24) |
| 32 | 중앙→우하단 1/3 |
| 33 | 중앙→우하단 2/3 |

#### 특수 위치
| 위치 | 설명 |
|-----|------|
| 34 | 시작점 (=0=20, 한 바퀴 완료) |
| 100 | 골인 완료 |
| -1 | 대기 (출발 전) |

### 자동 변환 규칙

#### 멈출 때만 변환
| 도착 위치 | 변환 | 설명 |
|----------|------|------|
| 5 | 21 | 우상단 코너에서 대각선 진입 |
| 10 | 28 | 좌상단 코너에서 대각선 진입 |
| 24 | 31 | 중앙에서 우하단 방향으로 변경 |

#### 항상 변환 (지나갈 때도)
| 도착 위치 | 변환 | 설명 |
|----------|------|------|
| 27 | 15 | 좌하단 코너로 외곽 합류 |
| 0 | 34 | 시작점 |
| 20 | 34 | 한 바퀴 완료 |

### 경로

#### 우상단 대각선 경로
```
21 → 22 → 23 → 24(→31) → 32 → 33 → 골인
                ↓ (지나갈 때)
               25 → 26 → 27(→15) → 16 → 17 → 18 → 19 → 34 → 골인
```

#### 좌상단 대각선 경로
```
28 → 29 → 30 → 31 → 32 → 33 → 골인
```

#### 외곽 경로
```
1 → 2 → 3 → 4 → 5(→21) → ... (대각선으로)
                    ↓ (지나갈 때)
                    6 → 7 → 8 → 9 → 10(→28) → ... (대각선으로)
                                        ↓ (지나갈 때)
                                       11 → ... → 15 → 16 → 17 → 18 → 19 → 34 → 골인
```

## 훌라 게임 규칙

### 턴 진행
- `currentTurn`: 0 = 플레이어, 1~3 = 컴퓨터
- 턴 변경 시 반드시 `_saveGame()` 호출 필요 (이어하기 정확성)
- 땡큐 시스템: 다른 플레이어가 버린 카드를 가져갈 수 있음

### 멜드 시스템
- Run: 같은 무늬 연속 3장 이상
- Group: 같은 숫자 3~4장
- 7 카드: 단독 등록 가능, 다른 플레이어 멜드에 붙여놓기 가능

## 스도쿠 게임

### 게임 종류
| 게임 | 화면 | 설명 |
|------|------|------|
| 일반 스도쿠 | `sudoku/screens/game_screen.dart` | 9x9 클래식, 쉬움/보통/어려움/달인 |
| 사무라이 스도쿠 | `sudoku/screens/samurai_game_screen.dart` | 5개 보드 겹침 |
| 킬러 스도쿠 | `sudoku/screens/killer_game_screen.dart` | 케이지 합계 맞추기 |

### 저장 시스템
스도쿠는 `sudoku/services/game_storage.dart`에서 별도 저장 관리
- 게임 종류별 독립 저장 (일반, 사무라이, 킬러)
- main.dart에서 `sudoku.` prefix로 import

## 오목 AI 패턴 우선순위

`lib/games/gomoku/gomoku_screen.dart`에서 AI 패턴 감지 우선순위:

1. **순수 연속 3** (`_●●●_`) - 양쪽 열림, 최우선 차단
2. **한칸 건너뛴+연속 3** (`●_●●●`) - 한쪽에 3개 이상 연속
3. **한칸 건너뛴 + 양끝 열림** - 빈칸 채우면 양쪽 열린 4
4. **양끝 막힌 연속 3** (`○_●●●_○`) - 양쪽 빈칸 너머에 상대돌, 낮은 우선순위
5. **일반 한칸 건너뛴 패턴** (`●_●●`)
6. **3x3 가능 위치** - 후순위

### 난이도별 AI 함수
- 쉬움: `_findOpenThree()` - 기본 패턴 감지
- 보통/어려움: `_blockOpenThreeSmartHard()` - 점수 평가로 최적 위치 선택
