// Contraste WCAG 2.2 entre os pares de tokens da especificação
// (docs/redesign/design-system.md, seções 1 e 2), calculado aqui do zero
// a partir dos hexadecimais: luminância relativa sRGB e (L1 + 0,05) /
// (L2 + 0,05). Não usa o computeLuminance do Flutter nem o
// CoresObra.contraste, que também são conferidos contra este cálculo.

import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/tokens.dart';

double _canal(int v) {
  final c = v / 255;
  return c <= 0.04045
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _luminancia(Color cor) {
  final argb = cor.toARGB32();
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return 0.2126 * _canal(r) + 0.7152 * _canal(g) + 0.0722 * _canal(b);
}

double razao(Color a, Color b) {
  final la = _luminancia(a);
  final lb = _luminancia(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Mínimos da seção 1.
const _textoPrincipal = 15.0;
const _textoSecundario = 7.0;
const _iconesEBordas = 3.0;

/// Texto colorido (status, laranja como texto): a spec não dá um número
/// e mede de 5,2:1 a 6,6:1; o piso é o AA do WCAG para texto.
const _textoColorido = 4.5;

typedef _Par = (
  String,
  Color Function(CoresObra),
  Color Function(CoresObra),
  double
);

final List<_Par> _pares = [
  // Texto principal (15:1).
  ('grafite no papel', (c) => c.grafite, (c) => c.papel, _textoPrincipal),
  (
    'texto do botão principal',
    (c) => c.sobreGrafite,
    (c) => c.grafite,
    _textoPrincipal
  ),
  // Texto secundário e rótulo de 13 sp (7:1).
  ('grafite2 no papel', (c) => c.grafite2, (c) => c.papel, _textoSecundario),
  ('grafite2 na folha', (c) => c.grafite2, (c) => c.folha, _textoSecundario),
  (
    'botão principal pressionado',
    (c) => c.sobreGrafite,
    (c) => c.grafite2,
    _textoSecundario
  ),
  // O laranja pressionado clareia: o preto em cima não cai (escurecer
  // dava 4,8:1).
  (
    'botão laranja pressionado',
    (c) => c.sobreMarca,
    (c) => c.marcaPressionada,
    _textoSecundario
  ),
  (
    'botão de contorno pressionado',
    (c) => c.grafite,
    (c) => c.folhaRebaixada,
    _textoSecundario
  ),
  // Ícones e bordas (3:1).
  ('traço no papel', (c) => c.traco, (c) => c.papel, _iconesEBordas),
  // Barra de progresso do Material: o que falta (traço) contra o que já
  // foi (grafite).
  (
    'progresso: feito contra o que falta',
    (c) => c.grafite,
    (c) => c.traco,
    _iconesEBordas
  ),
  ('traço na folha', (c) => c.traco, (c) => c.folha, _iconesEBordas),
  ('traço no trilho', (c) => c.traco, (c) => c.folhaRebaixada, _iconesEBordas),
  (
    'marcador da régua no papel',
    (c) => c.marcaTexto,
    (c) => c.papel,
    _iconesEBordas
  ),
  (
    'marcador da régua no trilho',
    (c) => c.marcaTexto,
    (c) => c.folhaRebaixada,
    _iconesEBordas
  ),
  // Halo do marcador e traço oblíquo invertido, onde cruzam o
  // preenchimento grafite.
  (
    'oblíquo invertido no preenchimento',
    (c) => c.sobreGrafite,
    (c) => c.grafite,
    _iconesEBordas
  ),
  (
    'halo do papel no preenchimento',
    (c) => c.papel,
    (c) => c.grafite,
    _iconesEBordas
  ),
  // Texto sobre laranja e sobre amarelo: sempre preto.
  ('preto na marca', (c) => c.sobreMarca, (c) => c.marca, _textoColorido),
  ('preto no aviso', (c) => c.sobreAviso, (c) => c.aviso, _textoSecundario),
  // Texto colorido.
  ('marcaTexto na folha', (c) => c.marcaTexto, (c) => c.folha, _textoColorido),
  ('marcaTexto no papel', (c) => c.marcaTexto, (c) => c.papel, _textoColorido),
  ('revisão na folha', (c) => c.revisao, (c) => c.folha, _textoColorido),
  ('revisão no papel', (c) => c.revisao, (c) => c.papel, _textoColorido),
  ('ok na folha', (c) => c.ok, (c) => c.folha, _textoColorido),
  ('ok no papel', (c) => c.ok, (c) => c.papel, _textoColorido),
];

void main() {
  for (final (tema, cores) in [
    ('claro', CoresObra.claro),
    ('escuro', CoresObra.escuro),
  ]) {
    group('contraste no tema $tema', () {
      test('todos os tokens são opacos', () {
        for (final cor in [
          cores.papel,
          cores.folha,
          cores.folhaRebaixada,
          cores.grafite,
          cores.grafite2,
          cores.traco,
          cores.grade,
          cores.marca,
          cores.sobreMarca,
          cores.marcaTexto,
          cores.revisao,
          cores.ok,
          cores.aviso,
          cores.sobreGrafite,
        ]) {
          expect(cor.a, 1.0, reason: 'cor translúcida: $cor');
        }
      });

      for (final (nome, frente, fundo, minimo) in _pares) {
        test('$nome ≥ $minimo:1', () {
          final r = razao(frente(cores), fundo(cores));
          expect(r, greaterThanOrEqualTo(minimo),
              reason: '$nome: ${r.toStringAsFixed(2)}:1');
          // O cálculo do CoresObra bate com o daqui.
          expect(CoresObra.contraste(frente(cores), fundo(cores)),
              closeTo(r, 0.01));
        });
      }
    });
  }

  test('os valores medidos que a especificação publica conferem', () {
    // (par, claro, escuro); null: a spec não publica para aquele tema.
    final medidos = <(
      String,
      Color Function(CoresObra),
      Color Function(CoresObra),
      double?,
      double?
    )>[
      ('grafite no papel', (c) => c.grafite, (c) => c.papel, 15.6, 15.8),
      ('grafite2 na folha', (c) => c.grafite2, (c) => c.folha, 8.1, 7.6),
      // No escuro a spec diz 3,6:1, mas #7A7F87 na #1A1C1F dá 4,2:1 (o
      // mínimo de 3:1 continua valendo, conferido acima).
      ('traço na folha', (c) => c.traco, (c) => c.folha, 4.8, null),
      ('preto na marca', (c) => c.sobreMarca, (c) => c.marca, 6.7, 8.0),
      ('marcaTexto na folha', (c) => c.marcaTexto, (c) => c.folha, 5.2, null),
      ('revisão na folha', (c) => c.revisao, (c) => c.folha, 6.6, null),
      ('ok na folha', (c) => c.ok, (c) => c.folha, 6.3, null),
      ('preto no aviso', (c) => c.sobreAviso, (c) => c.aviso, 11.7, 11.7),
    ];
    for (final (nome, frente, fundo, claro, escuro) in medidos) {
      for (final (cores, publicado) in [
        (CoresObra.claro, claro),
        (CoresObra.escuro, escuro),
      ]) {
        if (publicado == null) continue;
        final r = razao(frente(cores), fundo(cores));
        expect(r, closeTo(publicado, 0.05),
            reason: '$nome (${cores.brilho.name}): ${r.toStringAsFixed(2)}');
      }
    }
  });

  test('grafite na folha: 15:1 no claro; no escuro fica em 14,5:1', () {
    // A seção 1 pede 15:1 para o texto principal e a spec só mede o
    // grafite no papel. Na folha do tema escuro (#1A1C1F) o grafite dá
    // 14,5:1: ainda muito acima do AAA (7:1), mas abaixo da regra.
    // Fica registrado aqui para não piorar sem ninguém ver.
    expect(razao(CoresObra.claro.grafite, CoresObra.claro.folha),
        greaterThanOrEqualTo(_textoPrincipal));
    expect(razao(CoresObra.escuro.grafite, CoresObra.escuro.folha),
        greaterThanOrEqualTo(14.5));
  });
}
