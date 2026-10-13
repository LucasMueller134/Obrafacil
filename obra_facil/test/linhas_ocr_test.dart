import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/linhas_ocr.dart';

/// Linha com caixa de 10 px por caractere e 20 px de altura.
LinhaOcr _l(String texto, double x, double y, {double altura = 20}) =>
    LinhaOcr(texto, x, y, x + texto.length * 10, y + altura);

/// Rodapé de NFC-e em duas colunas: o ML Kit devolve os rótulos num bloco
/// e os valores noutro.
final _rotulos = BlocoOcr([
  _l('Qtd. total de itens', 20, 200),
  _l('Valor total R\$', 20, 225),
  _l('Desconto R\$', 20, 250),
  _l('Valor a pagar R\$', 20, 275),
]);
final _valores = BlocoOcr([
  _l('2', 420, 201),
  _l('380,00', 400, 226),
  _l('30,00', 410, 249),
  _l('350,00', 400, 274),
]);

void main() {
  group('Entrada do OCR', () {
    test('texto corrido igual ao do ML Kit: linhas e blocos por quebra', () {
      final entrada = EntradaOcr([_rotulos, _valores]);
      expect(
          entrada.texto,
          'Qtd. total de itens\nValor total R\$\nDesconto R\$\n'
          'Valor a pagar R\$\n2\n380,00\n30,00\n350,00');
      expect(entrada.temGeometria, isTrue);
    });

    test('texto sem geometria não é remontado', () {
      final entrada = EntradaOcr.deTexto('TOTAL 10,00');
      expect(entrada.texto, 'TOTAL 10,00');
      expect(entrada.blocos, isEmpty);
      expect(entrada.temGeometria, isFalse);
      expect(entrada.textoReconstruido, isNull);
    });

    test('linha sem caixa desliga a remontagem (não mistura as duas ordens)',
        () {
      final entrada = EntradaOcr([
        _rotulos,
        const BlocoOcr([LinhaOcr('350,00', 0, 0, 0, 0)]),
      ]);
      expect(entrada.temGeometria, isFalse);
      expect(entrada.textoReconstruido, isNull);
    });

    test('guarda os códigos lidos junto com o texto', () {
      final entrada = EntradaOcr([_rotulos],
          codigos: const [CodigoLido('qr', 'https://nfce?p=1')]);
      expect(entrada.codigos.single.formato, 'qr');
    });
  });

  group('Linhas visuais (remontagem pela posição)', () {
    test('nota em duas colunas: rótulo e valor voltam para a mesma linha', () {
      final entrada = EntradaOcr([_rotulos, _valores]);
      expect(entrada.textoReconstruido!.split('\n'), [
        'Qtd. total de itens 2',
        'Valor total R\$ 380,00',
        'Desconto R\$ 30,00',
        'Valor a pagar R\$ 350,00',
      ]);
    });

    test('ordena da esquerda para a direita, qualquer que seja o bloco', () {
      final linhas = reconstruirLinhas([
        _l('350,00', 400, 100),
        _l('TOTAL', 20, 100),
        _l('R\$', 200, 102),
      ]);
      expect(linhas.single.texto, 'TOTAL R\$ 350,00');
    });

    test('linhas vizinhas da mesma coluna não se juntam', () {
      // caixas que se encostam (a de baixo invade 4 px a de cima)
      final linhas = reconstruirLinhas([
        _l('CIMENTO CP-II', 20, 100),
        _l('AREIA MEDIA', 20, 116),
      ]);
      expect(linhas.map((l) => l.texto), ['CIMENTO CP-II', 'AREIA MEDIA']);
    });

    test('fonte maior no valor ainda fica na linha do rótulo', () {
      final linhas = reconstruirLinhas([
        _l('VALOR A PAGAR', 20, 300),
        _l('350,00', 400, 292, altura: 34),
        _l('Troco', 20, 340),
      ]);
      expect(linhas.map((l) => l.texto), ['VALOR A PAGAR 350,00', 'Troco']);
    });

    test('de cima para baixo pela posição, não pela ordem dos blocos', () {
      final linhas = reconstruirLinhas([
        _l('RODAPE', 20, 500),
        _l('TOPO', 20, 10),
      ]);
      expect(linhas.map((l) => l.texto), ['TOPO', 'RODAPE']);
    });
  });

  group('Foto inclinada', () {
    /// Cantos de uma linha girada [graus] em torno da origem — como o ML
    /// Kit descreve a linha de uma foto tirada com o celular torto.
    LinhaComCantos girada(String texto, double x, double y, double graus) {
      final a = graus * math.pi / 180;
      math.Point<num> p(double px, double py) => math.Point(
          px * math.cos(a) - py * math.sin(a),
          px * math.sin(a) + py * math.cos(a));
      final largura = texto.length * 10.0;
      return (
        texto,
        [
          p(x, y),
          p(x + largura, y),
          p(x + largura, y + 20),
          p(x, y + 20),
        ],
      );
    }

    List<List<LinhaComCantos>> rodape(double graus) => [
          [
            girada('Valor total R\$', 20, 225, graus),
            girada('Desconto R\$', 20, 250, graus),
            girada('Valor a pagar R\$', 20, 275, graus),
          ],
          [
            girada('380,00', 700, 225, graus),
            girada('30,00', 710, 250, graus),
            girada('350,00', 700, 275, graus),
          ],
        ];

    test('sem endireitar, 3° de inclinação separa rótulo e valor', () {
      // na foto, o valor 680 px à direita desce ~36 px: outra linha
      final blocos = [
        for (final b in rodape(3))
          BlocoOcr([
            for (final (t, c) in b)
              LinhaOcr(
                  t,
                  c.map((p) => p.x).reduce(math.min).toDouble(),
                  c.map((p) => p.y).reduce(math.min).toDouble(),
                  c.map((p) => p.x).reduce(math.max).toDouble(),
                  c.map((p) => p.y).reduce(math.max).toDouble()),
          ]),
      ];
      final linhas = EntradaOcr(blocos).textoReconstruido!.split('\n');
      expect(linhas, isNot(contains('Valor a pagar R\$ 350,00')));
    });

    test('endireitada, cada rótulo volta a ter o seu valor', () {
      for (final graus in [3.0, -4.0, 8.0]) {
        final entrada = EntradaOcr(blocosEndireitados(rodape(graus)));
        expect(
            entrada.textoReconstruido!.split('\n'),
            [
              'Valor total R\$ 380,00',
              'Desconto R\$ 30,00',
              'Valor a pagar R\$ 350,00',
            ],
            reason: '$graus°');
      }
    });

    test('foto deitada ou de cabeça para baixo que o ML Kit leu', () {
      // sem girar, as caixas retas de linhas em pé se sobrepõem todas na
      // vertical e a nota viraria uma linha só
      for (final graus in [90.0, -90.0, 180.0]) {
        final entrada = EntradaOcr(blocosEndireitados(rodape(graus)));
        expect(
            entrada.textoReconstruido!.split('\n'),
            [
              'Valor total R\$ 380,00',
              'Desconto R\$ 30,00',
              'Valor a pagar R\$ 350,00',
            ],
            reason: '$graus°');
      }
    });

    test('linhas em direções que não concordam: não gira', () {
      final blocos = blocosEndireitados([
        [
          girada('Valor total R\$', 20, 225, 0),
          girada('Desconto R\$', 20, 250, 0),
        ],
        [
          girada('CUPOM FISCAL ELETRONICO', 900, 0, 90),
          girada('VIA DO CONSUMIDOR XYZ', 950, 0, 90),
        ],
      ]);
      final primeira = blocos.first.linhas.first;
      expect(primeira.esquerda, closeTo(20, 0.001));
      expect(primeira.topo, closeTo(225, 0.001));
    });

    test('foto reta não muda de posição', () {
      final blocos = blocosEndireitados(rodape(0));
      final primeira = blocos.first.linhas.first;
      expect(primeira.esquerda, closeTo(20, 0.001));
      expect(primeira.topo, closeTo(225, 0.001));
      expect(primeira.direita, closeTo(160, 0.001));
      expect(primeira.base, closeTo(245, 0.001));
    });

    test('linha sem cantos fica sem caixa (sem remontagem)', () {
      final blocos = blocosEndireitados([
        [('TOTAL 10,00', const <math.Point<num>>[])],
      ]);
      expect(EntradaOcr(blocos).temGeometria, isFalse);
    });
  });
}
