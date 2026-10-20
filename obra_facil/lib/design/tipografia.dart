// Tipografia da prancheta (seção 3 da especificação).
//
// Archivo SemiCondensed nos títulos e números (lembra a letra técnica do
// carimbo), Atkinson Hyperlegible Next no texto (0/O e 1/l/I não se
// confundem sob reflexo) e IBM Plex Mono nos códigos. Todas embutidas.

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Papéis de texto. Os estilos não têm cor: a cor vem do componente ou do
/// [TextTheme] montado por [Tipografia.textTheme].
///
/// Todos usam algarismos tabulares: no app quase todo número é dinheiro,
/// quantidade ou porcentagem, e assim uma coluna de valores alinha e um
/// número que muda não tremula.
abstract final class Tipografia {
  static const String familiaTitulo = 'Archivo';
  static const String familiaTexto = 'Atkinson';
  static const String familiaCodigo = 'PlexMono';

  /// Algarismos de largura fixa.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextLeadingDistribution _par = TextLeadingDistribution.even;

  /// O número principal da tela (R$): 40 / 800.
  static const TextStyle valorHeroi = TextStyle(
    fontFamily: familiaTitulo,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: -0.4,
    fontFeatures: tabular,
    leadingDistribution: _par,
  );

  /// Nome da obra, título da tela: 30 / 800.
  static const TextStyle tituloTela = TextStyle(
    fontFamily: familiaTitulo,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.2,
    fontFeatures: tabular,
    leadingDistribution: _par,
  );

  /// Títulos de seção: 22 / 700.
  static const TextStyle titulo = TextStyle(
    fontFamily: familiaTitulo,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
    fontFeatures: tabular,
    leadingDistribution: _par,
  );

  /// Título de cartão, botão: 18 / 700.
  static const TextStyle subtitulo = TextStyle(
    fontFamily: familiaTitulo,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.25,
    fontFeatures: tabular,
    leadingDistribution: _par,
  );

  /// Texto: 17 / 400, altura 1,45.
  static const TextStyle corpo = TextStyle(
    fontFamily: familiaTexto,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.45,
    fontFeatures: tabular,
    leadingDistribution: _par,
  );

  /// Destaque no texto, item de lista: 17 / 700.
  static const TextStyle corpoForte = TextStyle(
    fontFamily: familiaTexto,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.35,
    fontFeatures: tabular,
    leadingDistribution: _par,
  );

  /// Texto secundário: 15 / 400 (mínimo para informação).
  static const TextStyle apoio = TextStyle(
    fontFamily: familiaTexto,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
    fontFeatures: tabular,
    leadingDistribution: _par,
  );

  /// Rótulo de campo e de carimbo: 13 / 700, espaçamento 1,0. Use sempre
  /// em caixa alta (o componente `Rotulo` já converte).
  static const TextStyle rotulo = TextStyle(
    fontFamily: familiaTitulo,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: 1.0,
    fontFeatures: tabular,
    leadingDistribution: _par,
  );

  /// Chave da NF-e, código de convite: 15 / 500.
  static const TextStyle codigo = TextStyle(
    fontFamily: familiaCodigo,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.45,
    leadingDistribution: _par,
  );

  /// [TextTheme] do Material com os papéis da prancheta, já com as cores.
  ///
  /// display → valor-herói e título de tela; headline → título de tela e
  /// título; title → título, subtítulo e corpo forte; body → corpo e
  /// apoio; label → subtítulo (botões), apoio forte e rótulo.
  static TextTheme textTheme(CoresObra cores) {
    final principal = cores.grafite;
    final secundaria = cores.grafite2;
    return TextTheme(
      displayLarge: valorHeroi.copyWith(color: principal),
      displayMedium: valorHeroi.copyWith(color: principal),
      displaySmall: tituloTela.copyWith(color: principal),
      headlineLarge: tituloTela.copyWith(color: principal),
      headlineMedium: tituloTela.copyWith(color: principal),
      headlineSmall: titulo.copyWith(color: principal),
      titleLarge: titulo.copyWith(color: principal),
      titleMedium: subtitulo.copyWith(color: principal),
      titleSmall: corpoForte.copyWith(color: principal),
      bodyLarge: corpo.copyWith(color: principal),
      bodyMedium: corpo.copyWith(color: principal),
      bodySmall: apoio.copyWith(color: secundaria),
      labelLarge: subtitulo.copyWith(color: principal),
      labelMedium:
          apoio.copyWith(fontWeight: FontWeight.w700, color: principal),
      labelSmall: rotulo.copyWith(color: secundaria),
    );
  }
}
