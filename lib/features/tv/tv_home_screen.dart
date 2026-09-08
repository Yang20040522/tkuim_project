import 'package:flutter/material.dart';
import '../../core/ui/tv_ui.dart';
import '../../models/training_action.dart';
import '../../services/history_service.dart';
import '../../widgets/pi_ip_dialog.dart';
import '../account/app_session.dart';
import '../account/role_select_screen.dart';
import '../plan/plan_screen.dart';
import '../training/action_list_screen.dart';

class TvHomeScreen extends StatelessWidget {
  const TvHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    void open(Widget page) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    return TvPage(
        title: 'RehabAssist TV · ${AppSession.name ?? "復健中心"}',
        child: Row(children: [
          SizedBox(
              width: 220,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.live_tv, size: 64),
                    const SizedBox(height: 24),
                    FilledButton(
                        autofocus: true,
                        onPressed: () => open(const PlanScreen()),
                        child: const Text('復健計畫')),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: () => open(const ActionListScreen()),
                        child: const Text('自由訓練')),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: () => open(const TvHistoryScreen()),
                        child: const Text('訓練紀錄')),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: () => open(const TvSettingsScreen()),
                        child: const Text('設定')),
                  ])),
          const SizedBox(width: 36),
          const Expanded(
              child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text('今天，一起練習。',
                    style:
                        TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                SizedBox(height: 24),
                Text(
                    '1  選擇復健計畫或自由訓練\n\n2  觀看動作示教\n\n3  輸入 Raspberry Pi IP，開始訓練',
                    style: TextStyle(fontSize: 24)),
                SizedBox(height: 28),
                Text('使用方向鍵移動，OK 確認，返回鍵回到上一頁。\n尚未連接攝影機時，可以安全停留在等待畫面。'),
              ]))),
        ]));
  }
}

class TvSettingsScreen extends StatefulWidget {
  const TvSettingsScreen({super.key});
  @override
  State<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  String? ip;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await PiIpPreferences.load();
    if (mounted) setState(() => ip = value);
  }

  @override
  Widget build(BuildContext context) => TvPage(
      title: '設定',
      child: ListView(children: [
        Text('Raspberry Pi：${ip ?? "尚未設定"}'),
        const Text('設定 IP 後，請在訓練畫面按「連接攝影機」。'),
        const SizedBox(height: 20),
        FilledButton(
            autofocus: true,
            onPressed: () async {
              final value = await showPiIpDialog(context, initialIp: ip);
              if (mounted && value != null) setState(() => ip = value);
            },
            child: const Text('設定 Raspberry Pi IP')),
        const SizedBox(height: 24),
        const Text('影像來源：外部攝影機\n遙控器：方向鍵 / OK / 返回'),
        const SizedBox(height: 24),
        OutlinedButton(
            onPressed: () async {
              final leave = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                        title: const Text('登出帳號？'),
                        actions: [
                          TextButton(
                              autofocus: true,
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('登出')),
                        ],
                      ));
              if (leave != true) return;
              await AppSession.clear();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                      builder: (_) => const RoleSelectScreen()),
                  (_) => false);
            },
            child: const Text('登出')),
      ]));
}

class TvHistoryScreen extends StatefulWidget {
  const TvHistoryScreen({super.key});
  @override
  State<TvHistoryScreen> createState() => _TvHistoryScreenState();
}

class _TvHistoryScreenState extends State<TvHistoryScreen> {
  late Future<List<TrainingRecord>> records = HistoryService().getHistory();
  bool busy = false;
  Future<void> _sync() async {
    setState(() => busy = true);
    try {
      final id = int.tryParse(AppSession.userId ?? '');
      if (id == null) throw StateError('請重新登入');
      final result = await HistoryService().uploadPendingRecords(userId: id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('上傳成功 ${result.success} 筆，失敗 ${result.failed} 筆')));
      setState(() => records = HistoryService().getHistory());
    } catch (error) {
      debugPrint('TV history sync: $error');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('同步失敗，請檢查網路後重試')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TvPage(
      title: '訓練紀錄',
      actions: [
        TextButton(
            autofocus: true,
            onPressed: busy ? null : _sync,
            child: Text(busy ? '同步中…' : '上傳待同步紀錄')),
      ],
      child: FutureBuilder<List<TrainingRecord>>(
          future: records,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: FilledButton(
                      onPressed: () => setState(
                          () => records = HistoryService().getHistory()),
                      child: const Text('讀取失敗，重試')));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Center(child: Text('尚無訓練紀錄'));
            }
            return ListView(
                children: snapshot.data!.reversed
                    .map((record) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: OutlinedButton(
                              onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                        title: Text(record.actionName),
                                        content: SingleChildScrollView(
                                            child: Text(
                                                '${record.timestamp}\n${record.difficulty}\n訓練時間 ${record.durationSeconds} 秒\n目標 ${record.targetReps} 下\n\n${record.mistakeLogs.isEmpty ? "沒有錯誤紀錄" : record.mistakeLogs.join("\n")}')),
                                        actions: [
                                          FilledButton(
                                              autofocus: true,
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('返回'))
                                        ],
                                      )),
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(children: [
                                    Expanded(
                                        child: Text(
                                            '${record.actionName} · ${record.difficulty}\n${record.timestamp}')),
                                    Text(record.isSynced ? '已同步' : '尚未同步'),
                                  ]))),
                        ))
                    .toList());
          }));
}
