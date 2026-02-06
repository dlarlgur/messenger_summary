# 플랜 구독 (Plan Subscribe) 구현 가이드

## 개요

상용 배포 시 플랜 구독 시스템을 구현하는 방법입니다. 인앱 결제와 서버 API를 연동해야 합니다.

## 구현 단계

### 1. 인앱 결제 패키지 추가

`pubspec.yaml`에 다음 패키지를 추가합니다:

```yaml
dependencies:
  in_app_purchase: ^3.1.11
```

### 2. 서버 API 설계

#### POST /api/v1/plan/subscribe

**Request:**
```json
{
  "purchaseToken": "GPA.1234-5678-9012-34567",
  "productId": "basic_plan_monthly",
  "platform": "android"
}
```

**Response (성공):**
```json
{
  "success": true,
  "message": "플랜이 Basic으로 설정되었습니다.",
  "deviceIdHash": "abc123...",
  "planType": "basic",
  "expiresAt": "2024-02-29T23:59:59",
  "limit": 200,
  "period": "monthly"
}
```

**Response (실패):**
```json
{
  "success": false,
  "error": "결제 검증 실패: 유효하지 않은 영수증입니다."
}
```

### 3. 서버 측 구현 (Java/Spring)

```java
@PostMapping("/plan/subscribe")
public Mono<ResponseEntity<Map<String, Object>>> subscribePlan(
        @RequestBody Map<String, String> request) {
    String purchaseToken = request.get("purchaseToken");
    String productId = request.get("productId");
    String platform = request.get("platform");
    
    if (purchaseToken == null || productId == null || platform == null) {
        Map<String, Object> errorResponse = new HashMap<>();
        errorResponse.put("error", "필수 파라미터가 누락되었습니다.");
        return Mono.just(ResponseEntity.badRequest().body(errorResponse));
    }

    // 1. JWT 토큰에서 deviceIdHash 추출
    String deviceIdHash = getDeviceIdHashFromJwt();
    
    // 2. 결제 영수증 검증
    // Android: Google Play Developer API로 검증
    // iOS: App Store Server API로 검증
    boolean isValid = verifyPurchase(purchaseToken, productId, platform);
    
    if (!isValid) {
        Map<String, Object> errorResponse = new HashMap<>();
        errorResponse.put("error", "결제 검증 실패: 유효하지 않은 영수증입니다.");
        return Mono.just(ResponseEntity.badRequest().body(errorResponse));
    }
    
    // 3. 플랜 정보 매핑
    PlanType planType = mapProductIdToPlanType(productId);
    LocalDateTime expiresAt = calculateExpirationDate(productId);
    
    // 4. 플랜 설정
    return planService.setPlan(deviceIdHash, planType, expiresAt)
            .map(success -> {
                if (Boolean.TRUE.equals(success)) {
                    Map<String, Object> response = new HashMap<>();
                    response.put("success", true);
                    response.put("message", "플랜이 " + planType.getName() + "으로 설정되었습니다.");
                    response.put("deviceIdHash", deviceIdHash);
                    response.put("planType", planType.getCode());
                    response.put("expiresAt", expiresAt.toString());
                    response.put("limit", planType.getLimit());
                    response.put("period", planType.getPeriod());
                    return ResponseEntity.ok(response);
                } else {
                    Map<String, Object> errorResponse = new HashMap<>();
                    errorResponse.put("error", "플랜 설정에 실패했습니다.");
                    return ResponseEntity.status(500).body(errorResponse);
                }
            });
}

private boolean verifyPurchase(String purchaseToken, String productId, String platform) {
    if ("android".equals(platform)) {
        // Google Play Developer API로 검증
        return verifyGooglePlayPurchase(purchaseToken, productId);
    } else if ("ios".equals(platform)) {
        // App Store Server API로 검증
        return verifyAppStorePurchase(purchaseToken, productId);
    }
    return false;
}
```

### 4. 클라이언트 측 구현 (Flutter)

#### 4.1 인앱 결제 서비스 생성

```dart
// lib/services/in_app_purchase_service.dart
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'plan_service.dart';

class InAppPurchaseService {
  static final InAppPurchaseService _instance = InAppPurchaseService._internal();
  factory InAppPurchaseService() => _instance;
  InAppPurchaseService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // 상품 ID 정의
  static const String basicPlanMonthly = 'basic_plan_monthly';
  static const Set<String> _productIds = {basicPlanMonthly};

  /// 인앱 결제 초기화
  Future<bool> initialize() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      debugPrint('❌ 인앱 결제를 사용할 수 없습니다.');
      return false;
    }

    // 구매 이력 리스너
    _subscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) => debugPrint('❌ 구매 스트림 에러: $error'),
    );

    return true;
  }

  /// 상품 정보 조회
  Future<List<ProductDetails>> getProducts() async {
    final ProductDetailsResponse response = 
        await _inAppPurchase.queryProductDetails(_productIds);
    
    if (response.error != null) {
      debugPrint('❌ 상품 조회 실패: ${response.error}');
      return [];
    }

    return response.productDetails;
  }

  /// 플랜 구매 시작
  Future<bool> purchasePlan(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
    );

    try {
      if (productDetails.id == basicPlanMonthly) {
        // Android
        if (Platform.isAndroid) {
          final GooglePlayPurchaseParam androidParam = 
              GooglePlayPurchaseParam(
            productDetails: productDetails as GooglePlayProductDetails,
            changeSubscriptionParam: null,
          );
          await _inAppPurchase.buyNonConsumable(purchaseParam: androidParam);
        } 
        // iOS
        else if (Platform.isIOS) {
          final AppStorePurchaseParam iosParam = AppStorePurchaseParam(
            productDetails: productDetails as AppStoreProductDetails,
          );
          await _inAppPurchase.buyNonConsumable(purchaseParam: iosParam);
        }
        return true;
      }
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
        final GooglePurchaseDetails androidPurchase = 
            purchase as GooglePurchaseDetails;
        purchaseToken = androidPurchase.billingClientPurchase
            ?.purchaseToken;
        platform = 'android';
      } else if (Platform.isIOS) {
        final AppStorePurchaseDetails iosPurchase = 
            purchase as AppStorePurchaseDetails;
        purchaseToken = iosPurchase.skPaymentTransaction
            ?.transactionIdentifier;
        platform = 'ios';
      }

      if (purchaseToken == null) {
        debugPrint('❌ 영수증 토큰을 가져올 수 없습니다.');
        return;
      }

      // 서버에 구독 요청
      final planService = PlanService();
      final result = await planService.subscribePlan(
        purchaseToken: purchaseToken,
        productId: purchase.productID,
        platform: platform,
      );

      if (result != null && result['success'] == true) {
        debugPrint('✅ 플랜 구독 완료: ${result['planType']}');
      } else {
        debugPrint('❌ 플랜 구독 실패');
      }
    } catch (e) {
      debugPrint('❌ 구매 성공 처리 중 오류: $e');
    }
  }

  /// 구매 에러 처리
  void _handlePurchaseError(PurchaseDetails purchase) {
    // 에러 처리 로직
    debugPrint('구매 에러: ${purchase.error}');
  }

  void dispose() {
    _subscription.cancel();
  }
}
```

#### 4.2 플랜 구매 UI 예시

```dart
// lib/screens/subscription_screen.dart
class SubscriptionScreen extends StatefulWidget {
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final InAppPurchaseService _purchaseService = InAppPurchaseService();
  List<ProductDetails> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializePurchase();
  }

  Future<void> _initializePurchase() async {
    final initialized = await _purchaseService.initialize();
    if (initialized) {
      await _loadProducts();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadProducts() async {
    final products = await _purchaseService.getProducts();
    setState(() => _products = products);
  }

  Future<void> _purchasePlan(ProductDetails product) async {
    final success = await _purchaseService.purchasePlan(product);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구매 시작에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('플랜 구독')),
      body: ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return ListTile(
            title: Text(product.title),
            subtitle: Text(product.description),
            trailing: Text(product.price),
            onTap: () => _purchasePlan(product),
          );
        },
      ),
    );
  }
}
```

## 주요 고려사항

### 1. 결제 영수증 검증
- **Android**: Google Play Developer API 사용
- **iOS**: App Store Server API 사용
- 서버에서 반드시 검증해야 함 (클라이언트 검증은 신뢰할 수 없음)

### 2. 구독 상태 관리
- 구독 만료 시 자동으로 Free 플랜으로 전환
- 구독 갱신 시 자동으로 플랜 연장
- 구독 취소 시 만료일까지 사용 가능

### 3. 에러 처리
- 네트워크 오류
- 결제 검증 실패
- 서버 오류
- 사용자 취소

### 4. 테스트
- Google Play Console에서 테스트 계정 설정
- App Store Connect에서 샌드박스 테스트
- 실제 결제 전 충분한 테스트 필요

## 참고 자료

- [Flutter in_app_purchase 패키지](https://pub.dev/packages/in_app_purchase)
- [Google Play Billing](https://developer.android.com/google/play/billing)
- [App Store In-App Purchase](https://developer.apple.com/in-app-purchase/)
