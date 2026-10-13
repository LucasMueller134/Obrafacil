import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/itens_parser.dart';
import 'package:obra_facil/services/ia/ocr_nota_service.dart';

/// Linha com caixa de 10 px por caractere e 20 px de altura.
LinhaOcr _l(String texto, double x, double y) =>
    LinhaOcr(texto, x, y, x + texto.length * 10, y + 20);

NotaFiscalExtraida _ler(List<BlocoOcr> blocos,
        {List<CodigoLido> codigos = const []}) =>
    OcrNotaService.interpretar(EntradaOcr(blocos, codigos: codigos));

NotaFiscalExtraida _lerTexto(String texto,
        {List<CodigoLido> codigos = const []}) =>
    OcrNotaService.interpretar(EntradaOcr.deTexto(texto, codigos: codigos));

/// Chaves com DV calculado à parte (ver chave_acesso_test.dart).
/// NFC-e de PE, junho de 2026, CNPJ 11.222.333/0001-81.
const _chaveNfce = '26260611222333000181650010000123451123456787';

/// A mesma loja, em contingência offline (tpEmis 9).
const _chaveOffline = '26260611222333000181650010000123469876543213';

/// DANFE de SP, maio de 2026, CNPJ 33.445.566/0001-86.
const _chaveDanfe = '35260533445566000186550010000007891112233447';

String _emGrupos(String chave) => [
      for (var i = 0; i < 44; i += 4) chave.substring(i, i + 4),
    ].join(' ');

/// NFC-e como o ML Kit devolve: cabeçalho, itens, e o rodapé em duas
/// colunas (rótulos num bloco, valores noutro).
List<BlocoOcr> _nfceDuasColunas({String cnpjImpresso = '11.222.333/0001-81'}) =>
    [
      BlocoOcr([
        _l('CONSTRUMAIS MATERIAIS DE CONSTRUCAO LTDA', 20, 20),
        _l('CNPJ: $cnpjImpresso IE: 0123456-78', 20, 45),
        _l('Av. Norte, 1500 - Encruzilhada', 20, 70),
        _l('Recife - PE', 20, 95),
      ]),
      BlocoOcr([
        _l('CIMENTO CP-II 50KG 10 SC X 32,00 320,00', 20, 140),
        _l('AREIA MEDIA 1 M3 X 60,00 60,00', 20, 165),
      ]),
      BlocoOcr([
        _l('Qtd. total de itens', 20, 200),
        _l('Valor total R\$', 20, 225),
        _l('Desconto R\$', 20, 250),
        _l('Valor a pagar R\$', 20, 275),
        _l('FORMA PAGAMENTO', 20, 300),
        _l('Dinheiro', 20, 325),
        _l('Troco R\$', 20, 350),
      ]),
      BlocoOcr([
        _l('2', 500, 200),
        _l('380,00', 450, 225),
        _l('30,00', 460, 250),
        _l('350,00', 450, 275),
        _l('VALOR PAGO R\$', 370, 300),
        _l('400,00', 450, 325),
        _l('50,00', 460, 350),
      ]),
      BlocoOcr([
        _l('Tributos aproximados R\$ 45,12 (Lei 12.741/2012)', 20, 390),
        _l('Numero 12345 Serie 001 Emissao 15/06/2026 14:32:10', 20, 415),
        _l('Consulte pela Chave de Acesso em', 20, 440),
        _l('www.sefaz.pe.gov.br/nfce', 20, 465),
        _l(_emGrupos(_chaveNfce), 20, 490),
        _l('CONSUMIDOR NAO IDENTIFICADO', 20, 515),
      ]),
    ];

void main() {
  group('Nota em duas colunas (geometria)', () {
    test('rótulo e valor de blocos diferentes voltam a se encontrar', () {
      final nota = _ler(_nfceDuasColunas());
      expect(nota.valorTotal, 350.00);
      expect(nota.fornecedorNome, 'Construmais Materiais de Construcao Ltda');
      expect(nota.cnpj, '11.222.333/0001-81');
      expect(nota.data, DateTime(2026, 6, 15));
      expect(nota.chaveAcesso, _chaveNfce);
    });

    test('o texto reconstruído vai junto, linha a linha como no papel', () {
      final nota = _ler(_nfceDuasColunas());
      expect(nota.textoReconstruido, contains('Valor a pagar R\$ 350,00'));
      expect(nota.textoReconstruido, contains('Troco R\$ 50,00'));
      // o texto original continua sendo o que o OCR leu, na ordem dele
      expect(nota.textoCompleto, contains('Valor a pagar R\$\nFORMA'));
    });

    test('itens saem certos do reconstruído (nome e preço em colunas)', () {
      // A tela tira os itens do texto reconstruído: no corrido, a
      // quantidade do cimento fica embaixo do nome da areia.
      final nota = _ler([
        BlocoOcr([
          _l('CIMENTO CP-II 50KG', 20, 140),
          _l('AREIA MEDIA', 20, 165),
        ]),
        BlocoOcr([
          _l('10 SC X 32,00 320,00', 300, 140),
          _l('1 M3 X 60,00 60,00', 300, 165),
        ]),
      ]);
      final itens = ItensParser.deNotaOcr(nota.textoReconstruido!);
      expect(itens.map((i) => (i.material, i.quantidade, i.unidade)), [
        ('Cimento', 10, 'sc'),
        ('Areia', 1, 'm³'),
      ]);
      final doCorrido = ItensParser.deNotaOcr(nota.textoCompleto);
      expect(doCorrido.map((i) => (i.material, i.quantidade)),
          isNot(contains(('Cimento', 10))));
    });

    test('sem geometria, contagem solta na linha de baixo não é o total', () {
      // corrido de duas colunas: o "5" da quantidade de itens cai logo
      // depois do rótulo "Valor a pagar"
      expect(
          _lerTexto('Qtd. total de itens\nValor a pagar R\$\n5\n350,00')
              .valorTotal,
          350.00);
    });

    test('sem geometria, o texto corrido é lido como antes', () {
      final entrada = EntradaOcr(_nfceDuasColunas());
      final semGeometria = OcrNotaService.parsearTexto(entrada.texto);
      expect(semGeometria.textoReconstruido, isNull);
      expect(semGeometria.fornecedorNome,
          'Construmais Materiais de Construcao Ltda');
      expect(semGeometria.cnpj, '11.222.333/0001-81');
    });

    test('DANFE: o valor está embaixo do rótulo, na mesma célula', () {
      final nota = _ler([
        BlocoOcr([_l('BASE DE CALC. DO ICMS', 20, 600)]),
        BlocoOcr([_l('0,00', 20, 625)]),
        BlocoOcr([_l('VALOR DO ICMS', 260, 600)]),
        BlocoOcr([_l('0,00', 260, 625)]),
        BlocoOcr([_l('V. TOTAL PRODUTOS', 700, 600)]),
        BlocoOcr([_l('350,00', 700, 625)]),
        BlocoOcr([
          _l('VALOR DO FRETE', 20, 650),
          _l('30,00', 20, 675),
        ]),
        BlocoOcr([
          _l('VALOR DO SEGURO', 260, 650),
          _l('0,00', 260, 675),
        ]),
        BlocoOcr([
          _l('DESCONTO', 450, 650),
          _l('0,00', 450, 675),
        ]),
        BlocoOcr([
          _l('VALOR TOTAL DA NOTA', 700, 650),
          _l('380,00', 700, 675),
        ]),
      ]);
      expect(nota.valorTotal, 380.00);
    });

    test('DANFE: valor da célula vizinha não é atribuído ao rótulo', () {
      // "VALOR TOTAL DA NOTA" sem número embaixo (o OCR não leu): o
      // número da célula do lado é do frete, não do total
      final nota = _ler([
        BlocoOcr([
          _l('VALOR DO FRETE', 20, 650),
          _l('VALOR TOTAL DA NOTA', 300, 650),
        ]),
        BlocoOcr([_l('30,00', 20, 675)]),
      ]);
      expect(nota.valorTotal, isNull);
    });

    test('o número da linha de baixo, de outro rótulo, não é o total', () {
      // O OCR perdeu o valor ao lado de "Valor a pagar". No texto corrido
      // o "5,00" do troco fica logo depois do rótulo; remontado, ele está
      // na linha do troco e é dele.
      final nota = _ler([
        BlocoOcr([
          _l('Valor total R\$', 20, 75),
          _l('Valor a pagar R\$', 20, 100),
          _l('Troco R\$', 20, 125),
        ]),
        BlocoOcr([
          _l('380,00', 450, 75),
          _l('5,00', 470, 125),
        ]),
      ]);
      expect(nota.valorTotal, isNot(5.00));
    });
  });

  group('Total: hierarquia dos rótulos', () {
    test('"valor a pagar" (com desconto) vence "valor total"', () {
      expect(
          _lerTexto('VALOR TOTAL R\$ 380,00\nDESCONTO R\$ 30,00\n'
                  'VALOR A PAGAR R\$ 350,00')
              .valorTotal,
          350.00);
      expect(_lerTexto('TOTAL A PAGAR 350,00\nSUBTOTAL 380,00').valorTotal,
          350.00);
    });

    test('DANFE: "valor total da nota" (com frete) vence o dos produtos', () {
      expect(
          _lerTexto('VALOR TOTAL DOS PRODUTOS 350,00\nVALOR DO FRETE 30,00\n'
                  'VALOR TOTAL DA NOTA 380,00')
              .valorTotal,
          380.00);
      expect(
          _lerTexto('V. TOTAL PRODUTOS 350,00\nV. TOTAL DA NOTA 380,00')
              .valorTotal,
          380.00);
    });

    test('rótulo abreviado com ponto ("VL. A PAGAR") mantém o nível', () {
      expect(
          _lerTexto('VL. TOTAL 380,00\nVL. A PAGAR 350,00').valorTotal, 350.00);
      expect(
          _lerTexto('VLR. TOTAL DOS PRODUTOS 350,00\nTOTAL 380,00').valorTotal,
          380.00);
    });

    test('fileira de campos do DANFE sem geometria: o k-ésimo valor', () {
      // o OCR leu a fileira de rótulos numa linha e a de valores noutra
      expect(
          _lerTexto('VALOR DO FRETE VALOR DO SEGURO DESCONTO OUTRAS DESPESAS '
                  'VALOR TOTAL DO IPI V. TOTAL DA NOTA\n'
                  '30,00 0,00 0,00 0,00 0,00 380,00')
              .valorTotal,
          380.00);
      // faltou um número e o total está no meio da fileira: sem como
      // alinhar, fica vazio em vez de pegar o valor do vizinho
      expect(
          _lerTexto('VALOR DO FRETE VALOR TOTAL DA NOTA VALOR DO SEGURO\n'
                  '30,00 0,00')
              .valorTotal,
          isNull);
    });

    test('"total dos produtos" e "subtotal" só valem sem total melhor', () {
      expect(_lerTexto('V. TOTAL PRODUTOS 350,00').valorTotal, 350.00);
      expect(_lerTexto('TOTAL DOS PRODUTOS 350,00\nTOTAL 330,00').valorTotal,
          330.00);
    });

    test('tributos aproximados nunca são o total', () {
      expect(
          _lerTexto('VALOR TOTAL 120,00\nVALOR TRIBUTOS R\$ 25,30').valorTotal,
          120.00);
      expect(
          _lerTexto('Tributos aproximados R\$ 125,30\nTOTAL R\$ 120,00')
              .valorTotal,
          120.00);
      expect(
          _lerTexto('Total aproximado de tributos R\$ 999,00\nTOTAL 120,00')
              .valorTotal,
          120.00);
      // sem rótulo de total, o maior número não pode ser o do imposto
      expect(
          _lerTexto('CIMENTO 32,00\nVal Aprox Tributos R\$ 99,00').valorTotal,
          32.00);
    });

    test('troco, desconto e total de itens sozinhos não viram total', () {
      expect(_lerTexto('TROCO R\$ 50,00').valorTotal, isNull);
      expect(_lerTexto('DESCONTO R\$ 30,00').valorTotal, isNull);
      expect(_lerTexto('TOTAL DE ITENS 5').valorTotal, isNull);
    });

    test('"total" do pagamento ou do desconto não é o da compra', () {
      // o pago inclui o troco; o de desconto é o que foi abatido
      expect(
          _lerTexto('SUBTOTAL 350,00\nTOTAL PAGO R\$ 400,00\nTROCO R\$ 50,00')
              .valorTotal,
          350.00);
      expect(_lerTexto('SUBTOTAL 380,00\nTOTAL DESCONTOS R\$ 30,00').valorTotal,
          380.00);
      // "com desconto" é o total já abatido
      expect(_lerTexto('TOTAL COM DESCONTO R\$ 350,00').valorTotal, 350.00);
      // e "sem desconto" ainda não é o cobrado
      expect(
          _lerTexto('TOTAL SEM DESCONTO R\$ 380,00\nTOTAL R\$ 350,00')
              .valorTotal,
          350.00);
      // abreviado, o imposto aproximado continua sendo imposto
      expect(
          _lerTexto('Trib aprox R\$ 99,00\nCIMENTO 32,00').valorTotal, 32.00);
    });
  });

  group('Total: leitura do número', () {
    test('vírgula decimal lida como ponto, mesmo com milhar', () {
      expect(_lerTexto('VALOR A PAGAR 1.250.00').valorTotal, 1250.00);
      expect(_lerTexto('TOTAL R\$ 1,250.00').valorTotal, 1250.00);
      expect(_lerTexto('TOTAL R\$ 1,250,00').valorTotal, 1250.00);
      expect(_lerTexto('TOTAL 12.50').valorTotal, 12.50);
    });

    test('letra no lugar de dígito no valor', () {
      expect(_lerTexto('VALOR A PAGAR R\$ S17,80').valorTotal, 517.80);
      expect(_lerTexto('TOTAL R\$ 35O.OO').valorTotal, 350.00);
      expect(_lerTexto('TOTAL R\$ 1.O5O,OO').valorTotal, 1050.00);
    });

    test('data e hora não viram valor', () {
      expect(_lerTexto('TOTAL\n15.06.26 14:32').valorTotal, isNull);
    });
  });

  group('Chave de acesso na nota', () {
    test('do QR da NFC-e (emissão online)', () {
      final nota = _lerTexto('CONSTRUMAIS LTDA\nTOTAL 350,00', codigos: [
        const CodigoLido('qr',
            'https://nfce.sefaz.pe.gov.br/nfce?p=$_chaveNfce|2|1|1|abcdef'),
      ]);
      expect(nota.chaveAcesso, _chaveNfce);
      expect(nota.cnpj, '11.222.333/0001-81');
      expect(nota.cnpjDaChave, isTrue);
    });

    test('do QR offline: dia e valor completam a nota', () {
      final nota = _lerTexto('CONSTRUMAIS LTDA', codigos: [
        const CodigoLido(
            'qr',
            'https://nfce.sefaz.pe.gov.br/nfce?p=$_chaveOffline|2|1|15|350.00|'
                'ab12|1|cd34'),
      ]);
      expect(nota.data, DateTime(2026, 6, 15));
      expect(nota.valorTotal, 350.00);
    });

    test('do código de barras do DANFE', () {
      final nota = _lerTexto('DANFE\nVALOR TOTAL DA NOTA 380,00',
          codigos: [const CodigoLido('code128', _chaveDanfe)]);
      expect(nota.chaveAcesso, _chaveDanfe);
      expect(nota.cnpj, '33.445.566/0001-86');
    });

    test('do texto, em grupos de 4', () {
      final nota = _lerTexto('CHAVE DE ACESSO\n${_emGrupos(_chaveDanfe)}');
      expect(nota.chaveAcesso, _chaveDanfe);
    });

    test('código de outra coisa (EAN, site) não vira chave', () {
      final nota = _lerTexto('TOTAL 10,00', codigos: const [
        CodigoLido('code128', '7891234567895'),
        CodigoLido('qr', 'https://www.loja.com.br/?p=promo'),
      ]);
      expect(nota.chaveAcesso, isNull);
      expect(nota.cnpj, isNull);
    });
  });

  group('CNPJ do emitente', () {
    test('o da chave vence o lido no texto com um dígito errado', () {
      final nota = _ler(_nfceDuasColunas(cnpjImpresso: '11.222.338/0001-81'));
      expect(nota.cnpj, '11.222.333/0001-81');
      expect(nota.cnpjDaChave, isTrue);
    });

    test('o da chave vence outro CNPJ válido do texto', () {
      final nota = _lerTexto('LOJA X\nCNPJ 33.445.566/0001-86\n'
          'CHAVE DE ACESSO ${_emGrupos(_chaveNfce)}');
      expect(nota.cnpj, '11.222.333/0001-81');
    });

    test('CNPJ inválido nunca vence um válido', () {
      final nota = _lerTexto('DEPOSITO CENTRAL LTDA\n'
          'CNPJ 12.345.678/0001-90\n'
          'Desenvolvido por Automa Sistemas CNPJ 04.567.890/0001-79');
      expect(nota.cnpj, '04.567.890/0001-79');
    });

    test('vários válidos: o do topo, não o de destinatário ou software', () {
      final nota = _lerTexto('DEPOSITO CENTRAL LTDA\n'
          'CNPJ 11.222.333/0001-81\n'
          'TOTAL 50,00\n'
          'CONSUMIDOR CNPJ 33.445.566/0001-86\n'
          'Software: Automa Sistemas 04.567.890/0001-79');
      expect(nota.cnpj, '11.222.333/0001-81');
    });

    test('seção do destinatário antes do emitente lido não toma o lugar', () {
      final nota = _lerTexto('DESTINATARIO / REMETENTE\n'
          'CNPJ 33.445.566/0001-86\n'
          'EMITENTE CNPJ 11.222.333/0001-81');
      // o do destinatário é de terceiro: o do emitente vem primeiro
      expect(nota.cnpj, '11.222.333/0001-81');
    });

    test('CNPJ com letra no lugar de dígito é corrigido', () {
      expect(_lerTexto('CNPJ: 11.222.333/OOO1-81').cnpj, '11.222.333/0001-81');
    });
  });

  group('Data de emissão', () {
    test('com chave, a data tem de cair no mês dela', () {
      final nota = _lerTexto('EMISSAO 15/05/2026 14:32\n'
          'Protocolo 15/06/2026\n'
          'CHAVE DE ACESSO ${_emGrupos(_chaveNfce)}');
      expect(nota.data, DateTime(2026, 6, 15));
    });

    test('com chave e nenhuma data do mês dela, fica vazia', () {
      final nota =
          _lerTexto('EMISSAO 15/05/2026\nCHAVE ${_emGrupos(_chaveNfce)}');
      expect(nota.data, isNull);
    });

    test('O no lugar de 0 na data', () {
      expect(_lerTexto('EMISSAO 27/O6/2026').data, DateTime(2026, 6, 27));
      expect(_lerTexto('DATA 2O/O6/2O26 10:15').data, DateTime(2026, 6, 20));
    });

    test('hora logo depois da data, com traço ou "às", marca a emissão', () {
      expect(_lerTexto('28/05/2026\n15/06/2026 - 14:32').data,
          DateTime(2026, 6, 15));
      expect(_lerTexto('28/05/2026\n15/06/26 às 14h32').data,
          DateTime(2026, 6, 15));
    });

    test('data do protocolo de autorização só serve se não houver outra', () {
      expect(
          _lerTexto('Protocolo de autorizacao 126260000123456 16/06/2026 '
                  '08:00:00\n15/06/2026 14:32:10')
              .data,
          DateTime(2026, 6, 15));
      expect(
          _lerTexto('Protocolo de autorizacao 126260000123456 16/06/2026').data,
          DateTime(2026, 6, 16));
    });

    test('vencimento com hora continua não sendo emissão', () {
      expect(_lerTexto('VENCIMENTO 15/07/2026 10:00').data, isNull);
    });

    test('emissão vence vencimento, entrega e impressão', () {
      expect(
          _lerTexto('DATA DE ENTREGA: 20/06/2026\nDATA DE EMISSAO: 15/06/2026')
              .data,
          DateTime(2026, 6, 15));
      expect(_lerTexto('Impresso em 16/06/2026 10:00\nEmissao 15/06/2026').data,
          DateTime(2026, 6, 15));
      expect(_lerTexto('EMISSAO: 15/06/2026 VENCIMENTO: 15/07/2026').data,
          DateTime(2026, 6, 15));
    });

    test('DANFE: data embaixo do rótulo, na célula da emissão', () {
      final nota = _ler([
        BlocoOcr([
          _l('DATA DA EMISSAO', 600, 300),
          _l('15/06/2026', 600, 325),
        ]),
        BlocoOcr([
          _l('DATA DA SAIDA/ENTRADA', 800, 300),
          _l('18/06/2026', 800, 325),
        ]),
      ]);
      expect(nota.data, DateTime(2026, 6, 15));
    });
  });

  group('Fornecedor', () {
    test('cidade e UF não viram fornecedor', () {
      const texto = '''
Jose Souza
Recife - Pe
CNPJ 11.222.333/0001-81
TOTAL 50,00
''';
      expect(OcrNotaService.parsearTexto(texto).fornecedorNome, 'Jose Souza');
      expect(
          OcrNotaService.parsearTexto('Recife - Pe\nCNPJ 11.222.333/0001-81')
              .fornecedorNome,
          isNull);
    });

    test('cabeçalho de tabela e número de pedido não viram fornecedor', () {
      const texto = '''
PEDIDO 0123
QUANT. DISCRIMINACAO VALOR
10 sacos cimento 350,00
TOTAL 350,00
''';
      expect(OcrNotaService.parsearTexto(texto).fornecedorNome, isNull);
    });

    test('nome de loja com palavra de endereço no meio continua valendo', () {
      expect(
          OcrNotaService.parsearTexto('CIDADE DAS TINTAS LTDA\nTOTAL 80,00')
              .fornecedorNome,
          'Cidade das Tintas Ltda');
    });

    test('nota manuscrita ilegível fica sem fornecedor', () {
      const texto = '''
1Om ar3ia
cmnt 5sc
Tot 280
''';
      expect(OcrNotaService.parsearTexto(texto).fornecedorNome, isNull);
    });

    test('canhoto do DANFE dá o nome do emitente', () {
      const texto = 'RECEBEMOS DE CONSTRUMAIS MATERIAIS LTDA OS PRODUTOS '
          'CONSTANTES DA NOTA FISCAL INDICADA AO LADO\nNF-e N 000.000.789';
      expect(OcrNotaService.parsearTexto(texto).fornecedorNome,
          'Construmais Materiais Ltda');
    });
  });

  group('Mescla dos passes de imagem', () {
    test('a chave de um passe corrige o CNPJ e a data do outro', () {
      final primeiro = _lerTexto('CONSTRUMAIS LTDA\nCNPJ 33.445.566/0001-86\n'
          'EMISSAO 15/05/2026\nTOTAL 350,00');
      final segundo = _lerTexto('EMISSAO 15/06/2026\n'
          'CHAVE DE ACESSO ${_emGrupos(_chaveNfce)}');
      final nota = primeiro.mesclar(segundo);
      expect(nota.cnpj, '11.222.333/0001-81');
      expect(nota.data, DateTime(2026, 6, 15));
      expect(nota.fornecedorNome, 'Construmais Ltda');
      expect(nota.valorTotal, 350.00);
      expect(nota.passes, 2);
    });

    test('CNPJ válido de um passe vence o inválido do outro', () {
      final nota = _lerTexto('CNPJ 11.222.333/0001-87')
          .mesclar(_lerTexto('CNPJ 11.222.333/0001-81'));
      expect(nota.cnpj, '11.222.333/0001-81');
    });
  });

  group('Aviso depois da leitura', () {
    test('diz quando o CNPJ veio da chave de acesso', () {
      final nota = _ler(_nfceDuasColunas(cnpjImpresso: '11.222.338/0001-81'));
      expect(OcrNotaService.avisoDaLeitura(nota),
          contains('CNPJ 11.222.333/0001-81 conferido pela chave de acesso'));
    });

    test('sem chave, não promete conferência', () {
      final nota = _lerTexto('DEPOSITO CENTRAL LTDA\n'
          'CNPJ 11.222.333/0001-81\nTOTAL 50,00');
      expect(OcrNotaService.avisoDaLeitura(nota), isNot(contains('chave')));
      expect(OcrNotaService.avisoDaLeitura(nota), contains('confira'));
    });

    test('nada lido: orienta a tirar outra foto', () {
      final nota = _lerTexto('a1 b2');
      expect(OcrNotaService.avisoDaLeitura(nota), contains('Não consegui ler'));
    });
  });

  group('Mensagem de erro para o usuário', () {
    test('cada falha tem uma explicação, sem o texto técnico', () {
      final erros = <Object>[
        TimeoutException('processImage', const Duration(seconds: 20)),
        MissingPluginException('No implementation found'),
        const FileSystemException('Cannot open file', '/tmp/x.jpg'),
        PlatformException(code: 'InputImageConverterError'),
        StateError('Bad state: recognizer closed'),
      ];
      for (final e in erros) {
        final msg = OcrNotaService.mensagemDeErro(e);
        expect(msg, isNot(contains('Exception')), reason: '$e');
        expect(msg, isNot(contains('Error')), reason: '$e');
        expect(msg, isNot(contains('/tmp')), reason: '$e');
        expect(msg, contains('mão'), reason: '$e');
      }
    });
  });
}
