package com.dksw.app

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
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
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import android.os.Build
import android.view.ViewGroup

class OnboardingActivity : Activity() {
    companion object {
        private const val TAG = "OnboardingActivity"
        private const val PREFS_NAME = "onboarding_prefs"
        private const val KEY_AGREEMENT = "agreement_accepted"
        private const val REQUEST_POST_NOTIFICATIONS = 1001
        private const val REQUEST_NOTIFICATION_LISTENER = 1002
        private const val REQUEST_BATTERY_OPT = 1003
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
    private lateinit var loadingOverlay: FrameLayout

    private var isServiceExpanded = false
    private var isPrivacyExpanded = false
    
    // 약관 URL
    private val privacyUrl = "https://dksw4.com/privacy"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_onboarding)

        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // 뷰 초기화 먼저 수행 (loadingOverlay 등)
        initViews()

        // 이미 동의한 경우 MainActivity로 이동
        if (prefs.getBoolean(KEY_AGREEMENT, false)) {
            proceedToMainActivity()
            return
        }

        setupListeners()
        applySystemBarInsets()
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
        loadingOverlay = findViewById(R.id.loadingOverlay)
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
     * 시스템 네비게이션바 영역만큼 하단 패딩 적용 (모든 기종 대응)
     */
    private fun applySystemBarInsets() {
        val contentView = findViewById<ViewGroup>(android.R.id.content) ?: return
        val rootView = contentView.getChildAt(0) ?: return

        rootView.setOnApplyWindowInsetsListener { view, insets ->
            val bottomInset = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                insets.getInsets(android.view.WindowInsets.Type.systemBars()).bottom
            } else {
                @Suppress("DEPRECATION")
                insets.systemWindowInsetBottom
            }
            view.setPadding(
                view.paddingLeft,
                view.paddingTop,
                view.paddingRight,
                (24 * resources.displayMetrics.density).toInt() + bottomInset
            )
            insets
        }

        rootView.requestApplyInsets()
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
     * 동의 저장 후 MainActivity로 이동
     * 권한 설정은 MainActivity의 Flutter PermissionScreen에서 처리
     */
    private fun startPermissionFlow() {
        btnStart.isEnabled = false
        prefs.edit().putBoolean(KEY_AGREEMENT, true).apply()
        Log.d(TAG, "✅ 동의 여부 저장 완료 - MainActivity로 이동")
        proceedToMainActivity()
    }

    /**
     * MainActivity로 이동
     * 로딩 스피너를 표시하고 예열된 Flutter 엔진을 사용하여 즉시 화면 전환
     */
    private fun proceedToMainActivity() {
        Log.d(TAG, "✅ 모든 권한 처리 완료 - MainActivity로 이동")
        
        // 로딩 오버레이 표시
        loadingOverlay.visibility = View.VISIBLE
        
        // Flutter 엔진이 준비될 때까지 약간 대기 (엔진 예열 보장)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            try {
                val intent = Intent(this, MainActivity::class.java)
                intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                intent.putExtra("fromOnboarding", true) // OnboardingActivity에서 넘어왔음을 표시
                startActivity(intent)
                finish()
            } catch (e: Exception) {
                Log.e(TAG, "❌ MainActivity 시작 실패: ${e.message}", e)
                // 실패해도 앱이 크래시하지 않도록 처리
                loadingOverlay.visibility = View.GONE
            }
        }, 200) // 엔진 준비를 위한 최소 지연
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
