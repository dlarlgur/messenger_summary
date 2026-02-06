import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ConsentScreen extends StatefulWidget {
  final VoidCallback onConsentComplete;

  const ConsentScreen({super.key, required this.onConsentComplete});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  final ApiService _apiService = ApiService();

  bool _serviceTerms = false;
  bool _privacyTerms = false;
  bool _messageSummaryTerms = false;
  bool _isLoading = false;

  bool get _allAgreed =>
      _serviceTerms && _privacyTerms && _messageSummaryTerms;

  void _toggleAll(bool? value) {
    setState(() {
      _serviceTerms = value ?? false;
      _privacyTerms = value ?? false;
      _messageSummaryTerms = value ?? false;
    });
  }

  Future<void> _saveConsent() async {
    if (!_allAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 약관에 동의해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _apiService.saveConsent(
        serviceTerms: _serviceTerms,
        privacyTerms: _privacyTerms,
        messageSummaryTerms: _messageSummaryTerms,
      );

      if (mounted) {
        widget.onConsentComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('동의 저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        title: const Text(
          '서비스 이용 동의',
          style: TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chat LLM 서비스 이용을 위해\n아래 약관에 동의해주세요.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // 전체 동의
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  value: _allAgreed,
                  onChanged: _toggleAll,
                  title: const Text(
                    '전체 동의',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: const Color(0xFF2196F3),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // 개별 약관
              _buildConsentItem(
                title: '서비스 이용약관 동의 (필수)',
                value: _serviceTerms,
                onChanged: (v) => setState(() => _serviceTerms = v ?? false),
              ),
              _buildConsentItem(
                title: '개인정보 처리방침 동의 (필수)',
                value: _privacyTerms,
                onChanged: (v) => setState(() => _privacyTerms = v ?? false),
              ),
              _buildConsentItem(
                title: '메시지 요약 서비스 동의 (필수)',
                subtitle: '카카오톡 메시지를 수집하여 AI로 요약합니다.',
                value: _messageSummaryTerms,
                onChanged: (v) =>
                    setState(() => _messageSummaryTerms = v ?? false),
              ),

              const Spacer(),

              // 동의 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveConsent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _allAgreed ? const Color(0xFF2196F3) : Colors.grey[300],
                    foregroundColor: _allAgreed ? Colors.white : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '동의하고 시작하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsentItem({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            )
          : null,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: const Color(0xFF2196F3),
      contentPadding: EdgeInsets.zero,
    );
  }
}
