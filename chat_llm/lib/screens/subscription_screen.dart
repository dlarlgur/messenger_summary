import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/in_app_purchase_service.dart';
import '../services/plan_service.dart';

/// 플랜 구독 화면
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final InAppPurchaseService _purchaseService = InAppPurchaseService();
  final PlanService _planService = PlanService();

  List<ProductDetails> _products = [];
  bool _isLoading = true;
  String? _error;
  String? _currentPlanType;
  bool _isPurchasing = false;
  StreamSubscription<PurchaseVerificationResult>? _verificationSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToVerificationResults();
    _initialize();
  }

  /// 검증 결과 스트림 구독
  void _subscribeToVerificationResults() {
    _verificationSubscription = _purchaseService.verificationResultStream.listen(
      (result) {
        if (!mounted) return;

        if (result.success) {
          // 성공: 플랜 정보 갱신 및 성공 메시지
          _planService.invalidateCache();
          _loadCurrentPlan();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          // 실패: 에러 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: '다시 시도',
                textColor: Colors.white,
                onPressed: _restorePurchases,
              ),
            ),
          );
        }
      },
    );
  }

  /// 현재 플랜 로드
  Future<void> _loadCurrentPlan() async {
    final planType = await _planService.getCurrentPlanType();
    if (mounted) {
      setState(() {
        _currentPlanType = planType;
      });
    }
  }

  Future<void> _initialize() async {
    // 현재 플랜 조회
    await _loadCurrentPlan();

    // 인앱 결제 초기화 및 상품 조회
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final initialized = await _purchaseService.initialize();
      if (!initialized) {
        setState(() {
          _error = '인앱 결제를 사용할 수 없습니다.';
          _isLoading = false;
        });
        return;
      }

      final products = await _purchaseService.getProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '상품 정보를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _purchasePlan(ProductDetails product) async {
    if (_isPurchasing) {
      return;
    }

    setState(() {
      _isPurchasing = true;
    });

    // 로딩 다이얼로그 표시
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await _purchaseService.purchasePlan(product);
      
      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (success) {
        // 구매 성공은 _handlePurchaseSuccess에서 처리됨
        // 여기서는 사용자에게 안내만 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('구매가 진행 중입니다. 완료되면 플랜이 자동으로 활성화됩니다.'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('구매 시작에 실패했습니다.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('구매 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'),
          duration: const Duration(seconds: 1),
        ),
      );
    } finally {
      setState(() {
        _isPurchasing = false;
      });
    }
  }

  Future<void> _restorePurchases() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // 스트림에서 결과를 타임아웃과 함께 대기
      final resultFuture = _purchaseService.verificationResultStream
          .first
          .timeout(const Duration(seconds: 10));

      await _purchaseService.restorePurchases();

      try {
        final result = await resultFuture;
        if (!mounted) return;
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success
                ? '구매가 복원되었습니다.'
                : '구매 복원 실패: ${result.message}'),
            backgroundColor: result.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      } on TimeoutException {
        if (!mounted) return;
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('복원할 구매 내역이 없습니다.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('구매 복원 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  void dispose() {
    _verificationSubscription?.cancel();
    _purchaseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('플랜 구독'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _restorePurchases,
            tooltip: '구매 복원',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '등록된 상품이 없습니다.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 현재 플랜 표시
        if (_currentPlanType != null) ...[
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '현재 플랜: ${_currentPlanType!.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // 상품 목록
        ..._products.map((product) => _buildProductCard(product)),
      ],
    );
  }

  Widget _buildProductCard(ProductDetails product) {
    final isCurrentPlan = _currentPlanType == 'basic' && 
                          product.id == InAppPurchaseService.basicPlanMonthly;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: isCurrentPlan || _isPurchasing ? null : () => _purchasePlan(product),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrentPlan)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        '현재 플랜',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      product.price,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2196F3),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isCurrentPlan && !_isPurchasing)
                    ElevatedButton(
                      onPressed: () => _purchasePlan(product),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('구독하기'),
                    )
                  else if (_isPurchasing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // 플랜 혜택 표시
              if (product.id == InAppPurchaseService.basicPlanMonthly) ...[
                const Divider(),
                const SizedBox(height: 8),
                _buildBenefitItem('월 150회 요약 가능'),
                const SizedBox(height: 4),
                _buildBenefitItem('메시지 최대 300개까지 요약'),
                const SizedBox(height: 4),
                _buildBenefitItem('자동 요약 기능 사용 가능'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle,
          size: 16,
          color: Colors.green,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
