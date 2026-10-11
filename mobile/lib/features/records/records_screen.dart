import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/records/records.dart';
import '../../core/ui/app_ui.dart' show AppBackground;
import '../../core/ui/components.dart';
import '../../games/game_catalog.dart';
import '../local_games/local_games_hub_screen.dart';
import '../local_games/shell/game_art.dart';
import '../privacy/privacy_screen.dart';

/// My Records (spec 4.10): best score, wins and games played per game, kept on this phone
/// only, last played first.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  Map<String, GameRecord>? records;
  List<String> recent = const [];

  @override
  void initState() {
    super.initState();
    Records.all().then((r) {
      if (mounted) setState(() => records = r);
    });
    Records.recent().then((r) {
      if (mounted) setState(() => recent = r);
    });
  }

  /// Name and colour for a game id, from the one-device list or the online catalog.
  (String, Color) _game(String id) {
    if (id == 'guess_person') return ('Guess the Person', const Color(0xFFFFC93C));
    for (final g in allLocalGames) {
      if (g.id == id) return (g.title, g.color);
    }
    for (final g in gameCatalog) {
      if (g.id == id) return (g.name, g.color);
    }
    return (id, const Color(0xFF7B4DFF));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final name = context.watch<AuthenticationManager>().displayName;
    final r = records;
    final order = {for (var i = 0; i < recent.length; i++) recent[i]: i};
    // Last played first (the recent list), then by how often.
    final entries = r == null
        ? const <MapEntry<String, GameRecord>>[]
        : (r.entries.where((e) => e.value.played > 0 || e.value.best > 0).toList()
          ..sort((a, b) {
            final x = order[a.key] ?? 1 << 20, y = order[b.key] ?? 1 << 20;
            return x != y ? x - y : b.value.played - a.value.played;
          }));
    final played = entries.fold(0, (s, e) => s + e.value.played);
    final wins = entries.fold(0, (s, e) => s + e.value.wins);
    final ink = t.flat ? FlatPalette.ink : Colors.white;
    final muted = t.flat ? FlatPalette.inkMuted : NeonPalette.textMuted;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 10), child: PageHeader(label: 'Saved on this phone', title: 'My records')),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                _Stat(GameIcons.dice5, '$played', 'Games'),
                const SizedBox(width: 8),
                _Stat(GameIcons.crown, '$wins', 'Wins'),
                const SizedBox(width: 8),
                _Stat(GameIcons.star, '${entries.length}', 'Different'),
              ]),
            ),
            Expanded(
              child: r == null
                  ? const Center(child: CircularProgressIndicator(color: Brand.gold))
                  : entries.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(32),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const GameIcon(GameIcons.trophy, size: 72, color: Brand.gold),
                              const SizedBox(height: 12),
                              Text('No games yet${name.isEmpty ? '' : ', $name'}!', textAlign: TextAlign.center, style: TextStyle(fontFamily: Fonts.display, fontSize: 22, color: t.onBg)),
                              const SizedBox(height: 4),
                              Text('Play any game and your best scores show up here.', textAlign: TextAlign.center, style: t.styles.body.copyWith(color: t.onBgMuted)),
                            ]),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final e = entries[i];
                            final (title, color) = _game(e.key);
                            return Semantics(
                              label: '$title: best ${e.value.best}, played ${e.value.played}${e.value.wins > 0 ? ', ${e.value.wins} wins' : ''}',
                              excludeSemantics: true,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: Skin.surface(radius: Radii.lg, depth: 0.8),
                                child: Row(children: [
                                  GameThumb(id: e.key, color: color, size: 46, radius: 12),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Fonts.display, fontSize: 17, color: ink)),
                                      Text('played ${e.value.played}${e.value.wins > 0 ? ' · wins ${e.value.wins}' : ''}',
                                          style: TextStyle(fontFamily: Fonts.body, fontSize: 12.5, fontWeight: FontWeight.w800, color: muted)),
                                    ]),
                                  ),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('BEST', style: TextStyle(fontFamily: Fonts.body, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: t.flat ? FlatPalette.label : NeonPalette.label)),
                                    Text('${e.value.best}', style: TextStyle(fontFamily: Fonts.display, fontSize: 26, height: 1.05, color: ink, fontFeatures: const [FontFeature.tabularFigures()])),
                                  ]),
                                ]),
                              ),
                            );
                          },
                        ),
            ),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(kTouchTarget, kTouchTarget)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                child: Text('Privacy & your data', style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w800, color: t.onBgMuted)),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final GameIcons icon;
  final String value, label;
  const _Stat(this.icon, this.value, this.label);
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Expanded(
      child: Semantics(
        label: '$value ${label.toLowerCase()}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: Skin.surface(radius: Radii.lg, depth: 0.8),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GameIcon(icon, size: 18, color: t.flat ? FlatPalette.ink : Brand.gold),
              const SizedBox(width: 6),
              Text(value, style: TextStyle(fontFamily: Fonts.display, fontSize: 22, color: t.flat ? FlatPalette.ink : Colors.white, fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
            Text(label.toUpperCase(), style: TextStyle(fontFamily: Fonts.body, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: t.flat ? FlatPalette.label : NeonPalette.label)),
          ]),
        ),
      ),
    );
  }
}
