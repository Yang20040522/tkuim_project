import 'package:flutter/material.dart';
import 'socket_client_service.dart';

class PhoneConnectionScreen extends StatefulWidget {
  const PhoneConnectionScreen({super.key});

  @override
  State<PhoneConnectionScreen> createState() => _PhoneConnectionScreenState();
}

class _PhoneConnectionScreenState extends State<PhoneConnectionScreen> {
  final _clientService = SocketClientService();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '4040');

  @override
  void initState() {
    super.initState();
    _clientService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _clientService.removeListener(_onServiceUpdate);
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _connect() {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 4040;
    if (ip.isNotEmpty) {
      _clientService.connect(ip, port);
    }
  }

  void _disconnect() {
    _clientService.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '連接輔助螢幕',
                      style: TextStyle(
                        color: Color(0xFF1A1D2E),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '將訓練資訊同步到另一台裝置',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    _buildOverviewCard(),
                    const SizedBox(height: 20),
                    _buildInputCard(),
                    const SizedBox(height: 32),
                    _buildStatusCard(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                    if (_clientService.errorMessage != null) _buildErrorCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF4A65FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4A65FF).withValues(alpha: 0.18),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_android_rounded, color: Color(0xFF4A65FF)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child:
                    Icon(Icons.arrow_forward_rounded, color: Color(0xFF6B7280)),
              ),
              Icon(Icons.tablet_android_rounded, color: Color(0xFF4A65FF)),
            ],
          ),
          SizedBox(height: 16),
          Text(
            '當手機需要架設在較遠位置進行動作辨識時，'
            '可連接平板同步查看訓練畫面、完成次數與即時提示。',
            style: TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE0F0)),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Color(0xFF374151), size: 16),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
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
          TextField(
            controller: _ipController,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: '例如：192.168.1.150',
              helperText: '請確認兩台裝置已連接至相同的 Wi-Fi 網路。',
              helperMaxLines: 2,
              prefixIcon: const Icon(
                Icons.tablet_android_rounded,
                color: Color(0xFF4A65FF),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
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
            subtitle: const Text(
              '預設通訊埠 4040',
              style: TextStyle(color: Color(0xFF8A9099), fontSize: 12),
            ),
            children: [
              TextField(
                controller: _portController,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: '通訊埠',
                  prefixIcon: const Icon(
                    Icons.settings_input_component,
                    color: Color(0xFF6B7280),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isConnected = _clientService.isConnected;
    final statusColor = isConnected
        ? const Color(0xFF22A06B)
        : _clientService.status == ClientStatus.error
            ? const Color(0xFFE24B4A)
            : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '連線狀態：',
            style: TextStyle(
                color: statusColor.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600),
          ),
          Text(
            _statusLabel,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  String get _statusLabel {
    return switch (_clientService.status) {
      ClientStatus.disconnected => '尚未連接輔助螢幕',
      ClientStatus.connecting => '正在連接輔助螢幕…',
      ClientStatus.connected => '輔助螢幕已連線',
      ClientStatus.error => '無法連接輔助螢幕',
    };
  }

  Widget _buildActionButtons() {
    final isConnecting = _clientService.status == ClientStatus.connecting;
    final isConnected = _clientService.isConnected;

    return Column(
      children: [
        GestureDetector(
          onTap: isConnecting || isConnected ? null : _connect,
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: isConnecting || isConnected
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF4A65FF), Color(0xFF6B82FF)]),
              color:
                  isConnecting || isConnected ? const Color(0xFFEDEFF7) : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: isConnecting
                  ? const CircularProgressIndicator(color: Color(0xFF4A65FF))
                  : Text(
                      isConnected ? '輔助螢幕已連線' : '開始連線',
                      style: TextStyle(
                        color: isConnecting || isConnected
                            ? const Color(0xFFB0B3C5)
                            : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
        if (isConnected) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _disconnect,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDE0F0)),
              ),
              child: const Center(
                child: Text(
                  '中斷連線',
                  style: TextStyle(
                    color: Color(0xFFFF4B4B),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '無法連接輔助螢幕',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '請確認 IP 位址正確，且兩台裝置位於相同網路。',
                  style: TextStyle(color: Color(0xFFB42318), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
