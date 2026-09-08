import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../core/ui/tv_ui.dart';

class TvLoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController identifier;
  final TextEditingController password;
  final String? Function(String?) validateIdentifier;
  final String? Function(String?) validatePassword;
  final VoidCallback login;
  final bool loading;
  const TvLoginForm(
      {super.key,
      required this.formKey,
      required this.identifier,
      required this.password,
      required this.validateIdentifier,
      required this.validatePassword,
      required this.login,
      required this.loading});

  @override
  Widget build(BuildContext context) => Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
          },
          child: TvPage(
              title: '患者登入',
              child: Row(children: [
                if (MediaQuery.sizeOf(context).width >= 760)
                  const Expanded(
                      child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RehabAssist',
                              style: TextStyle(
                                  fontSize: 42, fontWeight: FontWeight.bold)),
                          Text('TV Rehabilitation System',
                              style: TextStyle(fontSize: 22)),
                          SizedBox(height: 28),
                          Text('連接外部攝影機\n在大螢幕上進行復健訓練'),
                        ]),
                  )),
                Expanded(
                    child: Form(
                        key: formKey,
                        child: Column(children: [
                          Expanded(
                              child: SingleChildScrollView(
                                  child: Column(children: [
                            TextFormField(
                              key: const Key('tv-login-identifier'),
                              autofocus: true,
                              controller: identifier,
                              validator: validateIdentifier,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                  labelText: '電子郵件或帳號 ID'),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('tv-login-password'),
                              controller: password,
                              validator: validatePassword,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!loading) login();
                              },
                              decoration:
                                  const InputDecoration(labelText: '密碼'),
                            ),
                            const SizedBox(height: 12),
                            const Text('請使用既有患者帳號。註冊與帳號管理請使用手機版。'),
                          ]))),
                          const SizedBox(height: 8),
                          SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                key: const Key('tv-login-submit'),
                                onPressed: () {
                                  if (!loading) login();
                                },
                                child: Text(loading ? '登入中…' : '登入'),
                              )),
                        ]))),
              ])));
}
