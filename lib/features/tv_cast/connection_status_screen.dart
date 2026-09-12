import 'package:flutter/material.dart';
import 'socket_server_service.dart';

class ConnectionStatusScreen extends StatefulWidget {
  const ConnectionStatusScreen({super.key});

  @override
  State<ConnectionStatusScreen> createState() => _ConnectionStatusScreenState();
}

class _ConnectionStatusScreenState extends State<ConnectionStatusScreen> {
  final _serverService = SocketServerService();

  @override
  void initState() {
    super.initState();
    _serverService.addListener(_onServiceUpdate);
    _serverService.startServer();
  }

  @override
  void dispose() {
    _serverService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '雙螢幕連線',
                      style: TextStyle(
                        color: Color(0xFF1A1D2E),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '等待主要訓練裝置連線',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    _buildRoleCard(),
                    const SizedBox(height: 16),
                    _buildConnectionCard(),
                    const SizedBox(height: 16),
                    _buildNetworkCard(),
                    if (_serverService.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorCard(),
                    ],
                    const SizedBox(height: 16),
                    StreamBuilder<Map<String, dynamic>>(
                      stream: _serverService.messages,
                      builder: (context, snapshot) {
                        return _buildSyncIndicator(snapshot.hasData);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF374151),
            side: const BorderSide(color: Color(0xFFDDE0F0)),
          ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      ),
    );
  }

  Widget _buildRoleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: const Row(
        children: [
          _RoleIcon(
            icon: Icons.phone_android_rounded,
            label: '主要訓練裝置',
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.sync_alt_rounded, color: Color(0xFF4A65FF)),
          ),
          _RoleIcon(
            icon: Icons.tablet_android_rounded,
            label: '輔助顯示裝置',
            highlighted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    final connected = _serverService.isClientConnected;
    final color = connected ? const Color(0xFF22A06B) : const Color(0xFF4A65FF);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? '輔助螢幕已連線' : _serverStatusLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  connected ? '正在接收訓練資訊' : '請在主要訓練裝置輸入下方 IP 位址。',
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '輔助螢幕 IP 位址',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _serverService.ipAddress ?? '正在取得網路資訊…',
            style: const TextStyle(
              color: Color(0xFF1A1D2E),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '請確認兩台裝置已連接至相同的 Wi-Fi 網路。',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const Divider(height: 28),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text(
              '連線詳細資訊',
              style: TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '通訊埠：${_serverService.port}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncIndicator(bool hasReceivedMessage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          hasReceivedMessage ? Icons.sync_rounded : Icons.hourglass_top_rounded,
          color: const Color(0xFF6B7280),
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          hasReceivedMessage ? '正在接收訓練資訊' : '等待主要訓練裝置連線',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE24B4A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE24B4A).withValues(alpha: 0.22),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Color(0xFFE24B4A)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '無法啟動輔助螢幕連線，請確認網路狀態後再試。',
              style: TextStyle(color: Color(0xFFB42318), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String get _serverStatusLabel {
    return switch (_serverService.status) {
      ServerStatus.stopped => '等待連線',
      ServerStatus.starting => '正在準備連線…',
      ServerStatus.running => '等待連線',
      ServerStatus.error => '無法啟動連線',
    };
  }
}

class _RoleIcon extends StatelessWidget {
  const _RoleIcon({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color:
                highlighted ? const Color(0xFF4A65FF) : const Color(0xFF6B7280),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: highlighted
                  ? const Color(0xFF1A1D2E)
                  : const Color(0xFF4B5563),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
