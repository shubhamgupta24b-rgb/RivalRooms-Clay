import 'package:flutter/material.dart';
import 'tokens.dart';

export 'tokens.dart';

/// The type scale (spec 1.3). Display faces are Lilita One, the rest Nunito. Numbers that
/// change (scores, timers) use tabular figures.
@immutable
class GameType {
  final TextStyle display,
      h1,
      h2,
      h3,
      score,
      scoreLarge,
      body,
      bodyStrong,
      bodySmall,
      label,
      micro,
      button,
      buttonSmall;

  // Older names, still used across the app.
  TextStyle get headline => h2;
  TextStyle get title => h3;
  TextStyle get caption => bodySmall;

  const GameType({
    required this.display,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.score,
    required this.scoreLarge,
    required this.body,
    required this.bodyStrong,
    required this.bodySmall,
    required this.label,
    required this.micro,
    required this.button,
    required this.buttonSmall,
  });

  static const _tabular = [FontFeature.tabularFigures()];

  /// The scale in a given text, muted and label colour.
  factory GameType.of(Color text, Color muted, Color label) => GameType(
        display: TextStyle(
            fontFamily: Fonts.display, color: text, fontSize: 48, height: 1.0),
        h1: TextStyle(
            fontFamily: Fonts.display, color: text, fontSize: 38, height: 1.05),
        h2: TextStyle(
            fontFamily: Fonts.display, color: text, fontSize: 26, height: 1.1),
        h3: TextStyle(
            fontFamily: Fonts.display, color: text, fontSize: 20, height: 1.15),
        score: TextStyle(
            fontFamily: Fonts.display,
            color: text,
            fontSize: 28,
            height: 1.0,
            fontFeatures: _tabular),
        scoreLarge: TextStyle(
            fontFamily: Fonts.display,
            color: text,
            fontSize: 64,
            height: 1.0,
            fontFeatures: _tabular),
        body: TextStyle(
            fontFamily: Fonts.body,
            color: text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            height: 1.35),
        bodyStrong: TextStyle(
            fontFamily: Fonts.body,
            color: text,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            height: 1.3),
        bodySmall: TextStyle(
            fontFamily: Fonts.body,
            color: muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.3),
        label: TextStyle(
            fontFamily: Fonts.body,
            color: label,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 11 * 0.16),
        micro: TextStyle(
            fontFamily: Fonts.body,
            color: text,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6),
        button: const TextStyle(
            fontFamily: Fonts.display, fontSize: 22, height: 1.0),
        buttonSmall: const TextStyle(
            fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w900),
      );

  static GameType lerp(GameType a, GameType b, double t) {
    TextStyle l(TextStyle x, TextStyle y) => TextStyle.lerp(x, y, t)!;
    return GameType(
      display: l(a.display, b.display),
      h1: l(a.h1, b.h1),
      h2: l(a.h2, b.h2),
      h3: l(a.h3, b.h3),
      score: l(a.score, b.score),
      scoreLarge: l(a.scoreLarge, b.scoreLarge),
      body: l(a.body, b.body),
      bodyStrong: l(a.bodyStrong, b.bodyStrong),
      bodySmall: l(a.bodySmall, b.bodySmall),
      label: l(a.label, b.label),
      micro: l(a.micro, b.micro),
      button: l(a.button, b.button),
      buttonSmall: l(a.buttonSmall, b.buttonSmall),
    );
  }
}

/// The flavour-aware design tokens (spec 1.1, 2.1). Two instances: [neon] (night, the
/// default) and [flatSet] (the flat app). Read them with `context.tokens`.
///
/// Text pairs: [onBg]/[onBgMuted] go straight on the background or on [surface];
/// [text]/[textMuted] go on [card] surfaces.
@immutable
class GameTokens extends ThemeExtension<GameTokens> {
  final bool flat;
  final Color bgTop, bg, bgBottom;
  final Color surface, surfaceStrong, stroke, overlay, sheet;
  final Color card, cardRaised, sunken, strokeStrong, scrim;
  final Color onBg, onBgMuted, text, textMuted, label;
  final Color gold, goldDeep, onGold, success, warn, danger, info;
  final List<BoxShadow> shadowSm, shadowMd, shadowLg;

  /// Text styles in [onBg]. (Not called `type`: ThemeExtension uses that name as its key.)
  final GameType styles;

  /// Text styles in [text], for card surfaces.
  final GameType cardStyles;

  // Older names, still used across the app.
  Color get bgMid => bg;
  Color get glass => surface;
  Color get glassStrong => surfaceStrong;
  Color get accent => gold;
  Color get onAccent => onGold;

  const GameTokens({
    required this.flat,
    required this.bgTop,
    required this.bg,
    required this.bgBottom,
    required this.surface,
    required this.surfaceStrong,
    required this.stroke,
    required this.overlay,
    required this.sheet,
    required this.card,
    required this.cardRaised,
    required this.sunken,
    required this.strokeStrong,
    required this.scrim,
    required this.onBg,
    required this.onBgMuted,
    required this.text,
    required this.textMuted,
    required this.label,
    required this.gold,
    required this.goldDeep,
    required this.onGold,
    required this.success,
    required this.warn,
    required this.danger,
    required this.info,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
    required this.styles,
    required this.cardStyles,
  });

  static final neon = GameTokens(
    flat: false,
    bgTop: NeonPalette.bgTop,
    bg: NeonPalette.bg,
    bgBottom: NeonPalette.bgBottom,
    surface: NeonPalette.surface,
    surfaceStrong: NeonPalette.surfaceStrong,
    stroke: NeonPalette.stroke,
    overlay: NeonPalette.overlay,
    sheet: NeonPalette.sheet,
    card: NeonPalette.card,
    cardRaised: NeonPalette.cardRaised,
    sunken: NeonPalette.sunken,
    strokeStrong: NeonPalette.strokeStrong,
    scrim: const Color(
        0x9E060820), // rgba(6,8,32,0.62), as over the game in the Pause mockup
    onBg: NeonPalette.text,
    onBgMuted: NeonPalette.textMuted,
    text: NeonPalette.text,
    textMuted: NeonPalette.textMuted,
    label: NeonPalette.label,
    gold: Brand.gold,
    goldDeep: Brand.goldDeep,
    onGold: Brand.onGold,
    success: StatusColors.success,
    warn: StatusColors.warn,
    danger: StatusColors.danger,
    info: StatusColors.info,
    shadowSm: Shadows.small,
    shadowMd: Shadows.small,
    shadowLg: Shadows.large,
    styles:
        GameType.of(NeonPalette.text, NeonPalette.textMuted, NeonPalette.label),
    cardStyles:
        GameType.of(NeonPalette.text, NeonPalette.textMuted, NeonPalette.label),
  );

  /// Flat app: sky background with ink text on it (white text on the spec's sky would fail
  /// 4.5:1), white tiles, dark name strips.
  static final flatSet = GameTokens(
    flat: true,
    bgTop: FlatPalette.skyLight,
    bg: FlatPalette.sky,
    bgBottom: FlatPalette.skyDeep,
    surface: const Color(0xD9FFFFFF),
    surfaceStrong: FlatPalette.surfaceStrong,
    stroke: FlatPalette.stroke,
    overlay: FlatPalette.overlay,
    sheet: FlatPalette.surface,
    card: FlatPalette.surface,
    cardRaised: FlatPalette.surface,
    sunken: FlatPalette.option,
    strokeStrong: FlatPalette.stroke,
    scrim: const Color(0xB822212B),
    onBg: FlatPalette.ink,
    onBgMuted: FlatPalette.ink,
    text: FlatPalette.ink,
    textMuted: FlatPalette.inkMuted,
    label: FlatPalette.label,
    gold: Brand.gold,
    goldDeep: Brand.goldDeep,
    onGold: Brand.onGold,
    success: const Color(0xFF1E9E57),
    warn: StatusColors.warn,
    danger: FlatPalette.close,
    info: StatusColors.info,
    shadowSm: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 3))],
    shadowMd: const [BoxShadow(color: Color(0x38000000), offset: Offset(0, 4))],
    shadowLg: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 6))],
    styles: GameType.of(FlatPalette.ink, FlatPalette.ink, FlatPalette.ink),
    cardStyles:
        GameType.of(FlatPalette.ink, FlatPalette.inkMuted, FlatPalette.label),
  );

  @override
  GameTokens copyWith({bool? flat}) =>
      flat == null ? this : (flat ? flatSet : neon);

  @override
  GameTokens lerp(covariant GameTokens? o, double t) {
    if (o == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<BoxShadow> s(List<BoxShadow> a, List<BoxShadow> b) =>
        BoxShadow.lerpList(a, b, t) ?? b;
    return GameTokens(
      flat: t < 0.5 ? flat : o.flat,
      bgTop: c(bgTop, o.bgTop),
      bg: c(bg, o.bg),
      bgBottom: c(bgBottom, o.bgBottom),
      surface: c(surface, o.surface),
      surfaceStrong: c(surfaceStrong, o.surfaceStrong),
      stroke: c(stroke, o.stroke),
      overlay: c(overlay, o.overlay),
      sheet: c(sheet, o.sheet),
      card: c(card, o.card),
      cardRaised: c(cardRaised, o.cardRaised),
      sunken: c(sunken, o.sunken),
      strokeStrong: c(strokeStrong, o.strokeStrong),
      scrim: c(scrim, o.scrim),
      onBg: c(onBg, o.onBg),
      onBgMuted: c(onBgMuted, o.onBgMuted),
      text: c(text, o.text),
      textMuted: c(textMuted, o.textMuted),
      label: c(label, o.label),
      gold: c(gold, o.gold),
      goldDeep: c(goldDeep, o.goldDeep),
      onGold: c(onGold, o.onGold),
      success: c(success, o.success),
      warn: c(warn, o.warn),
      danger: c(danger, o.danger),
      info: c(info, o.info),
      shadowSm: s(shadowSm, o.shadowSm),
      shadowMd: s(shadowMd, o.shadowMd),
      shadowLg: s(shadowLg, o.shadowLg),
      styles: GameType.lerp(styles, o.styles, t),
      cardStyles: GameType.lerp(cardStyles, o.cardStyles, t),
    );
  }
}

extension GameTokensX on BuildContext {
  /// The design tokens in effect here (night unless inside a flat-look subtree).
  GameTokens get tokens =>
      Theme.of(this).extension<GameTokens>() ?? GameTokens.neon;

  /// Short alias of [tokens].
  GameTokens get tk => tokens;
}

/// Gives [child] the flat or night token set (e.g. a word game's play screen in the flat app).
class TokenScope extends StatelessWidget {
  final bool flat;
  final Widget child;
  const TokenScope({super.key, required this.flat, required this.child});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final want = flat ? GameTokens.flatSet : GameTokens.neon;
    if (identical(theme.extension<GameTokens>(), want)) return child;
    return Theme(
        data: theme.copyWith(extensions: [
          ...theme.extensions.values.where((e) => e is! GameTokens),
          want
        ]),
        child: child);
  }
}
