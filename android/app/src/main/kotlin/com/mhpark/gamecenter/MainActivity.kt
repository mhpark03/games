package com.mhpark.gamecenter

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.libraries.play.games.inputmapping.Input
import com.google.android.libraries.play.games.inputmapping.InputMappingClient

class MainActivity : FlutterFragmentActivity() {
    private var inputMappingClient: InputMappingClient? = null

    companion object {
        private const val CHANNEL = "com.mhpark.gamecenter/input_sdk"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 12+ 스플래시 스크린 설치
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            installSplashScreen()
        }

        // Edge-to-edge 지원 (Android 15 호환성)
        enableEdgeToEdge()

        super.onCreate(savedInstanceState)

        // Edge-to-edge: 시스템 바가 콘텐츠 위에 오도록 설정
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // Android 15 (API 35+): deprecated SHORT_EDGES → ALWAYS로 전환
        if (Build.VERSION.SDK_INT >= 35) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        // Flutter PlatformPlugin이 시스템 바 설정을 덮어쓸 수 있으므로
        // edge-to-edge 및 cutout 모드를 재적용
        if (Build.VERSION.SDK_INT >= 35) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isGooglePlayGamesOnPC" -> {
                    result.success(isGooglePlayGamesOnPC())
                }
                "initInputMapping" -> {
                    initInputMapping()
                    result.success(true)
                }
                "setInputContext" -> {
                    val contextName = call.argument<String>("context") ?: "menu"
                    setInputContext(contextName)
                    result.success(true)
                }
                "clearInputMapping" -> {
                    clearInputMapping()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Google Play Games on PC 환경인지 확인
     */
    private fun isGooglePlayGamesOnPC(): Boolean {
        return packageManager.hasSystemFeature("com.google.android.play.feature.HPE_EXPERIENCE")
    }

    /**
     * Input Mapping 초기화
     */
    private fun initInputMapping() {
        if (!isGooglePlayGamesOnPC()) return

        try {
            inputMappingClient = Input.getInputMappingClient(this)
            inputMappingClient?.setInputMappingProvider(GameInputMappingProvider())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Input Context 설정
     * @param contextName: "menu", "board", "puzzle", "action"
     */
    private fun setInputContext(contextName: String) {
        if (!isGooglePlayGamesOnPC()) return

        try {
            val context = when (contextName) {
                "menu" -> GameInputMappingProvider.menuContext
                "board" -> GameInputMappingProvider.boardGameContext
                "puzzle" -> GameInputMappingProvider.puzzleGameContext
                "action" -> GameInputMappingProvider.actionGameContext
                else -> GameInputMappingProvider.menuContext
            }
            inputMappingClient?.setInputContext(context)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Input Mapping 정리
     */
    private fun clearInputMapping() {
        try {
            inputMappingClient?.clearInputMappingProvider()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        clearInputMapping()
        super.onDestroy()
    }
}
