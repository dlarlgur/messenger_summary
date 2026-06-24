import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/chat_room.dart';
import '../services/local_db_service.dart';
import '../services/profile_image_service.dart';
import '../theme/app_tokens.dart';

/// 차단된 채팅방 관리 화면
class BlockedRoomsScreen extends StatefulWidget {
  const BlockedRoomsScreen({super.key});

  @override
  State<BlockedRoomsScreen> createState() => _BlockedRoomsScreenState();
}

class _BlockedRoomsScreenState extends State<BlockedRoomsScreen> {
  final LocalDbService _localDb = LocalDbService();
  final ProfileImageService _profileService = ProfileImageService();

  List<ChatRoom> _blockedRooms = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 선택 모드 — true 면 각 방을 체크박스로 다중 선택 후 일괄 해제 가능
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadBlockedRooms();
  }

  Future<void> _loadBlockedRooms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rooms = await _localDb.getBlockedRooms();
      if (mounted) {
        setState(() {
          _blockedRooms = rooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              AppLocalizations.of(context).blocked_loadFailed;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unblockRoom(ChatRoom room) async {
    final result = await _localDb.updateRoomSettings(room.id, blocked: false);

    if (result != null && mounted) {
      setState(() {
        _blockedRooms.removeWhere((r) => r.id == room.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${room.roomName} 차단이 해제되었습니다.'),
          duration: const Duration(seconds: 1),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).blocked_unblockFailed),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 선택 모드 시작 — 모든 선택 해제하고 진입.
  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _blockedRooms.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_blockedRooms.map((r) => r.id));
      }
    });
  }

  /// 선택된 방들 일괄 해제 — 확인 다이얼로그 → 순회 update.
  Future<void> _unblockSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).blocked_bulkUnblockTitle),
        content: Text('선택한 $count개 채팅방의 차단을 해제하시겠습니까?\n\n차단 해제 후 새 메시지가 다시 저장됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).blocked_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTokens.accent),
            child: Text(AppLocalizations.of(context).blocked_unblock),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    int success = 0;
    int fail = 0;
    for (final id in _selectedIds.toList()) {
      final result = await _localDb.updateRoomSettings(id, blocked: false);
      if (result != null) {
        success++;
      } else {
        fail++;
      }
    }
    if (!mounted) return;
    setState(() {
      _blockedRooms.removeWhere((r) => _selectedIds.contains(r.id) &&
          // fail 한 방은 그대로 두기 위해 success 된 id 만 제거하는 로직 — 단순화 위해 전부 제거 후 fail 시 재로드.
          true);
      _selectedIds.clear();
      _selectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          fail == 0
              ? '$success개 채팅방의 차단을 해제했습니다.'
              : '$success개 해제 / $fail개 실패. 목록을 새로고침합니다.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    if (fail > 0) {
      await _loadBlockedRooms();
    }
  }

  void _showUnblockConfirmDialog(ChatRoom room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).blocked_unblockTitle),
        content: Text('${room.roomName}의 차단을 해제하시겠습니까?\n\n차단 해제 후 새 메시지가 다시 저장됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).blocked_cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _unblockRoom(room);
            },
            style: TextButton.styleFrom(foregroundColor: AppTokens.accent),
            child: Text(AppLocalizations.of(context).blocked_unblock),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomProfile(ChatRoom room) {
    final profileFile = _profileService.getRoomProfile(room.roomName);

    if (profileFile != null && profileFile.existsSync()) {
      return ClipOval(
        child: Image.file(
          profileFile,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar(room);
          },
        ),
      );
    }

    return _buildDefaultAvatar(room);
  }

  Widget _buildDefaultAvatar(ChatRoom room) {
    final colorIndex = room.roomName.hashCode.abs() % Colors.primaries.length;
    final backgroundColor = Colors.primaries[colorIndex].shade200;

    return CircleAvatar(
      radius: 25,
      backgroundColor: backgroundColor,
      child: Text(
        room.roomName.isNotEmpty ? room.roomName[0] : '?',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        _blockedRooms.isNotEmpty && _selectedIds.length == _blockedRooms.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTokens.accent,
        foregroundColor: Colors.white,
        title: Text(
          _selectionMode
              ? '${_selectedIds.length}개 선택됨'
              : AppLocalizations.of(context).blocked_title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_selectionMode) ...[
            TextButton(
              onPressed: _blockedRooms.isEmpty ? null : _toggleSelectAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    allSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    allSelected
                        ? AppLocalizations.of(context).blocked_deselectAll
                        : AppLocalizations.of(context).blocked_selectAll,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.lock_open_rounded,
                color: _selectedIds.isEmpty
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white,
              ),
              onPressed: _selectedIds.isEmpty ? null : _unblockSelected,
              tooltip: AppLocalizations.of(context).blocked_unblockSelected,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _exitSelectionMode,
              tooltip: AppLocalizations.of(context).blocked_exitSelectionMode,
            ),
          ] else if (_blockedRooms.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: _enterSelectionMode,
              tooltip: AppLocalizations.of(context).blocked_edit,
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

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBlockedRooms,
              child: Text(AppLocalizations.of(context).blocked_retry),
            ),
          ],
        ),
      );
    }

    if (_blockedRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).blocked_emptyMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBlockedRooms,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _blockedRooms.length,
        itemBuilder: (context, index) {
          final room = _blockedRooms[index];
          return _buildRoomItem(room);
        },
      ),
    );
  }

  Widget _buildRoomItem(ChatRoom room) {
    final selected = _selectedIds.contains(room.id);
    return GestureDetector(
      onTap: _selectionMode
          ? () {
              _toggleSelect(room.id);
              HapticFeedback.selectionClick();
            }
          : () => _showUnblockConfirmDialog(room),
      onLongPress: _selectionMode
          ? null
          : () {
              _enterSelectionMode();
              _toggleSelect(room.id);
              HapticFeedback.mediumImpact();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTokens.accent : Colors.transparent,
            width: selected ? 2 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.10 : 0.06),
              blurRadius: selected ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // 선택 모드 — 동그란 체크 표시 (요약 히스토리와 동일 패턴)
            if (_selectionMode) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppTokens.accent : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppTokens.accent : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 12),
            ],
            _buildRoomProfile(room),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.roomName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    room.packageAlias,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // 선택 모드 아닐 때만 개별 해제 버튼
            if (!_selectionMode)
              TextButton(
                onPressed: () => _showUnblockConfirmDialog(room),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  AppLocalizations.of(context).blocked_unblock,
                  style: const TextStyle(
                    color: AppTokens.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
