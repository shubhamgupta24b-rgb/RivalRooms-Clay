import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/network/socket_manager.dart';
import '../../core/room/room_manager.dart';
import '../../core/ui/app_ui.dart' show AppBackground;
import '../../core/ui/components.dart';
import '../../games/game_catalog.dart';
import '../../games/game_host_screen.dart';
import '../create_room/game_grid.dart';
import '../local_games/shell/game_art.dart';

/// The room between games: the code to share, who's in, which game is next.
/// The host picks the game (or a party of random games) and starts.
class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rm = context.watch<RoomManager>();
    final socket = context.read<SocketManager>();
    final room = rm.room;
    final t = context.tk;

    if (room == null) {
      // Room is gone (left, or seat expired while offline): go back home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    if (room.status != 'lobby') return GameHostScreen(room: room);

    final myId = context.read<AuthenticationManager>().token.split(':')[1];
    final isHost = room.hostId == myId;
    final me = room.players.where((p) => p.userId == myId).firstOrNull;
    final host = room.players.where((p) => p.userId == room.hostId).firstOrNull;
    final game = gameCatalog.firstWhere((g) => g.id == room.gameType, orElse: () => GameInfo(room.gameType, gameName(room.gameType)));
    final n = room.players.length;
    final fits = n >= game.minPlayers && n <= game.maxPlayers;
    final away = room.players.where((p) => !p.connected).toList();

    Future<void> run(Future<String?> f) async {
      final err = await f;
      if (err != null && context.mounted) showToast(context, friendlyError(err), tone: Tone.danger, duration: const Duration(seconds: 3));
    }

    Future<void> pick() async {
      final id = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => GamePickerScreen(selectedId: room.gameType, playable: room.playable, playerCount: n)),
      );
      if (id != null) await run(rm.selectGame(id));
    }

    Future<void> leave() async {
      if (await confirmAction(context, title: 'Leave the room?', message: 'Your friends can carry on without you.', confirm: 'Leave', cancel: 'Stay', emoji: null)) {
        await rm.leave();
      }
    }

    final notReady = room.players.where((p) => !p.ready && p.userId != room.hostId).map((p) => p.username).toList();
    final ready = room.players.where((p) => p.ready).length;
    final waitLine = n < game.minPlayers
        ? 'Waiting for ${game.minPlayers - n} more ${game.minPlayers - n == 1 ? 'player' : 'players'}…'
        : (notReady.isEmpty ? (fits ? 'Everyone is ready!' : 'Pick a game for $n players') : 'Waiting for ${notReady.join(', ')} to tap Ready…');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await leave();
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(children: [
                  SizedBox(width: 92, child: Align(alignment: Alignment.centerLeft, child: _LeaveButton(onTap: leave))),
                  Expanded(child: Semantics(header: true, child: Text('GAME ROOM', textAlign: TextAlign.center, style: t.styles.label))),
                  SizedBox(width: 92, child: Align(alignment: Alignment.centerRight, child: RoundButton(icon: GameIcons.settings, label: 'Settings', onPressed: () => showSettingsSheet(context)))),
                ]),
              ),
              // Non-blocking states: our connection, and anyone who dropped out.
              ValueListenableBuilder<bool>(
                valueListenable: socket.connected,
                builder: (_, on, __) => AnimatedSize(
                  duration: Motion.of(context, Motion.normal),
                  child: on
                      ? const SizedBox(width: double.infinity)
                      : const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 0), child: ConnectionBanner(state: LinkState.reconnecting)),
                ),
              ),
              if (away.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: host != null && !host.connected && !isHost
                      ? const ConnectionBanner(state: LinkState.hostLeft)
                      : ConnectionBanner(state: LinkState.playerLeft, who: away.map((p) => p.username).join(', ')),
                ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 14), children: [
                  _CodeCard(code: room.code, quickPlay: room.isPublic),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Text('PLAYERS · $n / ${room.maxPlayers}', style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.82, color: t.onBg))),
                    Text('$ready ready', style: TextStyle(fontFamily: Fonts.body, fontSize: 12, fontWeight: FontWeight.w800, color: t.onBgMuted)),
                  ]),
                  const SizedBox(height: 8),
                  for (var i = 0; i < room.players.length; i++) ...[
                    _PlayerRow(player: room.players[i], seat: i, isHost: room.players[i].userId == room.hostId, isMe: room.players[i].userId == myId),
                    const SizedBox(height: 8),
                  ],
                  for (var i = room.players.length; i < room.maxPlayers; i++) ...[_EmptySeat(seat: i), const SizedBox(height: 8)],
                  const SizedBox(height: 6),
                  _GameCard(game: game, fits: fits, playerCount: n, isHost: isHost, onChange: pick),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(isHost ? waitLine : (me?.ready == true ? 'You are ready. The host starts the game.' : 'Tap Ready when you are set'),
                        textAlign: TextAlign.center, style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w800, color: t.onBgMuted)),
                  ),
                  const SizedBox(height: 10),
                  if (isHost) ...[
                    GoldButton('Start ${game.name}', icon: GameIcons.play, height: 58, onPressed: room.allReady && fits ? () => run(rm.start()) : null),
                    const SizedBox(height: 10),
                    KitButton('Party mode · 5 random games', icon: GameIcons.dice5, style: KitButtonStyle.outline, onPressed: room.allReady ? () => run(rm.startParty(5)) : null),
                  ] else if (me?.ready == true)
                    _ReadyDone(onTap: () => run(rm.setReady(false)))
                  else
                    GoldButton('Ready', icon: GameIcons.check, height: 58, onPressed: () => run(rm.setReady(true))),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _LeaveButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LeaveButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.tk.flat ? FlatPalette.close : const Color(0xFFFF8E8B);
    return Semantics(
      button: true,
      label: 'Leave room',
      excludeSemantics: true,
      child: Material(
        color: context.tk.flat ? Colors.white : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Radii.rChip, side: BorderSide(color: c.withValues(alpha: 0.6))),
        child: InkWell(
          borderRadius: Radii.rChip,
          onTap: onTap,
          child: SizedBox(
            height: kTouchTarget,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(child: Text('Leave', style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w900, color: c))),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Ready" done: outlined in green; tap to undo.
class _ReadyDone extends StatelessWidget {
  final VoidCallback onTap;
  const _ReadyDone({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      label: 'Ready. Tap to undo',
      excludeSemantics: true,
      child: Material(
        color: t.flat ? Colors.white : StatusColors.success.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: Radii.rButton, side: BorderSide(color: t.success, width: 2)),
        child: InkWell(
          borderRadius: Radii.rButton,
          onTap: () {
            haptic(HapticWeight.selection);
            onTap();
          },
          child: SizedBox(
            height: 58,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GameIcon(GameIcons.check, size: 22, color: t.success),
              const SizedBox(width: 10),
              Text('Ready', style: TextStyle(fontFamily: Fonts.display, fontSize: 22, color: t.flat ? t.success : const Color(0xFFB5F0CD))),
              const SizedBox(width: 10),
              Text('tap to undo', style: TextStyle(fontFamily: Fonts.body, fontSize: 12, fontWeight: FontWeight.w800, color: t.onBgMuted)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The room code in big letters, Copy and Share, and how friends join (Lobby mockup).
class _CodeCard extends StatelessWidget {
  final String code;
  final bool quickPlay; // an open room: players are matched in, no code needed
  const _CodeCard({required this.code, this.quickPlay = false});

  @override
  Widget build(BuildContext context) {
    Widget small(GameIcons icon, String label, VoidCallback onTap) => Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: Radii.rChip,
            child: InkWell(
              borderRadius: Radii.rChip,
              onTap: onTap,
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    GameIcon(icon, size: 16),
                    const SizedBox(width: 6),
                    Text(label, style: const TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: Skin.heroPanel(radius: 24),
      child: Column(children: [
        if (quickPlay) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: StatusColors.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: StatusColors.success.withValues(alpha: 0.6))),
            child: const Text('Open to everyone', style: TextStyle(fontFamily: Fonts.body, fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFB5F0CD))),
          ),
          const SizedBox(height: 8),
        ],
        const Text('ROOM CODE', style: TextStyle(fontFamily: Fonts.body, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.76, color: Colors.white)),
        const SizedBox(height: 10),
        Semantics(
          container: true,
          label: 'Room code ${code.split('').join(' ')}',
          excludeSemantics: true,
          child: LayoutBuilder(builder: (context, c) {
            final w = ((c.maxWidth - 5 * 6) / 6).clamp(30.0, 46.0);
            return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < code.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Container(
                  width: w,
                  height: w * 1.24,
                  alignment: Alignment.center,
                  decoration: Skin.surface(radius: Radii.card, depth: 0.55),
                  child: Text(code[i], style: TextStyle(fontFamily: Fonts.display, fontSize: w * 0.74, height: 1, color: Colors.white)),
                ),
              ],
            ]);
          }),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          small(GameIcons.copy, 'Copy', () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) showToast(context, 'Room code $code copied', tone: Tone.success);
          }),
          const SizedBox(width: 8),
          small(GameIcons.share, 'Share', () => shareText(context, 'Join my RivalRoom game: $code', copied: 'Room code $code copied')),
        ]),
        const SizedBox(height: 10),
        Text(quickPlay ? 'New players are matched in automatically, or join with this code' : 'Friends tap Join room and enter this code',
            textAlign: TextAlign.center, style: const TextStyle(fontFamily: Fonts.body, fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD6DAF7))),
      ]),
    );
  }
}

class _GameCard extends StatelessWidget {
  final GameInfo game;
  final bool fits;
  final int playerCount;
  final bool isHost;
  final VoidCallback onChange;
  const _GameCard({required this.game, required this.fits, required this.playerCount, required this.isHost, required this.onChange});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final ink = t.flat ? FlatPalette.ink : Colors.white;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: Skin.surface(radius: Radii.button, depth: 0.85),
      child: Row(children: [
        GameThumb(id: game.id, color: game.color, size: 56, radius: 14),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NEXT GAME', style: TextStyle(fontFamily: Fonts.body, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.54, color: t.flat ? FlatPalette.label : NeonPalette.label)),
            Text(game.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Fonts.display, fontSize: 20, height: 1.1, color: ink)),
            Text(fits ? '${game.playersLabel} players' : 'Needs ${game.playersLabel} players · you have $playerCount',
                style: TextStyle(fontFamily: Fonts.body, fontSize: 12.5, fontWeight: FontWeight.w800, color: fits ? (t.flat ? FlatPalette.inkMuted : NeonPalette.textMuted) : (t.flat ? FlatPalette.close : Brand.gold))),
          ]),
        ),
        if (isHost) KitButton('Change', style: KitButtonStyle.outline, height: 40, onPressed: onChange),
      ]),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final RoomPlayer player;
  final int seat;
  final bool isHost, isMe;
  const _PlayerRow({required this.player, required this.seat, required this.isHost, required this.isMe});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = PlayerPalette.color(seat);
    final (String status, Color fg, Color bg) = !player.connected
        ? ('OFFLINE', t.flat ? const Color(0xFF8A5A00) : const Color(0xFFFFD27A), t.warn.withValues(alpha: 0.2))
        : (player.ready
            ? ('READY', t.flat ? t.success : const Color(0xFFB5F0CD), StatusColors.success.withValues(alpha: 0.2))
            : ('NOT READY', t.flat ? FlatPalette.inkMuted : NeonPalette.textMuted, (t.flat ? FlatPalette.ink : Colors.white).withValues(alpha: 0.10)));
    final ink = t.flat ? FlatPalette.ink : Colors.white;
    final tags = [if (isMe) 'YOU', if (isHost) 'HOST'].join(' · ');
    return Semantics(
      label: '${player.username}${isMe ? ', you' : ''}${isHost ? ', host' : ''}, ${status.toLowerCase()}',
      excludeSemantics: true,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: Skin.surface(tint: isMe ? c : null, ring: isMe ? c.withValues(alpha: 0.7) : null, radius: Radii.lg, depth: 0.75),
        child: Row(children: [
          Opacity(opacity: player.connected ? 1 : 0.5, child: PlayerBadge(index: seat, size: 26, initial: player.username.isEmpty ? '?' : player.username)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: player.username),
                if (tags.isNotEmpty) TextSpan(text: '  $tags', style: TextStyle(fontSize: 11, color: t.flat ? fillFor(c) : PlayerPalette.tintFor(c))),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w900, color: ink),
            ),
          ),
          if (isHost) ...[GameIcon(GameIcons.crown, size: 18, color: t.flat ? const Color(0xFF8A5A00) : Brand.gold), const SizedBox(width: 8)],
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.normal),
            child: Container(
              key: ValueKey(status),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
              child: Text(status, style: TextStyle(fontFamily: Fonts.body, fontSize: 11, fontWeight: FontWeight.w900, color: fg)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EmptySeat extends StatelessWidget {
  final int seat;
  const _EmptySeat({required this.seat});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final line = t.flat ? FlatPalette.ink.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.22);
    return SizedBox(
      height: 54,
      child: CustomPaint(
        painter: _Dashed(line, 16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            SizedBox(width: 26, height: 26, child: CustomPaint(painter: _Dashed(PlayerPalette.color(seat).withValues(alpha: 0.7), 6))),
            const SizedBox(width: 10),
            Expanded(child: Text('Waiting for a player…', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Fonts.body, fontSize: 14, fontWeight: FontWeight.w800, color: t.onBgMuted))),
          ]),
        ),
      ),
    );
  }
}

/// A dashed rounded outline.
class _Dashed extends CustomPainter {
  final Color color;
  final double radius;
  const _Dashed(this.color, this.radius);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.75), Radius.circular(radius)));
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), p);
      }
    }
  }

  @override
  bool shouldRepaint(_Dashed old) => old.color != color;
}
