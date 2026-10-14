import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obra_facil/services/ia/ocr_nota_service.dart';

/// Linha com caixa de 10 px por caractere e 20 px de altura.
LinhaOcr _l(String texto, double x, double y) =>
    LinhaOcr(texto, x, y, x + texto.length * 10, y + 20);

double? _total(String texto) => OcrNotaService.parsearTexto(texto).valorTotal;

/// Casos achados pela revisão adversarial do OCR da nota: cada um falhava
/// antes da correção e trava a regressão daquela classe de erro.
void main() {
  group('Revisão: contagem de itens na linha do total não vira o total', () {
    test('"TOTAL (3 ITENS) R\$ 350,00" é 350, não 3', () {
      expect(
          _total('DEPOSITO BOA OBRA LTDA\nTOTAL (3 ITENS) R\$ 350,00'), 350.00);
    });
    test('as outras grafias do pedido e do cupom não fiscal', () {
      for (final linha in [
        'TOTAL 3 ITENS R\$ 350,00',
        'VALOR TOTAL (2 ITENS): 350,00',
        'TOTAL DE 3 ITENS R\$ 350,00',
        'TOTAL: 3 ITENS 350,00',
        'TOTAL (2 itens) R\$ 350,00',
        'TOTAL 3ITENS R\$ 350,00',
      ]) {
        expect(_total('DEPOSITO BOA OBRA LTDA\n$linha'), 350.00, reason: linha);
      }
    });
    test('total sem centavos depois da contagem também', () {
      expect(_total('DEPOSITO BOA OBRA LTDA\nTOTAL 3 ITENS R\$ 350'), 350);
      expect(_total('DEPOSITO BOA OBRA LTDA\nTOTAL: 3 ITENS 350'), 350);
    });
    test('contagem com o valor na linha de baixo', () {
      expect(_total('DEPOSITO BOA OBRA LTDA\nTOTAL (3 ITENS)\nR\$ 350,00'),
          350.00);
    });
    test('subtotal com contagem não toma o lugar do total', () {
      expect(
          _total('DEPOSITO BOA OBRA LTDA\nSUBTOTAL (2 itens) 380,00\n'
              'Desconto 30,00\nTOTAL 350,00'),
          350.00);
    });
    test('com geometria: contagem e valor em blocos lado a lado', () {
      final nota = OcrNotaService.interpretar(EntradaOcr([
        BlocoOcr([
          _l('DEPOSITO BOA OBRA LTDA', 20, 20),
          _l('CNPJ 11.222.333/0001-81', 20, 45),
        ]),
        BlocoOcr([
          _l('CIMENTO CP II 50KG 10 SC X 32,00 320,00', 20, 100),
          _l('AREIA MEDIA 1 M3 X 30,00 30,00', 20, 125),
        ]),
        BlocoOcr([_l('TOTAL (3 ITENS)', 20, 175)]),
        BlocoOcr([_l('R\$ 350,00', 400, 175)]),
      ]));
      expect(nota.valorTotal, 350.00);
    });
    test('"total de itens" continua sendo contagem', () {
      expect(_total('TOTAL DE ITENS 5'), isNull);
      expect(_total('ITENS: 3\nTOTAL R\$ 350,00'), 350.00);
      expect(_total('QTD TOTAL 3 ITENS\nTOTAL R\$ 350,00'), 350.00);
    });
  });

  group('Revisão: o rótulo da célula vizinha não desqualifica o total', () {
    // Rótulos do quadro "CÁLCULO DO IMPOSTO" do DANFE com a grafia do
    // Manual, que o ML Kit lê como uma linha só quando as células ficam
    // próximas.
    const rotulos1 = 'BASE DE CALCULO DO ICMS VALOR DO ICMS '
        'BASE DE CALCULO DO ICMS ST VALOR DO ICMS ST VALOR TOTAL DOS PRODUTOS';
    const valores1 = '0,00 0,00 0,00 0,00 350,00';
    const rotulos2 = 'VALOR DO FRETE VALOR DO SEGURO DESCONTO OUTRAS DESPESAS '
        'VALOR TOTAL DO IPI VALOR TOTAL DA NOTA';
    const valores2 = '30,00 0,00 0,00 0,00 0,00 380,00';

    test('DANFE sem geometria: "VALOR TOTAL DA NOTA" depois do IPI', () {
      expect(
          _total('CASA DO CONSTRUTOR LTDA\n'
              '001 CIMENTO CP II 50KG 10 SC 32,00 320,00\n'
              '002 AREIA MEDIA 1 M3 30,00 30,00\n'
              '$rotulos1\n$valores1\n$rotulos2\n$valores2'),
          380.00);
    });
    test('DANFE sem geometria: o dos produtos depois do ICMS ST', () {
      expect(
          _total('CASA DO CONSTRUTOR LTDA\n'
              '001 CIMENTO CP II 50KG 10 SC 32,00 320,00\n'
              '$rotulos1\n$valores1'),
          350.00);
    });
    test('DANFE com geometria: IPI e total da nota na mesma linha do OCR', () {
      final nota = OcrNotaService.interpretar(EntradaOcr([
        BlocoOcr([_l('CASA DO CONSTRUTOR LTDA', 20, 20)]),
        BlocoOcr([
          _l('001 CIMENTO CP II 50KG 10 SC 32,00 320,00', 20, 300),
          _l('002 AREIA MEDIA 1 M3 30,00 30,00', 20, 325),
        ]),
        BlocoOcr([
          _l('VALOR DO FRETE', 20, 650),
          _l('VALOR DO SEGURO', 200, 650),
          _l('VALOR TOTAL DO IPI VALOR TOTAL DA NOTA', 400, 650),
        ]),
        BlocoOcr([
          _l('30,00', 20, 675),
          _l('0,00', 200, 675),
          _l('0,00', 400, 675),
          _l('380,00', 600, 675),
        ]),
      ]));
      expect(nota.valorTotal, 380.00);
    });
    test('frete antes e tributos aproximados depois do total da nota', () {
      expect(
          _total('CASA DO CONSTRUTOR LTDA\n'
              'VALOR DO FRETE VALOR TOTAL DA NOTA\n30,00 380,00'),
          380.00);
      expect(
          _total('CASA DO CONSTRUTOR LTDA\n'
              '001 CIMENTO CP II 50KG 10 SC 32,00 320,00\n'
              'VALOR TOTAL DA NOTA VALOR APROX TRIBUTOS\n380,00 45,00'),
          380.00);
    });
    test('desconto ou frete abreviado na célula ao lado', () {
      expect(_total('VALOR TOTAL DESCONTO VALOR A PAGAR\n380,00 30,00 350,00'),
          350.00);
      expect(_total('FRETE VALOR TOTAL DA NOTA\n30,00 380,00'), 380.00);
    });
    test('qualificador colado ao "TOTAL" continua valendo', () {
      expect(_total('DESCONTO TOTAL R\$ 30,00\nTOTAL R\$ 350,00'), 350.00);
      expect(
          _total('VALOR DO FRETE TOTAL R\$ 30,00\nTOTAL R\$ 350,00'), 350.00);
      expect(_total('TOTAL DESCONTOS R\$ 30,00\nVALOR A PAGAR R\$ 350,00'),
          350.00);
      expect(_total('TOTAL DO IPI R\$ 12,00\nTOTAL R\$ 350,00'), 350.00);
    });
    test('quantidade ao lado de "VALOR TOTAL" é a coluna dos itens', () {
      expect(_total('QTD VALOR TOTAL\n10 320,00\nTOTAL R\$ 350,00'), 350.00);
    });
  });

  group('Revisão: o aviso só fala em recuperar quando a variante trouxe algo',
      () {
    // A foto pegou só a parte de baixo do cupom: total e data lidos, sem
    // fornecedor — a leitura tenta o realce e a binarização.
    const rodape = 'Valor total R\$ 380,00\nDesconto R\$ 30,00\n'
        'Valor a pagar R\$ 350,00\nEmissao 15/06/2026 14:32:10';

    test('variantes que leem o mesmo texto não contam como passe', () {
      final original = OcrNotaService.parsearTexto(rodape);
      expect(original.completa, isFalse);
      final nota = original
          .mesclar(OcrNotaService.parsearTexto(rodape))
          .mesclar(OcrNotaService.parsearTexto(rodape));
      expect(nota.passes, 1);
      expect(OcrNotaService.avisoDaLeitura(nota), isNot(contains('recuperei')));
      expect(OcrNotaService.avisoDaLeitura(nota), contains('confira'));
    });
    test('a variante que trouxe o fornecedor conta', () {
      final nota = OcrNotaService.parsearTexto(rodape)
          .mesclar(OcrNotaService.parsearTexto('DEPOSITO CENTRAL LTDA\n'
              'CNPJ 11.222.333/0001-81\n$rodape'));
      expect(nota.fornecedorNome, 'Deposito Central Ltda');
      expect(nota.passes, 2);
      expect(OcrNotaService.avisoDaLeitura(nota), contains('recuperei'));
    });
  });

  group('Revisão: CNPJ de terceiro nunca vira o do fornecedor', () {
    // O da loja com um dígito trocado pelo OCR (não fecha o DV): sem
    // CNPJ válido do emitente, fica o lido, como em qualquer nota.
    const lidoDaLoja = '12.345.678/0001-90';

    test('o do cliente do pedido, mesmo válido, não toma o lugar', () {
      final nota = OcrNotaService.parsearTexto('DEPOSITO CENTRAL LTDA\n'
          'CNPJ 12.345.678/0001-90\n'
          'PEDIDO 1234\n'
          'CLIENTE: CONSTRUTORA ALFA CNPJ 33.445.566/0001-86\n'
          'TOTAL R\$ 350,00');
      expect(nota.cnpj, lidoDaLoja);
    });
    test('DANFE: o do destinatário não vira o do emitente', () {
      final nota = OcrNotaService.parsearTexto('CASA DO CONSTRUTOR LTDA\n'
          'CNPJ\n'
          '12.345.678/0001-90\n'
          'DESTINATARIO / REMETENTE\n'
          'NOME / RAZAO SOCIAL\n'
          'CONSTRUTORA ALFA LTDA\n'
          'CNPJ / CPF\n'
          '33.445.566/0001-86\n'
          'VALOR TOTAL DA NOTA\n'
          '410,00');
      expect(nota.cnpj, lidoDaLoja);
    });
    test('nem o da software house ou o do contador', () {
      expect(
          OcrNotaService.parsearTexto('DEPOSITO CENTRAL LTDA\n'
                  'CNPJ 12.345.678/0001-90\n'
                  'Desenvolvido por Automa Sistemas CNPJ 04.567.890/0001-79')
              .cnpj,
          lidoDaLoja);
      expect(
          OcrNotaService.parsearTexto('CONSTRUMAIS LTDA\n'
                  'CNPJ 12.345.678/0001-90\n'
                  'CONTADOR 11.222.333/0001-81\nTOTAL 10,00')
              .cnpj,
          lidoDaLoja);
    });
    test('só CNPJ de terceiro na foto: fica vazio', () {
      final nota = OcrNotaService.parsearTexto('DEPOSITO CENTRAL LTDA\n'
          'CLIENTE: CONSTRUTORA ALFA CNPJ 33.445.566/0001-86\n'
          'TOTAL R\$ 350,00');
      expect(nota.cnpj, isNull);
    });
    test('com geometria, o do consumidor também fica de fora', () {
      final nota = OcrNotaService.interpretar(EntradaOcr([
        BlocoOcr([
          _l('DEPOSITO CENTRAL LTDA', 20, 20),
          _l('TOTAL R\$ 350,00', 20, 45),
          _l('CONSUMIDOR CNPJ 33.445.566/0001-86', 20, 70),
        ]),
      ]));
      expect(nota.cnpj, isNull);
    });
  });

  group('Revisão: a leitura para quando a tela fecha o leitor', () {
    // Os canais do ML Kit, simulados: o reconhecedor nativo que recebe
    // uma chamada depois de fechado é recriado e nunca mais é fechado.
    const canalTexto = MethodChannel('google_mlkit_text_recognizer');
    const canalCodigo = MethodChannel('google_mlkit_barcode_scanning');
    late Directory pasta;
    late String foto;
    late List<String> chamadas;
    late Completer<void> primeiraLeitura;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      pasta = await Directory.systemTemp.createTemp('ocr_dispose');
      foto = '${pasta.path}/nota.jpg';
      // foto sem texto: a leitura tentaria as quatro variantes
      await File(foto)
          .writeAsBytes(img.encodeJpg(img.Image(width: 400, height: 600)));
      chamadas = [];
      primeiraLeitura = Completer<void>();
      final mensageiro =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      mensageiro.setMockMethodCallHandler(canalTexto, (call) async {
        chamadas.add(call.method);
        if (call.method != 'vision#startTextRecognizer') return null;
        if (!primeiraLeitura.isCompleted) primeiraLeitura.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return {'text': '', 'blocks': <Object>[]};
      });
      mensageiro.setMockMethodCallHandler(canalCodigo, (call) async {
        chamadas.add('codigo:${call.method}');
        return call.method == 'vision#startBarcodeScanner' ? <Object>[] : null;
      });
    });

    tearDown(() async {
      final mensageiro =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      mensageiro.setMockMethodCallHandler(canalTexto, null);
      mensageiro.setMockMethodCallHandler(canalCodigo, null);
      await pasta.delete(recursive: true);
    });

    test('fechado no meio da leitura, nenhuma variante chama o ML Kit',
        () async {
      final ocr = OcrNotaService();
      final leitura = ocr.lerNota(foto);
      await primeiraLeitura.future;
      // o usuário volta da tela enquanto aparece "Lendo a nota fiscal…"
      ocr.dispose();
      final nota = await leitura;

      final fechou = chamadas.indexOf('vision#closeTextRecognizer');
      expect(fechou, isNot(-1));
      expect(chamadas.sublist(fechou + 1),
          isNot(contains('vision#startTextRecognizer')));
      // devolve o que a foto original deu, e não sobra arquivo de variante
      expect(nota.encontrouAlgo, isFalse);
      expect(pasta.listSync().map((e) => e.path.split('/').last), ['nota.jpg']);
    });

    test('depois de fechado, não reabre o reconhecedor', () async {
      final ocr = OcrNotaService()..dispose();
      chamadas.clear();
      await expectLater(ocr.lerNota(foto), throwsStateError);
      expect(chamadas, isEmpty);
    });
  });
}
