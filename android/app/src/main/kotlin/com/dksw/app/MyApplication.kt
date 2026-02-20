package com.dksw.app

import android.app.Application
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class MyApplication : Application() {
    companion object {
        private const val TAG = "MyApplication"
        const val FLUTTER_ENGINE_ID = "default_flutter_engine"
    }

    private lateinit var flutterEngine: FlutterEngine

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🚀 Application onCreate - Flutter 엔진 예열 시작")
        
        try {
            // 이미 캐시에 엔진이 있는지 확인
            val cachedEngine = FlutterEngineCache.getInstance().get(FLUTTER_ENGINE_ID)
            if (cachedEngine != null) {
                Log.d(TAG, "✅ 이미 캐시된 Flutter 엔진 발견 - 재사용")
                flutterEngine = cachedEngine
                return
            }
            
            // Flutter 엔진을 미리 생성하여 캐시에 저장
            flutterEngine = FlutterEngine(this)
            
            // Dart 코드 실행 시작 (엔진 예열)
            flutterEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            
            // 엔진을 캐시에 저장하여 MainActivity에서 재사용
            FlutterEngineCache.getInstance().put(FLUTTER_ENGINE_ID, flutterEngine)
            
            Log.d(TAG, "✅ Flutter 엔진 예열 완료 - 캐시에 저장됨")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Flutter 엔진 예열 실패: ${e.message}", e)
            // 예외가 발생해도 앱이 크래시하지 않도록 처리
        }
    }
}
