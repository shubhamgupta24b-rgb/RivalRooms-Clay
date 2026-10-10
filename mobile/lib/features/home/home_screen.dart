import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/lan/lan_host.dart';
import '../../core/network/lan_discovery.dart';
import '../../core/network/socket_manager.dart';
import '../../core/room/room_manager.dart';
import '../../core/ui/app_ui.dart';
import '../../core/records/records.dart';
import '../../core/settings/app_settings.dart';
import '../../core/ui/components.dart';
import '../../core/ui/materials/materials.dart';
import '../create_room/create_room_screen.dart';
import '../guess_person/screens/guess_person_menu_screen.dart';
import '../join_room/join_room_screen.dart';
import '../lobby/lobby_screen.dart';
import '../local_games/local_games_hub_screen.dart';
import '../local_games/shell/game_art.dart';
import '../local_games/shell/local_game_shell.dart';
import '../privacy/privacy_screen.dart';
import '../quick_play/quick_play_screen.dart';
import '../raja_mantri/rmcs_screen.dart';
import '../records/records_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SocketManager _socket = context.read<SocketManager>();
  bool _rejoined = false;
  String? _recent; // last game played on this phone

  @override
  void initState() {
    super.initState();
    // The server connects in the background, so check both now and once it comes up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _rejoinRoom());
    _socket.connected.addListener(_onConnection);
    _loadRecent();
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

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

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
        wifi ? 'The host isn\'t answering. Is their app still open, on the same hotspot or Wi-Fi?' : 'Not connected yet. The server may be waking up (up to a minute): it keeps trying by itself.',
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _WifiSearchSheet(),
    );
    if (choice == null || !mounted) return;
    if (choice == _WifiSearchSheet.host) {
      try {
        await LanHost.start();
      } catch (_) {
        if (mounted) showToast(context, 'Could not start hosting on this phone. Close other game apps and try again.', tone: Tone.danger, duration: const Duration(seconds: 4));
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
      message: '1. Turn on this phone\'s hotspot (or stay on the same Wi-Fi as your friends).\n'
          '2. Friends connect to it, open Party Games and tap Same Wi-Fi, then Join a friend.\n'
          '3. Create a room here and share the code (or use Quick Play).\n\n'
          'No internet needed. Keep this app open while you play.'
          '${ips.isEmpty ? '' : '\n\nThis phone: ${ips.join(' · ')}'}',
      actions: [Builder(builder: (c) => GoldButton('Got it', onPressed: () => Navigator.pop(c)))],
    );
  }

  /// Create, join or quick play, on the server picked by the mode (online or the Wi-Fi host).
  Future<void> _rooms() async {
    final wifi = AppConfig.mode == ServerMode.wifi;
    await showAppSheet<void>(
      context,
      title: wifi ? 'Rooms on this Wi-Fi' : 'Play online',
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SheetOption(icon: GameIcons.plus, tint: PlayerPalette.colors[0], title: 'Create room', text: 'Host a game and share the code', onTap: () {
          Navigator.pop(ctx);
          _open(const CreateRoomScreen());
        }),
        const SizedBox(height: 10),
        _SheetOption(icon: GameIcons.forward, tint: PlayerPalette.colors[1], title: 'Join room', text: "Enter a friend's 6-letter code", onTap: () {
          Navigator.pop(ctx);
          _open(const JoinRoomScreen());
        }),
        const SizedBox(height: 10),
        _SheetOption(icon: GameIcons.bolt, tint: PlayerPalette.colors[2], title: 'Quick play', text: 'Jump into an open room', onTap: () {
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
    if (mounted && AppConfig.mode == ServerMode.wifi && (before != ServerMode.wifi || _socket.connected.value)) await _rooms();
  }

  /// The last game played on this phone, for "Continue".
  Future<void> _loadRecent() async {
    try {
      final r = await Records.recent();
      if (mounted && r.isNotEmpty) setState(() => _recent = r.first);
    } catch (_) {}
  }

  (String, Color, Widget)? _game(String id) {
    if (id == 'guess_person') return ('Guess the Person', const Color(0xFFFFC93C), const GuessPersonMenuScreen());
    if (id == 'raja_mantri') return ('Raja Mantri', const Color(0xFF8A1C3A), const RmcsMenuScreen());
    for (final g in localGames) {
      if (g.id == id) return (g.title, g.color, LocalGameShell(game: g));
    }
    return null;
  }

  Future<void> _openGame(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _loadRecent();
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthenticationManager>().displayName;
    final t = context.tk;
    final recent = _recent == null ? null : _game(_recent!);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 22), children: [
                _header(name),
                const SizedBox(height: 16),
                _hero(),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _ModeTile(icon: GameIcons.globe, tint: PlayerPalette.colors[0], ink: PlayerPalette.tints[0], label: 'Play online', onTap: _playOnline)),
                  const SizedBox(width: 10),
                  Expanded(child: _ModeTile(icon: GameIcons.wifi, tint: PlayerPalette.colors[2], ink: PlayerPalette.tints[2], label: 'Same Wi-Fi', onTap: _sameWifi)),
                  const SizedBox(width: 10),
                  Expanded(child: _ModeTile(icon: GameIcons.trophy, tint: Brand.gold, ink: const Color(0xFFFFE08A), label: 'My records', onTap: () => _open(const RecordsScreen()))),
                ]),
                if (recent != null) ...[
                  const SizedBox(height: 16),
                  _ContinueChip(id: _recent!, title: recent.$1, color: recent.$2, onTap: () => _openGame(recent.$3)),
                ],
                const SizedBox(height: 16),
                SectionHeader('Featured games', action: 'See all', onAction: () => _open(const LocalGamesHubScreen())),
                const SizedBox(height: 8),
                _featured(),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(kTouchTarget, kTouchTarget), foregroundColor: t.onBgMuted),
                    onPressed: () => _open(const PrivacyScreen()),
                    child: Text('Privacy', style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w800, color: t.onBgMuted)),
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
    final t = context.tk;
    final seat = AppSettings.playerColor.value;
    return Row(children: [
      Container(
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: PlayerPalette.color(seat).withValues(alpha: 0.25), spreadRadius: 3)]),
        child: PlayerBadge(index: seat, size: 44, initial: name.isEmpty ? '?' : name),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Welcome back', style: TextStyle(fontFamily: Fonts.body, fontSize: 12, fontWeight: FontWeight.w800, color: t.flat ? t.onBg : NeonPalette.label)),
          Text(name.isEmpty ? 'Hi there' : 'Hi, $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Fonts.display, fontSize: 22, height: 1.1, color: t.onBg)),
        ]),
      ),
      _status(),
      const SizedBox(width: 4),
      RoundButton(icon: GameIcons.settings, label: 'Settings', onPressed: () => showSettingsSheet(context)),
    ]);
  }

  /// Online / Hosting on this phone / On a Wi-Fi host / Offline. Tap to retry when offline.
  Widget _status() => ValueListenableBuilder<bool>(
        valueListenable: _socket.connected,
        builder: (context, online, _) {
          final t = context.tk;
          final wifi = AppConfig.mode == ServerMode.wifi;
          final label = !online ? 'Offline' : (wifi ? (AppConfig.hosting ? 'Hosting' : 'Wi-Fi host') : 'Online');
          final c = online ? (wifi ? PlayerPalette.colors[3] : StatusColors.success) : (t.flat ? FlatPalette.inkMuted : NeonPalette.label);
          return Semantics(
            button: !online,
            label: online ? '$label: connected' : 'Offline. Tap to try again',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: Radii.rChip,
              onTap: online ? null : _connect,
              child: Container(
                constraints: const BoxConstraints(minHeight: 32),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: t.flat ? Colors.white : c.withValues(alpha: 0.14),
                  borderRadius: Radii.rChip,
                  border: Border.all(color: c.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(fontFamily: Fonts.body, fontSize: 12, fontWeight: FontWeight.w900, color: t.flat ? FlatPalette.ink : (online ? Color.lerp(c, Colors.white, 0.55) : NeonPalette.textMuted))),
                ]),
              ),
            ),
          );
        },
      );

  Widget _hero() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Brand.indigo, Brand.indigoDeep]),
        borderRadius: Radii.rBoard,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: Shadows.large,
      ),
      child: Stack(children: [
        const Positioned(right: -6, top: 6, child: ExcludeSemantics(child: SizedBox(width: 150, height: 120, child: CustomPaint(painter: _HeroArt())))),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PARTY GAMES', style: TextStyle(fontFamily: Fonts.body, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.76, color: Brand.goldLine)),
            const SizedBox(height: 6),
            const SizedBox(width: 190, child: Text('Ready to play?', style: TextStyle(fontFamily: Fonts.display, fontSize: 30, height: 1.05, color: Colors.white))),
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              child: Text('$totalGameCount games · 2–6 players\nNo internet needed',
                  style: const TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFD6DAF7))),
            ),
            const SizedBox(height: 14),
            IntrinsicWidth(child: GoldButton('Play on one phone', height: 50, fontSize: 19, onPressed: () => _open(const LocalGamesHubScreen()))),
          ]),
        ),
      ]),
    );
  }

  Widget _featured() {
    final picks = [
      for (final id in ['smash_karts', 'memory', 'ludo', 'colour_clash', 'raja_mantri', 'archery', 'guess_person', 'air_hockey'])
        if (_game(id) case final g?) (id, g),
    ];
    final info = {for (final g in localGames) g.id: g};
    return SizedBox(
      height: 178,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: picks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (id, (title, color, page)) = picks[i];
          final g = info[id];
          return SizedBox(
            width: 150,
            child: GameTile(
              id: id,
              title: title,
              color: color,
              minPlayers: g?.minPlayers ?? (id == 'raja_mantri' ? 4 : 2),
              maxPlayers: g?.maxPlayers ?? (id == 'raja_mantri' ? 4 : 6),
              onTap: () => _openGame(page),
            ),
          );
        },
      ),
    );
  }
}

/// A big square choice on Home: icon in a colour, Lilita label.
class _ModeTile extends StatelessWidget {
  final GameIcons icon;
  final Color tint, ink;
  final String label;
  final VoidCallback onTap;
  const _ModeTile({required this.icon, required this.tint, required this.ink, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final flat = context.tk.flat;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: flat ? Colors.white : tint.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: Radii.rButton, side: BorderSide(color: flat ? FlatPalette.stroke : Colors.white.withValues(alpha: 0.12))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            haptic(HapticWeight.selection);
            onTap();
          },
          child: SizedBox(
            height: 104,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              GameIcon(icon, size: 30, color: flat ? fillFor(tint) : ink),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(fontFamily: Fonts.display, fontSize: 15, color: flat ? FlatPalette.ink : Colors.white))),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Continue: play Archery again".
class _ContinueChip extends StatelessWidget {
  final String id, title;
  final Color color;
  final VoidCallback onTap;
  const _ContinueChip({required this.id, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final flat = context.tk.flat;
    final ink = flat ? FlatPalette.ink : Colors.white;
    return Semantics(
      button: true,
      label: 'Continue: play $title again',
      excludeSemantics: true,
      child: Material(
        color: flat ? Colors.white : Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: Radii.rLg, side: BorderSide(color: flat ? FlatPalette.stroke : Colors.white.withValues(alpha: 0.12))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                GameThumb(id: id, color: color, size: 32, radius: 9),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'Continue: ', style: TextStyle(color: flat ? FlatPalette.inkMuted : const Color(0xFFD6DAF7), fontWeight: FontWeight.w800)),
                      TextSpan(text: 'play $title again', style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: Fonts.body, fontSize: 14),
                  ),
                ),
                GameIcon(GameIcons.forward, size: 18, color: flat ? FlatPalette.ink : Brand.gold),
              ]),
            ),
          ),
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
  const _SheetOption({required this.icon, required this.tint, required this.title, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: Material(
        color: t.flat ? FlatPalette.option : Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: Radii.rLg, side: BorderSide(color: t.flat ? FlatPalette.stroke : Colors.white.withValues(alpha: 0.12))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            haptic(HapticWeight.selection);
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tint.withValues(alpha: t.flat ? 0.9 : 0.22), borderRadius: Radii.rCard),
                child: GameIcon(icon, size: 22, color: t.flat ? onColor(tint) : Color.lerp(tint, Colors.white, 0.5)!),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontFamily: Fonts.display, fontSize: 18, color: t.text)),
                  Text(text, style: TextStyle(fontFamily: Fonts.body, fontSize: 12.5, fontWeight: FontWeight.w700, color: t.textMuted)),
                ]),
              ),
              GameIcon(GameIcons.forward, size: 16, color: t.textMuted),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The hero card picture: a die and two cards (Main mockup).
class _HeroArt extends CustomPainter {
  const _HeroArt();
  @override
  void paint(Canvas canvas, Size size) {
    void card(Offset at, double angle, Color edge, {bool back = false}) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(angle);
      const r = Rect.fromLTWH(-24, -33, 48, 66);
      canvas.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(1, 4)), const Radius.circular(8)), Paint()..color = Colors.black.withValues(alpha: 0.3));
      if (back) {
        canvas.translate(r.left, r.top);
        const CardBackPainter(radius: 8).paint(canvas, r.size);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), Paint()..color = const Color(0xFFFFF8EC));
        canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(1.5), const Radius.circular(7)), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = edge);
        paintIcon(canvas, GameIcons.cherry, Rect.fromCenter(center: Offset.zero, width: 32, height: 32));
      }
      canvas.restore();
    }

    card(const Offset(62, 64), -0.22, PlayerPalette.colors[0], back: true);
    card(const Offset(100, 58), 0.16, PlayerPalette.colors[1]);
    // A die.
    canvas.save();
    canvas.translate(46, 92);
    canvas.rotate(0.2);
    const d = Rect.fromLTWH(-15, -15, 30, 30);
    canvas.drawRRect(RRect.fromRectAndRadius(d.shift(const Offset(0, 3)), const Radius.circular(7)), Paint()..color = Colors.black.withValues(alpha: 0.3));
    canvas.drawRRect(RRect.fromRectAndRadius(d, const Radius.circular(7)), Paint()..color = Colors.white);
    final pip = Paint()..color = Brand.onGold;
    for (final p in const [Offset(-7, -7), Offset(7, -7), Offset(0, 0), Offset(-7, 7), Offset(7, 7)]) {
      canvas.drawCircle(p, 2.8, pip);
    }
    canvas.restore();
    // Sparkles.
    final s = Paint()..color = Brand.gold;
    for (final (x, y, r) in const [(20.0, 22.0, 2.5), (136.0, 18.0, 2.0), (130.0, 104.0, 2.4)]) {
      canvas.drawCircle(Offset(x, y), r, s);
    }
  }

  @override
  bool shouldRepaint(_HeroArt old) => false;
}

/// Same Wi-Fi / hotspot: Host on this phone (pops [host]) or Join a friend, which searches
/// this Wi-Fi/hotspot for a phone or laptop hosting games and pops its URL when found;
/// or type the host's address.
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
    final url = AppConfig.normalise(_ctrl.text.contains(':') || _ctrl.text.startsWith('http') ? _ctrl.text : '${_ctrl.text}:${LanDiscovery.port}');
    if (url != null) Navigator.pop(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final muted = TextStyle(fontFamily: Fonts.body, fontSize: 14, fontWeight: FontWeight.w700, height: 1.4, color: t.textMuted);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 22 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: t.text.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(3)))),
        const SizedBox(height: 12),
        Text('SAME WI-FI · NO INTERNET', textAlign: TextAlign.center, style: t.cardStyles.label),
        const SizedBox(height: 2),
        Text(choosing ? 'Play on one hotspot' : (searching ? 'Looking for the host…' : 'No host found yet'), textAlign: TextAlign.center, style: t.cardStyles.h2),
        const SizedBox(height: 14),
        if (choosing) ...[
          Text('One phone hosts, the others join it. No internet needed.', textAlign: TextAlign.center, style: muted),
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
              text: "Connect to the host's hotspot (or same Wi-Fi), then search.",
              onTap: () {
                setState(() => choosing = false);
                _search();
              }),
        ] else if (searching) ...[
          Text('Searching this Wi-Fi or hotspot…', textAlign: TextAlign.center, style: muted),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress == 0 ? null : progress, minHeight: 8, color: Brand.gold, backgroundColor: t.text.withValues(alpha: 0.12)),
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
          GoldButton('Search again', icon: GameIcons.search, onPressed: _search),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType: TextInputType.url,
                style: TextStyle(fontFamily: Fonts.body, fontWeight: FontWeight.w800, color: t.text),
                decoration: InputDecoration(
                  hintText: "Host's address, e.g. 192.168.43.1",
                  hintStyle: TextStyle(fontFamily: Fonts.body, fontWeight: FontWeight.w700, color: t.textMuted),
                  fillColor: t.flat ? FlatPalette.option : Colors.white.withValues(alpha: 0.08),
                ),
                onSubmitted: (_) => _typed(),
              ),
            ),
            const SizedBox(width: 8),
            KitButton('Use', style: KitButtonStyle.outline, onPressed: _typed),
          ]),
        ],
      ]),
    );
  }
}
