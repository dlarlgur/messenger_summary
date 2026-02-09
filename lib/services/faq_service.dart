import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// FAQ 서비스 (공개 API)
class FAQService {
  static final FAQService _instance = FAQService._internal();
  factory FAQService() => _instance;
  
  static const String _baseUrl = 'https://api.dksw4.com';
  static const String _faqEndpoint = '/api/v1/faq';
  
  late final Dio _dio;
  
  FAQService._internal() {
    _initDio();
  }
  
  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
    // 공개 API이므로 인증 인터셉터 불필요
  }
  
  /// FAQ 조회
  Future<Map<String, dynamic>?> getFAQ() async {
    try {
      final response = await _dio.get(_faqEndpoint);
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ FAQ 조회 실패: $e');
      return null;
    }
  }
}
