import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'plan_service.dart';

/// 구매 검증 결과
class PurchaseVerificationResult {
  final bool success;
  final String message;
  final String? planType;

  PurchaseVerificationResult({
    required this.success,
    required this.message,
    this.planType,
  });
}

/// 인앱 결제 서비스
class InAppPurchaseService {
  static final InAppPurchaseService _instance = InAppPurchaseService._internal();
  factory InAppPurchaseService() => _instance;
  InAppPurchaseService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // 상품 ID 정의
  static const String basicPlanMonthly = 'basic_plan_monthly';
  static const Set<String> _productIds = {basicPlanMonthly};

  bool _isInitialized = false;
  final PlanService _planService = PlanService();

  // 검증 결과 스트림
  final StreamController<PurchaseVerificationResult> _verificationResultController =
      StreamController<PurchaseVerificationResult>.broadcast();

  // 활성 구독의 purchaseToken 캐시 (앱 실행 시 구독 부활용)
  String? _cachedPurchaseToken;

  // purchaseToken 캐시 완료를 알리는 Completer (queryPastPurchases 대기용)
  Completer<String?>? _purchaseTokenCompleter;

  /// 검증 결과 스트림 (UI에서 구독)
  Stream<PurchaseVerificationResult> get verificationResultStream =>
      _verificationResultController.stream;

  /// 인앱 결제 초기화
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      debugPrint('❌ 인앱 결제를 사용할 수 없습니다.');
      return false;
    }

    // 구매 이력 리스너
    _subscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdate,
      onDone: () {
        _subscription?.cancel();
        _subscription = null;
      },
      onError: (error) {
        debugPrint('❌ 구매 스트림 에러: $error');
      },
    );

    _isInitialized = true;
    debugPrint('✅ 인앱 결제 초기화 완료');
    return true;
  }

  /// BillingClient 재연결 (unset 시 Dart는 살아있어도 Native는 끊긴 상태)
  void _forceReconnect() {
    _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
    debugPrint('🔵 [IAP] BillingClient 재연결 시도 (unset 감지)');
  }

  /// 상품 정보 조회
  Future<List<ProductDetails>> getProducts() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return [];
      }
    }

    ProductDetailsResponse response;
    try {
      response = await _inAppPurchase.queryProductDetails(_productIds);
    } catch (e) {
      if (e.toString().contains('BillingClient is unset') ||
          e.toString().contains('unset')) {
        _forceReconnect();
        final initialized = await initialize();
        if (!initialized) return [];
        try {
          response = await _inAppPurchase.queryProductDetails(_productIds);
        } catch (e2) {
          debugPrint('❌ 상품 조회 에러 (재시도 후): $e2');
          return [];
        }
      } else {
        debugPrint('❌ 상품 조회 에러: $e');
        return [];
      }
    }

    if (response.error != null) {
      final msg = response.error!.message ?? '';
      if (msg.contains('BillingClient is unset') || msg.contains('Try reconnecting')) {
        _forceReconnect();
        final initialized = await initialize();
        if (!initialized) return [];
        try {
          final retry = await _inAppPurchase.queryProductDetails(_productIds);
          if (retry.error != null) {
            debugPrint('❌ 상품 조회 실패 (재시도 후): ${retry.error}');
            return [];
          }
          if (retry.productDetails.isEmpty) return [];
          debugPrint('✅ 상품 조회 성공 (재연결 후): ${retry.productDetails.length}개');
          return retry.productDetails;
        } catch (e2) {
          debugPrint('❌ 상품 조회 에러 (재시도 후): $e2');
          return [];
        }
      }
      debugPrint('❌ 상품 조회 실패: ${response.error}');
      return [];
    }

    if (response.productDetails.isEmpty) {
      debugPrint('⚠️ 등록된 상품이 없습니다.');
      return [];
    }

    debugPrint('✅ 상품 조회 성공: ${response.productDetails.length}개');
    return response.productDetails;
  }

  /// 플랜 구매 시작
  Future<bool> purchasePlan(ProductDetails productDetails) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return false;
      }
    }

    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      if (productDetails.id == basicPlanMonthly) {
        // Android
        if (Platform.isAndroid) {
          final GooglePlayPurchaseParam androidParam = 
              GooglePlayPurchaseParam(
            productDetails: productDetails as GooglePlayProductDetails,
            changeSubscriptionParam: null,
          );
          final bool success = await _inAppPurchase.buyNonConsumable(
            purchaseParam: androidParam,
          );
          if (success) {
            debugPrint('✅ Android 구매 시작 성공');
          } else {
            debugPrint('❌ Android 구매 시작 실패');
          }
          return success;
        } 
        // iOS
        else if (Platform.isIOS) {
          final AppStorePurchaseParam iosParam = AppStorePurchaseParam(
            productDetails: productDetails as AppStoreProductDetails,
          );
          final bool success = await _inAppPurchase.buyNonConsumable(
            purchaseParam: iosParam,
          );
          if (success) {
            debugPrint('✅ iOS 구매 시작 성공');
          } else {
            debugPrint('❌ iOS 구매 시작 실패');
          }
          return success;
        }
      }
      
      debugPrint('❌ 지원하지 않는 상품 ID: ${productDetails.id}');
      return false;
    } catch (e) {
      debugPrint('❌ 구매 시작 실패: $e');
      return false;
    }
  }

  /// 구매 업데이트 처리
  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        debugPrint('⏳ 구매 대기 중: ${purchase.productID}');
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('❌ 구매 실패: ${purchase.error}');
        _handlePurchaseError(purchase);
      } else if (purchase.status == PurchaseStatus.purchased ||
                 purchase.status == PurchaseStatus.restored) {
        debugPrint('✅ 구매 성공: ${purchase.productID}');
        
        // purchaseToken 캐시 저장 (기기 변경 시 구독 부활용)
        final verificationData = purchase.verificationData;
        if (verificationData.serverVerificationData.isNotEmpty) {
          _cachedPurchaseToken = verificationData.serverVerificationData;
          debugPrint('💾 purchaseToken 캐시 저장: ${_cachedPurchaseToken!.substring(0, math.min(8, _cachedPurchaseToken!.length))}...');
          // Completer가 대기 중이면 완료 알림
          if (_purchaseTokenCompleter != null && !_purchaseTokenCompleter!.isCompleted) {
            _purchaseTokenCompleter!.complete(_cachedPurchaseToken);
          }
        }
        
        await _handlePurchaseSuccess(purchase);
      }

      // 구매 완료 처리
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  /// 구매 성공 처리
  /// 
  /// 새로운 구매 또는 구매 복원 시 호출됨
  /// 기기 변경 시에도 올바르게 처리하기 위해 getCurrentPlan()을 사용
  Future<void> _handlePurchaseSuccess(PurchaseDetails purchase) async {
    try {
      String? purchaseToken;
      String platform;

      // 플랫폼별로 영수증 토큰 추출
      if (Platform.isAndroid) {
        // Android: verificationData에서 purchaseToken 추출
        final verificationData = purchase.verificationData;
        if (verificationData.serverVerificationData.isNotEmpty) {
          // Android에서는 serverVerificationData가 purchaseToken입니다
          purchaseToken = verificationData.serverVerificationData;
          platform = 'android';
        } else {
          debugPrint('❌ Android 구매 토큰을 가져올 수 없습니다.');
          return;
        }
      } else if (Platform.isIOS) {
        // iOS: verificationData에서 transactionIdentifier 추출
        final verificationData = purchase.verificationData;
        if (verificationData.serverVerificationData.isNotEmpty) {
          // iOS에서는 serverVerificationData가 transactionIdentifier입니다
          purchaseToken = verificationData.serverVerificationData;
          platform = 'ios';
        } else {
          debugPrint('❌ iOS 구매 토큰을 가져올 수 없습니다.');
          return;
        }
      } else {
        debugPrint('❌ 지원하지 않는 플랫폼');
        return;
      }

      if (purchaseToken == null || purchaseToken.isEmpty) {
        debugPrint('❌ 영수증 토큰을 가져올 수 없습니다.');
        return;
      }

      debugPrint('📝 영수증 토큰: $purchaseToken');
      debugPrint('📱 플랫폼: $platform');
      debugPrint('🛒 상품 ID: ${purchase.productID}');

      // 기기 변경 시나리오를 고려하여 getCurrentPlan() 사용
      // 이 메서드는 purchaseToken으로 기존 구독을 찾아서 deviceIdHash를 업데이트함
      final currentPlan = await _planService.getCurrentPlan(purchaseToken: purchaseToken);
      
      if (currentPlan != null) {
        final planType = currentPlan['planType'] as String?;
        debugPrint('✅ 플랜 복원/활성화 완료: $planType');
        
        if (planType != null && planType != 'free') {
          // 플랜 정보 캐시 무효화 (다음 조회 시 최신 정보 가져옴)
          _planService.invalidateCache();

          // 성공 결과 전송
          _verificationResultController.add(PurchaseVerificationResult(
            success: true,
            message: '플랜이 활성화되었습니다.',
            planType: planType,
          ));
          return;
        }
      }

      // getCurrentPlan()으로 처리되지 않은 경우 (새로운 구매)
      // subscribePlan()으로 새 구독 등록 시도
      debugPrint('📝 새로운 구매로 간주, subscribePlan() 호출');
      final result = await _planService.subscribePlan(
        purchaseToken: purchaseToken,
        productId: purchase.productID,
        platform: platform,
      );

      if (result != null && result['success'] == true) {
        debugPrint('✅ 플랜 구독 완료: ${result['planType']}');
        debugPrint('📅 만료일: ${result['expiresAt']}');

        // 플랜 정보 캐시 무효화 (다음 조회 시 최신 정보 가져옴)
        _planService.invalidateCache();

        // 성공 결과 전송
        _verificationResultController.add(PurchaseVerificationResult(
          success: true,
          message: '플랜이 활성화되었습니다.',
          planType: result['planType'] as String?,
        ));
      } else {
        debugPrint('❌ 플랜 구독 실패');
        String errorMessage = '서버 검증에 실패했습니다. 잠시 후 다시 시도해주세요.';
        if (result != null && result['error'] != null) {
          debugPrint('에러 메시지: ${result['error']}');
          errorMessage = result['error'] as String;
        }

        // 실패 결과 전송
        _verificationResultController.add(PurchaseVerificationResult(
          success: false,
          message: errorMessage,
        ));
      }
    } catch (e) {
      debugPrint('❌ 구매 성공 처리 중 오류: $e');

      // 에러 결과 전송
      _verificationResultController.add(PurchaseVerificationResult(
        success: false,
        message: '서버 검증 중 오류가 발생했습니다.',
      ));
    }
  }

  /// 구매 에러 처리
  void _handlePurchaseError(PurchaseDetails purchase) {
    debugPrint('구매 에러: ${purchase.error}');
    if (purchase.error != null) {
      debugPrint('에러 코드: ${purchase.error!.code}');
      debugPrint('에러 메시지: ${purchase.error!.message}');
      debugPrint('에러 상세: ${purchase.error!.details}');
    }
  }

  /// 구매 복원 (iOS에서 주로 사용)
  Future<void> restorePurchases() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return;
      }
    }

    try {
      await _inAppPurchase.restorePurchases();
      debugPrint('✅ 구매 복원 요청 완료');
    } catch (e) {
      debugPrint('❌ 구매 복원 실패: $e');
    }
  }

  /// 캐시된 purchaseToken 조회 (앱 실행 시 구독 부활용)
  /// 
  /// 반환값: 캐시된 purchaseToken (있으면), null (없으면)
  String? getCachedPurchaseToken() {
    return _cachedPurchaseToken;
  }

  /// 과거 구매 내역 조회 및 purchaseToken을 대기하여 반환
  ///
  /// restorePurchases()를 호출하고, purchaseStream을 통해 purchaseToken이
  /// 캐시될 때까지 최대 [timeout] 동안 대기합니다.
  /// 기존의 500ms 고정 딜레이 대신, Completer 기반으로 정확히 대기합니다.
  Future<String?> queryPastPurchasesAndWaitForToken({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('❌ 인앱 결제 초기화 실패, 구매 내역 조회 불가');
        return null;
      }
    }

    try {
      // 이미 캐시된 purchaseToken이 있으면 바로 반환
      if (_cachedPurchaseToken != null) {
        debugPrint('✅ 이미 캐시된 purchaseToken 존재');
        return _cachedPurchaseToken;
      }

      // Completer 생성 (purchaseStream에서 토큰 수신 시 완료됨)
      _purchaseTokenCompleter = Completer<String?>();

      debugPrint('📱 과거 구매 내역 조회 시도 (restorePurchases 호출)');
      await _inAppPurchase.restorePurchases();
      debugPrint('✅ 구매 복원 요청 완료 (purchaseStream 결과 대기 중...)');

      // purchaseToken이 캐시될 때까지 대기 (타임아웃 적용)
      final token = await _purchaseTokenCompleter!.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint('⏰ purchaseToken 대기 타임아웃 (${timeout.inSeconds}초)');
          return _cachedPurchaseToken; // 타임아웃 시 현재 캐시 값 반환 (null일 수 있음)
        },
      );

      _purchaseTokenCompleter = null;
      return token;
    } catch (e) {
      debugPrint('❌ 과거 구매 내역 조회 실패: $e');
      _purchaseTokenCompleter = null;
      return null;
    }
  }

  /// 과거 구매 내역 조회 (하위 호환용)
  Future<void> queryPastPurchases() async {
    await queryPastPurchasesAndWaitForToken();
  }

  /// 리소스 정리
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _verificationResultController.close();
    _isInitialized = false;
    debugPrint('✅ 인앱 결제 서비스 정리 완료');
  }
}
