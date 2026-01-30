import 'package:flutter/material.dart';
import '../models/chat_room.dart';
import '../services/api_service.dart';
import '../services/profile_image_service.dart';
import 'dart:io';

/// 차단된 채팅방 관리 화면
class BlockedRoomsScreen extends StatefulWidget {
  const BlockedRoomsScreen({super.key});

  @override
  State<BlockedRoomsScreen> createState() => _BlockedRoomsScreenState();
}

class _BlockedRoomsScreenState extends State<BlockedRoomsScreen> {
  final ApiService _apiService = ApiService();
  final ProfileImageService _profileService = ProfileImageService();
  
  List<ChatRoom> _blockedRooms = [];
  bool _isLoading = true;
  String? _errorMessage;

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
      final rooms = await _apiService.getBlockedRooms();
      if (mounted) {
        setState(() {
          _blockedRooms = rooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '차단된 채팅방을 불러오는데 실패했습니다.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unblockRoom(ChatRoom room) async {
    final result = await _apiService.updateRoomSettings(room.id, blocked: false);

    if (result != null && mounted) {
      setState(() {
        _blockedRooms.removeWhere((r) => r.id == room.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${room.roomName} 차단이 해제되었습니다.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('차단 해제에 실패했습니다.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showUnblockConfirmDialog(ChatRoom room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('차단 해제'),
        content: Text('${room.roomName}의 차단을 해제하시겠습니까?\n\n차단 해제 후 새 메시지가 다시 저장됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _unblockRoom(room);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('해제'),
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
    // 방 이름의 해시값으로 색상 결정
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('차단방 관리'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
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
              child: const Text('다시 시도'),
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
              '차단된 채팅방이 없습니다.',
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
        itemCount: _blockedRooms.length,
        itemBuilder: (context, index) {
          final room = _blockedRooms[index];
          return _buildRoomItem(room);
        },
      ),
    );
  }

  Widget _buildRoomItem(ChatRoom room) {
    return ListTile(
      leading: _buildRoomProfile(room),
      title: Text(
        room.roomName,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        room.packageAlias,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: TextButton(
        onPressed: () => _showUnblockConfirmDialog(room),
        child: const Text(
          '차단 해제',
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      onTap: () => _showUnblockConfirmDialog(room),
    );
  }
}
