package com.mhpark.gamecenter

import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.libraries.play.games.inputmapping.Input
import com.google.android.libraries.play.games.inputmapping.InputMappingClient

class MainActivity : FlutterActivity() {
    private var keepSplash = true
    private var inputMappingClient: InputMappingClient? = null

    companion object {
        private const val CHANNEL = "com.mhpark.gamecenter/input_sdk"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 12+ 스플래시 스크린 설치
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val splashScreen = installSplashScreen()
            // 스플래시를 Flutter UI가 준비될 때까지 유지
            splashScreen.setKeepOnScreenCondition { keepSplash }
        }
        super.onCreate(savedInstanceState)
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

    override fun onFlutterUiDisplayed() {
        // Flutter UI가 표시되면 스플래시 종료
        keepSplash = false
        super.onFlutterUiDisplayed()
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
