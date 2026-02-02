package com.example.chat_llm

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.view.View
import android.view.animation.Animation
import android.view.animation.Transformation
import android.net.Uri
import android.widget.Button
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

class OnboardingActivity : Activity() {
    companion object {
        private const val TAG = "OnboardingActivity"
        private const val PREFS_NAME = "onboarding_prefs"
        private const val KEY_AGREEMENT = "agreement_accepted"
        private const val REQUEST_BATTERY_OPTIMIZATION = 1001
        private const val REQUEST_NOTIFICATION_ACCESS = 1002
    }

    private lateinit var cbServiceAgreement: CheckBox
    private lateinit var cbPrivacyAgreement: CheckBox
    private lateinit var btnStart: Button
    private lateinit var prefs: SharedPreferences
    
    // 펼치기/접기 관련 뷰
    private lateinit var llServiceAgreement: LinearLayout
    private lateinit var llServiceHeader: LinearLayout
    private lateinit var llServiceContent: LinearLayout
    private lateinit var tvServiceExpand: TextView
    private lateinit var llPrivacyAgreement: LinearLayout
    private lateinit var llPrivacyHeader: LinearLayout
    private lateinit var llPrivacyContent: LinearLayout
    private lateinit var tvPrivacyExpand: TextView
    private lateinit var btnServiceFullText: Button
    private lateinit var btnPrivacyFullText: Button
    
    private var isServiceExpanded = false
    private var isPrivacyExpanded = false
    
    // 약관 URL
    private val privacyUrl = "https://dksw4.com/privacy"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_onboarding)

        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // 이미 동의한 경우 MainActivity로 이동
        if (prefs.getBoolean(KEY_AGREEMENT, false)) {
            proceedToMainActivity()
            return
        }

        initViews()
        setupListeners()
    }

    private fun initViews() {
        cbServiceAgreement = findViewById(R.id.cbServiceAgreement)
        cbPrivacyAgreement = findViewById(R.id.cbPrivacyAgreement)
        btnStart = findViewById(R.id.btnStart)
        
        // 펼치기/접기 관련 뷰
        llServiceAgreement = findViewById(R.id.llServiceAgreement)
        llServiceHeader = findViewById(R.id.llServiceHeader)
        llServiceContent = findViewById(R.id.llServiceContent)
        tvServiceExpand = findViewById(R.id.tvServiceExpand)
        llPrivacyAgreement = findViewById(R.id.llPrivacyAgreement)
        llPrivacyHeader = findViewById(R.id.llPrivacyHeader)
        llPrivacyContent = findViewById(R.id.llPrivacyContent)
        tvPrivacyExpand = findViewById(R.id.tvPrivacyExpand)
        btnServiceFullText = findViewById(R.id.btnServiceFullText)
        btnPrivacyFullText = findViewById(R.id.btnPrivacyFullText)
    }

    private fun setupListeners() {
        // 서비스 이용약관 펼치기/접기 (헤더 영역 클릭 시)
        llServiceHeader.setOnClickListener {
            toggleExpand(llServiceContent, tvServiceExpand, isServiceExpanded)
            isServiceExpanded = !isServiceExpanded
        }
        
        // 개인정보 처리방침 펼치기/접기 (헤더 영역 클릭 시)
        llPrivacyHeader.setOnClickListener {
            toggleExpand(llPrivacyContent, tvPrivacyExpand, isPrivacyExpanded)
            isPrivacyExpanded = !isPrivacyExpanded
        }
        
        // 체크박스 클릭 시 이벤트가 헤더로 전파되지 않도록
        cbServiceAgreement.setOnClickListener {
            // 체크박스만 동작
        }
        
        cbPrivacyAgreement.setOnClickListener {
            // 체크박스만 동작
        }
        
        // 체크박스 상태에 따라 버튼 활성화/비활성화
        val checkBoxListener = { _: View ->
            val allChecked = cbServiceAgreement.isChecked && cbPrivacyAgreement.isChecked
            btnStart.isEnabled = allChecked
            btnStart.alpha = if (allChecked) 1.0f else 0.5f
        }
        
        cbServiceAgreement.setOnCheckedChangeListener { _, _ ->
            checkBoxListener.invoke(cbServiceAgreement)
        }
        
        cbPrivacyAgreement.setOnCheckedChangeListener { _, _ ->
            checkBoxListener.invoke(cbPrivacyAgreement)
        }

        // 시작 버튼 클릭
        btnStart.setOnClickListener {
            if (cbServiceAgreement.isChecked && cbPrivacyAgreement.isChecked) {
                startPermissionFlow()
            }
        }
        
        // 전문 보기 버튼 클릭
        btnServiceFullText.setOnClickListener {
            openPrivacyUrl()
        }
        
        btnPrivacyFullText.setOnClickListener {
            openPrivacyUrl()
        }
    }
    
    /**
     * 약관 전문 보기 (브라우저 열기)
     */
    private fun openPrivacyUrl() {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(privacyUrl))
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "브라우저 열기 실패: ${e.message}")
            Toast.makeText(this, "브라우저를 열 수 없습니다.", Toast.LENGTH_SHORT).show()
        }
    }
    
    /**
     * 펼치기/접기 애니메이션
     */
    private fun toggleExpand(contentView: LinearLayout, expandTextView: TextView, isExpanded: Boolean) {
        if (isExpanded) {
            // 접기
            collapseView(contentView)
            expandTextView.text = "펼치기 ▼"
        } else {
            // 펼치기
            expandView(contentView)
            expandTextView.text = "접기 ▲"
        }
    }
    
    /**
     * 뷰 펼치기 애니메이션
     */
    private fun expandView(view: View) {
        view.measure(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        val targetHeight = view.measuredHeight
        
        view.layoutParams.height = 0
        view.visibility = View.VISIBLE
        
        val animation = object : Animation() {
            override fun applyTransformation(interpolatedTime: Float, t: Transformation?) {
                view.layoutParams.height = if (interpolatedTime == 1f) {
                    LinearLayout.LayoutParams.WRAP_CONTENT
                } else {
                    (targetHeight * interpolatedTime).toInt()
                }
                view.requestLayout()
            }
            
            override fun willChangeBounds(): Boolean {
                return true
            }
        }
        
        animation.duration = 300
        view.startAnimation(animation)
    }
    
    /**
     * 뷰 접기 애니메이션
     */
    private fun collapseView(view: View) {
        val initialHeight = view.measuredHeight
        
        val animation = object : Animation() {
            override fun applyTransformation(interpolatedTime: Float, t: Transformation?) {
                if (interpolatedTime == 1f) {
                    view.visibility = View.GONE
                } else {
                    view.layoutParams.height = initialHeight - (initialHeight * interpolatedTime).toInt()
                    view.requestLayout()
                }
            }
            
            override fun willChangeBounds(): Boolean {
                return true
            }
        }
        
        animation.duration = 300
        view.startAnimation(animation)
    }

    /**
     * Step 1: 동의 여부를 SharedPreferences에 저장
     * Step 2: 알림 접근 권한 확인
     * Step 3: 배터리 최적화 제외 권한 확인
     */
    private fun startPermissionFlow() {
        // Step 1: 동의 여부 저장
        prefs.edit().putBoolean(KEY_AGREEMENT, true).apply()
        Log.d(TAG, "✅ Step 1: 동의 여부 저장 완료")

        // Step 2: 알림 접근 권한 확인 (먼저)
        checkNotificationAccess()
    }

    /**
     * Step 2: 알림 접근 권한 확인
     */
    private fun checkNotificationAccess() {
        val enabledNotificationListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        )

        val packageName = packageName
        val isNotificationAccessEnabled = if (!TextUtils.isEmpty(enabledNotificationListeners)) {
            enabledNotificationListeners.split(":").any { listener ->
                val componentName = android.content.ComponentName.unflattenFromString(listener)
                componentName != null && TextUtils.equals(packageName, componentName.packageName)
            }
        } else {
            false
        }

        if (isNotificationAccessEnabled) {
            Log.d(TAG, "✅ Step 2: 알림 접근 권한 이미 설정됨")
            Toast.makeText(this, "알림 접근 권한이 이미 설정되어 있습니다.", Toast.LENGTH_SHORT).show()
            // Step 3로 진행
            checkBatteryOptimization()
        } else {
            Log.d(TAG, "⚠️ Step 2: 알림 접근 권한 필요")
            showNotificationAccessDialog()
        }
    }
    
    /**
     * 알림 접근 권한 안내 다이얼로그
     */
    private fun showNotificationAccessDialog() {
        AlertDialog.Builder(this)
            .setTitle(R.string.notification_access_title)
            .setMessage(R.string.notification_access_message)
            .setPositiveButton(R.string.go_to_settings) { _, _ ->
                // 알림 접근 권한 설정 화면으로 이동
                val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                startActivityForResult(intent, REQUEST_NOTIFICATION_ACCESS)
            }
            .setNegativeButton(R.string.cancel) { _, _ ->
                // 취소 시에도 다음 단계로 진행 (선택적)
                checkBatteryOptimization()
            }
            .setCancelable(false)
            .show()
    }

    /**
     * Step 3: 배터리 최적화 제외 권한 확인
     */
    private fun checkBatteryOptimization() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val isIgnoringBatteryOptimizations = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true // Android 6.0 미만은 항상 true
        }

        if (isIgnoringBatteryOptimizations) {
            Log.d(TAG, "✅ Step 3: 배터리 최적화 제외 이미 설정됨")
            Toast.makeText(this, "배터리 최적화 제외가 이미 설정되어 있습니다.", Toast.LENGTH_SHORT).show()
            // 모든 권한 설정 완료 - MainActivity로 이동
            proceedToMainActivity()
        } else {
            Log.d(TAG, "⚠️ Step 3: 배터리 최적화 제외 필요")
            showBatteryOptimizationDialog()
        }
    }

    /**
     * 배터리 최적화 제외 안내 다이얼로그
     */
    private fun showBatteryOptimizationDialog() {
        AlertDialog.Builder(this)
            .setTitle(R.string.battery_optimization_title)
            .setMessage(R.string.battery_optimization_message)
            .setPositiveButton(R.string.go_to_settings) { _, _ ->
                // 배터리 최적화 설정 화면으로 이동
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = android.net.Uri.parse("package:$packageName")
                    }
                    try {
                        startActivityForResult(intent, REQUEST_BATTERY_OPTIMIZATION)
                    } catch (e: Exception) {
                        Log.e(TAG, "배터리 최적화 설정 화면 이동 실패: ${e.message}")
                        // 대체 방법: 일반 설정 화면으로 이동
                        val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivityForResult(fallbackIntent, REQUEST_BATTERY_OPTIMIZATION)
                    }
                }
            }
            .setNegativeButton(R.string.cancel) { _, _ ->
                // 취소 시에도 다음 단계로 진행 (선택적)
                checkNotificationAccess()
            }
            .setCancelable(false)
            .show()
    }


    /**
     * 설정 화면에서 돌아온 후 처리
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            REQUEST_NOTIFICATION_ACCESS -> {
                Log.d(TAG, "알림 접근 권한 설정 화면에서 돌아옴")
                // 알림 접근 권한 확인 후 배터리 최적화 확인
                checkBatteryOptimization()
            }
            REQUEST_BATTERY_OPTIMIZATION -> {
                Log.d(TAG, "배터리 최적화 설정 화면에서 돌아옴")
                // 배터리 최적화 설정 후 MainActivity로 이동
                checkBatteryOptimization()
            }
        }
    }

    /**
     * MainActivity로 이동
     */
    private fun proceedToMainActivity() {
        Log.d(TAG, "✅ 모든 설정 완료 - MainActivity로 이동")
        val intent = Intent(this, MainActivity::class.java)
        // FLAG_ACTIVITY_CLEAR_TOP만 사용하여 같은 태스크에서 MainActivity를 시작
        // FLAG_ACTIVITY_NEW_TASK를 제거하여 새로운 태스크가 생성되지 않도록 함
        intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        startActivity(intent)
        finish()
    }

    /**
     * 뒤로가기 버튼 비활성화 (동의 전에는 앱을 종료할 수 없음)
     */
    override fun onBackPressed() {
        // 동의 전에는 뒤로가기 비활성화
        if (!cbServiceAgreement.isChecked || !cbPrivacyAgreement.isChecked) {
            Toast.makeText(this, "서비스 이용을 위해 모든 항목에 동의가 필요합니다.", Toast.LENGTH_SHORT).show()
            return
        }
        super.onBackPressed()
    }
}
