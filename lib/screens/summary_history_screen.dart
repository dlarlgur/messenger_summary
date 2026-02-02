import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import '../services/local_db_service.dart';
import '../config/constants.dart';
import 'package:intl/intl.dart';

/// 요약 히스토리 화면
class SummaryHistoryScreen extends StatefulWidget {
  final int roomId;
  final String roomName;

  const SummaryHistoryScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
  }) : super(key: key);

  @override
  State<SummaryHistoryScreen> createState() => _SummaryHistoryScreenState();
}

class _SummaryHistoryScreenState extends State<SummaryHistoryScreen> {
  final LocalDbService _localDb = LocalDbService();
  List<SummaryItem> _summaries = [];
  bool _isLoading = true;
  Set<int> _selectedSummaryIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  /// 요약 히스토리 로드
  Future<void> _loadSummaries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 빈 요약 먼저 정리
      await _localDb.deleteEmptySummaries();

      // 요약 히스토리 로드
      final detailResponse = await _localDb.getRoomSummaries(widget.roomId);

      // 최신순 정렬 (summaryTo 기준, 없으면 summaryFrom)
      final sortedSummaries = List<SummaryItem>.from(detailResponse.summaries);
      sortedSummaries.sort((a, b) {
        final aTime = a.summaryTo ?? a.summaryFrom ?? DateTime(1970);
        final bTime = b.summaryTo ?? b.summaryFrom ?? DateTime(1970);
        return bTime.compareTo(aTime); // 최신이 먼저
      });

      if (mounted) {
        setState(() {
          _summaries = sortedSummaries;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('요약 히스토리 로딩 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('요약 히스토리 로딩 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 선택 모드 토글
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedSummaryIds.clear();
      }
    });
  }

  /// 요약 항목 선택/해제
  void _toggleSummarySelection(int summaryId) {
    setState(() {
      if (_selectedSummaryIds.contains(summaryId)) {
        _selectedSummaryIds.remove(summaryId);
      } else {
        _selectedSummaryIds.add(summaryId);
      }
    });
  }

  /// 전체 선택/해제
  void _toggleSelectAll() {
    setState(() {
      if (_selectedSummaryIds.length == _summaries.length) {
        // 모두 선택되어 있으면 전체 해제
        _selectedSummaryIds.clear();
      } else {
        // 일부만 선택되어 있거나 아무것도 선택 안 되어 있으면 전체 선택
        _selectedSummaryIds = _summaries.map((s) => s.summaryId).toSet();
      }
    });
    HapticFeedback.selectionClick();
  }

  /// 선택된 요약 삭제
  Future<void> _deleteSelectedSummaries() async {
    if (_selectedSummaryIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '요약 삭제',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '선택한 ${_selectedSummaryIds.length}개의 요약을 삭제하시겠습니까?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      int successCount = 0;
      for (final summaryId in _selectedSummaryIds) {
        final success = await _localDb.deleteSummary(summaryId);
        if (success) successCount++;
      }

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount개의 요약이 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );

        // 선택 모드 종료 및 목록 새로고침
        setState(() {
          _isSelectionMode = false;
          _selectedSummaryIds.clear();
        });
        _loadSummaries();
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 개별 요약 삭제
  Future<void> _deleteSummary(int summaryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '요약 삭제',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          '이 요약을 삭제하시겠습니까?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await _localDb.deleteSummary(summaryId);

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('요약이 삭제되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadSummaries();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('삭제에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 날짜 포맷팅
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return '오늘';
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      return '어제';
    } else {
      return DateFormat('M월 d일', 'ko_KR').format(date);
    }
  }

  /// 시간 포맷팅
  String _formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// 날짜/시간 포맷팅
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(AppColors.summaryPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _isSelectionMode
            ? Text(
                '${_selectedSummaryIds.length}개 선택됨',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              )
            : const Text(
                'AI 요약 히스토리',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          if (_isSelectionMode) ...[
            // 전체 선택/해제 버튼
            IconButton(
              icon: Icon(
                _selectedSummaryIds.length == _summaries.length
                    ? Icons.deselect
                    : Icons.select_all,
                color: Colors.white,
              ),
              onPressed: _toggleSelectAll,
              tooltip: _selectedSummaryIds.length == _summaries.length
                  ? '전체 해제'
                  : '전체 선택',
            ),
            // 선택 삭제 버튼
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _selectedSummaryIds.isEmpty ? null : _deleteSelectedSummaries,
              tooltip: '선택 삭제',
            ),
          ],
          IconButton(
            icon: Icon(
              _isSelectionMode ? Icons.close : Icons.checklist,
              color: Colors.white,
            ),
            onPressed: _toggleSelectionMode,
            tooltip: _isSelectionMode ? '선택 모드 종료' : '선택 모드',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(AppColors.summaryPrimary)),
              ),
            )
          : _summaries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '요약 히스토리가 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _summaries.length,
                  itemBuilder: (context, index) {
                    final summary = _summaries[index];
                    final isSelected = _selectedSummaryIds.contains(summary.summaryId);
                    final isFirst = index == 0;
                    final isLast = index == _summaries.length - 1;

                    // 날짜 구분선 표시 여부 결정
                    DateTime? prevDate;
                    if (index > 0) {
                      final prevSummary = _summaries[index - 1];
                      prevDate = prevSummary.summaryTo ?? prevSummary.summaryFrom;
                    }
                    final currentDate = summary.summaryTo ?? summary.summaryFrom;
                    final showDateDivider = prevDate == null ||
                        (currentDate != null &&
                            DateTime(prevDate.year, prevDate.month, prevDate.day) !=
                                DateTime(currentDate.year, currentDate.month, currentDate.day));

                    return Column(
                      children: [
                        if (showDateDivider && currentDate != null)
                          _buildDateDivider(currentDate),
                        _buildSummaryCard(summary, isSelected),
                        if (isLast) const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
    );
  }

  /// 날짜 구분선
  Widget _buildDateDivider(DateTime date) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF8BA4B8).withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// 요약 상세보기 다이얼로그
  void _showSummaryDetail(SummaryItem summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // 핸들바
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(AppColors.summaryPrimary).withOpacity(0.12),
                      const Color(AppColors.summaryPrimary).withOpacity(0.06),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(AppColors.summaryPrimary),
                            Color(0xFF3A7ECC),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.summaryName,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (summary.summaryFrom != null && summary.summaryTo != null)
                            Text(
                              '${_formatDateTime(summary.summaryFrom!)} ~ ${_formatDateTime(summary.summaryTo!)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(AppColors.summaryPrimary).withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // 내용
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 요약 메시지
                    MarkdownBody(
                      data: summary.summaryMessage,
                      selectable: true,
                      softLineBreak: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          fontSize: 16,
                          height: 1.8,
                          color: Color(0xFF2A2A2A),
                          fontWeight: FontWeight.w500,
                        ),
                        pPadding: const EdgeInsets.only(bottom: 8),
                        h1: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          color: Color(0xFF2A2A2A),
                        ),
                        h1Padding: const EdgeInsets.only(bottom: 12, top: 8),
                        h2: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          color: Color(0xFF2A2A2A),
                        ),
                        h2Padding: const EdgeInsets.only(bottom: 10, top: 8),
                        h3: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: Color(0xFF2A2A2A),
                        ),
                        h3Padding: const EdgeInsets.only(bottom: 8, top: 6),
                        strong: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2A2A2A),
                        ),
                        blockSpacing: 12,
                        listIndent: 24,
                      ),
                    ),
                    // 상세 메시지 (있을 경우)
                    if (summary.summaryDetailMessage != null &&
                        summary.summaryDetailMessage!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF2196F3).withOpacity(0.08),
                              const Color(0xFF2196F3).withOpacity(0.03),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF2196F3).withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: Color(0xFF2196F3),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '상세 내용',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2196F3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            MarkdownBody(
                              data: summary.summaryDetailMessage!,
                              selectable: true,
                              softLineBreak: true,
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(
                                  fontSize: 15,
                                  height: 1.8,
                                  color: Color(0xFF2A2A2A),
                                  fontWeight: FontWeight.w400,
                                ),
                                pPadding: const EdgeInsets.only(bottom: 8),
                                h1: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
                                  color: Color(0xFF2A2A2A),
                                ),
                                h1Padding: const EdgeInsets.only(bottom: 10, top: 6),
                                h2: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
                                  color: Color(0xFF2A2A2A),
                                ),
                                h2Padding: const EdgeInsets.only(bottom: 8, top: 6),
                                h3: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  color: Color(0xFF2A2A2A),
                                ),
                                h3Padding: const EdgeInsets.only(bottom: 6, top: 4),
                                strong: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2A2A2A),
                                ),
                                blockSpacing: 10,
                                listIndent: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 요약 카드
  Widget _buildSummaryCard(SummaryItem summary, bool isSelected) {
    return GestureDetector(
      onTap: _isSelectionMode
          ? () {
              _toggleSummarySelection(summary.summaryId);
              HapticFeedback.selectionClick();
            }
          : () {
              _showSummaryDetail(summary);
            },
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleSummarySelection(summary.summaryId);
          HapticFeedback.mediumImpact();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(
                  color: const Color(AppColors.summaryPrimary),
                  width: 3,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(AppColors.summaryPrimary).withOpacity(0.12),
                    const Color(AppColors.summaryPrimary).withOpacity(0.06),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  // 선택 체크박스 (선택 모드일 때만)
                  if (_isSelectionMode)
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(AppColors.summaryPrimary)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? const Color(AppColors.summaryPrimary)
                              : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  // AI 아이콘
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(AppColors.summaryPrimary),
                          Color(0xFF3A7ECC),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(AppColors.summaryPrimary).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.summaryName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (summary.summaryFrom != null && summary.summaryTo != null)
                          Text(
                            '${_formatDateTime(summary.summaryFrom!)} ~ ${_formatDateTime(summary.summaryTo!)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(AppColors.summaryPrimary).withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 삭제 버튼 (선택 모드가 아닐 때만)
                  if (!_isSelectionMode)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _deleteSummary(summary.summaryId),
                      tooltip: '삭제',
                    ),
                ],
              ),
            ),
            // 내용
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 요약 메시지 미리보기 (최대 3줄)
                  MarkdownBody(
                    data: summary.summaryMessage,
                    selectable: true,
                    softLineBreak: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Color(0xFF2A2A2A),
                        fontWeight: FontWeight.w500,
                      ),
                      pPadding: const EdgeInsets.only(bottom: 8),
                      h1: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: Color(0xFF2A2A2A),
                      ),
                      h1Padding: const EdgeInsets.only(bottom: 10, top: 6),
                      h2: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: Color(0xFF2A2A2A),
                      ),
                      h2Padding: const EdgeInsets.only(bottom: 8, top: 6),
                      h3: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: Color(0xFF2A2A2A),
                      ),
                      h3Padding: const EdgeInsets.only(bottom: 6, top: 4),
                      strong: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A2A2A),
                      ),
                      blockSpacing: 8,
                      listIndent: 20,
                    ),
                  ),
                  // 상세보기 버튼 (상세 메시지가 있을 때만)
                  if (summary.summaryDetailMessage != null &&
                      summary.summaryDetailMessage!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _showSummaryDetail(summary),
                        icon: const Icon(
                          Icons.expand_more,
                          color: Color(0xFF2196F3),
                        ),
                        label: const Text(
                          '상세보기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
