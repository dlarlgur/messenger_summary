import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'plan_service.dart';

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

  /// 상품 정보 조회
  Future<List<ProductDetails>> getProducts() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return [];
      }
    }

    try {
      final ProductDetailsResponse response = 
          await _inAppPurchase.queryProductDetails(_productIds);
      
      if (response.error != null) {
        debugPrint('❌ 상품 조회 실패: ${response.error}');
        return [];
      }

      if (response.productDetails.isEmpty) {
        debugPrint('⚠️ 등록된 상품이 없습니다.');
        return [];
      }

      debugPrint('✅ 상품 조회 성공: ${response.productDetails.length}개');
      return response.productDetails;
    } catch (e) {
      debugPrint('❌ 상품 조회 에러: $e');
      return [];
    }
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
        await _handlePurchaseSuccess(purchase);
      }

      // 구매 완료 처리
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  /// 구매 성공 처리
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

      // 서버에 구독 요청
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
      } else {
        debugPrint('❌ 플랜 구독 실패');
        if (result != null) {
          debugPrint('에러 메시지: ${result['error']}');
        }
      }
    } catch (e) {
      debugPrint('❌ 구매 성공 처리 중 오류: $e');
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

  /// 리소스 정리
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
    debugPrint('✅ 인앱 결제 서비스 정리 완료');
  }
}
