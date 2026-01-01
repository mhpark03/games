package com.mhpark.gamecenter

import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var keepSplash = true

    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 12+ 스플래시 스크린 설치
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val splashScreen = installSplashScreen()
            // 스플래시를 Flutter UI가 준비될 때까지 유지
            splashScreen.setKeepOnScreenCondition { keepSplash }
        }
        super.onCreate(savedInstanceState)
    }

    override fun onFlutterUiDisplayed() {
        // Flutter UI가 표시되면 스플래시 종료
        keepSplash = false
        super.onFlutterUiDisplayed()
    }
}
