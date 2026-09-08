import '../platform/app_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

ThemeData tvTheme() {
  final base =
      ThemeData(colorSchemeSeed: const Color(0xff2359a8), useMaterial3: true);
  final button = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
    textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    side: WidgetStateProperty.resolveWith((states) => BorderSide(
          color: states.contains(WidgetState.focused)
              ? const Color(0xffea8a00)
              : Colors.transparent,
          width: 4,
        )),
    overlayColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.focused) ? const Color(0x33ea8a00) : null),
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
        bodyLarge: const TextStyle(fontSize: 22),
        bodyMedium: const TextStyle(fontSize: 20),
        bodySmall: const TextStyle(fontSize: 18),
        titleLarge: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
    scaffoldBackgroundColor: const Color(0xffeef3f9),
    elevatedButtonTheme: ElevatedButtonThemeData(style: button),
    filledButtonTheme: FilledButtonThemeData(style: button),
    outlinedButtonTheme: OutlinedButtonThemeData(style: button),
    textButtonTheme: TextButtonThemeData(style: button),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xffea8a00), width: 4)),
    ),
  );
}

class TvRemoteScope extends StatelessWidget {
  final Widget child;
  const TvRemoteScope({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        },
        child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(), child: child),
      );
}

/// Focusable replacement for presentation-layer tap-only cards.
class TvTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool autofocus;
  final HitTestBehavior? behavior;
  const TvTap(
      {super.key,
      required this.child,
      this.onTap,
      this.autofocus = false,
      this.behavior});
  @override
  State<TvTap> createState() => _TvTapState();
}

class _TvTapState extends State<TvTap> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => FocusableActionDetector(
        enabled: widget.onTap != null,
        autofocus: widget.autofocus,
        onFocusChange: (value) {
          setState(() => focused = value);
          if (value) {
            Scrollable.ensureVisible(context,
                alignmentPolicy:
                    ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
          }
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          })
        },
        child: Semantics(
            button: true,
            enabled: widget.onTap != null,
            child: GestureDetector(
              onTap: widget.onTap,
              behavior: widget.behavior,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: focused
                          ? const Color(0xffea8a00)
                          : Colors.transparent,
                      width: 4),
                ),
                child: widget.child,
              ),
            )),
      );
}

class TvPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  const TvPage(
      {super.key,
      required this.title,
      required this.child,
      this.actions = const []});
  @override
  Widget build(BuildContext context) => TvRemoteScope(
          child: Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
                child: child)),
      ));
}

class TvWaitingView extends StatelessWidget {
  final String message;
  const TvWaitingView({super.key, this.message = '等待外部攝影機連線'});
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xff14263e),
        child: Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ))),
      );
}

/// Leave a one-line TV input with Up/Down; Left/Right still edit its value.
class TvTextNavigation extends StatelessWidget {
  final Widget child;
  const TvTextNavigation({super.key, required this.child});
  @override
  Widget build(BuildContext context) => !AppPlatform.current.supportsDpad ? child : Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
      SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
    }, child: child,
  );
}
