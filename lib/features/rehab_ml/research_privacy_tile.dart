import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ml_research_api.dart';
import 'research_collection_gate.dart';

/// The same patient-facing server consent control is used on phone and TV.
class ResearchPrivacyTile extends StatefulWidget {
  const ResearchPrivacyTile({super.key, this.autofocus = false});
  final bool autofocus;
  @override
  State<ResearchPrivacyTile> createState() => _ResearchPrivacyTileState();
}

class _ResearchPrivacyTileState extends State<ResearchPrivacyTile>
    with WidgetsBindingObserver {
  final gate = ResearchCollectionGate.instance;
  bool busy = false;
  bool focused = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    gate.addListener(_update);
    _refresh();
  }

  void _update() { if (mounted) setState(() {}); }
  Future<void> _refresh() async {
    await gate.refresh(force: true);
    if (mounted) setState(() {});
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _change(bool enabled) async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    final success = await gate.setEnabled(enabled);
    if (mounted) setState(() {
      busy = false;
      if (enabled && !success) error = gate.error ?? '目前無法開啟研究資料收集。';
      if (!enabled && gate.error != null) error = gate.error;
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除我的研究資料'),
        content: const Text('這會刪除已儲存在伺服器的研究資料，且無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('確認刪除')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    setState(() { busy = true; error = null; });
    try {
      await MlResearchApi().deleteMyData();
      await gate.refresh(force: true);
    } catch (failure) {
      error = MlResearchException.safeMessage(failure);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    gate.removeListener(_update);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(autofocus: widget.autofocus,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.select ||
                 event.logicalKey == LogicalKeyboardKey.enter ||
                 event.logicalKey == LogicalKeyboardKey.space)) {
              if (!busy) _change(!gate.enabled);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onFocusChange: (value) { if (mounted) setState(() => focused = value); },
          child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(
              color: focused ? Theme.of(context).colorScheme.primary : Colors.transparent,
              width: 3), borderRadius: BorderRadius.circular(12)),
          child: SwitchListTile(
            autofocus: false,
            title: const Text('允許匿名復健研究資料收集'),
            subtitle: const Text('手機與 TV 共用研究同意。無法連線確認時，會暫停建立新研究樣本；復健訓練照常進行。'),
            value: gate.enabled,
            onChanged: busy ? null : _change,
          ),
        )),
        Text(gate.enabled ? '目前已開啟' : '目前已關閉或尚未完成伺服器確認'),
        if (gate.enabled && gate.consent?.handAvailable != true)
          const Text('手部研究範圍目前尚未核准。'),
        if (error != null || gate.error != null)
          Text(error ?? gate.error!, style: const TextStyle(color: Colors.red)),
        TextButton(onPressed: busy ? null : _delete,
            child: const Text('刪除我的研究資料')),
      ],
    )),
  );
}

class ResearchPrivacyPage extends StatelessWidget {
  const ResearchPrivacyPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('資料與隱私')),
    body: SafeArea(child: ListView(
      padding: const EdgeInsets.all(24),
      children: const [ResearchPrivacyTile(autofocus: true)])),
  );
}
