import '../core/ui/tv_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PiIpPreferences {
  static const _key = 'tv_pi_camera_ip';
  static Future<String?> load() async {
    try { return (await SharedPreferences.getInstance()).getString(_key); }
    catch (error) { debugPrint('Pi IP restore failed: $error'); return null; }
  }
  static Future<void> save(String ip) async {
    try { await (await SharedPreferences.getInstance()).setString(_key, ip); }
    catch (error) { debugPrint('Pi IP persistence failed: $error'); }
  }
}

bool isValidPiIpv4(String value) {
  final parts = value.split('.');
  return parts.length == 4 && parts.every((part) =>
    RegExp(r'^\d{1,3}$').hasMatch(part) && int.parse(part) <= 255);
}

Future<String?> showPiIpDialog(BuildContext context, {String? initialIp}) async {
  final saved = initialIp ?? await PiIpPreferences.load();
  if (!context.mounted) return null;
  final ip = await showDialog<String>(context: context,
    builder: (_) => _PiIpDialog(initialIp: saved ?? '192.168.0.103'));
  if (ip != null) await PiIpPreferences.save(ip);
  return ip;
}

class _PiIpDialog extends StatefulWidget {
  final String initialIp;
  const _PiIpDialog({required this.initialIp});
  @override
  State<_PiIpDialog> createState() => _PiIpDialogState();
}
class _PiIpDialogState extends State<_PiIpDialog> {
  late final controller = TextEditingController(text: widget.initialIp);
  final form = GlobalKey<FormState>();
  void submit() {
    if (form.currentState!.validate()) Navigator.pop(context, controller.text.trim());
  }
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('連接樹莓派鏡頭'),
    content: SizedBox(width: 460, child: Form(key: form, child: TvTextNavigation(child: TextFormField(
      autofocus: true, controller: controller,
      decoration: const InputDecoration(labelText: '樹莓派 IP 位址', hintText: '例如 192.168.0.103'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      textInputAction: TextInputAction.done, onFieldSubmitted: (_) => submit(),
      validator: (value) => isValidPiIpv4(value?.trim() ?? '') ? null : '請輸入有效 IPv4 位址（0–255）',
    )))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
      FilledButton(onPressed: submit, child: const Text('確認 IP')),
    ],
  );
}
