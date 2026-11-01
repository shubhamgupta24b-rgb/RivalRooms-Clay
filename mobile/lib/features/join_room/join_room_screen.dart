import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/room/room_manager.dart';
import '../../core/ui/app_ui.dart' show AppBackground;
import '../../core/ui/components.dart';
import '../lobby/lobby_screen.dart';

const _codeLength = 6;

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});
  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final ctrl = TextEditingController();
  final focus = FocusNode();
  bool busy = false;
  int _fails = 0; // bumps the shake on a failed join
  String? _error; // shown under the boxes

  @override
  void initState() {
    super.initState();
    focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    ctrl.dispose();
    focus.dispose();
    super.dispose();
  }

  bool get _complete => ctrl.text.length == _codeLength;

  Future<void> _join() async {
    if (!_complete || busy) return;
    final rm = context.read<RoomManager>();
    final nav = Navigator.of(context);
    setState(() => busy = true);
    final err = await rm.join(ctrl.text);
    if (!mounted) return;
    if (err != null) {
      haptic(HapticWeight.heavy);
      setState(() {
        busy = false;
        _fails++;
        _error = friendlyError(err);
      });
      return;
    }
    nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LobbyScreen()),
        (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                child:
                    PageHeader(label: 'Join a room', title: 'Enter the code')),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                              child: GameIcon(GameIcons.lock,
                                  size: 52,
                                  color:
                                      t.flat ? FlatPalette.ink : Brand.gold)),
                          const SizedBox(height: 10),
                          Text(
                              'Ask the host for the 6-letter code on their screen',
                              textAlign: TextAlign.center,
                              style:
                                  t.styles.body.copyWith(color: t.onBgMuted)),
                          const SizedBox(height: 20),
                          Shake(
                            trigger: _fails == 0 ? null : _fails,
                            child: _CodeBoxes(
                              ctrl: ctrl,
                              focus: focus,
                              error: _error != null,
                              onChanged: () => setState(() => _error = null),
                              onSubmit: _join,
                            ),
                          ),
                          AnimatedSize(
                            duration: Motion.of(context, Motion.normal),
                            child: _error == null
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(_error!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontFamily: Fonts.body,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: t.flat
                                                  ? FlatPalette.close
                                                  : const Color(0xFFFF8E8B))),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 24),
                          GoldButton(busy ? 'Joining…' : 'Join room',
                              icon: GameIcons.forward,
                              height: 58,
                              onPressed: _complete && !busy ? _join : null),
                          const SizedBox(height: 24),
                          const _Tip(
                              icon: GameIcons.wifi,
                              text:
                                  'Everyone plays on the same server: online, or the same Wi-Fi host.'),
                          const SizedBox(height: 8),
                          const _Tip(
                              icon: GameIcons.restart,
                              text:
                                  'The host picks the games: you stay in the room between rounds.'),
                        ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Six letter boxes; typing goes into an invisible text field laid over them.
class _CodeBoxes extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;
  final bool error;
  const _CodeBoxes(
      {required this.ctrl,
      required this.focus,
      required this.onChanged,
      required this.onSubmit,
      this.error = false});

  @override
  Widget build(BuildContext context) {
    final text = ctrl.text;
    final t = context.tk;
    final ink = t.flat ? FlatPalette.ink : Colors.white;
    final gold = t.flat ? FlatPalette.ink : Brand.gold;
    final red = t.flat ? FlatPalette.close : const Color(0xFFFF5E5B);
    return LayoutBuilder(builder: (context, c) {
      final box = ((c.maxWidth - 5 * 8) / _codeLength).clamp(36.0, 58.0);
      return SizedBox(
        height: box * 1.2,
        child: Stack(children: [
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < _codeLength; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: box,
                  height: box * 1.2,
                  alignment: Alignment.center,
                  decoration: Skin.surface(
                    radius: Radii.card,
                    sunken: i >= text.length,
                    tint: i < text.length ? gold : null,
                    ring: error
                        ? red
                        : (i == text.length && focus.hasFocus ? gold : null),
                    depth: 0.6,
                  ),
                  child: Text(i < text.length ? text[i] : '',
                      style: TextStyle(
                          fontFamily: Fonts.display,
                          color: ink,
                          fontSize: (box * 0.55).clamp(20.0, 30.0))),
                ),
              ],
            ]),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: ctrl,
                focusNode: focus,
                autofocus: true,
                maxLength: _codeLength,
                showCursor: false,
                enableInteractiveSelection: false,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  TextInputFormatter.withFunction(
                      (_, v) => v.copyWith(text: v.text.toUpperCase())),
                ],
                decoration: const InputDecoration(
                    counterText: '', border: InputBorder.none),
                onChanged: (_) => onChanged(),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
          ),
        ]),
      );
    });
  }
}

class _Tip extends StatelessWidget {
  final GameIcons icon;
  final String text;
  const _Tip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final muted = t.flat ? FlatPalette.inkMuted : NeonPalette.textMuted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: Skin.surface(radius: Radii.chip, depth: 0.6),
      child: Row(children: [
        GameIcon(icon, size: 18, color: muted),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontFamily: Fonts.body,
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700))),
      ]),
    );
  }
}
