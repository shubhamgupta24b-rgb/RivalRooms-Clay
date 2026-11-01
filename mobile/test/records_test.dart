import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/auth/authentication_manager.dart';
import 'package:multiplayer_game/core/records/records.dart';
import 'package:multiplayer_game/features/records/records_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('records count games and wins, and keep the best score', () async {
    await Records.add('bingo', score: 1, won: true);
    await Records.add('bingo', score: 0);
    await Records.add('fruit_merge', score: 120);
    await Records.add('fruit_merge', score: 80);
    final r = await Records.all();
    expect(r['bingo']!.played, 2);
    expect(r['bingo']!.wins, 1);
    expect(r['fruit_merge']!.best, 120);
    expect(r['fruit_merge']!.played, 2);
  });

  test('older solo best scores show up, and clear() wipes everything',
      () async {
    SharedPreferences.setMockInitialValues(
        {'best_flappy_jump': 17, 'name': 'Asha'});
    expect((await Records.all())['flappy_jump']!.best, 17);
    await Records.add('flappy_jump', score: 9);
    expect((await Records.all())['flappy_jump']!.best, 17,
        reason: 'the old best still counts');
    await Records.clear();
    expect(await Records.all(), isEmpty);
    expect((await SharedPreferences.getInstance()).getString('name'), 'Asha',
        reason: 'clear() only touches records');
  });

  testWidgets('My Records lists games with best score, wins and totals',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'records':
          '{"bingo":{"p":3,"w":2,"b":1},"fruit_merge":{"p":5,"w":0,"b":340}}',
    });
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => AuthenticationManager(),
        child: const MaterialApp(home: RecordsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Fruit Merge'), findsOneWidget);
    expect(find.text('340'), findsOneWidget);
    expect(find.text('Bingo'), findsOneWidget);
    expect(find.text('played 3 · wins 2'), findsOneWidget);
    expect(find.bySemanticsLabel('8 games'), findsOneWidget,
        reason: 'games played in total');
    expect(find.bySemanticsLabel('2 wins'), findsOneWidget);
  });

  testWidgets('no games yet: a friendly empty screen', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => AuthenticationManager(),
        child: const MaterialApp(home: RecordsScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('No games yet'), findsOneWidget);
  });
}
