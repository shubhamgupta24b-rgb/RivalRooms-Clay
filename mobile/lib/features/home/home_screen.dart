import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/lan/lan_host.dart';
import '../../core/network/lan_discovery.dart';
import '../../core/network/socket_manager.dart';
import '../../core/room/room_manager.dart';
import '../../core/ui/app_ui.dart';
import '../../core/ui/components.dart';
import '../create_room/create_room_screen.dart';
import '../join_room/join_room_screen.dart';
import '../lobby/lobby_screen.dart';
import '../local_games/local_games_hub_screen.dart';
import 'play_count.dart';
import '../privacy/privacy_screen.dart';
import '../quick_play/quick_play_screen.dart';
import '../records/records_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SocketManager _socket = context.read<SocketManager>();
  bool _rejoined = false;

  @override
  void initState() {
    super.initState();
    // The server connects in the background, so check both now and once it comes up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _rejoinRoom());
    _socket.connected.addListener(_onConnection);
  }

  void _onConnection() {
    if (_socket.connected.value) _rejoinRoom();
  }

  /// If the server still has us in a room (e.g. app restarted), jump back in.
  Future<void> _rejoinRoom() async {
    if (_rejoined || !_socket.connected.value || !mounted) return;
    final rm = context.read<RoomManager>();
    final nav = Navigator.of(context);
    await rm.resync();
    if (rm.room != null && mounted && !_rejoined) {
      _rejoined = true;
      nav.push(MaterialPageRoute(builder: (_) => const LobbyScreen()));
    }
  }

  @override
  void dispose() {
    _socket.connected.removeListener(_onConnection);
    super.dispose();
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  /// (Re)connects to the server for the current mode and says how it went.
  Future<void> _connect({String? done}) async {
    final token = context.read<AuthenticationManager>().token;
    final wifi = AppConfig.mode == ServerMode.wifi;
    try {
      await _socket.connect(AppConfig.serverUrl, token);
      if (mounted) showToast(context, done ?? 'Connected!', tone: Tone.success);
    } catch (_) {
      if (!mounted) return;
      showToast(
        context,
        wifi
            ? 'The host isn\'t answering. Is their app still open, on the same hotspot or Wi-Fi?'
            : 'Not connected yet. The server may be waking up (up to a minute): it keeps trying by itself.',
        tone: Tone.warn,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _useOnline() async {
    if (AppConfig.mode == ServerMode.online && _socket.connected.value) return;
    if (AppConfig.hosting) await LanHost.stop();
    await AppConfig.useOnline();
    if (!mounted) return;
    setState(() {});
    await _connect(done: 'Online: play with friends anywhere');
  }

  /// Same Wi-Fi / hotspot, no internet: host the games on this phone, or join a phone
  /// (or laptop) that hosts them.
  Future<void> _useWifi() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tk.flat ? Colors.white : NeonPalette.sheet,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _WifiSearchSheet(),
    );
    if (choice == null || !mounted) return;
    if (choice == _WifiSearchSheet.host) {
      try {
        await LanHost.start();
      } catch (_) {
        if (mounted)
          showToast(context,
              'Could not start hosting on this phone. Close other game apps and try again.',
              tone: Tone.danger, duration: const Duration(seconds: 4));
        return;
      }
      await AppConfig.useWifi(LanHost.selfUrl, hosting: true);
      if (!mounted) return;
      setState(() {});
      await _connect(done: 'This phone is hosting: create a room!');
      if (mounted) await _showHostHelp();
      return;
    }
    if (AppConfig.hosting) await LanHost.stop();
    await AppConfig.useWifi(choice);
    if (!mounted) return;
    setState(() {});
    await _connect(done: 'Connected to the host on this Wi-Fi');
  }

  /// What the host tells their friends.
  Future<void> _showHostHelp() async {
    final ips = await LanHost.addresses();
    if (!mounted) return;
    await showAppDialog<void>(
      context,
      emoji: null,
      title: 'Hosting on this phone',
      message:
          '1. Turn on this phone\'s hotspot (or stay on the same Wi-Fi as your friends).\n'
          '2. Friends connect to it, open Party Games and tap Same Wi-Fi, then Join a friend.\n'
          '3. Create a room here and share the code (or use Quick Play).\n\n'
          'No internet needed. Keep this app open while you play.'
          '${ips.isEmpty ? '' : '\n\nThis phone: ${ips.join(' · ')}'}',
      actions: [
        Builder(
            builder: (c) =>
                GoldButton('Got it', onPressed: () => Navigator.pop(c)))
      ],
    );
  }

  /// Create, join or quick play, on the server picked by the mode (online or the Wi-Fi host).
  Future<void> _rooms() async {
    final wifi = AppConfig.mode == ServerMode.wifi;
    await showAppSheet<void>(
      context,
      title: wifi ? 'Rooms on this Wi-Fi' : 'Play online',
      builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetOption(
                icon: GameIcons.plus,
                tint: PlayerPalette.colors[0],
                title: 'Create room',
                text: 'Host a game and share the code',
                onTap: () {
                  Navigator.pop(ctx);
                  _open(const CreateRoomScreen());
                }),
            const SizedBox(height: 10),
            _SheetOption(
                icon: GameIcons.forward,
                tint: PlayerPalette.colors[1],
                title: 'Join room',
                text: "Enter a friend's 6-letter code",
                onTap: () {
                  Navigator.pop(ctx);
                  _open(const JoinRoomScreen());
                }),
            const SizedBox(height: 10),
            _SheetOption(
                icon: GameIcons.bolt,
                tint: PlayerPalette.colors[2],
                title: 'Quick play',
                text: 'Jump into an open room',
                onTap: () {
                  Navigator.pop(ctx);
                  _open(const QuickPlayScreen());
                }),
          ]),
    );
  }

  Future<void> _playOnline() async {
    if (AppConfig.mode == ServerMode.wifi) await _useOnline();
    if (mounted) await _rooms();
  }

  Future<void> _sameWifi() async {
    final before = AppConfig.mode;
    await _useWifi();
    if (mounted &&
        AppConfig.mode == ServerMode.wifi &&
        (before != ServerMode.wifi || _socket.connected.value)) await _rooms();
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthenticationManager>().displayName;
    final t = context.tk;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                  children: [
                    _header(name),
                    const SizedBox(height: 28),
                    const Text('How many are playing?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: Fonts.display,
                            fontSize: 28,
                            height: 1.05,
                            color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('$totalGameCount games · no internet needed',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: Fonts.body,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white70)),
                    const SizedBox(height: 18),
                    _countGrid(),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: _ModeTile(
                              icon: GameIcons.globe,
                              tint: const Color(0xFF2E8BFF),
                              ink: const Color(0xFF9CC9FF),
                              label: 'Players online',
                              hint: 'Internet rooms',
                              onTap: _playOnline)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _ModeTile(
                              icon: GameIcons.wifi,
                              tint: const Color(0xFF1AA6A6),
                              ink: const Color(0xFFB6F2F2),
                              label: 'Same Wi-Fi',
                              hint: 'Hotspot, no internet',
                              onTap: _sameWifi)),
                    ]),
                    const SizedBox(height: 14),
                    _RecordsPill(onTap: () => _open(const RecordsScreen())),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(
                            minimumSize: const Size(kTouchTarget, kTouchTarget),
                            foregroundColor: t.onBgMuted),
                        onPressed: () => _open(const PrivacyScreen()),
                        child: Text('Privacy',
                            style: TextStyle(
                                fontFamily: Fonts.body,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: t.onBgMuted)),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(String name) {
    final initial = name.trim().isEmpty ? 'S' : name.trim().characters.first.toUpperCase();
    return Row(children: [
      Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7B5CFF), Color(0xFF3E22B2)]),
            boxShadow: const [
              BoxShadow(color: Color(0x553E22B2), blurRadius: 8, offset: Offset(0, 3))
            ]),
        child: Text(initial,
            style: const TextStyle(
                fontFamily: Fonts.display, fontSize: 22, color: Colors.white)),
      ),
      const SizedBox(width: 10),
      const Expanded(
        child: Text('RivalRoom Clay',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: Fonts.display, fontSize: 20, color: Colors.white)),
      ),
      _status(),
      const SizedBox(width: 4),
      RoundButton(
          icon: GameIcons.settings,
          label: 'Settings',
          onPressed: () => showSettingsSheet(context)),
    ]);
  }

  void _openCount(PlayCount count) =>
      _open(LocalGamesHubScreen(playCount: count));

  Widget _countGrid() {
    const cards = [
      (PlayCount.solo, '1', 'Solo', Color(0xFFE23B4A)),
      (PlayCount.two, '2', 'Players', Color(0xFF2E8BFF)),
      (PlayCount.three, '3', 'Players', Color(0xFF2ECC71)),
      (PlayCount.threePlus, '3+', 'Players', Color(0xFFFFC21A)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        for (final (count, numeral, caption, color) in cards)
          _CountCard(
              numeral: numeral,
              caption: caption,
              color: color,
              onTap: () => _openCount(count)),
      ],
    );
  }

  /// Online / Hosting on this phone / On a Wi-Fi host / Offline. Tap to retry when offline.
  Widget _status() => ValueListenableBuilder<bool>(
        valueListenable: _socket.connected,
        builder: (context, online, _) {
          final t = context.tk;
          final wifi = AppConfig.mode == ServerMode.wifi;
          // Names the real mode. A dead socket is not a separate "Offline" game.
          final label = !online
              ? (wifi ? 'Same Wi-Fi · off' : 'Online · off')
              : (wifi
                  ? (AppConfig.hosting ? 'Same Wi-Fi · host' : 'Same Wi-Fi')
                  : 'Online');
          final c = online
              ? (wifi ? PlayerPalette.colors[3] : StatusColors.success)
              : (t.flat ? FlatPalette.inkMuted : NeonPalette.label);
          return Semantics(
            button: !online,
            label: online ? '$label: connected' : 'Offline. Tap to try again',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: Radii.rChip,
              onTap: online ? null : _connect,
              child: Container(
                constraints: const BoxConstraints(minHeight: 32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration:
                    Skin.surface(tint: c, radius: Radii.chip, depth: 0.5),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontFamily: Fonts.body,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: t.flat
                              ? FlatPalette.ink
                              : (online
                                  ? Color.lerp(c, Colors.white, 0.55)
                                  : NeonPalette.textMuted))),
                ]),
              ),
            ),
          );
        },
      );

}

/// Puffy clay count card: purple body, glossy numeral, coloured caption.
class _CountCard extends StatelessWidget {
  final String numeral, caption;
  final Color color;
  final VoidCallback onTap;
  const _CountCard(
      {required this.numeral,
      required this.caption,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$numeral $caption',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          haptic(HapticWeight.selection);
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4A32C4), Color(0xFF2A1878)]),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x55201060),
                    blurRadius: 16,
                    offset: Offset(0, 8))
              ]),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(children: [
            Expanded(
              child: Center(
                child: Text(numeral,
                    style: TextStyle(
                        fontFamily: Fonts.display,
                        fontSize: 64,
                        height: 0.9,
                        color: color,
                        shadows: [
                          Shadow(
                              color: Colors.white.withValues(alpha: 0.45),
                              offset: const Offset(-1, -2)),
                          Shadow(
                              color: color.withValues(alpha: 0.8),
                              offset: const Offset(0, 4),
                              blurRadius: 0),
                        ])),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(14)),
              child: Text(caption.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 16,
                      color: Colors.white)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RecordsPill extends StatelessWidget {
  final VoidCallback onTap;
  const _RecordsPill({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'My records',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFE08A), Color(0xFFFFC21A)]),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x66C48A00),
                    blurRadius: 12,
                    offset: Offset(0, 6))
              ]),
          child: const Text('My records',
              style: TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 22,
                  color: Color(0xFF3A2500))),
        ),
      ),
    );
  }
}

/// A big square choice on Home: icon in a colour, Lilita label.
class _ModeTile extends StatelessWidget {
  final GameIcons icon;
  final Color tint, ink;
  final String label;
  final String? hint;
  final VoidCallback onTap;
  const _ModeTile(
      {required this.icon,
      required this.tint,
      required this.ink,
      required this.label,
      this.hint,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final flat = context.tk.flat;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SkinPanel(
        tint: tint,
        radius: Radii.button,
        onTap: onTap,
        child: SizedBox(
          height: 112,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            GameIcon(icon, size: 28, color: flat ? fillFor(tint) : ink),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      style: TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 15,
                          color: flat ? FlatPalette.ink : Colors.white))),
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                child: Text(hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: Fonts.body,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: flat ? FlatPalette.inkMuted : Colors.white70)),
              ),
          ]),
        ),
      ),
    );
  }
}

/// An option row in a sheet: icon tile, title, a line of help.
class _SheetOption extends StatelessWidget {
  final GameIcons icon;
  final Color tint;
  final String title, text;
  final VoidCallback onTap;
  const _SheetOption(
      {required this.icon,
      required this.tint,
      required this.title,
      required this.text,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: SkinPanel(
        radius: Radii.lg,
        depth: 0.8,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration:
                  Skin.surface(tint: tint, radius: Radii.card, depth: 0.5),
              child: GameIcon(icon,
                  size: 22,
                  color: t.flat
                      ? onColor(tint)
                      : Color.lerp(tint, Colors.white, 0.5)!),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontFamily: Fonts.display,
                            fontSize: 18,
                            color: t.text)),
                    Text(text,
                        style: TextStyle(
                            fontFamily: Fonts.body,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: t.textMuted)),
                  ]),
            ),
            GameIcon(GameIcons.forward, size: 16, color: t.textMuted),
          ]),
        ),
      ),
    );
  }
}

class _WifiSearchSheet extends StatefulWidget {
  static const host = 'host';
  const _WifiSearchSheet();
  @override
  State<_WifiSearchSheet> createState() => _WifiSearchSheetState();
}

class _WifiSearchSheetState extends State<_WifiSearchSheet> {
  double progress = 0;
  bool choosing = true; // host or join?
  bool searching = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      searching = true;
      progress = 0;
    });
    final url = await LanDiscovery.find(onProgress: (p) {
      if (mounted) setState(() => progress = p);
    });
    if (!mounted) return;
    if (url != null) {
      Navigator.pop(context, url);
    } else {
      setState(() => searching = false);
    }
  }

  void _typed() {
    final url = AppConfig.normalise(
        _ctrl.text.contains(':') || _ctrl.text.startsWith('http')
            ? _ctrl.text
            : '${_ctrl.text}:${LanDiscovery.port}');
    if (url != null) Navigator.pop(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final muted = TextStyle(
        fontFamily: Fonts.body,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: t.textMuted);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 22 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
                child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                        color: t.text.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 12),
            Text('SAME WI-FI · NO INTERNET',
                textAlign: TextAlign.center, style: t.cardStyles.label),
            const SizedBox(height: 2),
            Text(
                choosing
                    ? 'Play on one hotspot'
                    : (searching
                        ? 'Looking for the host…'
                        : 'No host found yet'),
                textAlign: TextAlign.center,
                style: t.cardStyles.h2),
            const SizedBox(height: 14),
            if (choosing) ...[
              Text('One phone hosts, the others join it. No internet needed.',
                  textAlign: TextAlign.center, style: muted),
              const SizedBox(height: 14),
              _SheetOption(
                  icon: GameIcons.wifi,
                  tint: PlayerPalette.colors[3],
                  title: 'Host on this phone',
                  text: 'Turn on your hotspot. Friends join it and play here.',
                  onTap: () => Navigator.pop(context, _WifiSearchSheet.host)),
              const SizedBox(height: 10),
              _SheetOption(
                  icon: GameIcons.search,
                  tint: PlayerPalette.colors[2],
                  title: 'Join a friend',
                  text:
                      "Connect to the host's hotspot (or same Wi-Fi), then search.",
                  onTap: () {
                    setState(() => choosing = false);
                    _search();
                  }),
            ] else if (searching) ...[
              Text('Searching this Wi-Fi or hotspot…',
                  textAlign: TextAlign.center, style: muted),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: progress == 0 ? null : progress,
                    minHeight: 8,
                    color: Brand.gold,
                    backgroundColor: t.text.withValues(alpha: 0.12)),
              ),
            ] else ...[
              Text(
                '1. One friend taps Same Wi-Fi, then Host on this phone, and turns on their hotspot.\n'
                '2. Connect this phone to that hotspot (Settings, Wi-Fi).\n'
                '3. Tap Search again.\n\n'
                'Have internet? Use Play online instead.',
                style: muted,
              ),
              const SizedBox(height: 14),
              GoldButton('Search again',
                  icon: GameIcons.search, onPressed: _search),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.url,
                    style: TextStyle(
                        fontFamily: Fonts.body,
                        fontWeight: FontWeight.w800,
                        color: t.text),
                    decoration: InputDecoration(
                      hintText: "Host's address, e.g. 192.168.43.1",
                      hintStyle: TextStyle(
                          fontFamily: Fonts.body,
                          fontWeight: FontWeight.w700,
                          color: t.textMuted),
                      fillColor: t.flat
                          ? FlatPalette.option
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                    onSubmitted: (_) => _typed(),
                  ),
                ),
                const SizedBox(width: 8),
                KitButton('Use',
                    style: KitButtonStyle.outline, onPressed: _typed),
              ]),
            ],
          ]),
    );
  }
}
