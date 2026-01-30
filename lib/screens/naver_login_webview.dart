import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NaverLoginWebView extends StatefulWidget {
  final String authUrl;

  const NaverLoginWebView({
    super.key,
    required this.authUrl,
  });

  @override
  State<NaverLoginWebView> createState() => _NaverLoginWebViewState();
}

class _NaverLoginWebViewState extends State<NaverLoginWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasNavigatedBack = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              debugPrint('WebView 페이지 시작: $url');
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
              }
              _handleCallback(url);
            },
            onPageFinished: (url) {
              debugPrint('WebView 페이지 완료: $url');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
              _handleCallback(url);
            },
            onWebResourceError: (error) {
              debugPrint('WebView 에러: ${error.description}');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = '페이지를 불러올 수 없습니다. 네트워크 연결을 확인해주세요.';
                });
              }
            },
            onNavigationRequest: (request) {
              debugPrint('네비게이션 요청: ${request.url}');
              final uri = Uri.parse(request.url);
              if ((uri.path.contains('/callback/') ||
                      uri.path.contains('/callback') ||
                      uri.queryParameters.containsKey('code')) &&
                  uri.queryParameters.containsKey('code')) {
                _handleCallback(request.url);
                return NavigationDecision.prevent;
              }
              _handleCallback(request.url);
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.authUrl));
    } catch (e) {
      debugPrint('WebView 초기화 에러: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '로그인 화면을 불러올 수 없습니다. 잠시 후 다시 시도해주세요.';
        });
      }
    }
  }

  void _handleCallback(String url) {
    if (_hasNavigatedBack) return;

    try {
      debugPrint('콜백 URL 확인: $url');
      final uri = Uri.parse(url);

      final hasCallbackPath = uri.path.contains('/callback/') ||
          uri.path.contains('/callback') ||
          uri.path.contains('callback');
      final hasCode = uri.queryParameters.containsKey('code');
      final hasError = uri.queryParameters.containsKey('error');

      debugPrint(
          '콜백 체크 - path: ${uri.path}, hasCallbackPath: $hasCallbackPath, hasCode: $hasCode, hasError: $hasError');

      if (hasError) {
        final error = uri.queryParameters['error'];
        final errorDescription = uri.queryParameters['error_description'];
        debugPrint('네이버 로그인 에러: $error - $errorDescription');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '로그인에 실패했습니다: ${errorDescription ?? error}';
          });
        }
        return;
      }

      if ((hasCallbackPath || hasCode) && hasCode) {
        final code = uri.queryParameters['code'];
        final state = uri.queryParameters['state'];

        debugPrint('콜백 감지 성공 - code: $code, state: $state');

        if (code != null && code.isNotEmpty && mounted) {
          _hasNavigatedBack = true;
          Navigator.of(context).pop({
            'code': code,
            'state': state,
          });
        }
      }
    } catch (e) {
      debugPrint('콜백 처리 에러: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '콜백 처리 중 오류가 발생했습니다: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF03C75A),
        title: const Text(
          '네이버 로그인',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
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
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _hasNavigatedBack = false;
                        });
                        _initializeWebView();
                      },
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  Container(
                    color: Colors.white,
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF03C75A)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
