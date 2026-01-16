package com.mhpark.gamecenter

import android.view.KeyEvent
import com.google.android.libraries.play.games.inputmapping.InputMappingProvider
import com.google.android.libraries.play.games.inputmapping.datamodel.*

/**
 * Google Play Games for PC Input SDK Provider
 * 게임별 키보드/마우스 매핑 정의
 */
class GameInputMappingProvider : InputMappingProvider {

    companion object {
        private const val VERSION = "1.0.0"

        // ===== 액션 ID 정의 =====
        private object ActionIds {
            const val MOVE_UP = 1L
            const val MOVE_DOWN = 2L
            const val MOVE_LEFT = 3L
            const val MOVE_RIGHT = 4L
            const val SELECT = 5L
            const val BACK = 6L
            const val UNDO = 7L
            const val PAUSE = 8L
            const val HINT = 9L
            // 숫자 입력 (스도쿠, 숫자야구 등)
            const val NUM_1 = 11L
            const val NUM_2 = 12L
            const val NUM_3 = 13L
            const val NUM_4 = 14L
            const val NUM_5 = 15L
            const val NUM_6 = 16L
            const val NUM_7 = 17L
            const val NUM_8 = 18L
            const val NUM_9 = 19L
            const val NUM_0 = 20L
            const val DELETE = 21L
            // 테트리스
            const val ROTATE = 30L
            const val DROP = 31L
            const val HOLD = 32L
        }

        // ===== 그룹 ID 정의 =====
        private object GroupIds {
            const val NAVIGATION = 1L
            const val GAME_ACTIONS = 2L
            const val NUMBER_INPUT = 3L
            const val TETRIS_ACTIONS = 4L
        }

        // ===== 컨텍스트 ID 정의 =====
        private object ContextIds {
            const val MENU = 1L
            const val BOARD_GAME = 2L
            const val PUZZLE_GAME = 3L
            const val ACTION_GAME = 4L
        }

        // ===== 이동 액션 =====
        private val moveUpAction = InputAction.create(
            "위로 이동",
            ActionIds.MOVE_UP,
            InputControls.create(
                listOf(KeyEvent.KEYCODE_W, KeyEvent.KEYCODE_DPAD_UP),
                emptyList()
            ),
            InputEnums.REMAP_OPTION_ENABLED
        )

        private val moveDownAction = InputAction.create(
            "아래로 이동",
            ActionIds.MOVE_DOWN,
            InputControls.create(
                listOf(KeyEvent.KEYCODE_S, KeyEvent.KEYCODE_DPAD_DOWN),
                emptyList()
            ),
            InputEnums.REMAP_OPTION_ENABLED
        )

        private val moveLeftAction = InputAction.create(
            "왼쪽 이동",
            ActionIds.MOVE_LEFT,
            InputControls.create(
                listOf(KeyEvent.KEYCODE_A, KeyEvent.KEYCODE_DPAD_LEFT),
                emptyList()
            ),
            InputEnums.REMAP_OPTION_ENABLED
        )

        private val moveRightAction = InputAction.create(
            "오른쪽 이동",
            ActionIds.MOVE_RIGHT,
            InputControls.create(
                listOf(KeyEvent.KEYCODE_D, KeyEvent.KEYCODE_DPAD_RIGHT),
                emptyList()
            ),
            InputEnums.REMAP_OPTION_ENABLED
        )

        // ===== 게임 동작 액션 =====
        private val selectAction = InputAction.create(
            "선택/확인",
            ActionIds.SELECT,
            InputControls.create(
                listOf(KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_SPACE),
                listOf(InputControls.MOUSE_LEFT_CLICK)
            ),
            InputEnums.REMAP_OPTION_ENABLED
        )

        private val backAction = InputAction.create(
            "뒤로가기",
            ActionIds.BACK,
            InputControls.create(
                listOf(KeyEvent.KEYCODE_ESCAPE, KeyEvent.KEYCODE_BACK),
                emptyList()
            ),
            InputEnums.REMAP_OPTION_DISABLED
        )

        private val undoAction = InputAction.create(
            "되돌리기",
            ActionIds.UNDO,
            InputControls.create(
                listOf(KeyEvent.KEYCODE_Z),
                emptyList()
            ),
            InputEnums.REMAP_OPTION_ENABLED
        )

        private val pauseAction = InputAction.create(
            "일시정지",
            ActionIds.PAUSE,
            InputControls.create(
                listOf(KeyEvent.KEYCODE_P),
                emptyList()
            ),
            InputEnums.REMAP_OPTION_ENABLED
        )

        private val hintAction = InputAction.create(
            "힌트",
            ActionIds.HINT,
            InputControls.create(
                listOf(KeyEvent.KEYCODE_H),
                emptyList()
            ),
            InputEnums.REMAP_OPTION_ENABLED
        )

        // ===== 숫자 입력 액션 =====
        private val numberActions = listOf(
            InputAction.create("1", ActionIds.NUM_1,
                InputControls.create(listOf(KeyEvent.KEYCODE_1), emptyList()),
                InputEnums.REMAP_OPTION_ENABLED),
            InputAction.create("2", ActionIds.NUM_2,
                InputControls.create(listOf(KeyEvent.KEYCODE_2), emptyList()),
                InputEnums.REMAP_OPTION_ENABLED),
            InputAction.create("3", ActionIds.NUM_3,
                InputControls.create(listOf(KeyEvent.KEYCODE_3), emptyList()),
                InputEnums.REMAP_OPTION_ENABLED),
            InputAction.create("4", ActionIds.NUM_4,
                InputControls.create(listOf(KeyEvent.KEYCODE_4), emptyList()),
                InputEnums.REMAP_OPTION_ENABLED),
            InputAction.create("5", ActionIds.NUM_5,
                InputControls.create(listOf(KeyEvent.KEYCODE_5), emptyList()),
                InputEnums.REMAP_OPTION_ENABLED),
            InputAction.create("6", ActionIds.NUM_6,
                InputControls.create(listOf(KeyEvent.KEYCODE_6), emptyList()),
                InputEnums.REMAP_OPTION_ENABLED),
            InputAction.create("7", ActionIds.NUM_7,
                InputControls.create(listOf(KeyEvent.KEYCODE_7), emptyList()),
                InputEnums.REMAP_OPTION_ENABLED),
            InputAction.create("8", ActionIds.NUM_8,
                InputControls.create(listOf(KeyEvent.KEYCODE_8), emptyList()),
                InputEnums.REMAP_OPTION_ENABLED),
            InputAction.create("9", ActionIds.NUM_9,
                InputControls.create(listOf(KeyEvent.KEYCODE_9), emptyList()),
                InputEnums.REMAP_OPTION_ENABLED),
            InputAction.create("0/지우기", ActionIds.NUM_0,
                InputControls.create(listOf(KeyEvent.KEYCODE_0, KeyEvent.KEYCODE_DEL), emptyList()),
                InputEnums.REMAP_OPTION_ENABLED)
        )

        // ===== 테트리스 전용 액션 =====
        private val rotateAction = InputAction.create(
            "회전",
            ActionIds.ROTATE,
            InputControls.create(
                listOf(KeyEvent.KEYCODE_R, KeyEvent.KEYCODE_SPACE),
                emptyList()
            ),
            InputEnums.REMAP_OPTION_ENABLED
        )

        private val dropAction = InputAction.create(
            "빠른 낙하",
            ActionIds.DROP,
            InputControls.create(
                listOf(KeyEvent.KEYCODE_SPACE),
                emptyList()
            ),
            InputEnums.REMAP_OPTION_ENABLED
        )

        private val holdAction = InputAction.create(
            "홀드",
            ActionIds.HOLD,
            InputControls.create(
                listOf(KeyEvent.KEYCODE_C, KeyEvent.KEYCODE_SHIFT_LEFT),
                emptyList()
            ),
            InputEnums.REMAP_OPTION_ENABLED
        )

        // ===== 그룹 정의 =====
        private val navigationGroup = InputGroup.create(
            "이동",
            listOf(moveUpAction, moveDownAction, moveLeftAction, moveRightAction),
            GroupIds.NAVIGATION,
            InputEnums.REMAP_OPTION_ENABLED
        )

        private val gameActionsGroup = InputGroup.create(
            "게임 동작",
            listOf(selectAction, backAction, undoAction, pauseAction, hintAction),
            GroupIds.GAME_ACTIONS,
            InputEnums.REMAP_OPTION_ENABLED
        )

        private val numberInputGroup = InputGroup.create(
            "숫자 입력",
            numberActions,
            GroupIds.NUMBER_INPUT,
            InputEnums.REMAP_OPTION_ENABLED
        )

        private val tetrisActionsGroup = InputGroup.create(
            "테트리스 조작",
            listOf(moveLeftAction, moveRightAction, moveDownAction, rotateAction, dropAction, holdAction),
            GroupIds.TETRIS_ACTIONS,
            InputEnums.REMAP_OPTION_ENABLED
        )

        // ===== 컨텍스트 정의 =====
        val menuContext = InputContext.create(
            "메뉴",
            InputIdentifier.create(VERSION, ContextIds.MENU),
            listOf(navigationGroup, gameActionsGroup)
        )

        val boardGameContext = InputContext.create(
            "보드 게임",
            InputIdentifier.create(VERSION, ContextIds.BOARD_GAME),
            listOf(navigationGroup, gameActionsGroup)
        )

        val puzzleGameContext = InputContext.create(
            "퍼즐 게임",
            InputIdentifier.create(VERSION, ContextIds.PUZZLE_GAME),
            listOf(navigationGroup, gameActionsGroup, numberInputGroup)
        )

        val actionGameContext = InputContext.create(
            "액션 게임",
            InputIdentifier.create(VERSION, ContextIds.ACTION_GAME),
            listOf(tetrisActionsGroup, gameActionsGroup)
        )
    }

    override fun onProvideInputMap(): InputMap {
        return InputMap.create(
            listOf(navigationGroup, gameActionsGroup, numberInputGroup, tetrisActionsGroup),
            MouseSettings.create(true, false),
            InputIdentifier.create(VERSION, 0L),
            InputEnums.REMAP_OPTION_ENABLED,
            // ESC와 Back은 리매핑 불가
            listOf(
                InputControls.create(listOf(KeyEvent.KEYCODE_ESCAPE), emptyList()),
                InputControls.create(listOf(KeyEvent.KEYCODE_BACK), emptyList())
            )
        )
    }
}
