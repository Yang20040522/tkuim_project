import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/ui/app_colors.dart';

enum PrivacyPermissionType {
  camera,
  microphone,
  notifications,
  nearbyDevices,
}

enum PrivacyPermissionState {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  unavailable,
}

abstract interface class PrivacyPermissionService {
  bool isSupported(PrivacyPermissionType type);

  Future<PrivacyPermissionState> status(PrivacyPermissionType type);

  Future<PrivacyPermissionState> request(PrivacyPermissionType type);

  Future<bool> openSettings();
}

class DevicePrivacyPermissionService implements PrivacyPermissionService {
  const DevicePrivacyPermissionService();

  @override
  bool isSupported(PrivacyPermissionType type) {
    if (kIsWeb) return false;
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile) return false;
    if (type == PrivacyPermissionType.nearbyDevices) {
      return defaultTargetPlatform == TargetPlatform.android;
    }
    return true;
  }

  @override
  Future<PrivacyPermissionState> status(PrivacyPermissionType type) async {
    if (!isSupported(type)) return PrivacyPermissionState.unavailable;
    try {
      return _mapStatus(await _permission(type).status);
    } on MissingPluginException {
      return PrivacyPermissionState.unavailable;
    } on PlatformException {
      return PrivacyPermissionState.unavailable;
    } on UnsupportedError {
      return PrivacyPermissionState.unavailable;
    }
  }

  @override
  Future<PrivacyPermissionState> request(PrivacyPermissionType type) async {
    if (!isSupported(type)) return PrivacyPermissionState.unavailable;
    try {
      return _mapStatus(await _permission(type).request());
    } on MissingPluginException {
      return PrivacyPermissionState.unavailable;
    } on PlatformException {
      return PrivacyPermissionState.unavailable;
    } on UnsupportedError {
      return PrivacyPermissionState.unavailable;
    }
  }

  @override
  Future<bool> openSettings() async {
    if (kIsWeb) return false;
    try {
      return await openAppSettings();
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on UnsupportedError {
      return false;
    }
  }

  Permission _permission(PrivacyPermissionType type) {
    return switch (type) {
      PrivacyPermissionType.camera => Permission.camera,
      PrivacyPermissionType.microphone => Permission.microphone,
      PrivacyPermissionType.notifications => Permission.notification,
      PrivacyPermissionType.nearbyDevices => Permission.bluetoothConnect,
    };
  }

  PrivacyPermissionState _mapStatus(PermissionStatus status) {
    if (status.isGranted) return PrivacyPermissionState.granted;
    if (status.isPermanentlyDenied) {
      return PrivacyPermissionState.permanentlyDenied;
    }
    if (status.isRestricted) return PrivacyPermissionState.restricted;
    if (status.isLimited) return PrivacyPermissionState.limited;
    if (status.isDenied) return PrivacyPermissionState.denied;
    return PrivacyPermissionState.unavailable;
  }
}

class PrivacyPermissionsScreen extends StatefulWidget {
  const PrivacyPermissionsScreen({
    super.key,
    this.permissionService,
  });

  final PrivacyPermissionService? permissionService;

  @override
  State<PrivacyPermissionsScreen> createState() =>
      _PrivacyPermissionsScreenState();
}

class _PrivacyPermissionsScreenState extends State<PrivacyPermissionsScreen>
    with WidgetsBindingObserver {
  late final PrivacyPermissionService _permissionService;
  final Map<PrivacyPermissionType, PrivacyPermissionState> _statuses = {};
  final Set<PrivacyPermissionType> _busyPermissions = {};
  bool _loading = true;

  static const _items = <_PermissionItemData>[
    _PermissionItemData(
      type: PrivacyPermissionType.camera,
      icon: Icons.camera_alt_outlined,
      title: '相機',
      description: '用於復健姿態辨識、動作評估、影像掃描與需要攝影機的訓練功能。',
    ),
    _PermissionItemData(
      type: PrivacyPermissionType.microphone,
      icon: Icons.mic_none_outlined,
      title: '麥克風',
      description: '用於視訊通話、影音互動及需要收音的功能。',
    ),
    _PermissionItemData(
      type: PrivacyPermissionType.notifications,
      icon: Icons.notifications_none_outlined,
      title: '通知',
      description: '用於復健提醒、系統通知與相關訓練提醒。',
    ),
    _PermissionItemData(
      type: PrivacyPermissionType.nearbyDevices,
      icon: Icons.bluetooth_outlined,
      title: '附近裝置',
      description: '用於部分裝置連線與周邊裝置功能。',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permissionService =
        widget.permissionService ?? const DevicePrivacyPermissionService();
    _refreshStatuses();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses(showLoading: false);
    }
  }

  Future<void> _refreshStatuses({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    final nextStatuses = <PrivacyPermissionType, PrivacyPermissionState>{};
    for (final item in _items) {
      nextStatuses[item.type] = _permissionService.isSupported(item.type)
          ? await _permissionService.status(item.type)
          : PrivacyPermissionState.unavailable;
    }
    if (!mounted) return;
    setState(() {
      _statuses
        ..clear()
        ..addAll(nextStatuses);
      _loading = false;
    });
  }

  Future<void> _handlePermission(PrivacyPermissionType type) async {
    final current = _statuses[type] ?? PrivacyPermissionState.unavailable;
    if (_busyPermissions.contains(type)) return;
    if (current == PrivacyPermissionState.permanentlyDenied) {
      await _openSettings();
      return;
    }
    if (current != PrivacyPermissionState.denied) return;

    setState(() => _busyPermissions.add(type));
    final status = await _permissionService.request(type);
    if (!mounted) return;
    setState(() {
      _busyPermissions.remove(type);
      _statuses[type] = status;
    });
  }

  Future<void> _openSettings() async {
    final opened = await _permissionService.openSettings();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('無法開啟系統設定，請從裝置設定手動調整權限。')),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: const Text(
          '隱私權限',
          style: TextStyle(
            color: Color(0xFF1A1D2E),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1D2E)),
        actions: [
          IconButton(
            key: const Key('privacy-refresh'),
            tooltip: '重新整理權限狀態',
            onPressed: _loading ? null : _refreshStatuses,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const _IntroCard(),
            const SizedBox(height: 20),
            const _SectionTitle(title: '裝置權限'),
            const SizedBox(height: 10),
            _PermissionCard(
              items: _items,
              statuses: _statuses,
              busyPermissions: _busyPermissions,
              loading: _loading,
              onTap: _handlePermission,
            ),
            const SizedBox(height: 24),
            const _SectionTitle(title: '資料與隱私'),
            const SizedBox(height: 10),
            const _PrivacyDataCard(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('open-system-permission-settings'),
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('開啟系統權限設定'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: const BorderSide(color: AppColors.primaryBlue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(icon: Icons.shield_outlined),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '你的隱私，由你掌控',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'RehabAssist 僅在功能需要時使用裝置權限。你可以在這裡查看目前的授權狀態，並隨時前往系統設定調整。',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.items,
    required this.statuses,
    required this.busyPermissions,
    required this.loading,
    required this.onTap,
  });

  final List<_PermissionItemData> items;
  final Map<PrivacyPermissionType, PrivacyPermissionState> statuses;
  final Set<PrivacyPermissionType> busyPermissions;
  final bool loading;
  final ValueChanged<PrivacyPermissionType> onTap;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _PermissionTile(
              data: items[index],
              status: statuses[items[index].type] ??
                  PrivacyPermissionState.unavailable,
              loading: loading || busyPermissions.contains(items[index].type),
              onTap: () => onTap(items[index].type),
            ),
            if (index != items.length - 1)
              const Divider(
                height: 1,
                indent: 68,
                endIndent: 16,
                color: Color(0xFFE8EAF1),
              ),
          ],
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.data,
    required this.status,
    required this.loading,
    required this.onTap,
  });

  final _PermissionItemData data;
  final PrivacyPermissionState status;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canAct = !loading &&
        (status == PrivacyPermissionState.denied ||
            status == PrivacyPermissionState.permanentlyDenied);
    return InkWell(
      onTap: canAct ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBox(icon: data.icon, size: 42, iconSize: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.description,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  if (status == PrivacyPermissionState.permanentlyDenied) ...[
                    const SizedBox(height: 6),
                    const Text(
                      '此權限已被系統停用，請前往裝置設定重新開啟。',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _PermissionStatusBadge(status: status, loading: loading),
          ],
        ),
      ),
    );
  }
}

class _PermissionStatusBadge extends StatelessWidget {
  const _PermissionStatusBadge({required this.status, required this.loading});

  final PrivacyPermissionState status;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final presentation = loading
        ? const _StatusPresentation(
            '查詢中', Color(0xFFF0F1F5), AppColors.secondaryText)
        : switch (status) {
            PrivacyPermissionState.granted => const _StatusPresentation(
                '已允許', Color(0xFFE8F7EF), Color(0xFF237A4B)),
            PrivacyPermissionState.denied => const _StatusPresentation(
                '允許', Color(0xFFEFF1FF), AppColors.primaryBlue),
            PrivacyPermissionState.permanentlyDenied =>
              const _StatusPresentation(
                  '前往設定', Color(0xFFFFF4E5), Color(0xFF9A5A00)),
            PrivacyPermissionState.restricted => const _StatusPresentation(
                '受系統限制', Color(0xFFF4EEF9), Color(0xFF76518D)),
            PrivacyPermissionState.limited => const _StatusPresentation(
                '部分允許', Color(0xFFFFF4E5), Color(0xFF9A5A00)),
            PrivacyPermissionState.unavailable => const _StatusPresentation(
                '不適用', Color(0xFFF0F1F5), AppColors.secondaryText),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: presentation.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        presentation.label,
        style: TextStyle(
          color: presentation.foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PrivacyDataCard extends StatelessWidget {
  const _PrivacyDataCard();

  static const _paragraphs = [
    'RehabAssist 會依功能需求處理帳號資料、復健計畫、訓練紀錄與相關系統資料。',
    '部分資料會透過 RehabAssist 後端服務進行同步與保存，以支援帳號、治療師指派、復健計畫與訓練紀錄等功能。',
    '姿態辨識主要由裝置端進行，以降低持續將攝影機影像傳送至遠端服務的需求。',
    'AI 復健助手會在使用者主動使用功能時，將回答所需的相關資訊傳送至 AI 中介服務處理。',
    '裝置權限只會在對應功能需要時使用，使用者也可以隨時透過裝置系統設定調整已授予的權限。',
  ];

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          for (var index = 0; index < _paragraphs.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _paragraphs[index],
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
            if (index != _paragraphs.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard(
      {required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.primaryText,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.size = 46, this.iconSize = 22});

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1FF),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: AppColors.primaryBlue, size: iconSize),
    );
  }
}

class _PermissionItemData {
  const _PermissionItemData({
    required this.type,
    required this.icon,
    required this.title,
    required this.description,
  });

  final PrivacyPermissionType type;
  final IconData icon;
  final String title;
  final String description;
}

class _StatusPresentation {
  const _StatusPresentation(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;
}
